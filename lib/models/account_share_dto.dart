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
  });

  factory SharedSessionDto.fromJson(Object? json) {
    final object = json is Map<String, Object?>
        ? json
        : json is Map
            ? Map<String, Object?>.from(json)
            : throw FormatException('sharedSession must be a JSON object');
    return SharedSessionDto(
      source: object['source'] as String? ?? 'collaboration',
      sessionId: object['sessionId'] as String? ?? '',
      title: object['title'] as String? ?? '',
      status: object['status'] as String? ?? 'active',
      grantorUsername: object['grantorUsername'] as String? ?? '',
      canJoin: object['canJoin'] == true,
      createdAt: object['createdAt'] as String? ?? '',
      updatedAt: object['updatedAt'] as String? ?? '',
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
}

final class AccountShareGrantDto {
  const AccountShareGrantDto({
    required this.id,
    required this.grantorUserId,
    required this.granteeUserId,
    required this.status,
  });

  factory AccountShareGrantDto.fromJson(Object? json) {
    final object = json is Map<String, Object?>
        ? json
        : json is Map
            ? Map<String, Object?>.from(json)
            : throw FormatException('share must be a JSON object');
    return AccountShareGrantDto(
      id: object['id'] as String? ?? '',
      grantorUserId: object['grantorUserId'] as String? ?? '',
      granteeUserId: object['granteeUserId'] as String? ?? '',
      status: object['status'] as String? ?? '',
    );
  }

  final String id;
  final String grantorUserId;
  final String granteeUserId;
  final String status;
}
