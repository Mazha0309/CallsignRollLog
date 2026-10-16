import 'package:openlogtool/models/dictionary_item.dart';

final class SharedDictionaryItem {
  const SharedDictionaryItem({
    required this.dictType,
    required this.raw,
    this.pinyin,
    this.abbreviation,
  });

  factory SharedDictionaryItem.fromJson(Map<String, Object?> json) =>
      SharedDictionaryItem(
        dictType: json['dictType'] as String? ?? '',
        raw: json['raw'] as String? ?? '',
        pinyin: json['pinyin'] as String?,
        abbreviation: json['abbreviation'] as String?,
      );

  final String dictType;
  final String raw;
  final String? pinyin;
  final String? abbreviation;
}

final class SharedDictionarySnapshot {
  const SharedDictionarySnapshot({
    required this.grantId,
    required this.grantorUsername,
    required this.exists,
    required this.revision,
    required this.items,
  });

  factory SharedDictionarySnapshot.fromJson(Map<String, Object?> json) =>
      SharedDictionarySnapshot(
        grantId: json['grantId'] as String? ?? '',
        grantorUsername: json['grantorUsername'] as String? ?? '',
        exists: json['exists'] == true,
        revision: (json['revision'] as num?)?.toInt() ?? 0,
        items: [
          for (final row in json['items'] as List? ?? const [])
            SharedDictionaryItem.fromJson(
                Map<String, Object?>.from(row as Map)),
        ],
      );

  final String grantId;
  final String grantorUsername;
  final bool exists;
  final int revision;
  final List<SharedDictionaryItem> items;
}

final class SharedCallsignReuse {
  const SharedCallsignReuse({
    required this.candidateId,
    required this.callsign,
    required this.device,
    required this.antenna,
    required this.qth,
    required this.power,
    required this.height,
  });

  factory SharedCallsignReuse.fromJson(Map<String, Object?> json) =>
      SharedCallsignReuse(
        candidateId: json['candidateId'] as String? ?? '',
        callsign: json['callsign'] as String? ?? '',
        device: json['device'] as String? ?? '',
        antenna: json['antenna'] as String? ?? '',
        qth: json['qth'] as String? ?? '',
        power: json['power'] as String? ?? '',
        height: json['height'] as String? ?? '',
      );

  final String candidateId;
  final String callsign;
  final String device;
  final String antenna;
  final String qth;
  final String power;
  final String height;
}

/// Own rows win on the same type and raw text. Shared rows are display-only.
List<DictionaryItem> mergeSharedDictionary({
  required List<DictionaryItem> own,
  required Iterable<SharedDictionaryItem> shared,
  required String sourceLabel,
}) {
  final owned = <String>{
    for (final item in own) '${item.type}\u0000${item.raw}',
  };
  return [
    ...own,
    for (final item in shared)
      if (item.raw.isNotEmpty &&
          !owned.contains('${item.dictType}\u0000${item.raw}'))
        DictionaryItem(
          raw: item.raw,
          pinyin: item.pinyin ?? '',
          abbreviation: item.abbreviation ?? '',
          type: item.dictType,
          origin: 'shared',
          syncId: 'shared:${item.dictType}:${item.raw}',
          sourceLabel: sourceLabel,
        ),
  ];
}
