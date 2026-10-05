import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/services/crash_report_guidance.dart';

void main() {
  group('crashReportLocationsFor', () {
    test('points Windows at the OpenLogTool minidump directory', () {
      final locations = crashReportLocationsFor(
        operatingSystem: 'windows',
        environment: const {'LOCALAPPDATA': r'C:\Users\Klaus\AppData\Local'},
      );
      expect(locations, hasLength(1));
      expect(locations.single.directory, contains(r'\OpenLogTool\CrashDumps'));
      expect(locations.single.fileSuffix, '.dmp');
    });

    test('omits the Windows location when LOCALAPPDATA is unavailable', () {
      expect(
        crashReportLocationsFor(
          operatingSystem: 'windows',
          environment: const {},
        ),
        isEmpty,
      );
    });

    test('points macOS at the system diagnostic reports', () {
      final locations = crashReportLocationsFor(
        operatingSystem: 'macos',
        homeDirectory: '/Users/klaus',
      );
      expect(locations, hasLength(1));
      expect(
        locations.single.directory,
        '/Users/klaus/Library/Logs/DiagnosticReports',
      );
      expect(locations.single.fileSuffix, '.ips');
    });

    test('prefers XDG_DATA_HOME on Linux and keeps a core-dump hint', () {
      final locations = crashReportLocationsFor(
        operatingSystem: 'linux',
        environment: const {'XDG_DATA_HOME': '/data'},
      );
      expect(locations.first.directory, '/data/openlogtool/crashes');
      expect(locations.any((l) => l.hint?.contains('coredumpctl') ?? false),
          isTrue);
    });

    test('falls back to ~/.local/share on Linux', () {
      final locations = crashReportLocationsFor(
        operatingSystem: 'linux',
        homeDirectory: '/home/klaus',
        environment: const {},
      );
      expect(
        locations.first.directory,
        '/home/klaus/.local/share/openlogtool/crashes',
      );
    });

    test('returns nothing for platforms without desktop reports', () {
      expect(
        crashReportLocationsFor(operatingSystem: 'android'),
        isEmpty,
      );
    });
  });

  group('describeCrashReportLocations', () {
    test('lists newest matching artifacts first and skips other files',
        () async {
      final tmp = await Directory.systemTemp.createTemp('olt-crash-guidance');
      addTearDown(() => tmp.delete(recursive: true));
      final crashDir = Directory('${tmp.path}/openlogtool/crashes');
      await crashDir.create(recursive: true);

      final older = File('${crashDir.path}/older.log')
        ..writeAsStringSync('older');
      final newer = File('${crashDir.path}/newer.log')
        ..writeAsStringSync('newer content');
      File('${crashDir.path}/notes.txt').writeAsStringSync('ignore me');
      await older.setLastModified(DateTime.utc(2026, 1, 1));
      await newer.setLastModified(DateTime.utc(2026, 6, 1));

      final lines = await describeCrashReportLocations(
        operatingSystem: 'linux',
        environment: {'XDG_DATA_HOME': tmp.path},
      );

      expect(lines.any((l) => l.contains('newer.log')), isTrue);
      expect(lines.any((l) => l.contains('older.log')), isTrue);
      expect(lines.any((l) => l.contains('notes.txt')), isFalse);
      expect(
        lines.indexWhere((l) => l.contains('newer.log')),
        lessThan(lines.indexWhere((l) => l.contains('older.log'))),
      );
    });

    test('degrades to no lines when the directory is absent', () async {
      final lines = await describeCrashReportLocations(
        operatingSystem: 'windows',
        environment: const {'LOCALAPPDATA': r'Z:\definitely\missing'},
      );
      expect(lines, isEmpty);
    });
  });
}
