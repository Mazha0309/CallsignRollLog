import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openlogtool/models/account_share_dto.dart';
import 'package:openlogtool/models/dictionary_item.dart';
import 'package:openlogtool/models/shared_dictionary.dart';
import 'package:openlogtool/providers/account_share_provider.dart';

import 'account_share_provider_test.dart' show FakeServer, apiWith, snapshot;

const features = [
  'accountSessionSharing',
  'batchSessionSharing',
  'accountShareDictionary',
];

http.Response json(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

void main() {
  test('omitted shareDictionary stays off', () {
    final grant = AccountShareGrantDto.fromJson({
      'id': 'old',
      'grantorUserId': 'owner',
      'granteeUserId': 'reader',
      'status': 'accepted',
    });
    expect(grant.shareDictionary, isFalse);
  });

  test('own dictionary wins and shared rows stay out of the local library', () {
    final merged = mergeSharedDictionary(
      own: [
        DictionaryItem(
          raw: 'IC-705',
          pinyin: 'mine',
          abbreviation: 'me',
          type: 'device',
          origin: 'user',
          syncId: 'own-1',
        ),
      ],
      shared: const [
        SharedDictionaryItem(
            dictType: 'device', raw: 'IC-705', pinyin: 'other'),
        SharedDictionaryItem(
          dictType: 'antenna',
          raw: 'Yagi',
          abbreviation: 'Y',
        ),
      ],
      sourceLabel: '来自 owner',
    );
    expect(merged.map((item) => item.raw), ['IC-705', 'Yagi']);
    expect(merged.first.origin, 'user');
    expect(merged.last.origin, 'shared');
    expect(merged.last.sourceLabel, '来自 owner');
  });

  test('dictionary field is omitted unless the server advertises it', () async {
    final bodies = <Map<String, Object?>>[];
    final server = FakeServer(apiWith((request) async {
      if (request.method != 'GET') {
        bodies.add(jsonDecode(request.body) as Map<String, Object?>);
      }
      return request.url.path.endsWith('/social')
          ? snapshot('bob')
          : json({'items': []});
    }), features: const [
      'friendCollaboration',
      'accountSessionSharing',
      'batchSessionSharing',
    ])
      ..id = 'owner';
    final sharing = AccountShareProvider();
    addTearDown(sharing.dispose);
    addTearDown(server.dispose);
    sharing.updateServer(server);
    await Future<void>.delayed(Duration.zero);
    await sharing.saveShare(
      username: 'bob',
      scopeMode: 'all',
      sessions: const [],
      canEditLogs: false,
      canDeleteLogs: false,
      shareDictionary: true,
      expectedScope: sharing.accountScope,
    );
    expect(bodies.single.containsKey('shareDictionary'), isFalse);
  });

  test('accepted dictionary is cached by revision and dropped when access ends',
      () async {
    var revision = 3;
    var shareDictionary = true;
    var dictionaryStatus = 200;
    final dictionaryReads = <String>[];
    final historyCalls = <String>[];
    final server = FakeServer(apiWith((request) async {
      if (request.url.path.endsWith('/dictionary')) {
        dictionaryReads.add(request.url.path);
        if (dictionaryStatus != 200) {
          return json({
            'error': {
              'code': 'NOT_FOUND',
              'message': 'missing',
              'requestId': 'r',
            },
          }, dictionaryStatus);
        }
        return json({
          'grantId': 'grant-1',
          'grantorUsername': 'owner',
          'exists': true,
          'revision': revision,
          'items': [
            {
              'dictType': 'device',
              'raw': 'IC-705',
              'pinyin': null,
              'abbreviation': null,
            },
          ],
        });
      }
      if (request.url.path.endsWith('/callsign-history')) {
        historyCalls.add(request.url.queryParameters['callsign']!);
        expect(request.url.queryParameters['callsign'], 'BG5AAA');
        return json({
          'grantId': 'grant-1',
          'grantorUsername': 'owner',
          'callsign': 'BG5AAA',
          'items': [
            {
              'candidateId': 'one',
              'callsign': 'BG5AAA',
              'device': 'IC-705',
              'antenna': '',
              'qth': 'Shanghai',
              'power': '10W',
              'height': '',
              'remarks': 'hidden',
            },
          ],
        });
      }
      if (request.url.path.endsWith('/social')) return snapshot('bob');
      if (request.url.queryParameters['box'] == 'active') {
        return json({
          'items': [
            {
              'id': 'grant-1',
              'grantorUserId': 'owner',
              'grantorUsername': 'owner',
              'granteeUserId': 'reader',
              'status': 'accepted',
              'shareDictionary': shareDictionary,
            },
          ],
        });
      }
      return json({'items': []});
    }), features: features)
      ..id = 'reader';
    final sharing = AccountShareProvider();
    addTearDown(sharing.dispose);
    addTearDown(server.dispose);
    sharing.updateServer(server);
    await Future<void>.delayed(Duration.zero);
    expect(sharing.receivedGrants.single.shareDictionary, isTrue);

    final first = await sharing.ensureSharedDictionary('grant-1');
    revision = 3;
    final second = await sharing.ensureSharedDictionary('grant-1');
    expect(identical(first, second), isTrue);
    expect(first!.items.single.raw, 'IC-705');
    expect(dictionaryReads, hasLength(2));

    revision = 4;
    final updated = await sharing.ensureSharedDictionary('grant-1');
    expect(identical(updated, first), isFalse);
    expect(updated!.revision, 4);

    final history = await sharing.sharedCallsignHistory(
      grantId: 'grant-1',
      callsign: '  bg5aaa  ',
      canEditLogs: true,
      expectedScope: sharing.accountScope,
    );
    expect(history.single.device, 'IC-705');
    expect(history.single.qth, 'Shanghai');
    expect(historyCalls, ['BG5AAA']);
    await sharing.sharedCallsignHistory(
      grantId: 'grant-1',
      callsign: 'BG5AAA',
      canEditLogs: false,
      expectedScope: sharing.accountScope,
    );
    expect(historyCalls, ['BG5AAA']);

    shareDictionary = false;
    await sharing.refresh();
    expect(sharing.dictionaryFor('grant-1'), isNull);

    shareDictionary = true;
    dictionaryStatus = 200;
    await sharing.refresh();
    await sharing.ensureSharedDictionary('grant-1');
    expect(sharing.dictionaryFor('grant-1'), isNotNull);
    dictionaryStatus = 404;
    expect(await sharing.ensureSharedDictionary('grant-1'), isNull);
    expect(sharing.dictionaryFor('grant-1'), isNull);
  });
}
