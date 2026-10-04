import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/models/controller_display.dart';
import 'package:openlogtool/utils/log_time.dart';

void main() {
  test('visible ordinal prefers saved records over a stale snapshot', () {
    expect(
      resolveVisibleRecordOrdinal(snapshotOrdinal: 1, savedCount: 3),
      4,
    );
    expect(
      resolveVisibleRecordOrdinal(snapshotOrdinal: 5, savedCount: 3),
      5,
    );
    expect(resolveVisibleRecordOrdinal(savedCount: 3), 4);
    expect(
      resolveVisibleRecordCount(snapshotTotalRecords: 1, savedCount: 3),
      3,
    );
    expect(
      resolveVisibleRecordCount(snapshotTotalRecords: 5, savedCount: 3),
      5,
    );
  });

  test('maps the live-draft response into controller display data', () {
    final dto = ControllerDisplayDto.fromLiveDraftJson(
      {
        'draft': {
          'fields': {
            'controller': 'BG5CRL',
            'callsign': 'BA4AAA',
            'time': '20:15',
            'rstSent': '59',
            'rstRcvd': '57',
            'qth': '上海',
            'device': 'IC-7300',
            'power': '100W',
            'antenna': 'DP',
            'height': '12m',
            'remarks': '移动设台',
          },
          'fieldRevisions': {'callsign': 4},
          'lastUpdatedBy': {
            'userId': 'user-2',
            'username': '书记员乙',
          },
          'lastUpdatedAt': '2026-07-13T12:00:00Z',
        },
        'locks': [
          {'field': 'qth', 'holderName': '书记员甲'},
        ],
        'currentOrdinal': 8,
        'totalRecords': 7,
        'previousRecord': {
          'controller': 'BG5CRL',
          'callsign': 'BH4BBB',
          'rstSent': '58',
        },
      },
      sessionTitle: '周日晚间点名',
    );

    expect(dto.sessionTitle, '周日晚间点名');
    expect(dto.currentOrdinal, 8);
    expect(dto.totalRecords, 7);
    expect(dto.current.toJson(), {
      'controller': 'BG5CRL',
      'callsign': 'BA4AAA',
      'time': '20:15',
      'rstSent': '59',
      'rstRcvd': '57',
      'qth': '上海',
      'device': 'IC-7300',
      'power': '100W',
      'antenna': 'DP',
      'height': '12m',
      'remarks': '移动设台',
    });
    expect(dto.previous?.callsign, 'BH4BBB');
    expect(dto.fieldRevisions['callsign'], 4);
    expect(dto.locks.single.holderName, '书记员甲');
    expect(dto.lastUpdatedBy, '书记员乙');
  });

  test('detail presets resolve to stable field sets', () {
    const minimal = ControllerDisplayPreferences(
      detail: ControllerDisplayDetail.minimal,
    );
    const standard = ControllerDisplayPreferences(
      detail: ControllerDisplayDetail.standard,
    );
    const full = ControllerDisplayPreferences();

    expect(minimal.fieldsFor(previous: false), {
      ControllerDisplayField.controller,
      ControllerDisplayField.callsign,
    });
    expect(
      standard.fieldsFor(previous: false),
      contains(ControllerDisplayField.qth),
    );
    expect(
      standard.fieldsFor(previous: false),
      isNot(contains(ControllerDisplayField.device)),
    );
    expect(
      full.fieldsFor(previous: true).length,
      ControllerDisplayField.values.length,
    );
  });

  test('display scale is backward compatible, bounded and serialized', () {
    final legacy = ControllerDisplayPreferences.fromJson({
      'detail': 'standard',
    });
    final tooSmall = ControllerDisplayPreferences.fromJson({'scale': 0.25});
    final tooLarge = ControllerDisplayPreferences.fromJson({'scale': 3});
    final invalid = ControllerDisplayPreferences.fromJson({'scale': 'NaN'});
    final custom = legacy.copyWith(scale: 1.35);

    expect(legacy.scale, ControllerDisplayPreferences.defaultScale);
    expect(tooSmall.scale, ControllerDisplayPreferences.minScale);
    expect(tooLarge.scale, ControllerDisplayPreferences.maxScale);
    expect(invalid.scale, ControllerDisplayPreferences.defaultScale);
    expect(custom.scale, 1.35);
    expect(custom.toJson()['scale'], 1.35);
  });

  test('controller display renders canonical timestamps locally', () {
    final localTime = DateTime(2026, 7, 13, 20, 15);
    final record = ControllerRecordDisplay.fromJson({
      'time': localTime.toUtc().toIso8601String(),
    });

    expect(record.time, '20:15');
  });

  test('a directly constructed record keeps its timestamp unchanged', () {
    const timestamp = '2026-07-13T12:15:00Z';
    const record = ControllerRecordDisplay(time: timestamp);

    expect(record.time, timestamp);
    expect(record.valueFor(ControllerDisplayField.time), timestamp);
    expect(record.toJson()['time'], timestamp);
    expect(formatLogTimeForDisplay(record.time), matches(r'^\d{2}:\d{2}$'));
    expect(formatLogTimeForDisplay(record.time), isNot(timestamp));
  });
}
