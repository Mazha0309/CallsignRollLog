import 'package:openlogtool/models/log_entry.dart';
import 'package:openlogtool/utils/log_time.dart';

const String controllerDisplayPreferencesStorageKey =
    'controllerDisplayPreferences';

/// 主控屏可以展示的固定记录字段。
enum ControllerDisplayField {
  controller('controller'),
  callsign('callsign'),
  time('time'),
  rstSent('rstSent'),
  rstRcvd('rstRcvd'),
  qth('qth'),
  device('device'),
  power('power'),
  antenna('antenna'),
  height('height'),
  remarks('remarks');

  const ControllerDisplayField(this.wireName);

  final String wireName;

  static ControllerDisplayField? fromWireName(String value) {
    for (final field in values) {
      if (field.wireName == value) return field;
    }
    return null;
  }
}

enum ControllerDisplayDetail { minimal, standard, full, custom }

enum ControllerConnectionState { connected, reconnecting, offline }

/// 单条“当前/上一位”显示数据。字段名与 live-draft API 保持一致。
class ControllerRecordDisplay {
  const ControllerRecordDisplay({
    this.controller = '',
    this.callsign = '',
    this.time = '',
    this.rstSent = '',
    this.rstRcvd = '',
    this.qth = '',
    this.device = '',
    this.power = '',
    this.antenna = '',
    this.height = '',
    this.remarks = '',
  });

  factory ControllerRecordDisplay.fromJson(Object? value) {
    final map = value is Map
        ? Map<String, Object?>.from(value)
        : const <String, Object?>{};
    String text(String key, [String? fallback]) =>
        (map[key] ?? (fallback == null ? null : map[fallback]))?.toString() ??
        '';
    return ControllerRecordDisplay(
      controller: text('controller', 'controllerCallsign'),
      callsign: text('callsign'),
      time: formatLogTimeForDisplay(text('time')),
      rstSent: text('rstSent', 'report'),
      rstRcvd: text('rstRcvd'),
      qth: text('qth'),
      device: text('device'),
      power: text('power'),
      antenna: text('antenna'),
      height: text('height'),
      remarks: text('remarks'),
    );
  }

  factory ControllerRecordDisplay.fromLog(LogEntry log) =>
      ControllerRecordDisplay(
        controller: log.controller,
        callsign: log.callsign,
        time: formatLogTimeForDisplay(log.time),
        rstSent: log.report,
        rstRcvd: log.rstRcvd,
        qth: log.qth,
        device: log.device,
        power: log.power,
        antenna: log.antenna,
        height: log.height,
        remarks: log.remarks,
      );

  final String controller;
  final String callsign;
  final String time;
  final String rstSent;
  final String rstRcvd;
  final String qth;
  final String device;
  final String power;
  final String antenna;
  final String height;
  final String remarks;

  String valueFor(ControllerDisplayField field) => switch (field) {
        ControllerDisplayField.controller => controller,
        ControllerDisplayField.callsign => callsign,
        ControllerDisplayField.time => time,
        ControllerDisplayField.rstSent => rstSent,
        ControllerDisplayField.rstRcvd => rstRcvd,
        ControllerDisplayField.qth => qth,
        ControllerDisplayField.device => device,
        ControllerDisplayField.power => power,
        ControllerDisplayField.antenna => antenna,
        ControllerDisplayField.height => height,
        ControllerDisplayField.remarks => remarks,
      };

  Map<String, Object?> toJson() => {
        for (final field in ControllerDisplayField.values)
          field.wireName: valueFor(field),
      };
}

class ControllerFieldLock {
  const ControllerFieldLock({
    required this.field,
    this.holderName,
    this.expiresAt,
  });

  factory ControllerFieldLock.fromJson(Object? value) {
    final map = value is Map
        ? Map<String, Object?>.from(value)
        : const <String, Object?>{};
    final field = (map['field'] ?? map['fieldName'] ?? '').toString();
    final expiresAt = DateTime.tryParse((map['expiresAt'] ?? '').toString());
    return ControllerFieldLock(
      field: field,
      holderName: (map['holderName'] ?? map['username'] ?? map['lastUpdatedBy'])
          ?.toString(),
      expiresAt: expiresAt,
    );
  }

  final String field;
  final String? holderName;
  final DateTime? expiresAt;

  Map<String, Object?> toJson() => {
        'field': field,
        'holderName': holderName,
        'expiresAt': expiresAt?.toUtc().toIso8601String(),
      };
}

