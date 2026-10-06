import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_lib;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/models/export_settings.dart';
import 'package:openlogtool/models/log_entry.dart';
import 'package:openlogtool/services/export_service.dart';

void main() {
  group('ExportService.generateFileName', () {
    final now = DateTime(2026, 8, 5, 14, 30, 45);

    test('replaces all time placeholders', () {
      final name = ExportService.generateFileName(
        '{yyyy}-{MM}-{dd}_{HH}{mm}{ss}',
        now,
      );
      expect(name, '2026-08-05_143045');
    });

    test('replaces {session} with the session title', () {
      final name = ExportService.generateFileName(
        '{session}_{yyyy}',
        now,
        sessionTitle: '2026年夏季点名',
      );
      expect(name, '2026年夏季点名_2026');
    });

    test('uses fallback when session title is missing', () {
      final name = ExportService.generateFileName(
        '{session}',
        now,
      );
      expect(name, 'session');
    });

    test('leaves the template unchanged when no placeholder matches', () {
      final name = ExportService.generateFileName('点名记录', now);
      expect(name, '点名记录');
    });

    test('uses the session title directly when the switch is on', () {
      final name = ExportService.generateFileName(
        '点名记录_{yyyy}-{MM}-{dd}',
        now,
        sessionTitle: '2026年夏季点名',
        useSessionTitle: true,
      );
      expect(name, '2026年夏季点名');
    });

    test('falls back to the template when the switch is on but title is blank',
        () {
      final name = ExportService.generateFileName(
        '{yyyy}-{MM}-{dd}',
        now,
        sessionTitle: '   ',
        useSessionTitle: true,
      );
      expect(name, '2026-08-05');
    });

    test('uses the template when the switch is off', () {
      final name = ExportService.generateFileName(
        '{session}_{yyyy}',
        now,
        sessionTitle: '2026年夏季点名',
        useSessionTitle: false,
      );
      expect(name, '2026年夏季点名_2026');
    });
  });

  group('ExportService web download metadata', () {
    test('web download uses exact filename and json mime', () {
      final meta = ExportService.webDownloadMeta(
        '点名记录_2026-08-05.json',
        Uint8List.fromList([1, 2, 3]),
        mimeType: 'application/json',
      );
      expect(meta.filename, '点名记录_2026-08-05.json');
      expect(meta.mimeType, 'application/json');
      expect(meta.bytes, [1, 2, 3]);
    });

    test('appends extension when filename lacks it', () {
      final meta = ExportService.webDownloadMeta(
        '点名记录',
        Uint8List.fromList([1]),
        mimeType: 'application/json',
        extension: '.json',
      );
      expect(meta.filename, '点名记录.json');
    });

    test('mime type mapping is case-insensitive', () {
      expect(ExportService.mimeTypeForExtension('JSON'), 'application/json');
      expect(ExportService.mimeTypeForExtension('xlsx'),
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      expect(ExportService.mimeTypeForExtension('csv'),
          'application/octet-stream');
      expect(
          ExportService.mimeTypeForExtension(null), 'application/octet-stream');
    });

    test('maps adif mime type', () {
      expect(ExportService.mimeTypeForExtension('adi'), 'text/plain');
      expect(ExportService.mimeTypeForExtension('ADIF'), 'text/plain');
    });

    test('does not append extension when already present', () {
      final meta = ExportService.webDownloadMeta(
        '点名记录.xlsx',
        Uint8List.fromList([1]),
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        extension: '.xlsx',
      );
      expect(meta.filename, '点名记录.xlsx');
    });
  });

  test('Excel data rows use the configured table background color', () {
    final bytes = ExportService.generateExcelBytes(
      [
        LogEntry(
          id: 'log-1',
          time: '20:01',
          controller: 'BG5CRL',
          callsign: 'BG5CRL',
          report: '59',
          rstRcvd: '59',
          qth: '杭州',
          device: 'FT-991A',
          power: '15W',
          antenna: '八木',
          height: '5米',
        ),
      ],
      ExportSettings(
        tableBackgroundColor: const Color(0xFF123456),
        useAlternateColors: false,
        showFooter: false,
      ),
      DateTime(2026, 8, 23),
    );

    expect(bytes, isNotNull);
    final workbook = excel_lib.Excel.decodeBytes(bytes!);
    final cell = workbook['点名记录'].cell(excel_lib.CellIndex.indexByString('A4'));
    expect(cell.cellStyle?.backgroundColor.colorHex, 'FF123456');
  });

  group('ExportService.generateAdif', () {
    test('writes LoTW fields with station callsign as controller', () {
      final adif = ExportService.generateAdif(
        [
          LogEntry(
            id: 'log-1',
            time: '2026-07-13T12:01:00Z',
            controller: 'BG5CRL',
            callsign: 'BG5CRL',
            report: '59',
            rstRcvd: '57',
            qth: 'PM00de',
            device: 'FT-991A',
            power: '50W',
            antenna: 'GP',
            height: '8m',
            remarks: 'net check-in',
          ),
        ],
        createdAt: DateTime.utc(2026, 7, 13, 12, 30),
      );

      expect(adif, contains('<ADIF_VER:5>3.1.4'));
      expect(adif, contains('<PROGRAMID:17>Callsign Roll Log'));
      expect(adif, contains('<CALL:6>BG5CRL'));
      expect(adif, contains('<STATION_CALLSIGN:6>BG5CRL'));
      expect(adif, contains('<OPERATOR:6>BG5CRL'));
      expect(adif, contains('<QSO_DATE:8>20260713'));
      expect(adif, contains('<TIME_ON:4>1201'));
      expect(adif, contains('<MODE:2>FM'));
      expect(adif, contains('<BAND:2>2M'));
      expect(adif, contains('<RST_SENT:2>59'));
      expect(adif, contains('<RST_RCVD:2>57'));
      expect(adif, contains('<GRIDSQUARE:6>PM00DE'));
      expect(adif, isNot(contains('<COMMENT')));
      expect(adif, isNot(contains('<NOTES')));
      expect(adif, isNot(contains('APP_OPENLOGTOOL')));
      expect(adif, contains('<EOR>'));
    });

    test('splits one ADIF file per controller', () {
      final files = ExportService.generateAdifByController([
        LogEntry(
          id: 'log-1',
          time: '2026-07-13T12:00:00Z',
          controller: 'BG5CRL',
          callsign: 'BG5CRL',
          report: '59',
          rstRcvd: '59',
          qth: 'PM00',
          device: '',
          power: '',
          antenna: '',
          height: '',
        ),
        LogEntry(
          id: 'log-2',
          time: '2026-07-13T12:05:00Z',
          controller: 'ba4aaa',
          callsign: 'BD4BBB',
          report: '59',
          rstRcvd: '59',
          qth: '杭州',
          device: '',
          power: '',
          antenna: '',
          height: '',
        ),
        LogEntry(
          id: 'log-3',
          time: '2026-07-13T12:10:00Z',
          controller: 'BG5CRL',
          callsign: 'BG5GEH',
          report: '59',
          rstRcvd: '59',
          qth: '',
          device: '',
          power: '',
          antenna: '',
          height: '',
        ),
      ], createdAt: DateTime.utc(2026, 7, 13));

      expect(files.keys.toList()..sort(), ['BA4AAA', 'BG5CRL']);
      expect(files['BG5CRL'], contains('<CALL:6>BG5CRL'));
      expect(files['BG5CRL'], contains('<CALL:6>BG5GEH'));
      expect(files['BG5CRL'], contains('<STATION_CALLSIGN:6>BG5CRL'));
      expect(files['BG5CRL'], isNot(contains('BD4BBB')));
      expect(files['BA4AAA'], contains('<CALL:6>BD4BBB'));
      expect(files['BA4AAA'], contains('<STATION_CALLSIGN:6>BA4AAA'));
      expect(files['BA4AAA'], contains('<QTH:2>杭州'));
    });

    test('clock-only time uses the log createdAt date', () {
      final adif = ExportService.generateAdif(
        [
          LogEntry(
            id: 'log-2',
            time: '20:15',
            controller: 'BA4AAA',
            callsign: 'BD4BBB',
            report: '599',
            rstRcvd: '',
            qth: '杭州',
            device: '',
            power: '15',
            antenna: '',
            height: '',
            remarks: '',
            createdAt: '2026-08-19T01:00:00Z',
          ),
        ],
        createdAt: DateTime.utc(2026, 1, 1),
      );

      expect(adif, contains('<QSO_DATE:8>20260819'));
      expect(adif, contains('<TIME_ON:4>2015'));
      expect(adif, contains('<TX_PWR:2>15'));
    });

    test('packs multiple controller ADIF files into a zip', () {
      final bytes = ExportService.generateAdifArchiveBytes({
        'BG5CRL': 'ADI-A',
        'BA4AAA': 'ADI-B',
      });
      expect(bytes, isNotEmpty);
    });
  });
}
