import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart' as logging;
import 'package:openlogtool/services/crash_report_guidance.dart';
import 'package:openlogtool/services/key_value_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum AppLogLevel { debug, info, warning, error }

@immutable
class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.source,
    this.error,
    this.stackTrace,
  });

  factory AppLogEntry.fromJson(Object? value) {
    if (value is! Map) throw const FormatException('log entry is not a map');
    final json = value.cast<String, Object?>();
    final timestamp = DateTime.tryParse(json['timestamp']?.toString() ?? '');
    final levelName = json['level']?.toString();
    if (timestamp == null || levelName == null) {
      throw const FormatException('invalid log entry');
    }
    return AppLogEntry(
      timestamp: timestamp,
      level: AppLogLevel.values.firstWhere(
        (candidate) => candidate.name == levelName,
        orElse: () => AppLogLevel.info,
      ),
      message: json['message']?.toString() ?? '',
      source: json['source']?.toString() ?? 'legacy',
      error: json['error']?.toString(),
      stackTrace: json['stackTrace']?.toString(),
    );
  }

  final DateTime timestamp;
  final AppLogLevel level;
  final String message;
  final String source;
  final String? error;
  final String? stackTrace;

  Map<String, Object?> toJson() => <String, Object?>{
        'timestamp': timestamp.toIso8601String(),
        'level': level.name,
        'message': message,
        'source': source,
        if (error != null && error!.isNotEmpty) 'error': error,
        if (stackTrace != null && stackTrace!.isNotEmpty)
          'stackTrace': stackTrace,
      };

  String get searchableText => <String>[
        timestamp.toIso8601String(),
        level.name,
        source,
        message,
        if (error != null) error!,
        if (stackTrace != null) stackTrace!,
      ].join('\n').toLowerCase();

  String toDisplayString() {
    final buffer = StringBuffer()
      ..write(timestamp.toLocal().toIso8601String())
      ..write(' [${level.name.toUpperCase()}]')
      ..write(' [$source] ')
      ..write(message);
    if (error != null && error!.isNotEmpty) {
      buffer
        ..write('\n  ')
        ..write(error);
    }
    if (stackTrace != null && stackTrace!.isNotEmpty) {
      buffer
        ..write('\n')
        ..write(stackTrace);
    }
    return buffer.toString();
  }
}

/// Application-wide diagnostic log.
///
/// Native builds keep JSON-lines files in the application support directory
/// with bounded rotation. Web builds keep a bounded structured snapshot in the
/// same IndexedDB-backed key/value store as the rest of the application. The
/// in-memory list is also a [ChangeNotifier], allowing the diagnostics dialog
/// to update while it remains open.
class AppLogger extends ChangeNotifier {
  AppLogger._() {
    logging.Logger.root.level = logging.Level.ALL;
    logging.Logger.root.onRecord.listen(_onRecord);
  }

  static final AppLogger instance = AppLogger._();

  static const int ringCapacity = 2000;
  static const int webPersistCapacity = 1200;
  static const int fileMaxBytes = 5 * 1024 * 1024;
  static const int fileKeepCount = 5;
  static const String _webLogKey = 'diagnostic_logs_v2';
  static const String _webRunningKey = 'diagnostic_run_active_v1';

  final List<AppLogEntry> _entries = <AppLogEntry>[];
  File? _file;
  File? _runMarker;
  KeyValueStore? _webStore;
  Future<void> _writeChain = Future<void>.value();
  bool _notifyScheduled = false;
  bool _initialized = false;
  DebugPrintCallback? _capturedDebugPrint;

  List<AppLogEntry> snapshotEntries() =>
      List<AppLogEntry>.unmodifiable(_entries);

  /// Compatibility view used by older call sites and text exports.
  List<String> snapshot() =>
      _entries.map((entry) => entry.toDisplayString()).toList(growable: false);

  void resetForTest() {
    _entries.clear();
    _file = null;
    _runMarker = null;
    _webStore = null;
    _writeChain = Future<void>.value();
    _notifyScheduled = false;
    _initialized = false;
  }

  Future<void> flushForTest() => _writeChain;

  Future<void> initForTest({required Directory logDir}) async {
    await _initializeNative(logDir, markRunActive: false);
    _initialized = true;
  }

