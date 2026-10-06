import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:openlogtool/config/version.dart';
import 'package:openlogtool/models/export_settings.dart';
import 'package:openlogtool/models/log_entry.dart';
import 'package:openlogtool/utils/log_time.dart';
import 'package:openlogtool/services/export_web_download.dart'
    if (dart.library.io) 'package:openlogtool/services/export_web_download_stub.dart'
    as web_dl;

class ExportSaveResult {
  final String? path;
  final bool usedSaf;
  final bool cancelled;

  const ExportSaveResult({
    this.path,
    this.usedSaf = false,
    this.cancelled = false,
  });
}

/// Web 端浏览器原生下载的元数据。
class WebDownloadMeta {
  final String filename;
  final String mimeType;
  final List<int> bytes;

  const WebDownloadMeta({
    required this.filename,
    required this.mimeType,
    required this.bytes,
  });
}

class ExportService {
  /// 根据配置的平台路径和平台类型，解析实际可用的导出路径。
  static Future<String?> resolveExportPath(String configuredPath) async {
    if (kIsWeb) return null;
    if (!Platform.isAndroid && configuredPath.isNotEmpty) {
      return configuredPath;
    }

    final directory = await getDownloadsDirectory();
    return directory?.path;
  }

  /// 判断当前 [configuredPath] 是否在 Android 上需要走 SAF 文件选择器。
  /// 桌面端始终返回 false。
  static Future<bool> shouldUseSaf(String configuredPath) async {
    // Web file downloads also have to go through the browser picker because
    // dart:io paths are unavailable.
    if (kIsWeb) return true;
    if (!Platform.isAndroid) {
      return false;
    }

    final normalizedConfiguredPath = configuredPath.trim();
    if (normalizedConfiguredPath.isEmpty) {
      return false;
    }

    final downloadsDirectory = await getDownloadsDirectory();
    final downloadsPath = downloadsDirectory?.path;
    if (downloadsPath == null) {
      return true;
    }

    final normalizedDownloadsPath = _normalizePath(downloadsPath);
    final normalizedConfigured = _normalizePath(normalizedConfiguredPath);

    return !(normalizedConfigured == normalizedDownloadsPath ||
        normalizedConfigured.startsWith('$normalizedDownloadsPath/'));
  }

  /// 保存二进制数据到文件。
  /// Android 上如需 SAF，使用 [FilePicker.saveFile]；其余平台直接写文件。
  /// Web 上使用浏览器原生下载（Blob + AnchorElement），不走 file_picker。
  static Future<ExportSaveResult> saveFile({
    required String configuredPath,
    required String filename,
    required Uint8List bytes,
    required String dialogTitle,
    required List<String> allowedExtensions,
  }) async {
    if (kIsWeb) {
      final ext = allowedExtensions.firstOrNull;
      final mime = mimeTypeForExtension(ext);
      return downloadOnWeb(webDownloadMeta(
        filename,
        bytes,
        mimeType: mime,
        extension: ext == null ? null : '.$ext',
      ));
    }

    if (await shouldUseSaf(configuredPath)) {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        bytes: bytes,
      );

      if (result == null) {
        return const ExportSaveResult(cancelled: true, usedSaf: true);
      }

      return ExportSaveResult(path: result, usedSaf: true);
    }

    final exportPath = await resolveExportPath(configuredPath);
    if (exportPath == null) {
      return const ExportSaveResult();
    }

