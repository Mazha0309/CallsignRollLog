import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as excel_lib;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/models/export_settings.dart';
import 'package:openlogtool/models/log_entry.dart';
import 'package:openlogtool/services/export_service.dart';

/// 极简 ADI 解析器：严格按声明的长度**逐字节**切片，用来验证导出自洽。
Map<String, String> _parseAdi(String text) {
  final bytes = utf8.encode(text);
  final fields = <String, String>{};
  var i = 0;
  while (i < bytes.length) {
    if (bytes[i] != 0x3C) {
      i++;
      continue;
    }
    final gt = bytes.indexOf(0x3E, i);
    if (gt < 0) break;
    final header = ascii.decode(bytes.sublist(i + 1, gt));
    i = gt + 1;
    final parts = header.split(':');
    if (parts.length < 2) continue;
    final length = int.tryParse(parts[1]);
    if (length == null) continue;
    fields[parts[0].toUpperCase()] = utf8.decode(bytes.sublist(i, i + length));
    i += length;
  }
  return fields;
}

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
      // 长度按 UTF-8 字节数声明（杭州 = 6 字节），不是字符数
      expect(files['BA4AAA'], contains('<QTH:6>杭州'));
    });

    test('declares UTF-8 byte lengths so non-ASCII fields round-trip', () {
      const qth = '宁波高新区';
      const device = '森海克斯 GT 12';
      final adif = ExportService.generateAdif(
        [
          LogEntry(
            id: 'log-1',
            time: '2026-10-05T20:31:00Z',
            controller: 'BG5CRL',
            callsign: 'BG5DBL',
            report: '59',
            rstRcvd: '59',
            qth: qth,
            device: device,
            power: '8W',
            antenna: '老鹰 770拉杆',
            height: '8楼',
            remarks: '首次上联',
          ),
        ],
        createdAt: DateTime.utc(2026, 10, 5, 13),
      );

      expect(adif, contains('<QTH:${utf8.encode(qth).length}>$qth'));

      // 按声明长度逐字节切片，应能完整还原中文值
      final parsed = _parseAdi(adif);
      expect(parsed['CALL'], 'BG5DBL');
      expect(parsed['QTH'], qth);
      expect(parsed['MY_RIG'], device);
      // TX_PWR 是数值字段，单位被去掉
      expect(parsed['TX_PWR'], '8');
      expect(parsed['RST_SENT'], '59');
    });

    test('honours the mode and band chosen for the export', () {
      final log = LogEntry(
        id: 'log-1',
        time: '2026-10-05T20:31:00Z',
        controller: 'BG5CRL',
        callsign: 'BG5DBL',
        report: '59',
        rstRcvd: '59',
        qth: 'PM00',
        device: '',
        power: '',
        antenna: '',
        height: '',
      );
      final adif = ExportService.generateAdif(
        [log],
        createdAt: DateTime.utc(2026, 10, 5),
        mode: 'USB',
        band: '70CM',
      );
      expect(adif, contains('<MODE:3>USB'));
      expect(adif, contains('<BAND:4>70CM'));

      // 按主控分组时同样要带上选择
      final files = ExportService.generateAdifByController(
        [log],
        createdAt: DateTime.utc(2026, 10, 5),
        mode: 'CW',
        band: '6M',
      );
      expect(files['BG5CRL'], contains('<MODE:2>CW'));
      expect(files['BG5CRL'], contains('<BAND:2>6M'));

      // 默认值仍是 FM / 2M
      final def = ExportService.generateAdif([log]);
      expect(def, contains('<MODE:2>FM'));
      expect(def, contains('<BAND:2>2M'));
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
