import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:openlogtool/models/account_share_dto.dart';
import 'package:openlogtool/models/social_dto.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/services/collaboration_sync.dart';
import 'package:openlogtool/services/social_realtime.dart';

class AccountShareProvider with ChangeNotifier {
  AccountShareProvider(
      {this.socialSocketConnector = const WebSocketChannelConnector()});
  final CollaborationSocketConnector socialSocketConnector;
  SocialRealtimeClient? _realtime;
  bool _refreshAgain = false;
  ServerProvider? _server;
  List<SharedSessionDto> _sharedSessions = const [];
  List<AccountShareGrantDto> _inbox = const [];
  List<AccountShareGrantDto> _outgoing = const [];
  Object? _lastError;
  Object? _inboxError;
  SocialSnapshot _social = const SocialSnapshot();
  String? _scope;
  int _epoch = 0;
  int revision = 0;
  bool _disposed = false;
  bool _loading = false;
  bool _busy = false;
  Timer? _timer;
  final _pendingMutations = <String, String>{};
  SocialSnapshot get social => _social;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get accountId => _server?.accountId;
  String? get accountScope => _scope;
  bool get supportsBatchSharing =>
      supportsLegacySharing &&
      (_server?.serverInfo?.features.contains('batchSessionSharing') ?? false);
  bool get supportsDirectJoin =>
      supportsFriends &&
      (_server?.serverInfo?.features.contains('friendDirectJoin') ?? false);
  bool get supportsFriends =>
      _server?.isLoggedIn == true &&
      (_server?.serverInfo?.features.contains('friendCollaboration') ?? false);
  bool get supportsLegacySharing =>
      _server?.isLoggedIn == true &&
      (_server?.serverInfo?.features.contains('accountSessionSharing') ??
          false);

  List<SharedSessionDto> get sharedSessions => _sharedSessions;
  List<AccountShareGrantDto> get inbox => _inbox;
  List<AccountShareGrantDto> get outgoing => _outgoing;
  Object? get inboxError => _inboxError;
  Set<String> get pendingInboundKeys => {
        for (final grant in inbox)
          if (grant.status == 'pending') 'share:${grant.id}',
        if (supportsFriends)
          for (final request in [
            ...social.friendRequests,
            ...social.sessionRequests
          ])
            if (request.recipientId == accountId && request.status == 'pending')
              '${request.sessionId == null ? 'friend' : 'session'}:${request.id}',
      };
  int get pendingInboundCount => supportsFriends
      ? [..._social.friendRequests, ..._social.sessionRequests]
              .where((r) => r.recipientId == accountId && r.status == 'pending')
              .length +
          _inbox.length
      : _inbox.length;
  Object? get lastError => _lastError;

  bool get isSupported =>
      _server?.isLoggedIn == true &&
      (supportsFriends ||
          (_server?.serverInfo?.features.contains('accountSessionSharing') ??
              false));

  void updateServer(ServerProvider server) {
    _server = server;
    final nextScope = '${server.contextRevision}|${server.serverUrl}|'
        '${server.accountId}|${server.serverInfo?.serverInstanceId}|$supportsFriends|$isSupported|'
        '${server.serverInfo?.features.contains('socialWebSocket')}|$supportsBatchSharing';
    if (_scope == nextScope) return;
    _scope = nextScope;
    _epoch++;
    _timer?.cancel();
    _realtime?.dispose();
    _realtime = null;
    _refreshAgain = false;
    _sharedSessions = const [];
    _inbox = const [];
    _outgoing = const [];
    _social = const SocialSnapshot();
    _lastError = null;
    _inboxError = null;
    _loading = false;
    _busy = false;
    _pendingMutations.clear();
    revision++;
    scheduleMicrotask(() {
      if (_disposed || _scope != nextScope) return;
      notifyListeners();
      if (isSupported) unawaited(refresh());
    });
    if (supportsFriends &&
        server.serverInfo!.features.contains('socialWebSocket')) {
      final api = server.api;
      _realtime = SocialRealtimeClient(
        ticketUri: api.socialWebSocketTicketUri,
        accountId: server.accountId!,
        serverInstanceId: server.serverInfo!.serverInstanceId,
        connector: socialSocketConnector,
        onInvalidate: () {
          if (!_disposed && _scope == nextScope) unawaited(refresh());
        },
      )..start();
    } else if (isSupported) {
      // Compatibility only: older servers do not expose an account channel.
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    }
  }

