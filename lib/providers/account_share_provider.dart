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
  Object? _lastError;
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
  bool get supportsFriends =>
      _server?.isLoggedIn == true &&
      (_server?.serverInfo?.features.contains('friendCollaboration') ?? false);
  bool get supportsLegacySharing =>
      _server?.isLoggedIn == true &&
      (_server?.serverInfo?.features.contains('accountSessionSharing') ??
          false);

  List<SharedSessionDto> get sharedSessions => _sharedSessions;
  List<AccountShareGrantDto> get inbox => _inbox;
  int get pendingInboundCount => supportsFriends
      ? [..._social.friendRequests, ..._social.sessionRequests]
          .where((r) => r.recipientId == accountId && r.status == 'pending')
          .length
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
        '${server.serverInfo?.features.contains('socialWebSocket')}';
    if (_scope == nextScope) return;
    _scope = nextScope;
    _epoch++;
    _timer?.cancel();
    _realtime?.dispose();
    _realtime = null;
    _refreshAgain = false;
    _sharedSessions = const [];
    _inbox = const [];
    _social = const SocialSnapshot();
    _lastError = null;
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
    try {
      if (supportsFriends) {
        final snapshot = await api.getSocialSnapshot();
        if (_disposed || epoch != _epoch) return;
        _social = snapshot;
      }
      if (supportsLegacySharing) {
        final shared = await api.listSharedSessions();
        final inbox = await api.listSessionShares('inbox');
        if (_disposed || epoch != _epoch) return;
        _sharedSessions = shared;
        _inbox = inbox;
      }
      _lastError = null;
      revision++;
    } catch (error) {
      if (_disposed || epoch != _epoch) return;
      _lastError = error;
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
    final server = _server;
    if (server == null) return;
    await server.api.acceptSessionShare(
      shareId: shareId,
      idempotencyKey: 'share-accept-${DateTime.now().microsecondsSinceEpoch}',
    );
    await refresh();
  }

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
        ),
    ];
  }
}