/// 只读主控屏的稳定输入协议。
///
/// [fromLiveDraftJson] 直接接受服务端 GET live-draft 的响应，界面因此可以
/// 先使用本地注入数据，待 API 完成后无缝切换到实时草稿。
class ControllerDisplayDto {
  const ControllerDisplayDto({
    required this.sessionTitle,
    required this.currentOrdinal,
    required this.totalRecords,
    required this.current,
    this.previous,
    this.connectionState = ControllerConnectionState.connected,
    this.lastUpdatedBy,
    this.lastUpdatedAt,
    this.fieldRevisions = const {},
    this.locks = const [],
  });

  factory ControllerDisplayDto.fromLiveDraftJson(
    Object? value, {
    String sessionTitle = '',
    ControllerConnectionState connectionState =
        ControllerConnectionState.connected,
  }) {
    final map = value is Map
        ? Map<String, Object?>.from(value)
        : const <String, Object?>{};
    final draft = map['draft'] is Map
        ? Map<String, Object?>.from(map['draft']! as Map)
        : const <String, Object?>{};
    final rawFields = draft['fields'] ?? map['fields'];
    final revisionsValue = draft['fieldRevisions'] ?? map['fieldRevisions'];
    final revisions = revisionsValue is Map
        ? revisionsValue.map(
            (key, value) =>
                MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
          )
        : const <String, int>{};
    final rawLocks = map['locks'];
    return ControllerDisplayDto(
      sessionTitle: (map['sessionTitle'] ?? sessionTitle).toString(),
      currentOrdinal: _integer(map['currentOrdinal'], fallback: 1),
      totalRecords: _integer(map['totalRecords']),
      current: ControllerRecordDisplay.fromJson(rawFields),
      previous: map['previousRecord'] == null
          ? null
          : ControllerRecordDisplay.fromJson(map['previousRecord']),
      connectionState: connectionState,
      lastUpdatedBy: _actorName(
        draft['lastUpdatedBy'] ?? map['lastUpdatedBy'],
      ),
      lastUpdatedAt: DateTime.tryParse(
        (draft['lastUpdatedAt'] ?? map['lastUpdatedAt'] ?? '').toString(),
      ),
      fieldRevisions: revisions,
      locks: rawLocks is List
          ? rawLocks.map(ControllerFieldLock.fromJson).toList(growable: false)
          : const [],
    );
  }

  factory ControllerDisplayDto.fromJson(Object? value) {
    final map = value is Map
        ? Map<String, Object?>.from(value)
        : const <String, Object?>{};
    final stateName = map['connectionState']?.toString();
    return ControllerDisplayDto(
      sessionTitle: (map['sessionTitle'] ?? '').toString(),
      currentOrdinal: _integer(map['currentOrdinal'], fallback: 1),
      totalRecords: _integer(map['totalRecords']),
      current: ControllerRecordDisplay.fromJson(map['current']),
      previous: map['previous'] == null
          ? null
          : ControllerRecordDisplay.fromJson(map['previous']),
      connectionState: ControllerConnectionState.values.firstWhere(
        (value) => value.name == stateName,
        orElse: () => ControllerConnectionState.offline,
      ),
      lastUpdatedBy: map['lastUpdatedBy']?.toString(),
      lastUpdatedAt: DateTime.tryParse((map['lastUpdatedAt'] ?? '').toString()),
      fieldRevisions: map['fieldRevisions'] is Map
          ? (map['fieldRevisions']! as Map).map(
              (key, value) =>
                  MapEntry(key.toString(), (value as num?)?.toInt() ?? 0),
            )
          : const {},
      locks: map['locks'] is List
          ? (map['locks']! as List)
              .map(ControllerFieldLock.fromJson)
              .toList(growable: false)
          : const [],
    );
  }

  final String sessionTitle;
  final int currentOrdinal;
  final int totalRecords;
  final ControllerRecordDisplay current;
  final ControllerRecordDisplay? previous;
  final ControllerConnectionState connectionState;
  final String? lastUpdatedBy;
  final DateTime? lastUpdatedAt;
  final Map<String, int> fieldRevisions;
  final List<ControllerFieldLock> locks;

  bool get isStale => connectionState != ControllerConnectionState.connected;