  Future<void> init({
    Directory? logDirOverride,
    bool trackRunState = true,
  }) async {
    if (_initialized) return;
    logging.Logger.root.level = logging.Level.ALL;
    var previousRunMayHaveCrashed = false;
    try {
      if (kIsWeb) {
        _webStore = await openKeyValueStore();
        previousRunMayHaveCrashed = await _webStore!.getBool(_webRunningKey);
        await _loadWebEntries();
        await _webStore!.setBool(_webRunningKey, true);
      } else {
        final directory = logDirOverride ??
            Directory(
              p.join(
                (await getApplicationSupportDirectory()).path,
                'logs',
              ),
            );
        previousRunMayHaveCrashed =
            await _initializeNative(directory, markRunActive: trackRunState);
      }
    } catch (error, stackTrace) {
      // Do not feed storage failures back into this logger: a full disk or a
      // denied directory must not create an infinite logging loop.
      debugPrintSynchronously(
        'AppLogger persistence setup failed; using memory only: '
        '$error\n$stackTrace',
      );
    }
    _initialized = true;
    info('Diagnostic logging initialized (web=$kIsWeb, persistent='
        '${_file != null || _webStore != null})');
    if (previousRunMayHaveCrashed) {
      warn(
        'The previous process did not record a clean shutdown. Review the '
        'preceding entries and the platform crash report if one is available.',
      );
      try {
        final locations = await describeCrashReportLocations();
        if (locations.isNotEmpty) {
          log(
            AppLogLevel.info,
            'Crash artifacts to inspect for the previous run:',
            source: 'CrashReports',
          );
          for (final location in locations) {
            log(AppLogLevel.info, location, source: 'CrashReports');
          }
        }
      } catch (error) {
        debugPrintSynchronously(
          'AppLogger could not locate crash reports: $error',
        );
      }
    }
  }

  Future<bool> _initializeNative(
    Directory directory, {
    required bool markRunActive,
  }) async {
    await directory.create(recursive: true);
    _file = File(p.join(directory.path, 'app.log'));
    await _loadNativeEntries();
    if (!markRunActive) return false;
    _runMarker = File(p.join(directory.path, '.run-active'));
    final previousRunMayHaveCrashed = await _runMarker!.exists();
    await _runMarker!.writeAsString(DateTime.now().toUtc().toIso8601String());
    return previousRunMayHaveCrashed;
  }

  Future<void> _loadNativeEntries() async {
    final file = _file;
    if (file == null) return;
    final loaded = <AppLogEntry>[];
    for (var suffix = fileKeepCount; suffix >= 1; suffix -= 1) {
      await _readNativeFile(File('${file.path}.$suffix'), loaded);
    }
    await _readNativeFile(file, loaded);
    _mergePersistedEntries(loaded);
  }

