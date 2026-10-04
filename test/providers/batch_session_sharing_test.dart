import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openlogtool/models/account_share_dto.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/services/server_api.dart';
import 'account_share_provider_test.dart' show FakeServer, apiWith, snapshot;

const features = [
  'friendCollaboration',
  'accountSessionSharing',
  'batchSessionSharing'
];
http.Response items(List<Object?> items) =>
    http.Response(jsonEncode({'items': items}), 200);
void main() {
  test(
      'inbox appears while catalog is slow and survives unrelated load failures',
      () async {
    final catalog = Completer<http.Response>();
    final server = FakeServer(apiWith((request) async {
      if (request.url.path.endsWith('/social')) {
        throw http.ClientException('social unavailable');
      }
      if (request.url.path.endsWith('/shared-sessions')) return catalog.future;
      return items(request.url.queryParameters['box'] == 'inbox'
          ? [
              {
                'id': 'share-1',
                'grantorUserId': 'bob',
                'granteeUserId': 'owner',
                'grantorUsername': 'bob',
                'status': 'pending',
              }
            ]
          : []);
    }), features: features)
      ..id = 'owner';
    final sharing = AccountShareProvider();
    addTearDown(sharing.dispose);
    addTearDown(server.dispose);
    sharing.updateServer(server);
    await Future<void>.delayed(Duration.zero);
    expect(sharing.loading, isTrue);
    expect(sharing.inbox.single.id, 'share-1');
    expect(sharing.pendingInboundKeys, {'share:share-1'});
    catalog.complete(http.Response(
        '{"error":{"code":"SNAPSHOT_CORRUPT","message":"unavailable"}}', 500));
    await Future<void>.delayed(Duration.zero);
    expect(sharing.loading, isFalse);
    expect(sharing.lastError, isNotNull);
    expect(sharing.inboxError, isNull);
    expect(sharing.inbox.single.id, 'share-1');
  });

  test('failed inbox is visible and a late old inbox cannot cross accounts',
      () async {
    final oldInbox = Completer<http.Response>();
    var first = true;
    final server = FakeServer(apiWith((request) async {
      if (request.url.path.endsWith('/social')) return snapshot('friend');
      if (request.url.queryParameters['box'] == 'inbox') {
        if (first) {
          first = false;
          return oldInbox.future;
        }
        throw http.ClientException('offline');
      }
      return items([]);
    }), features: features)
      ..id = 'owner';
    final sharing = AccountShareProvider();
    addTearDown(sharing.dispose);
    addTearDown(server.dispose);
    sharing.updateServer(server);
    await Future<void>.delayed(Duration.zero);
    server.id = 'another';
    sharing.updateServer(server);
    await Future<void>.delayed(Duration.zero);
    oldInbox.complete(items([
      {'id': 'private-old', 'status': 'pending'}
    ]));
    await Future<void>.delayed(Duration.zero);
    expect(sharing.inbox, isEmpty);
    expect(sharing.inboxError, isNotNull);
  });
  test(
      'batch grants send selected scope and separate record capabilities; all omits selection',
      () async {
    final bodies = <Map<String, Object?>>[];
    final server = FakeServer(apiWith((request) async {
      if (request.method == 'GET') {
        return request.url.path.endsWith('/social')
            ? snapshot('bob')
            : items([]);
      }
      bodies.add(jsonDecode(request.body) as Map<String, Object?>);
      return http.Response('{}', 200);
    }), features: features)
      ..id = 'owner';
    final sharing = AccountShareProvider();
    addTearDown(sharing.dispose);
    addTearDown(server.dispose);
    sharing.updateServer(server);
    await Future<void>.delayed(Duration.zero);
    const selection = [
      ShareSessionRef(source: 'personal', sessionId: 'a'),
      ShareSessionRef(source: 'collaboration', sessionId: 'b')
    ];
    await sharing.saveShare(
        username: 'bob',
        scopeMode: 'selected',
        sessions: selection,
        canEditLogs: true,
        canDeleteLogs: false,
        expectedScope: sharing.accountScope);
    expect(bodies.single, {
      'granteeUsername': 'bob',
      'includePersonal': true,
      'includeOwned': true,
      'includeEditor': false,
      'canJoinAs': 'none',
      'scopeMode': 'selected',
      'selectedSessions': [
        {'source': 'personal', 'sessionId': 'a'},
        {'source': 'collaboration', 'sessionId': 'b'}
      ],
      'canEditLogs': true,
      'canDeleteLogs': false
    });
    await sharing.saveShare(
        username: 'bob',
        scopeMode: 'all',
        sessions: selection,
        canEditLogs: true,
        canDeleteLogs: true,
        expectedScope: sharing.accountScope,
        grantId: 'existing');
    expect(bodies.last['selectedSessions'], isEmpty);
    expect(bodies.last['scopeMode'], 'all');
    expect(bodies.last['canDeleteLogs'], isTrue);
    final scope = sharing.accountScope;
    server.id = 'other';
    sharing.updateServer(server);
    await expectLater(
        sharing.respondShare('existing', 'revoke', expectedScope: scope),
        throwsStateError);
    expect(bodies.length, 2);
  });
  test(
      'modern messages include sharing requests and retry reuses one idempotency key',
      () async {
    final keys = <String>[];
    final server = FakeServer(apiWith((request) async {
      if (request.method == 'GET') {
        if (request.url.path.endsWith('/social')) return snapshot('bob');
        return items(request.url.queryParameters['box'] == 'inbox'
            ? [
                {
                  'id': 'incoming',
                  'grantorUserId': 'bob',
                  'granteeUserId': 'owner',
                  'grantorUsername': 'bob',
                  'status': 'pending'
                }
              ]
            : []);
      }
      keys.add(request.headers['idempotency-key']!);
      if (keys.length == 1) throw http.ClientException('lost response');
      return http.Response('{}', 200);
    }), features: features)
      ..id = 'owner';
    final sharing = AccountShareProvider();
    addTearDown(sharing.dispose);
    addTearDown(server.dispose);
    sharing.updateServer(server);
    await Future<void>.delayed(Duration.zero);
    expect(sharing.pendingInboundCount, 1);
    await expectLater(
        sharing.respondShare('incoming', 'accept',
            expectedScope: sharing.accountScope),
        throwsA(isA<ServerApiException>()));
    await sharing.respondShare('incoming', 'accept',
        expectedScope: sharing.accountScope);
    expect(keys.length, 2);
    expect(keys[0], keys[1]);
  });
  test('shared record reads preserve pagination and exact grant identity',
      () async {
    final server = FakeServer(apiWith((request) async {
      if (request.url.path.endsWith('/logs')) {
        expect(request.url.queryParameters['grantId'], 'grant');
        expect(request.url.queryParameters['page'], '2');
        expect(request.url.queryParameters['q'], 'test');
        return http.Response(
            '{"items":[{"sync_id":"log"}],"total":51,"page":2,"totalPages":2}',
            200);
      }
      return request.url.path.endsWith('/social') ? snapshot('bob') : items([]);
    }), features: features)
      ..id = 'owner';
    final sharing = AccountShareProvider();
    addTearDown(sharing.dispose);
    addTearDown(server.dispose);
    sharing.updateServer(server);
    await Future<void>.delayed(Duration.zero);
    final page = await sharing.loadSharedRecords(
        const SharedSessionDto(
            source: 'personal',
            sessionId: 'same-id',
            title: '',
            status: 'active',
            grantorUsername: 'bob',
            canJoin: false,
            createdAt: '',
            updatedAt: '',
            grantId: 'grant'),
        page: 2,
        query: 'test',
        expectedScope: sharing.accountScope);
    expect(page.page, 2);
    expect(page.total, 51);
    expect(page.totalPages, 2);
  });
}
