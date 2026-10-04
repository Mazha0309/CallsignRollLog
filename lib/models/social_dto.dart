typedef SocialJson = Map<String, Object?>;

class SocialPerson {
  SocialPerson.fromJson(SocialJson json)
      : userId = json['userId']! as String,
        username = json['username']! as String;
  final String userId;
  final String username;
}

class SocialUserSearchResult {
  const SocialUserSearchResult(
      {required this.userId,
      required this.username,
      required this.relationship,
      this.requestId});
  factory SocialUserSearchResult.fromJson(SocialJson json) =>
      SocialUserSearchResult(
          userId: json['userId']! as String,
          username: json['username']! as String,
          relationship: json['relationship']! as String,
          requestId: json['requestId'] as String?);
  final String userId, username, relationship;
  final String? requestId;
}

class SocialUserSearchPage {
  const SocialUserSearchPage({this.items = const [], this.hasMore = false});
  factory SocialUserSearchPage.fromJson(SocialJson json) =>
      SocialUserSearchPage(
          items: List.unmodifiable((json['items']! as List).map((value) =>
              SocialUserSearchResult.fromJson(
                  Map<String, Object?>.from(value as Map)))),
          hasMore: json['hasMore']! as bool);
  final List<SocialUserSearchResult> items;
  final bool hasMore;
}

class SocialRequest {
  SocialRequest.fromJson(SocialJson json)
      : id = json['id']! as String,
        senderId = json['senderId']! as String,
        senderUsername = json['senderUsername']! as String,
        recipientId = json['recipientId']! as String,
        recipientUsername = json['recipientUsername']! as String,
        status = json['status']! as String,
        sessionId = json['sessionId'] as String?,
        sessionTitle = json['sessionTitle'] as String?,
        kind = json['kind'] as String?,
        role = json['role'] as String?;
  final String id,
      senderId,
      senderUsername,
      recipientId,
      recipientUsername,
      status;
  final String? sessionId, sessionTitle, kind, role;
}

class FriendSession {
  FriendSession.fromJson(SocialJson json)
      : sessionId = json['sessionId']! as String,
        title = json['title']! as String,
        ownerId = json['ownerId']! as String,
        ownerUsername = json['ownerUsername']! as String,
        visibility = json['visibility']! as String,
        joinPolicy = json['joinPolicy'] as String? ?? 'approval',
        defaultRole = json['defaultRole'] as String? ?? 'viewer';
  final String sessionId, title, ownerId, ownerUsername, visibility;
  final String joinPolicy, defaultRole;
}

class SocialSnapshot {
  const SocialSnapshot(
      {this.friends = const [],
      this.friendRequests = const [],
      this.sessionRequests = const [],
      this.sessions = const [],
      this.blocks = const []});
  factory SocialSnapshot.fromJson(SocialJson json) {
    List<T> items<T>(String key, T Function(SocialJson) parse) =>
        List.unmodifiable((json[key]! as List)
            .map((value) => parse(Map<String, Object?>.from(value as Map))));
    return SocialSnapshot(
      friends: items('friends', SocialPerson.fromJson),
      friendRequests: items('friendRequests', SocialRequest.fromJson),
      sessionRequests: items('sessionRequests', SocialRequest.fromJson),
      sessions: items('sessions', FriendSession.fromJson),
      blocks: items('blocks', SocialPerson.fromJson),
    );
  }
  final List<SocialPerson> friends, blocks;
  final List<SocialRequest> friendRequests, sessionRequests;
  final List<FriendSession> sessions;
}
