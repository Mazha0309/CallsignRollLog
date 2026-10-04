import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:openlogtool/services/collaboration_sync.dart';

/// A receive-only, account-scoped invalidation channel. REST remains canonical;
/// every successful handshake (including reconnects) reloads missed changes.
class SocialRealtimeClient {
  SocialRealtimeClient({
    required this.ticketUri,
    required this.accountId,
    required this.serverInstanceId,
    required this.onInvalidate,
    this.connector = const WebSocketChannelConnector(),
    this.retryBase = const Duration(seconds: 1),
    this.heartbeatTimeout = const Duration(seconds: 50),
  });

  final Future<Uri> Function() ticketUri;
  final String accountId, serverInstanceId;
  final void Function() onInvalidate;
  final CollaborationSocketConnector connector;
  final Duration retryBase, heartbeatTimeout;
  CollaborationSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  Timer? _retry, _watchdog;
  int _generation = 0, _attempts = 0;
  bool _disposed = false, _started = false, _ready = false;

  void start() {
    if (_disposed || _started) return;
    _started = true;
    unawaited(_connect());
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  Future<void> _connect() async {
    final generation = ++_generation;
    try {
      final uri = await ticketUri().timeout(const Duration(seconds: 12));
      if (!_current(generation)) return;
      final pending = connector.connect(uri);
      // A timed-out native connection can still succeed later: close it too.
      unawaited(pending.then((socket) {
        if (!_current(generation)) _close(socket);
      }, onError: (Object _) {}));
      final socket = await pending.timeout(const Duration(seconds: 12));
      if (!_current(generation)) {
        _close(socket);
        return;
      }
      _socket = socket;
      _ready = false;
      _armWatchdog(generation);
      _subscription = socket.messages.listen(
        (raw) => _message(raw, generation),
        onError: (Object _) => _disconnected(generation),
        onDone: () => _disconnected(generation),
      );
    } catch (_) {
      _disconnected(generation);
    }
  }

  void _message(Object? raw, int generation) {
    if (!_current(generation)) return;
    try {
      if (raw is! String || raw.length > 4096) throw const FormatException();
      final message = jsonDecode(raw) as Map<String, dynamic>;
      switch (message['type']) {
        case 'social.ready':
          if (message['userId'] != accountId ||
              message['serverInstanceId'] != serverInstanceId) {
            throw const FormatException('Unexpected account or server');
          }
          _ready = true;
          _attempts = 0;
          onInvalidate();
        case 'social.changed':
          if (!_ready) throw const FormatException('Handshake required');
          onInvalidate();
        case 'social.ping':
          if (!_ready) throw const FormatException('Handshake required');
        default:
          throw const FormatException('Unknown notification');
      }
      _armWatchdog(generation);
    } catch (_) {
      _disconnected(generation);
    }
  }

  void _armWatchdog(int generation) {
    _watchdog?.cancel();
    _watchdog = Timer(heartbeatTimeout, () => _disconnected(generation));
  }

  void _close(CollaborationSocket socket) {
    unawaited(socket.close().catchError((Object _) {}));
  }

  void _disconnected(int generation) {
    if (!_current(generation)) return;
    _generation++;
    _watchdog?.cancel();
    unawaited(_subscription?.cancel());
    _subscription = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) _close(socket);
    final base =
        min(30000, retryBase.inMilliseconds * (1 << min(_attempts++, 5)));
    _retry?.cancel();
    _retry = Timer(
        Duration(milliseconds: base + Random().nextInt(max(1, base ~/ 4))), () {
      if (!_disposed) unawaited(_connect());
    });
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _retry?.cancel();
    _watchdog?.cancel();
    unawaited(_subscription?.cancel());
    if (_socket case final socket?) _close(socket);
    _socket = null;
  }
}
