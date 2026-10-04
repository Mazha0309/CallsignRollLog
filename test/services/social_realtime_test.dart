import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/services/collaboration_sync.dart';
import 'package:openlogtool/services/social_realtime.dart';

class TestSocialSocket implements CollaborationSocket {
  final controller = StreamController<Object?>();
  bool closed = false;
  void emit(String type, [Map<String, Object?> fields = const {}]) =>
      controller.add(jsonEncode({'type': type, ...fields}));
  @override
  Stream<Object?> get messages => controller.stream;
  @override
  Future<void> close() async {
    closed = true;
    if (!controller.isClosed) unawaited(controller.close());
  }
}

class TestSocialConnector implements CollaborationSocketConnector {
  final sockets = <TestSocialSocket>[];
  Completer<CollaborationSocket>? pending;
  @override
  Future<CollaborationSocket> connect(Uri uri) async {
    final socket = TestSocialSocket();
    sockets.add(socket);
    return pending?.future ?? Future.value(socket);
  }
}

void main() {
  testWidgets(
      'ready/change invalidate; heartbeats do not poll; disconnect resyncs',
      (tester) async {
    final sockets = TestSocialConnector();
    var changes = 0, tickets = 0;
    final client = SocialRealtimeClient(
      accountId: 'bob',
      serverInstanceId: 'server',
      connector: sockets,
      ticketUri: () async =>
          Uri.parse('wss://example.test/ws/social?ticket=${++tickets}'),
      onInvalidate: () => changes++,
      retryBase: const Duration(milliseconds: 10),
    )..start();
    addTearDown(client.dispose);
    await tester.pump();
    sockets.sockets.first
        .emit('social.ready', {'userId': 'bob', 'serverInstanceId': 'server'});
    await tester.pump();
    expect(changes, 1);
    sockets.sockets.first.emit('social.changed');
    await tester.pump();
    expect(changes, 2);
    await tester.pump(const Duration(seconds: 31));
    sockets.sockets.first.emit('social.ping');
    await tester.pump();
    expect(changes, 2);
    expect(tickets, 1);
    await sockets.sockets.first.close();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(tickets, 2);
    sockets.sockets.last
        .emit('social.ready', {'userId': 'bob', 'serverInstanceId': 'server'});
    await tester.pump();
    expect(changes, 3);
    client.dispose();
    await tester.pump();
  });

  testWidgets('wrong account is rejected and disposal closes late handshakes',
      (tester) async {
    final sockets = TestSocialConnector();
    var changes = 0;
    final client = SocialRealtimeClient(
      accountId: 'bob',
      serverInstanceId: 'server',
      connector: sockets,
      ticketUri: () async =>
          Uri.parse('wss://example.test/ws/social?ticket=one'),
      onInvalidate: () => changes++,
      retryBase: const Duration(milliseconds: 10),
    )..start();
    addTearDown(client.dispose);
    await tester.pump();
    sockets.sockets.first.emit(
        'social.ready', {'userId': 'alice', 'serverInstanceId': 'server'});
    await tester.pump();
    expect(changes, 0);
    expect(sockets.sockets.first.closed, isTrue);
    final pending = Completer<CollaborationSocket>();
    sockets.pending = pending;
    await tester.pump(const Duration(milliseconds: 20));
    client.dispose();
    pending.complete(sockets.sockets.last);
    await tester.pump();
    expect(sockets.sockets.last.closed, isTrue);
    await tester.pump(const Duration(minutes: 1));
    expect(sockets.sockets, hasLength(2));
  });

  testWidgets('missing heartbeat reconnects without periodic data requests',
      (tester) async {
    final sockets = TestSocialConnector();
    final client = SocialRealtimeClient(
      accountId: 'bob',
      serverInstanceId: 'server',
      connector: sockets,
      ticketUri: () async =>
          Uri.parse('wss://example.test/ws/social?ticket=one'),
      onInvalidate: () {},
      retryBase: const Duration(milliseconds: 10),
    )..start();
    addTearDown(client.dispose);
    await tester.pump();
    sockets.sockets.first
        .emit('social.ready', {'userId': 'bob', 'serverInstanceId': 'server'});
    await tester.pump();
    await tester.pump(const Duration(seconds: 51));
    expect(sockets.sockets.first.closed, isTrue);
    await tester.pump(const Duration(milliseconds: 20));
    expect(sockets.sockets, hasLength(2));
    client.dispose();
    await tester.pump();
  });
}