  Map<String, Object?> toJson() => {
        'sessionTitle': sessionTitle,
        'currentOrdinal': currentOrdinal,
        'totalRecords': totalRecords,
        'current': current.toJson(),
        'previous': previous?.toJson(),
        'connectionState': connectionState.name,
        'lastUpdatedBy': lastUpdatedBy,
        'lastUpdatedAt': lastUpdatedAt?.toUtc().toIso8601String(),
        'fieldRevisions': fieldRevisions,
        'locks': locks.map((lock) => lock.toJson()).toList(growable: false),
      };
}

int resolveVisibleRecordOrdinal({
  int? snapshotOrdinal,
  required int savedCount,
}) {
  final nextFromLogs = savedCount + 1;
  if (snapshotOrdinal == null) return nextFromLogs;
  return snapshotOrdinal > nextFromLogs ? snapshotOrdinal : nextFromLogs;
}

int resolveVisibleRecordCount({
  int? snapshotTotalRecords,
  required int savedCount,
}) {
  if (snapshotTotalRecords == null) return savedCount;
  return snapshotTotalRecords > savedCount ? snapshotTotalRecords : savedCount;
}

int _integer(Object? value, {int fallback = 0}) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

String? _actorName(Object? value) {
  if (value == null) return null;
  if (value is Map) {
    final map = Map<String, Object?>.from(value);
    return (map['username'] ?? map['displayName'] ?? map['userId'])?.toString();
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

class ControllerDisplayPreferences {
  const ControllerDisplayPreferences({
    this.detail = ControllerDisplayDetail.full,
    this.currentFields = _allFields,
    this.previousFields = _allFields,
    this.scale = defaultScale,
  }) : assert(scale >= minScale && scale <= maxScale);

  static const double minScale = 0.75;
  static const double maxScale = 2;
  static const double defaultScale = 1;
  static const double scaleStep = 0.05;
  static const int scaleDivisions = 25;

  static const Set<ControllerDisplayField> _allFields = {
    ...ControllerDisplayField.values,
  };

  static const Set<ControllerDisplayField> minimalFields = {
    ControllerDisplayField.controller,
    ControllerDisplayField.callsign,
  };

  static const Set<ControllerDisplayField> standardFields = {
    ControllerDisplayField.controller,
    ControllerDisplayField.callsign,
    ControllerDisplayField.time,
    ControllerDisplayField.rstSent,
    ControllerDisplayField.rstRcvd,
    ControllerDisplayField.qth,
  };

  factory ControllerDisplayPreferences.fromJson(Object? value) {
    final map = value is Map
        ? Map<String, Object?>.from(value)
        : const <String, Object?>{};
    final detail = ControllerDisplayDetail.values.firstWhere(
      (entry) => entry.name == map['detail'],
      orElse: () => ControllerDisplayDetail.full,
    );
    Set<ControllerDisplayField> fields(String key) {
      final raw = map[key];
      if (raw is! List) return _allFields;
      return raw
          .map((item) => ControllerDisplayField.fromWireName('$item'))
          .whereType<ControllerDisplayField>()
          .toSet();
    }

    return ControllerDisplayPreferences(
      detail: detail,
      currentFields: fields('currentFields'),
      previousFields: fields('previousFields'),
      scale: normalizeScale(map['scale']),
    );
  }

  final ControllerDisplayDetail detail;
  final Set<ControllerDisplayField> currentFields;
  final Set<ControllerDisplayField> previousFields;
  final double scale;

  static double normalizeScale(Object? value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    if (parsed == null || !parsed.isFinite) return defaultScale;
    return parsed.clamp(minScale, maxScale).toDouble();
  }

  Set<ControllerDisplayField> fieldsFor({required bool previous}) {
    if (detail == ControllerDisplayDetail.minimal) return minimalFields;
    if (detail == ControllerDisplayDetail.standard) return standardFields;
    if (detail == ControllerDisplayDetail.full) return _allFields;
    return previous ? previousFields : currentFields;
  }

  ControllerDisplayPreferences copyWith({
    ControllerDisplayDetail? detail,
    Set<ControllerDisplayField>? currentFields,
    Set<ControllerDisplayField>? previousFields,
    double? scale,
  }) =>
      ControllerDisplayPreferences(
        detail: detail ?? this.detail,
        currentFields: currentFields ?? this.currentFields,
        previousFields: previousFields ?? this.previousFields,
        scale: normalizeScale(scale ?? this.scale),
      );

  Map<String, Object?> toJson() => {
        'detail': detail.name,
        'currentFields': currentFields
            .map((field) => field.wireName)
            .toList(growable: false),
        'previousFields': previousFields
            .map((field) => field.wireName)
            .toList(growable: false),
        'scale': scale,
      };
}