  Future<void> refresh() async {
    final server = _server;
    if (server == null || !isSupported || _disposed) return;
    if (_loading) {
      _refreshAgain = true;
      return;
    }
    final epoch = _epoch;
    final api = server.api;
    _loading = true;
    notifyListeners();
    final errors = <Object>[];
    Future<void> load<T>(Future<T> Function() fetch, void Function(T) apply,
        {bool inbox = false}) async {
      try {
        final value = await fetch();
        if (_disposed || epoch != _epoch) return;
        apply(value);
        if (inbox) _inboxError = null;
        revision++;
        notifyListeners();
      } catch (error) {
        if (_disposed || epoch != _epoch) return;
        errors.add(error);
        if (inbox) _inboxError = error;
      }
    }

    try {
      // Invitations must not wait for, or disappear behind, a failed catalog
      // or social request. Each response still belongs to this account epoch.
      await Future.wait([
        if (supportsFriends)
          load(api.getSocialSnapshot, (value) => _social = value),
        if (supportsLegacySharing) ...[
          load(() => api.listSessionShares('inbox'), (value) => _inbox = value,
              inbox: true),
          load(api.listSharedSessions, (value) => _sharedSessions = value),
          if (supportsBatchSharing)
            load(
                () => Future.wait([
                      api.listSessionShares('outbox'),
                      api.listSessionShares('active'),
                    ]),
                (value) => _outgoing = [
                      ...value[0],
                      ...value[1]
                          .where((grant) => grant.grantorUserId == accountId),
                    ]),
        ],
      ]);
      if (_disposed || epoch != _epoch) return;
      _lastError = errors.firstOrNull;
    } finally {
      if (!_disposed && epoch == _epoch) {
        _loading = false;
        notifyListeners();
        if (_refreshAgain) {
          _refreshAgain = false;
          unawaited(refresh());
        }
      }
    }
  }

  /// Search results belong to this account/server, never a later connection.
  Future<SocialUserSearchPage> searchUsers(String query) async {
    if (_disposed || !supportsFriends) throw StateError('SOCIAL_UNAVAILABLE');
    final text = query.trim();
    if (text.runes.length < 2 || text.runes.length > 64) {
      throw ArgumentError.value(query, 'query', 'Use 2–64 characters');
    }
    final scope = _scope;
    final result = await _server!.api.searchSocialUsers(text);
    if (_disposed || scope != _scope) throw StateError('ACCOUNT_CHANGED');
    return result;
  }

