import 'package:flutter/foundation.dart';
import 'package:openlogtool/models/account_share_dto.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:openlogtool/providers/session_provider.dart';

class AccountShareProvider with ChangeNotifier {
  ServerProvider? _server;
  List<SharedSessionDto> _sharedSessions = const [];
  List<AccountShareGrantDto> _inbox = const [];
  Object? _lastError;

  List<SharedSessionDto> get sharedSessions => _sharedSessions;
  List<AccountShareGrantDto> get inbox => _inbox;
  int get pendingInboundCount => _inbox.length;
  Object? get lastError => _lastError;

  bool get isSupported =>
      _server?.serverInfo?.features.contains('accountSessionSharing') ?? false;

  void updateServer(ServerProvider server) {
    if (identical(_server, server)) return;
    _server = server;
    if (server.isLoggedIn && isSupported) {
      refresh();
    } else {
      _sharedSessions = const [];
      _inbox = const [];
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final server = _server;
    if (server == null || !server.isLoggedIn || !isSupported) return;
    try {
      final shared = await server.api.listSharedSessions();
      final inbox = await server.api.listSessionShares('inbox');
      _sharedSessions = shared;
      _inbox = inbox;
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _lastError = error;
      notifyListeners();
    }
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
