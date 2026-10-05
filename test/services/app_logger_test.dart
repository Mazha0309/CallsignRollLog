import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/services/app_logger.dart';

void main() {
  tearDown(() {
    AppLogger.instance.resetForTest();
  });

  test('writes entries to ring buffer', () {
    AppLogger.instance.debug('d1');
    AppLogger.instance.info('i1');
    AppLogger.instance.error('e1', StackTrace.current);
    final lines = AppLogger.instance.snapshot();
    expect(lines.any((l) => l.contains('d1')), isTrue);
    expect(lines.any((l) => l.contains('i1')), isTrue);
    expect(lines.any((l) => l.contains('e1')), isTrue);
  });

  test('keeps structured levels, sources, errors, and stacks', () {
    final stack = StackTrace.current;
    AppLogger.instance.log(
      AppLogLevel.error,
      'synchronization failed',
      source: 'CollaborationSync',
      error: StateError('offline'),
      stackTrace: stack,
    );

    final entry = AppLogger.instance.snapshotEntries().single;
    expect(entry.level, AppLogLevel.error);
    expect(entry.source, 'CollaborationSync');
    expect(entry.error, contains('offline'));
    expect(entry.stackTrace, isNotEmpty);
    expect(entry.searchableText, contains('synchronization failed'));
  });

  test('warns and locates crash reports after an unclean shutdown', () async {
    final dir = await Directory.systemTemp.createTemp('olt-log-crash-test');
    addTearDown(() => dir.delete(recursive: true));
    // A run marker that was never cleared mimics a process that died.
    await File('${dir.path}/.run-active').writeAsString('2026-01-01T00:00:00Z');

    await AppLogger.instance.init(logDirOverride: dir, trackRunState: true);

    final entries = AppLogger.instance.snapshotEntries();
    expect(
      entries.any((entry) => entry.message.contains('clean shutdown')),
      isTrue,
    );
    // Linux always contributes a core-dump hint, so the locator reports at
    // least one line there; other platforms may legitimately find nothing.
    if (Platform.operatingSystem == 'linux') {
      expect(
        entries.any((entry) => entry.source == 'CrashReports'),
        isTrue,
      );
    }
    // Drain queued writes before tearDown deletes the temporary directory.
    await AppLogger.instance.flushForTest();
  });

  test('rotates ring buffer at capacity', () {
    for (var i = 0; i < AppLogger.ringCapacity + 100; i++) {
      AppLogger.instance.info('msg$i');
    }
    final lines = AppLogger.instance.snapshot();
    expect(lines.length, AppLogger.ringCapacity);
    expect(lines.any((l) => l.contains('msg0')), isFalse);
    expect(
      lines.any((l) => l.contains('msg${AppLogger.ringCapacity + 99}')),
      isTrue,
    );
  });

  test('writes to file with rotation', () async {
    final dir = await Directory.systemTemp.createTemp('olt-log-test');
    addTearDown(() => dir.delete(recursive: true));
    await AppLogger.instance.initForTest(logDir: dir);
    AppLogger.instance.error('boom', StackTrace.current);
    await AppLogger.instance.flushForTest();
    final file = File('${dir.path}/app.log');
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync().contains('boom'), isTrue);
  });

  test('restores persisted entries and can clear them', () async {
    final dir = await Directory.systemTemp.createTemp('olt-log-restore-test');
    addTearDown(() => dir.delete(recursive: true));
    await AppLogger.instance.initForTest(logDir: dir);
    AppLogger.instance.log(
      AppLogLevel.warning,
      'remember me',
      source: 'PersistenceTest',
    );
    await AppLogger.instance.flushForTest();

    AppLogger.instance.resetForTest();
    await AppLogger.instance.initForTest(logDir: dir);
    final restored = AppLogger.instance.snapshotEntries();
    expect(restored.any((entry) => entry.message == 'remember me'), isTrue);
    expect(
      restored.any((entry) => entry.source == 'PersistenceTest'),
      isTrue,
    );

    await AppLogger.instance.clear();
    expect(AppLogger.instance.snapshotEntries(), isEmpty);
    expect(File('${dir.path}/app.log').existsSync(), isFalse);
  });
}
