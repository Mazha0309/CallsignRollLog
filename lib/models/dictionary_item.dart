import 'dart:math';

import 'package:openlogtool/utils/dictionary_match.dart';

class DictionaryItem {
  final int? id;
  final String raw;
  final String pinyin;
  final String abbreviation;
  final String syncId;
  final bool hasExplicitSyncId;
  final String type;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final String? sourceDeviceId;
  final String origin;

  factory DictionaryItem({
    int? id,
    required String raw,
    required String pinyin,
    required String abbreviation,
    String? syncId,
    String type = '',
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
    String? sourceDeviceId,
    String origin = 'user',
  }) {
    final normalizedCreatedAt = _normalizeTimestamp(createdAt);
    return DictionaryItem._internal(
      id: id,
      raw: raw,
      pinyin: pinyin,
      abbreviation: abbreviation,
      syncId: _normalizeSyncId(syncId, prefix: 'dict'),
      hasExplicitSyncId: _hasText(syncId),
      type: type,
      createdAt: normalizedCreatedAt,
      updatedAt: _normalizeTimestamp(updatedAt, fallback: normalizedCreatedAt),
      deletedAt: deletedAt,
      sourceDeviceId: sourceDeviceId,
      origin: origin,
    );
  }

  const DictionaryItem._internal({
    required this.id,
    required this.raw,
    required this.pinyin,
    required this.abbreviation,
    required this.syncId,
    required this.hasExplicitSyncId,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.sourceDeviceId,
    required this.origin,
  });

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;

  static String _normalizeSyncId(String? value, {required String prefix}) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    return _generateSyncId(prefix);
  }

  static String _generateSyncId(String prefix) {
    final random = Random.secure();
    final suffix = List<String>.generate(
      4,
      (_) => random.nextInt(1 << 16).toRadixString(16).padLeft(4, '0'),
    ).join();
    return '$prefix-${DateTime.now().toUtc().microsecondsSinceEpoch}-$suffix';
  }

  static String _normalizeTimestamp(String? value, {String? fallback}) {
    final normalized = value?.trim();
    if (_isValidIsoTimestamp(normalized)) {
      return normalized!;
    }
    final normalizedFallback = fallback?.trim();
    if (_isValidIsoTimestamp(normalizedFallback)) {
      return normalizedFallback!;
    }
    return DateTime.now().toUtc().toIso8601String();
  }

  static bool _isValidIsoTimestamp(String? value) {
    if (value == null || value.isEmpty) {
      return false;
    }
    return DateTime.tryParse(value) != null;
  }

  static String? _normalizeNullableString(dynamic value) {
    if (value == null) {
      return null;
    }
    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  static int? _readLocalId(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  factory DictionaryItem.fromMap(Map<String, dynamic> map) {
    return DictionaryItem(
      id: _readLocalId(map['id']),
      raw: map['raw']?.toString() ?? '',
      pinyin: map['pinyin']?.toString() ?? '',
      abbreviation: map['abbreviation']?.toString() ?? '',
      syncId: _normalizeNullableString(map['sync_id'] ?? map['syncId']),
      type: map['type']?.toString() ?? '',
      createdAt: map['created_at']?.toString() ?? map['createdAt']?.toString(),
      updatedAt: map['updated_at']?.toString() ?? map['updatedAt']?.toString(),
      deletedAt:
          _normalizeNullableString(map['deleted_at'] ?? map['deletedAt']),
      sourceDeviceId: _normalizeNullableString(
          map['source_device_id'] ?? map['sourceDeviceId']),
      origin: map['origin']?.toString() ?? 'user',
    );
  }

  factory DictionaryItem.fromJson(Map<String, dynamic> json) {
    return DictionaryItem(
      id: _readLocalId(json['id']),
      raw: json['raw']?.toString() ?? '',
      pinyin: json['pinyin']?.toString() ?? '',
      abbreviation: json['abbreviation']?.toString() ?? '',
      syncId: _normalizeNullableString(json['syncId'] ?? json['sync_id']),
      type: json['type']?.toString() ?? '',
      createdAt:
          json['createdAt']?.toString() ?? json['created_at']?.toString(),
      updatedAt:
          json['updatedAt']?.toString() ?? json['updated_at']?.toString(),
      deletedAt:
          _normalizeNullableString(json['deletedAt'] ?? json['deleted_at']),
      sourceDeviceId: _normalizeNullableString(
          json['sourceDeviceId'] ?? json['source_device_id']),
      origin: json['origin']?.toString() ?? 'user',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'raw': raw,
      'pinyin': pinyin,
      'abbreviation': abbreviation,
      'sync_id': syncId,
      'type': type,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
      'source_device_id': sourceDeviceId,
      'origin': origin,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'raw': raw,
      'pinyin': pinyin,
      'abbreviation': abbreviation,
      'syncId': syncId,
      'type': type,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deletedAt': deletedAt,
      'sourceDeviceId': sourceDeviceId,
      'origin': origin,
    };
  }

  DictionaryItem copyWith({
    int? id,
    String? raw,
    String? pinyin,
    String? abbreviation,
    String? syncId,
    String? type,
    String? createdAt,
    String? updatedAt,
    Object? deletedAt = _dictionaryCopyWithSentinel,
    Object? sourceDeviceId = _dictionaryCopyWithSentinel,
    String? origin,
  }) {
    return DictionaryItem(
      id: id ?? this.id,
      raw: raw ?? this.raw,
      pinyin: pinyin ?? this.pinyin,
      abbreviation: abbreviation ?? this.abbreviation,
      syncId: syncId ?? this.syncId,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: identical(deletedAt, _dictionaryCopyWithSentinel)
          ? this.deletedAt
          : deletedAt as String?,
      sourceDeviceId: identical(sourceDeviceId, _dictionaryCopyWithSentinel)
          ? this.sourceDeviceId
          : sourceDeviceId as String?,
      origin: origin ?? this.origin,
    );
  }

  bool matches(String query) {
    return matchDictionaryText(
      query: query,
      raw: raw,
      pinyin: pinyin,
      abbreviation: abbreviation,
    ) != null;
  }

  @override
  String toString() => raw;
}

const Object _dictionaryCopyWithSentinel = Object();