  Future<void> _readNativeFile(
    File file,
    List<AppLogEntry> destination,
  ) async {
    if (!await file.exists()) return;
    for (final line in await file.readAsLines()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        destination.add(AppLogEntry.fromJson(jsonDecode(trimmed)));
      } catch (_) {
        destination.add(_legacyEntry(trimmed));
      }
    }
  }

  Future<void> _loadWebEntries() async {
    final encoded = await _webStore?.getString(_webLogKey);
    if (encoded == null || encoded.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return;
      _mergePersistedEntries(
        decoded.map(AppLogEntry.fromJson).toList(growable: false),
      );
    } catch (error) {
      debugPrintSynchronously('AppLogger could not restore Web logs: $error');
    }
  }

  void _mergePersistedEntries(List<AppLogEntry> persisted) {
    if (persisted.isEmpty) return;
    final current = List<AppLogEntry>.of(_entries);
    _entries
      ..clear()
      ..addAll(persisted)
      ..addAll(current);
    _trimRing();
    _scheduleNotify();
  }

  AppLogEntry _legacyEntry(String line) {
    final match = RegExp(
      r'^(\d{4}-\d\d-\d\dT\S+) \[(\w+)\] (.*)$',
    ).firstMatch(line);
    final levelName = match?.group(2)?.toLowerCase();
    return AppLogEntry(
      timestamp: DateTime.tryParse(match?.group(1) ?? '') ?? DateTime.now(),
      level: switch (levelName) {
        'fine' || 'finer' || 'finest' || 'debug' => AppLogLevel.debug,
        'warning' || 'warn' => AppLogLevel.warning,
        'severe' || 'shout' || 'error' => AppLogLevel.error,
        _ => AppLogLevel.info,
      },
      message: match?.group(3) ?? line,
      source: 'legacy',
    );
  }

  void _onRecord(logging.LogRecord record) {
    final entry = AppLogEntry(
      timestamp: record.time,
      level: _levelFromLogging(record.level),
      message: record.message,
      source: record.loggerName.isEmpty ? 'OpenLogTool' : record.loggerName,
      error: record.error?.toString(),
      stackTrace: record.stackTrace?.toString(),
    );
    _entries.add(entry);
    _trimRing();
    _scheduleNotify();
    if (kIsWeb) debugPrintSynchronously(entry.toDisplayString());
    _queuePersistence(() => _persistEntry(entry));
  }

  void _trimRing() {
    final overflow = _entries.length - ringCapacity;
    if (overflow > 0) _entries.removeRange(0, overflow);
  }

  void _scheduleNotify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    Future<void>.microtask(() {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  void _queuePersistence(Future<void> Function() operation) {
    _writeChain = _writeChain.then((_) => operation()).catchError(
      (Object error, StackTrace stackTrace) {
        debugPrintSynchronously('AppLogger persistence write failed: $error');
      },
    );
  }

  Future<void> _persistEntry(AppLogEntry entry) async {
    final webStore = _webStore;
    if (webStore != null) {
      final first = _entries.length > webPersistCapacity
          ? _entries.length - webPersistCapacity
          : 0;
      await webStore.setString(
        _webLogKey,
        jsonEncode(
          _entries
              .sublist(first)
              .map((candidate) => candidate.toJson())
              .toList(growable: false),
        ),
      );
      return;
    }

    final file = _file;
    if (file == null) return;
    final line = '${jsonEncode(entry.toJson())}\n';
    if (await file.exists() &&
        await file.length() + utf8.encode(line).length > fileMaxBytes) {
      await _rotateFiles(file);
    }
    await file.writeAsString(line, mode: FileMode.append, flush: true);
  }

  Future<void> _rotateFiles(File file) async {
    final oldest = File('${file.path}.$fileKeepCount');
    if (await oldest.exists()) await oldest.delete();
    for (var suffix = fileKeepCount - 1; suffix >= 1; suffix -= 1) {
      final source = File('${file.path}.$suffix');
      if (!await source.exists()) continue;
      final destination = File('${file.path}.${suffix + 1}');
      if (await destination.exists()) await destination.delete();
      await source.rename(destination.path);
    }
    if (await file.exists()) {
      final first = File('${file.path}.1');
      if (await first.exists()) await first.delete();
      await file.rename(first.path);
    }
    _file = File(file.path);
  }

  Future<void> clear() async {
    _entries.clear();
    // Clearing is an explicit UI action, so publish it immediately. Regular
    // high-frequency writes remain microtask-coalesced by [_scheduleNotify].
    notifyListeners();
    _queuePersistence(() async {
      final webStore = _webStore;
      if (webStore != null) {
        await webStore.remove(_webLogKey);
        return;
      }
      final file = _file;
      if (file == null) return;
      for (var suffix = fileKeepCount; suffix >= 1; suffix -= 1) {
        final rotated = File('${file.path}.$suffix');
        if (await rotated.exists()) await rotated.delete();
      }
      if (await file.exists()) await file.delete();
    });
    await _writeChain;
  }

  /// Marks lifecycle detach as intentional. If the process is terminated
  /// before this completes, the next startup retains a diagnostic warning.
  Future<void> markCleanShutdown() async {
    info('Application lifecycle detached');
    _queuePersistence(() async {
      if (_webStore != null) {
        await _webStore!.setBool(_webRunningKey, false);
      }
      final marker = _runMarker;
      if (marker != null && await marker.exists()) await marker.delete();
    });
    await _writeChain;
  }

  /// Mirrors legacy [debugPrint] calls into the persistent diagnostic stream.
  /// This lets older providers contribute useful breadcrumbs while they are
  /// migrated to structured logging. The original console callback still runs.
  void installDebugPrintCapture() {
    if (_capturedDebugPrint != null) return;
    final original = debugPrint;
    _capturedDebugPrint = original;
    debugPrint = (String? message, {int? wrapWidth}) {
      final text = message?.trim();
      if (text != null && text.isNotEmpty) {
        final normalized = text.toLowerCase();
        final level = normalized.contains('error') ||
                normalized.contains('failed') ||
                normalized.contains('exception')
            ? AppLogLevel.warning
            : AppLogLevel.debug;
        log(level, text, source: 'DebugPrint');
      }
      original(message, wrapWidth: wrapWidth);
    };
    info('Legacy debugPrint capture enabled');
  }

  void log(
    AppLogLevel level,
    String message, {
    String source = 'OpenLogTool',
    Object? error,
    StackTrace? stackTrace,
  }) {
    logging.Logger(source).log(
      _loggingLevel(level),
      message,
      error,
      stackTrace,
    );
  }

  void debug(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.fine(message, error, stackTrace);

  void info(String message) => _logger.info(message);

  void warn(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.warning(message, error, stackTrace);

  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.severe(message, error, stackTrace);

  final logging.Logger _logger = logging.Logger('OpenLogTool');

  static AppLogLevel _levelFromLogging(logging.Level level) {
    if (level >= logging.Level.SEVERE) return AppLogLevel.error;
    if (level >= logging.Level.WARNING) return AppLogLevel.warning;
    if (level >= logging.Level.INFO) return AppLogLevel.info;
    return AppLogLevel.debug;
  }

  static logging.Level _loggingLevel(AppLogLevel level) => switch (level) {
        AppLogLevel.debug => logging.Level.FINE,
        AppLogLevel.info => logging.Level.INFO,
        AppLogLevel.warning => logging.Level.WARNING,
        AppLogLevel.error => logging.Level.SEVERE,
      };
}