  Future<void> mutateSocial(String method, String path,
      [Map<String, Object?> body = const {}]) async {
    if (!supportsFriends || _busy) throw StateError('SOCIAL_UNAVAILABLE');
    final epoch = _epoch;
    final scope = _scope;
    final api = _server!.api;
    final operation = '$method|$path|${jsonEncode(body)}';
    final key = _pendingMutations.putIfAbsent(
        operation,
        () => List.generate(
            16,
            (_) => Random.secure()
                .nextInt(256)
                .toRadixString(16)
                .padLeft(2, '0')).join());
    _busy = true;
    notifyListeners();
    try {
      await api.socialMutation(method, path, body: body, idempotencyKey: key);
      if (_disposed || epoch != _epoch) throw StateError('ACCOUNT_CHANGED');
      _pendingMutations.remove(operation);
      // Invalidate an older poll so it cannot replace the post-mutation snapshot.
      _epoch++;
      _loading = false;
      await refresh();
      if (_disposed || _scope != scope) throw StateError('ACCOUNT_CHANGED');
    } finally {
      if (!_disposed && _scope == scope) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _timer?.cancel();
    _realtime?.dispose();
    super.dispose();
  }

  Future<void> createRequest(String username) async {
    final server = _server;
    if (server == null) return;
    await server.api.createSessionShare(
      granteeUsername: username,
      idempotencyKey: 'share-${DateTime.now().microsecondsSinceEpoch}',
    );
    await refresh();
  }

  Future<void> acceptRequest(String shareId) async {
    await respondShare(shareId, 'accept', expectedScope: _scope);
  }

  Future<void> _shareMutation(String method, String path,
      Map<String, Object?> body, String? expectedScope) async {
    if (_disposed ||
        !supportsLegacySharing ||
        _busy ||
        expectedScope != _scope) {
      throw StateError('ACCOUNT_CHANGED');
    }
    final scope = _scope;
    final api = _server!.api;
    final operation = '$method|$path|${jsonEncode(body)}';
    final key = _pendingMutations.putIfAbsent(
        operation,
        () => List.generate(
            16,
            (_) => Random.secure()
                .nextInt(256)
                .toRadixString(16)
                .padLeft(2, '0')).join());
    _busy = true;
    notifyListeners();
    try {
      await api.accountShareMutation(method, path,
          body: body, idempotencyKey: key);
      if (_disposed || scope != _scope) throw StateError('ACCOUNT_CHANGED');
      _pendingMutations.remove(operation);
      _epoch++;
      _loading = false;
      await refresh();
      if (_disposed || scope != _scope) throw StateError('ACCOUNT_CHANGED');
    } finally {
      if (!_disposed && scope == _scope) {
        _busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> respondShare(String id, String action,
          {required String? expectedScope}) =>
      _shareMutation(
          'POST',
          '/session-shares/${Uri.encodeComponent(id)}/$action',
          const {},
          expectedScope);

  Future<void> saveShare(
      {required String username,
      required String scopeMode,
      required List<ShareSessionRef> sessions,
      required bool canEditLogs,
      required bool canDeleteLogs,
      required String? expectedScope,
      String? grantId}) {
    if (!supportsBatchSharing) throw StateError('SHARING_UPGRADE_REQUIRED');
    return _shareMutation(
        grantId == null ? 'POST' : 'PATCH',
        '/session-shares${grantId == null ? '' : '/${Uri.encodeComponent(grantId)}'}',
        {
          if (grantId == null) 'granteeUsername': username,
          'includePersonal': true,
          'includeOwned': true,
          'includeEditor': false,
          'canJoinAs': 'none',
          'scopeMode': scopeMode,
          'selectedSessions': scopeMode == 'all'
              ? []
              : sessions.map((s) => s.toJson()).toList(),
          'canEditLogs': canEditLogs,
          'canDeleteLogs': canDeleteLogs,
        },
        expectedScope);
  }

  Future<List<ShareSessionRef>> loadShareCandidates() async {
    if (!supportsBatchSharing) throw StateError('SHARING_UPGRADE_REQUIRED');
    final scope = _scope;
    final rows = await _server!.api.listShareCandidates();
    if (_disposed || scope != _scope) throw StateError('ACCOUNT_CHANGED');
    return rows;
  }

  Future<SharedRecordsPage> loadSharedRecords(SharedSessionDto session,
      {int page = 1, String query = '', required String? expectedScope}) async {
    if (_disposed || !supportsLegacySharing || expectedScope != _scope) {
      throw StateError('ACCOUNT_CHANGED');
    }
    final result =
        await _server!.api.sharedRecordsPage(session, page: page, query: query);
    if (_disposed || expectedScope != _scope) {
      throw StateError('ACCOUNT_CHANGED');
    }
    return result;
  }

  Future<void> mutateSharedRecord(
          SharedSessionDto session, Map<String, Object?> body,
          {required String? expectedScope}) =>
      _shareMutation(
          'POST',
          '/shared-sessions/${Uri.encodeComponent(session.source)}/${Uri.encodeComponent(session.sessionId)}/logs/mutations',
          {'grantId': session.grantId, ...body},
          expectedScope);

  SharedSessionDto? sharedSessionById(String sessionId) {
    for (final item in _sharedSessions) {
      if (item.sessionId == sessionId) return item;
    }
    return null;
  }

  Future<List<Map<String, Object?>>> loadSharedLogs(
    SharedSessionDto session,
  ) async {
    final server = _server;
    if (server == null) return const [];
    return server.api.listSharedSessionLogs(
      source: session.source,
      sessionId: session.sessionId,
    );
  }

  Future<void> joinOwnedSession({
    required String sessionId,
    required String passphrase,
  }) async {
    final server = _server;
    if (server == null) return;
    final scope = _scope;
    await server.api.joinWithShare(
      sessionId: sessionId,
      passphrase: passphrase,
      idempotencyKey: 'share-join-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (_disposed || _scope != scope) throw StateError('ACCOUNT_CHANGED');
    await refresh();
    if (_disposed || _scope != scope) throw StateError('ACCOUNT_CHANGED');
  }

  List<SessionListEntry> sharedHistoryEntries() {
    return [
      for (final item in _sharedSessions)
        SessionListEntry(
          session: Session(
            sessionId: item.sessionId,
            title: item.title,
            status: item.status,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
          ),
          hasCollaborationBinding: false,
          isShared: true,
          sharedGrantorUsername: item.grantorUsername,
          sharedSession: item,
        ),
    ];
  }
}
