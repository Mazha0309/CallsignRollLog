final class SharedSessionDto {
  const SharedSessionDto({
    required this.source,
    required this.sessionId,
    required this.title,
    required this.status,
    required this.grantorUsername,
    required this.canJoin,
    required this.createdAt,
    required this.updatedAt,
    this.grantId = '',
    this.grantorUserId = '',
    this.canEditLogs = false,
    this.canDeleteLogs = false,
    this.snapshotRevision,
    this.logCount = 0,
  });

  factory SharedSessionDto.fromJson(Object? json) {
    final object = json is Map<String, Object?>
        ? json
        : json is Map
            ? Map<String, Object?>.from(json)
            : throw const FormatException('sharedSession must be a JSON object');
    return SharedSessionDto(
      source: object['source'] as String? ?? 'collaboration',
      sessionId: object['sessionId'] as String? ?? '',
      title: object['title'] as String? ?? '',
      status: object['status'] as String? ?? 'active',
      grantorUsername: object['grantorUsername'] as String? ?? '',
      canJoin: object['canJoin'] == true,
      createdAt: object['createdAt'] as String? ?? '',
      updatedAt: object['updatedAt'] as String? ?? '',
      grantId: object['grantId'] as String? ?? '',
      grantorUserId: object['grantorUserId'] as String? ?? '',
      canEditLogs: object['canEditLogs'] == true,
      canDeleteLogs: object['canDeleteLogs'] == true,
      snapshotRevision: (object['snapshotRevision'] as num?)?.toInt(),
      logCount: (object['logCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String source;
  final String sessionId;
  final String title;
  final String status;
  final String grantorUsername;
  final bool canJoin;
  final String createdAt;
  final String updatedAt;
  final String grantId, grantorUserId;
  final bool canEditLogs, canDeleteLogs;
  final int? snapshotRevision;
  final int logCount;
  String get identity => '$grantId:$source:$sessionId';
}

final class AccountShareGrantDto {
  const AccountShareGrantDto({
    required this.id,
    required this.grantorUserId,
    required this.granteeUserId,
    required this.status,
    this.grantorUsername = '',
    this.granteeUsername = '',
    this.scopeMode = 'all',
    this.selectedSessions = const [],
    this.canEditLogs = false,
    this.canDeleteLogs = false,
  });

  factory AccountShareGrantDto.fromJson(Object? json) {
    final object = json is Map<String, Object?>
        ? json
        : json is Map
            ? Map<String, Object?>.from(json)
            : throw const FormatException('share must be a JSON object');
    return AccountShareGrantDto(
      id: object['id'] as String? ?? '',
      grantorUserId: object['grantorUserId'] as String? ?? '',
      granteeUserId: object['granteeUserId'] as String? ?? '',
      status: object['status'] as String? ?? '',
      grantorUsername: object['grantorUsername'] as String? ?? '',
      granteeUsername: object['granteeUsername'] as String? ?? '',
      scopeMode: object['scopeMode'] as String? ?? 'all',
      selectedSessions: [
        for (final row in object['selectedSessions'] as List? ?? const [])
          ShareSessionRef.fromJson(Map<String, Object?>.from(row as Map))
      ],
      canEditLogs: object['canEditLogs'] == true,
      canDeleteLogs: object['canDeleteLogs'] == true,
    );
  }

  final String id;
  final String grantorUserId;
  final String granteeUserId;
  final String status;
  final String grantorUsername, granteeUsername, scopeMode;
  final List<ShareSessionRef> selectedSessions;
  final bool canEditLogs, canDeleteLogs;
}

final class ShareSessionRef {
  const ShareSessionRef(
      {required this.source, required this.sessionId, this.title = ''});
  factory ShareSessionRef.fromJson(Map<String, Object?> json) =>
      ShareSessionRef(
          source: json['source']! as String,
          sessionId: json['sessionId']! as String,
          title: json['title'] as String? ?? '');
  final String source, sessionId, title;
  String get identity => '$source:$sessionId';
  Map<String, Object?> toJson() => {'source': source, 'sessionId': sessionId};
}

final class SharedRecordsPage {
  const SharedRecordsPage(
      {required this.items,
      required this.page,
      required this.totalPages,
      required this.total,
      this.session});
  factory SharedRecordsPage.fromJson(Map<String, Object?> json) =>
      SharedRecordsPage(
          items: [
            for (final item in json['items'] as List)
              Map<String, Object?>.from(item as Map)
          ],
          page: (json['page'] as num?)?.toInt() ?? 1,
          totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
          total: (json['total'] as num?)?.toInt() ??
              (json['items'] as List).length,
          session: json['session'] == null
              ? null
              : SharedSessionDto.fromJson(json['session']));
  final List<Map<String, Object?>> items;
  final int page, totalPages, total;
  final SharedSessionDto? session;
}
