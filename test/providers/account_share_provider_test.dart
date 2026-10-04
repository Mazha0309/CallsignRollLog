import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openlogtool/models/collaboration_dto.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/services/server_api.dart';
import '../services/social_realtime_test.dart' show TestSocialConnector;

http.Response snapshot(String name) => http.Response(
    jsonEncode({
      'friends': [
        {'userId': name, 'username': name}
      ],
      'friendRequests': [],
      'sessionRequests': [],
      'sessions': [],
      'blocks': [],
    }),
    200,
    headers: {'content-type': 'application/json'});
ServerApi apiWith(Future<http.Response> Function(http.Request) handler) =>
    ServerApi(
        baseUri: Uri.parse('https://example.test'),
        httpClient: MockClient(handler),
        tokenStore: MemoryTokenStore(AuthSessionDto(
            accessToken: 'access',
            accessTokenExpiresIn: 900,
            refreshToken: 'refresh',
            refreshTokenExpiresAt: DateTime.utc(2099),
            user:
                const ApiUserDto(id: 'user', username: 'user', role: 'user'))));

void main() {
  test('user search encodes the query and parses relationship metadata',
      () async {
    final server = FakeServer(apiWith((request) async {
      if (request.url.path.endsWith('/social')) return snapshot('friend');
      expect(request.url.path, '/api/v1/social/users');
      expect(request.url.queryParameters['query'], 'BA & 1');
      expect(request.method, 'GET');
      return http.Response(
          jsonEncode({
            'items': [
              {
                'userId': 'alice',
                'username': 'BA & 1',
                'relationship': 'incoming',
                'requestId': 'pending-1'
              }
            ],
            'hasMore': true
          }),
          200);
    }))
      ..id = 'bob';
    final provider = AccountShareProvider();
    addTearDown(provider.dispose);
    addTearDown(server.dispose);
    provider.updateServer(server);
    await Future<void>.delayed(Duration.zero);
    final result = await provider.searchUsers('  BA & 1  ');
    expect(result.items.single.relationship, 'incoming');
    expect(result.items.single.requestId, 'pending-1');
    expect(result.hasMore, isTrue);
    await expectLater(provider.searchUsers(' B '), throwsArgumentError);
  });
  test('search response cannot be returned to a different account', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final server = FakeServer(apiWith((request) async {
      if (request.url.path.endsWith('/social')) return snapshot('friend');
      started.complete();
      return response.future;
    }))
      ..id = 'bob';
    final provider = AccountShareProvider();
    addTearDown(provider.dispose);
    addTearDown(server.dispose);
    provider.updateServer(server);
    await Future<void>.delayed(Duration.zero);
    final search = provider.searchUsers('BA');
    final assertion = expectLater(search, throwsStateError);
    await started.future;
    server.id = 'carol';
    provider.updateServer(server);
    response.complete(http.Response('{"items":[],"hasMore":false}', 200));
    await assertion;
  });
  testWidgets(
      'WebSocket invalidations during a load are replayed without polling',
      (tester) async {
    final first = Completer<http.Response>();
    var reads = 0;
    final sockets = TestSocialConnector();
    final server = FakeServer(apiWith((request) async {
      if (request.url.path.endsWith('/ws-ticket')) {
        return http.Response('{"ticket":"one"}', 200);
      }
      reads++;
      if (reads == 1) return first.future;
      return snapshot('latest');
    }), features: const ['friendCollaboration', 'socialWebSocket'])
      ..id = 'bob';
    final provider = AccountShareProvider(socialSocketConnector: sockets);
    provider.updateServer(server);
    await tester.pump();
    expect(reads, 1);
    sockets.sockets.single
        .emit('social.ready', {'userId': 'bob', 'serverInstanceId': 'test'});
    sockets.sockets.single.emit('social.changed');
    sockets.sockets.single.emit('social.changed');
    await tester.pump();
    first.complete(snapshot('outdated'));
    await tester.pump();
    expect(reads, 2);
    expect(provider.social.friends.single.username, 'latest');
    await tester.pump(const Duration(seconds: 31));
    expect(reads, 2, reason: 'Modern servers use no 30-second poll');
    server.id = null;
    provider.updateServer(server);
    await tester.pump();
    expect(sockets.sockets.single.closed, isTrue);
    expect(provider.social.friends, isEmpty);
    provider.dispose();
    server.dispose();
    await tester.pump();
  });

  test('modern server retains legacy shared history during migration',
      () async {
    final server = FakeServer(apiWith((request) async {
      if (request.url.path.endsWith('/social')) return snapshot('alice');
      return http.Response(
          jsonEncode({
            'items': request.url.path.endsWith('/shared-sessions')
                ? [
                    {'sessionId': 'old-session', 'title': 'Legacy history'}
                  ]
                : []
          }),
          200);
    }), features: const ['friendCollaboration', 'accountSessionSharing'])
      ..id = 'bob';
    final provider = AccountShareProvider();
    addTearDown(provider.dispose);
    addTearDown(server.dispose);
    provider.updateServer(server);
    await Future<void>.delayed(Duration.zero);
    expect(provider.social.friends.single.username, 'alice');
    expect(provider.sharedHistoryEntries().single.session.sessionId,
        'old-session');
  });
  test(
      'account change during post-mutation refresh cannot report a successful join',
      () async {
    final refresh = Completer<http.Response>();
    final refreshing = Completer<void>();
    var reads = 0;
    final server = FakeServer(apiWith((request) async {
      if (request.method != 'GET') return http.Response('{}', 200);
      if (++reads == 2) {
        refreshing.complete();
        return refresh.future;
      }
      return snapshot('friend');
    }))
      ..id = 'alice';
    final provider = AccountShareProvider();
    addTearDown(provider.dispose);
    addTearDown(server.dispose);
    provider.updateServer(server);
    await Future<void>.delayed(Duration.zero);
    final mutation =
        provider.mutateSocial('POST', '/session-requests/example/accept');
    final assertion = expectLater(mutation, throwsA(isA<StateError>()));
    await refreshing.future;
    server.id = 'bob';
    provider.updateServer(server);
    refresh.complete(snapshot('old-friend'));
    await assertion;
    expect(provider.busy, isFalse);
  });
  test(
      'same provider object handles login and logout without leaking its old list',
      () async {
    final server = FakeServer(apiWith((_) async => snapshot('alice')));
    final provider = AccountShareProvider();
    addTearDown(provider.dispose);
    addTearDown(server.dispose);
    provider.updateServer(server);
    await Future<void>.delayed(Duration.zero);
    expect(provider.social.friends, isEmpty);
    server.id = 'bob';
    provider.updateServer(server);
    await Future<void>.delayed(Duration.zero);
    expect(provider.social.friends.single.username, 'alice');
    server.id = null;
    provider.updateServer(server);
    expect(provider.social.friends, isEmpty);
    await Future<void>.delayed(Duration.zero);
  });
  test('late response cannot repopulate the next account', () async {
    final late = Completer<http.Response>();
    final started = Completer<void>();
    var calls = 0;
    final server = FakeServer(apiWith((_) async {
      if (++calls == 1) {
        started.complete();
        return late.future;
      }
      return snapshot('carol-friend');
    }))
      ..id = 'alice';
    final provider = AccountShareProvider();
    addTearDown(provider.dispose);
    addTearDown(server.dispose);
    provider.updateServer(server);
    await started.future;
    server.id = 'carol';
    provider.updateServer(server);
    await Future<void>.delayed(Duration.zero);
    expect(provider.social.friends.single.username, 'carol-friend');
    late.complete(snapshot('alice-friend'));
    await Future<void>.delayed(Duration.zero);
    expect(provider.social.friends.single.username, 'carol-friend');
  });
  test('retry after lost response reuses the mutation id', () async {
    final keys = <String>[];
    final server = FakeServer(apiWith((request) async {
      if (request.method == 'GET') return snapshot('alice');
      keys.add(request.headers['idempotency-key']!);
      if (keys.length == 1) throw http.ClientException('connection lost');
      return http.Response('{}', 200);
    }))
      ..id = 'bob';
    final provider = AccountShareProvider();
    addTearDown(provider.dispose);
    addTearDown(server.dispose);
    provider.updateServer(server);
    await Future<void>.delayed(Duration.zero);
    await expectLater(
        provider
            .mutateSocial('POST', '/friend-requests', {'username': 'alice'}),
        throwsA(isA<ServerApiException>()));
    await provider
        .mutateSocial('POST', '/friend-requests', {'username': 'alice'});
    expect(keys.length, 2);
    expect(keys.first, keys.last);
    expect(provider.busy, isFalse);
  });
}

class FakeServer extends ServerProvider {
  FakeServer(this.testApi, {this.features = const ['friendCollaboration']})
      : super(autoLoadSettings: false);
  final ServerApi testApi;
  final List<String> features;
  String? id;
  @override
  ServerApi get api => testApi;
  @override
  String? get accountId => id;
  @override
  bool get isLoggedIn => id != null;
  @override
  String get serverUrl => 'https://example.test';
  @override
  ServerInfoDto get serverInfo => ServerInfoDto(
      serverInstanceId: 'test',
      protocolMin: 1,
      protocolMax: 1,
      features: features,
      serverTime: DateTime.utc(2026),
      environment: 'test');
}
