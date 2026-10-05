import 'dart:io';

import 'package:flutter/foundation.dart';

/// A platform-specific place that may hold crash artifacts for this
/// application.
///
/// Either [directory] (something we can inspect) or [hint] (an instruction
/// such as "run `coredumpctl list`") is set. [fileSuffix] narrows directory
/// listings to the artifact kind that matters on that platform.
@immutable
class CrashReportLocation {
  const CrashReportLocation({this.directory, this.fileSuffix, this.hint});

  /// Directory that may contain crash artifacts.
  final String? directory;

  /// Only files whose path ends with this suffix are reported.
  final String? fileSuffix;

  /// Human-readable instruction that does not map to a single directory.
  final String? hint;
}

/// Returns the crash-artifact locations for [operatingSystem].
///
/// Pure so tests can drive it with synthetic platforms. Paths follow the same
/// application-support roots that `path_provider` uses on each desktop
/// platform, so native handlers and the Dart log stay next to each other.
@visibleForTesting
List<CrashReportLocation> crashReportLocationsFor({
  required String operatingSystem,
  Map<String, String> environment = const <String, String>{},
  String? homeDirectory,
}) {
  final home =
      homeDirectory ?? environment['HOME'] ?? environment['USERPROFILE'];
  switch (operatingSystem) {
    case 'windows':
      final localAppData = environment['LOCALAPPDATA'];
      return <CrashReportLocation>[
        if (localAppData != null && localAppData.isNotEmpty)
          CrashReportLocation(
            directory: '$localAppData\\OpenLogTool\\CrashDumps',
            fileSuffix: '.dmp',
          ),
      ];
    case 'macos':
      // macOS has no in-process handler; the system writes symbolicated `.ips`
      // reports here and the app only points at them.
      return <CrashReportLocation>[
        if (home != null)
          CrashReportLocation(
            directory: '$home/Library/Logs/DiagnosticReports',
            fileSuffix: '.ips',
          ),
      ];
    case 'linux':
      final dataHome = (environment['XDG_DATA_HOME']?.isNotEmpty ?? false)
          ? environment['XDG_DATA_HOME']!
          : (home == null ? null : '$home/.local/share');
      return <CrashReportLocation>[
        if (dataHome != null)
          CrashReportLocation(
            directory: '$dataHome/openlogtool/crashes',
            fileSuffix: '.log',
          ),
        const CrashReportLocation(
          hint: 'System core dumps: run `coredumpctl list` (systemd) or check '
              '/var/crash (apport).',
        ),
      ];
    default:
      return const <CrashReportLocation>[];
  }
}

/// Returns human-readable lines describing where the previous run may have
/// left crash artifacts.
///
/// Never throws: a missing directory, a permission error, or a Web runtime all
/// degrade to fewer (or no) lines so diagnostics can never fail the caller.
Future<List<String>> describeCrashReportLocations({
  String? operatingSystem,
  Map<String, String>? environment,
  String? homeDirectory,
  int maxPerLocation = 3,
}) async {
  if (kIsWeb) return const <String>[];

  final locations = crashReportLocationsFor(
    operatingSystem: operatingSystem ?? Platform.operatingSystem,
    environment: environment ?? Platform.environment,
    homeDirectory: homeDirectory,
  );

  final lines = <String>[];
  for (final location in locations) {
    final hint = location.hint;
    if (hint != null && hint.isNotEmpty) {
      lines.add(hint);
    }
    final directory = location.directory;
    if (directory == null) continue;
    try {
      final dir = Directory(directory);
      if (!await dir.exists()) continue;
      final entries = <File>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        if (location.fileSuffix != null &&
            !entity.path.endsWith(location.fileSuffix!)) {
          continue;
        }
        entries.add(entity);
      }
      final stats = <({File file, FileStat stat})>[];
      for (final file in entries) {
        try {
          stats.add((file: file, stat: await file.stat()));
        } catch (_) {
          // Skip entries that vanish or cannot be stat'ed.
        }
      }
      stats.sort((a, b) => b.stat.modified.compareTo(a.stat.modified));
      for (final entry in stats.take(maxPerLocation)) {
        lines.add('${entry.file.path} (${entry.stat.size} bytes, '
            'modified ${entry.stat.modified.toIso8601String()})');
      }
    } catch (_) {
      // Diagnostics must never fail the caller.
    }
  }
  return lines;
}