    final file = File(p.join(exportPath, filename));
    await file.writeAsBytes(bytes);
    return ExportSaveResult(path: file.path, usedSaf: false);
  }

  /// 根据扩展名返回下载 MIME 类型（大小写不敏感）。
  static String mimeTypeForExtension(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'json':
        return 'application/json';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'adi':
      case 'adif':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  /// 组装 Web 下载元数据；[extension] 缺失时自动补全扩展名。
  static WebDownloadMeta webDownloadMeta(
    String filename,
    List<int> bytes, {
    required String mimeType,
    String? extension,
  }) {
    var name = filename;
    if (extension != null && !name.endsWith(extension)) {
      name = '$name$extension';
    }
    return WebDownloadMeta(filename: name, mimeType: mimeType, bytes: bytes);
  }

  /// Web 端浏览器原生下载（绕过 file_picker 的文件名/返回 bug）。
  /// 实际实现按平台条件导入：Web 用 Blob + AnchorElement，dart:io 为占位。
  static Future<ExportSaveResult> downloadOnWeb(WebDownloadMeta meta) =>
      web_dl.downloadOnWeb(meta);

  /// 从模板和当前时间生成导出文件名。
  /// 模板支持 {yyyy} {MM} {dd} {HH} {mm} {ss} 以及可选的 {session}（会话名）。
  /// [useSessionTitle] 开启且会话名非空时，文件名直接使用会话名。
  static String generateFileName(
    String template,
    DateTime now, {
    String? sessionTitle,
    bool useSessionTitle = false,
  }) {
    final normalizedSessionTitle = sessionTitle?.trim() ?? '';
    if (useSessionTitle && normalizedSessionTitle.isNotEmpty) {
      return normalizedSessionTitle;
    }

    String filename = template;
    filename = filename.replaceAll('{yyyy}', now.year.toString());
    filename =
        filename.replaceAll('{MM}', now.month.toString().padLeft(2, '0'));
    filename = filename.replaceAll('{dd}', now.day.toString().padLeft(2, '0'));
    filename = filename.replaceAll('{HH}', now.hour.toString().padLeft(2, '0'));
    filename =
        filename.replaceAll('{mm}', now.minute.toString().padLeft(2, '0'));
    filename =
        filename.replaceAll('{ss}', now.second.toString().padLeft(2, '0'));
    if (sessionTitle != null && sessionTitle.isNotEmpty) {
      filename = filename.replaceAll('{session}', sessionTitle);
    } else {
      filename = filename.replaceAll('{session}', 'session');
    }
    return filename;
  }

  static String _normalizePath(String path) {
    var normalized = path.replaceAll('\\', '/').trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  /// 将日志列表序列化为 JSON 字符串的字节。
  static Uint8List generateJsonBytes(List<LogEntry> logs) {
    final jsonData = logs.map((log) => log.toJson()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  static Uint8List generateAdifBytes(
    List<LogEntry> logs, {
    DateTime? createdAt,
  }) {
    return Uint8List.fromList(
      utf8.encode(generateAdif(logs, createdAt: createdAt)),
    );
  }

  static Map<String, String> generateAdifByController(
    List<LogEntry> logs, {
    DateTime? createdAt,
  }) {
    final grouped = <String, List<LogEntry>>{};
    for (final log in logs) {
      final controller = log.controller.trim().toUpperCase();
      if (controller.isEmpty) continue;
      grouped.putIfAbsent(controller, () => []).add(log);
    }
    return {
      for (final entry in grouped.entries)
        entry.key: generateAdif(
          entry.value,
          createdAt: createdAt,
          stationCallsign: entry.key,
        ),
    };
  }

  static Uint8List generateAdifArchiveBytes(
    Map<String, String> files, {
    String Function(String stationCallsign)? fileNameForStation,
  }) {
    final archive = Archive();
    files.forEach((station, contents) {
      final name = fileNameForStation?.call(station) ?? '$station.adi';
      final encoded = utf8.encode(contents);
      archive.addFile(ArchiveFile(name, encoded.length, encoded));
    });
    return Uint8List.fromList(ZipEncoder().encode(archive) ?? const <int>[]);
  }

  static String generateAdif(
    List<LogEntry> logs, {
    DateTime? createdAt,
    String? stationCallsign,
  }) {
    final created = (createdAt ?? DateTime.now()).toUtc();
    final buffer = StringBuffer()
      ..writeln('ADIF export from OpenLogTool')
      ..write(_adifField('ADIF_VER', '3.1.4'))
      ..write(_adifField('PROGRAMID', 'OpenLogTool'))
      ..write(_adifField('PROGRAMVERSION', appVersion))
      ..write(_adifField(
        'CREATED_TIMESTAMP',
        '${_adifDate(created)} ${_adifTime(created, includeSeconds: true)}',
      ))
      ..writeln('<EOH>');

    for (final log in logs) {
      final operator = log.controller.trim().toUpperCase();
      final station = (stationCallsign ?? operator).trim().toUpperCase();
      final qsoTime = _adifQsoDateTime(log.time, fallback: log.createdAt);
      buffer.write(_adifField('CALL', log.callsign.trim().toUpperCase()));
      buffer.write(_adifField('STATION_CALLSIGN', station));
      buffer.write(_adifField('OPERATOR', operator));
      if (qsoTime != null) {
        buffer.write(_adifField('QSO_DATE', _adifDate(qsoTime)));
        buffer.write(_adifField('TIME_ON', _adifTime(qsoTime)));
      }
      buffer.write(_adifField('MODE', 'FM'));
      buffer.write(_adifField('BAND', '2M'));
      buffer.write(_adifField('RST_SENT', log.report.trim()));
      buffer.write(_adifField('RST_RCVD', log.rstRcvd.trim()));
      final qth = log.qth.trim();
      final grid = _adifGridSquare(qth);
      if (grid != null) {
        buffer.write(_adifField('GRIDSQUARE', grid));
      } else {
        buffer.write(_adifField('QTH', qth));
      }
      buffer.write(_adifField('MY_RIG', log.device.trim()));
      buffer.write(_adifField('TX_PWR', _adifPower(log.power)));
      buffer.writeln('<EOR>');
    }
    return buffer.toString();
  }

  static String _adifField(String name, String value) {
    if (value.isEmpty) return '';
    return '<$name:${value.length}>$value';
  }

  static DateTime? _adifQsoDateTime(String raw, {String? fallback}) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return DateTime.tryParse(fallback ?? '')?.toUtc();
    final parsed = DateTime.tryParse(normalized);
    if (parsed != null) return parsed.toUtc();
    final match =
        RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(normalized);
    if (match == null) return DateTime.tryParse(fallback ?? '')?.toUtc();
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final second = int.parse(match.group(3) ?? '0');
    final reference =
        DateTime.tryParse(fallback ?? '')?.toUtc() ?? DateTime.now().toUtc();
    return DateTime.utc(
      reference.year,
      reference.month,
      reference.day,
      hour,
      minute,
      second,
    );
  }

  static String _adifDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';

  static String _adifTime(DateTime value, {bool includeSeconds = false}) {
    final time = '${value.hour.toString().padLeft(2, '0')}'
        '${value.minute.toString().padLeft(2, '0')}';
    if (!includeSeconds) return time;
    return '$time${value.second.toString().padLeft(2, '0')}';
  }

  static String? _adifGridSquare(String value) {
    final match = RegExp(r'^[A-Ra-r]{2}\d{2}([A-Xa-x]{2})?$').firstMatch(value);
    if (match == null) return null;
    return value.toUpperCase();
  }

  static String _adifPower(String value) {
    final match = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(value.trim());
    return match?.group(1) ?? value.trim();
  }

  /// 根据日志列表和导出设置生成 Excel 文件字节。
  static Uint8List? generateExcelBytes(
    List<LogEntry> logs,
    ExportSettings settings,
    DateTime now, {
    String? sessionTitle,
  }) {
    const headers = <String>[
      '#',
      '时间',
      '呼号',
      'RST发',
      'RST收',
      'QTH',
      '设备',
      '功率',
      '天线',
      '高度',
      '备注',
    ];
    const colWidths = <double>[
      10, // 序号 / 主控标记
      8, // 时间
      10, // 呼号
      8, // RST 发
      8, // RST 收
      22, // QTH
      20, // 设备
      7, // 功率
      22, // 天线
      7, // 高度
      10, // 备注
    ];
    final lastColumnIndex = headers.length - 1;
    final excel = excel_lib.Excel.createExcel();
    final sheet = excel['点名记录'];

    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != '点名记录') {
      excel.delete(defaultSheet);
    }

    final headerColor =
        excel_lib.ExcelColor.fromInt(settings.headerBackgroundColor.toARGB32());
    final headerRowColor = excel_lib.ExcelColor.fromInt(
        settings.headerRowBackgroundColor.toARGB32());
    final controllerColor = excel_lib.ExcelColor.fromInt(
        settings.controllerBackgroundColor.toARGB32());
    final alternateColor =
        excel_lib.ExcelColor.fromInt(settings.alternateRowColor.toARGB32());
    final tableColor =
        excel_lib.ExcelColor.fromInt(settings.tableBackgroundColor.toARGB32());

    final borderStyle = excel_lib.Border(
      borderStyle: excel_lib.BorderStyle.Thin,
      borderColorHex: excel_lib.ExcelColor.grey,
    );

    final String? excelFontFamily =
        settings.fontFamily.isEmpty ? null : settings.fontFamily;

    // Header
    final normalizedSessionTitle = sessionTitle?.trim() ?? '';
    final headerText =
        settings.useSessionTitleAsHeader && normalizedSessionTitle.isNotEmpty
            ? normalizedSessionTitle
            : generateFileName(settings.headerText, now);
    sheet.insertRowIterables([excel_lib.TextCellValue(headerText)], 0);
    sheet.merge(
      excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      excel_lib.CellIndex.indexByColumnRow(
        columnIndex: lastColumnIndex,
        rowIndex: 0,
      ),
      customValue: excel_lib.TextCellValue(headerText),
    );
    sheet.row(0).forEach((cell) {
      if (cell != null) {
        cell.cellStyle = excel_lib.CellStyle(
          backgroundColorHex: headerColor,
          fontSize: 14,
          bold: true,
          fontFamily: excelFontFamily,
          horizontalAlign: excel_lib.HorizontalAlign.Center,
          verticalAlign: excel_lib.VerticalAlign.Center,
          textWrapping: excel_lib.TextWrapping.WrapText,
          topBorder: borderStyle,
          bottomBorder: borderStyle,
          leftBorder: borderStyle,
          rightBorder: borderStyle,
        );
      }
    });
    sheet.setRowHeight(0, 30);

    // Column headers
    sheet.insertRowIterables(
      headers.map((e) => excel_lib.TextCellValue(e)).toList(),
      1,
    );
    sheet.row(1).forEach((cell) {
      if (cell != null) {
        cell.cellStyle = excel_lib.CellStyle(
          backgroundColorHex: headerRowColor,
          fontSize: 12,
          bold: true,
          fontFamily: excelFontFamily,
          horizontalAlign: excel_lib.HorizontalAlign.Center,
          verticalAlign: excel_lib.VerticalAlign.Center,
          topBorder: borderStyle,
          bottomBorder: borderStyle,
          leftBorder: borderStyle,
          rightBorder: borderStyle,
        );
      }
    });
    sheet.setRowHeight(1, 25);

    // A controller row starts each contiguous controller/time segment. If the
    // same controller appears again after another controller (A → B → A),
    // create a fresh row so the later stint keeps its own start time.
    int globalIndex = 1;
    int currentRow = 2;
    String? lastController;
    int blockRowColorIndex = 0;

    for (final log in logs) {
      if (log.controller != lastController) {
        lastController = log.controller;
        blockRowColorIndex = 0;
        final controllerTime = calculateControllerTime(log.time);

        final controllerRow = <String>[
          '点名主控:',
          controllerTime,
          log.controller,
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
        ];
        sheet.insertRowIterables(
          controllerRow.map((e) => excel_lib.TextCellValue(e)).toList(),
          currentRow,
        );
        sheet.row(currentRow).forEach((cell) {
          if (cell != null) {
            cell.cellStyle = excel_lib.CellStyle(
              backgroundColorHex: controllerColor,
              fontSize: 11,
              bold: true,
              fontFamily: excelFontFamily,
              horizontalAlign: excel_lib.HorizontalAlign.Center,
              verticalAlign: excel_lib.VerticalAlign.Center,
              topBorder: borderStyle,
              bottomBorder: borderStyle,
              leftBorder: borderStyle,
              rightBorder: borderStyle,
            );
          }
        });
        sheet.setRowHeight(currentRow, 20);
        currentRow++;
      }

      final rowColor = settings.useAlternateColors && blockRowColorIndex.isOdd
          ? alternateColor
          : tableColor;
      blockRowColorIndex++;

      final displayTime = formatLogTimeForDisplay(log.time);
      final rowData = [
        excel_lib.TextCellValue(globalIndex.toString()),
        excel_lib.TextCellValue(displayTime),
        excel_lib.TextCellValue(log.callsign),
        excel_lib.TextCellValue(log.report),
        excel_lib.TextCellValue(log.rstRcvd),
        excel_lib.TextCellValue(log.qth),
        excel_lib.TextCellValue(log.device),
        excel_lib.TextCellValue(log.power),
        excel_lib.TextCellValue(log.antenna),
        excel_lib.TextCellValue(log.height),
        excel_lib.TextCellValue(log.remarks),
      ];
      sheet.insertRowIterables(rowData, currentRow);
      sheet.row(currentRow).forEach((cell) {
        if (cell != null) {
          cell.cellStyle = excel_lib.CellStyle(
            backgroundColorHex: rowColor,
            fontSize: 11,
            fontFamily: excelFontFamily,
            horizontalAlign: excel_lib.HorizontalAlign.Center,
            verticalAlign: excel_lib.VerticalAlign.Center,
            topBorder: borderStyle,
            bottomBorder: borderStyle,
            leftBorder: borderStyle,
            rightBorder: borderStyle,
          );
        }
      });
      sheet.setRowHeight(currentRow, 20);
      globalIndex++;
      currentRow++;
    }

    // Footer
    if (settings.showFooter) {
      currentRow += 2;
      const footerBgColor = excel_lib.ExcelColor.white;
      const footerTextColor = excel_lib.ExcelColor.grey;
      final lightGreyBorder = excel_lib.Border(
        borderStyle: excel_lib.BorderStyle.Thin,
        borderColorHex: excel_lib.ExcelColor.grey,
      );

      final footerTexts = [
        '此表格由 OpenLogTool 生成导出，本项目使用开源协议: GNU Affero General Public License V3',
        '项目仓库地址: https://github.com/Mazha0309/OpenLogTool',
        '分享点名记录时无须携带本条说明',
      ];

      for (final text in footerTexts) {
        sheet.insertRowIterables(
          [excel_lib.TextCellValue(text)],
          currentRow,
        );
        sheet.merge(
          excel_lib.CellIndex.indexByColumnRow(
              columnIndex: 0, rowIndex: currentRow),
          excel_lib.CellIndex.indexByColumnRow(
              columnIndex: lastColumnIndex, rowIndex: currentRow),
          customValue: excel_lib.TextCellValue(text),
        );
        sheet.row(currentRow).forEach((cell) {
          if (cell != null) {
            cell.cellStyle = excel_lib.CellStyle(
              backgroundColorHex: footerBgColor,
              fontColorHex: footerTextColor,
              fontSize: 10,
              fontFamily: excelFontFamily,
              horizontalAlign: excel_lib.HorizontalAlign.Center,
              verticalAlign: excel_lib.VerticalAlign.Center,
              leftBorder: lightGreyBorder,
              rightBorder: lightGreyBorder,
            );
          }
        });
        sheet.setRowHeight(currentRow, 22);
        currentRow++;
      }
    }

    // Column widths
    for (var i = 0; i < colWidths.length; i++) {
      sheet.setColumnWidth(i, colWidths[i]);
    }

    // `Excel.save()` starts a browser download by itself and uses the package
    // default name (`FlutterExcel.xlsx`). The app owns saving so it can apply
    // the configured session filename on every platform; encode only here.
    final saved = excel.encode();
    return saved != null ? Uint8List.fromList(saved) : null;
  }

  /// 计算控制器时间显示值（比第一条记录早一分钟并取整）。
  static String calculateControllerTime(String timeStr) {
    if (timeStr.isEmpty) return '';
    timeStr = formatLogTimeForDisplay(timeStr);
    final parts = timeStr.split(':');
    if (parts.length < 2) return timeStr;

    var hours = int.tryParse(parts[0]) ?? 0;
    var minutes = int.tryParse(parts[1]) ?? 0;

    minutes -= 1;
    if (minutes < 0) {
      minutes = 59;
      hours = (hours - 1) % 24;
    }

    if (minutes % 5 == 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    }

    final nearestFive = (minutes / 5).round() * 5;
    final nearestTen = (minutes / 10).round() * 10;

    final diffToFive = (minutes - nearestFive).abs();
    final diffToTen = (minutes - nearestTen).abs();

    if (diffToTen == 1 || nearestTen == 60) {
      minutes = nearestTen == 60 ? 0 : nearestTen;
      if (nearestTen == 60) {
        hours = (hours + 1) % 24;
      }
    } else if (diffToFive == 1) {
      minutes = nearestFive % 60;
      if (nearestFive == 60) {
        hours = (hours + 1) % 24;
        minutes = 0;
      }
    }

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
}

/// JSON 导入解析结果。
class ImportResult {
  final List<LogEntry> logs;

  const ImportResult({required this.logs});
}

/// 从 JSON 字符串解析导入数据。
/// 支持两种格式：OpenLogTool 原生 JSON（数组）和 HamTool 导出格式（含 `currentRecords` 的 Map）。
ImportResult parseJsonImport(String jsonString) {
  final jsonData = json.decode(jsonString);
  final List<LogEntry> importedLogs;

  if (jsonData is Map && jsonData.containsKey('currentRecords')) {
    // HamTool format compatibility
    final records = jsonData['currentRecords'] as List;
    importedLogs = records.map((item) {
      String time = '';
      final createdAt = item['created_at'];
      if (createdAt != null) {
        try {
          final dt = DateTime.parse(createdAt.toString());
          time =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {}
      }

      String callsign = '';
      String qth = '';
      if (item['called_call'] != null) {
        callsign = item['called_call'].toString();
      }
      if (item['qth'] != null) {
        qth = item['qth'].toString();
      }

      String report = '59';
      if (item['signal_report'] != null) {
        report = item['signal_report'].toString();
      }

      return LogEntry(
        time: time,
        controller: item['controller_call']?.toString() ?? '',
        callsign: callsign,
        report: report,
        qth: qth,
        device: item['device']?.toString() ?? '',
        power: item['power']?.toString() ?? '',
        antenna: item['antenna']?.toString() ?? '',
        height: item['height']?.toString() ?? '',
      );
    }).toList();
  } else if (jsonData is List) {
    // OpenLogTool JSON format
    importedLogs = jsonData.map((item) {
      String callsign = '';
      String qth = '';
      if (item['callsign'] != null) callsign = item['callsign'].toString();
      if (item['qth'] != null) qth = item['qth'].toString();

      return LogEntry(
        time: item['time']?.toString() ?? '',
        controller: item['controller']?.toString() ?? '',
        callsign: callsign,
        report: (item['rstSent'] ?? item['rst_sent'] ?? item['report'])
                ?.toString() ??
            '59',
        rstRcvd: (item['rstRcvd'] ?? item['rst_rcvd'])?.toString() ?? '',
        qth: qth,
        device: item['device']?.toString() ?? '',
        power: item['power']?.toString() ?? '',
        antenna: item['antenna']?.toString() ?? '',
        height: item['height']?.toString() ?? '',
      );
    }).toList();
  } else {
    throw const FormatException('未知的JSON格式');
  }

  return ImportResult(logs: importedLogs);
}
