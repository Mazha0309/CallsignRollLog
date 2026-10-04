import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openlogtool/models/collaboration_dto.dart';
import 'package:openlogtool/models/live_draft.dart';
import 'package:openlogtool/services/server_api.dart';

void main() {
  group('ServerApi authentication', () {
    test('register and login persist tokens, then logout clears them',
        () async {
      final store = MemoryTokenStore();
      final seen = <String>[];
      final client = MockClient((request) async {
        seen.add('${request.method} ${request.url.path}');
        switch ('${request.method} ${request.url.path}') {
          case 'POST /api/v1/auth/register':
            expect(jsonDecode(request.body), {
              'username': 'alice',
              'password': 'a-secure-password',
              'deviceId': 'device-1',
            });
            return _jsonResponse(
                _authJson('register-access', 'register-refresh'), 201);
          case 'POST /api/v1/auth/login':
            return _jsonResponse(_authJson('login-access', 'login-refresh'));
          case 'POST /api/v1/auth/logout':
            expect(request.headers['authorization'], 'Bearer login-access');
            expect(jsonDecode(request.body), {'refreshToken': 'login-refresh'});
            return http.Response('', 204);
          default:
            fail('Unexpected request: ${request.method} ${request.url}');
        }
      });
      final api = _api(store: store, client: client);

      await api.register(
        const AuthCredentialsDto(
          username: 'alice',
          password: 'a-secure-password',
          deviceId: 'device-1',
        ),
      );
      expect((await store.read())?.accessToken, 'register-access');

      await api.login(
        const AuthCredentialsDto(
          username: 'alice',
          password: 'a-secure-password',
        ),
      );
      expect((await store.read())?.accessToken, 'login-access');

      await api.logout();
      expect(await store.read(), isNull);
      expect(seen, [
        'POST /api/v1/auth/register',
        'POST /api/v1/auth/login',
        'POST /api/v1/auth/logout',
      ]);
    });

    test('a 401 refreshes once, stores rotated tokens, and retries once',
        () async {
      final store = MemoryTokenStore(
        AuthSessionDto.fromJson(_authJson('old-access', 'old-refresh')),
      );
      var meCalls = 0;
      var refreshCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/me') {
          meCalls += 1;
          if (meCalls == 1) {
            expect(request.headers['authorization'], 'Bearer old-access');
            return _apiError(401, 'TOKEN_EXPIRED');
          }
          expect(request.headers['authorization'], 'Bearer new-access');
          return _jsonResponse(_userJson);
        }
        if (request.url.path == '/api/v1/auth/refresh') {
          refreshCalls += 1;
          expect(jsonDecode(request.body), {
            'refreshToken': 'old-refresh',
            'deviceId': 'device-1',
          });
          return _jsonResponse(_authJson('new-access', 'new-refresh'));
        }
        fail('Unexpected request: ${request.method} ${request.url}');
      });
      final api = _api(store: store, client: client);

      final user = await api.getMe();

      expect(user.username, 'alice');
      expect(meCalls, 2);
      expect(refreshCalls, 1);
      expect((await store.read())?.refreshToken, 'new-refresh');
    });

    test('a second 401 is not refreshed again and clears current tokens',
        () async {
      final store = MemoryTokenStore(
        AuthSessionDto.fromJson(_authJson('old-access', 'old-refresh')),
      );
      var refreshCalls = 0;
      var meCalls = 0;
      var invalidations = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/refresh') {
          refreshCalls += 1;
          return _jsonResponse(_authJson('new-access', 'new-refresh'));
        }
        meCalls += 1;
        return _apiError(401, 'TOKEN_INVALID');
      });
      final api = _api(
        store: store,
        client: client,
        onAuthInvalidated: () => invalidations += 1,
      );

      await expectLater(
        api.getMe(),
        throwsA(
          isA<ServerApiException>()
              .having((error) => error.code, 'code', 'TOKEN_INVALID')
              .having((error) => error.statusCode, 'statusCode', 401),
        ),
      );

      expect(meCalls, 2);
      expect(refreshCalls, 1);
      expect(await store.read(), isNull);
      expect(invalidations, 1);
    });

    test('a non-token 401 after refresh does not erase the rotated session',
        () async {
      final store = MemoryTokenStore(
        AuthSessionDto.fromJson(_authJson('old-access', 'old-refresh')),
      );
      var accountCalls = 0;
      var invalidations = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/refresh') {
          return _jsonResponse(_authJson('new-access', 'new-refresh'));
        }
        accountCalls += 1;
        return accountCalls == 1
            ? _apiError(401, 'TOKEN_EXPIRED')
            : _apiError(401, 'AUTH_REQUIRED');
      });
      final api = _api(
        store: store,
        client: client,
        onAuthInvalidated: () => invalidations += 1,
      );

      await expectLater(
        api.getMe(),
        throwsA(
          isA<ServerApiException>()
              .having((error) => error.code, 'code', 'AUTH_REQUIRED'),
        ),
      );

      expect((await store.read())?.refreshToken, 'new-refresh');
      expect(invalidations, 0);
    });

    test('an ambiguous refresh 401 preserves the current login', () async {
      final store = MemoryTokenStore(
        AuthSessionDto.fromJson(_authJson('old-access', 'old-refresh')),
      );
      var invalidations = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/refresh') {
          return _apiError(401, 'AUTH_REQUIRED');
        }
        return _apiError(401, 'TOKEN_EXPIRED');
      });
      final api = _api(
        store: store,
        client: client,
        onAuthInvalidated: () => invalidations += 1,
      );

      await expectLater(
        api.getMe(),
        throwsA(
          isA<ServerApiException>()
              .having((error) => error.code, 'code', 'AUTH_REQUIRED'),
        ),
      );

      expect((await store.read())?.refreshToken, 'old-refresh');
      expect(invalidations, 0);
    });

    test('an explicitly invalid refresh token clears the current login',
        () async {
      final store = MemoryTokenStore(
        AuthSessionDto.fromJson(_authJson('old-access', 'old-refresh')),
      );
      var invalidations = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/refresh') {
          return _apiError(401, 'REFRESH_TOKEN_INVALID');
        }
        return _apiError(401, 'TOKEN_EXPIRED');
      });
      final api = _api(
        store: store,
        client: client,
        onAuthInvalidated: () => invalidations += 1,
      );

      await expectLater(
        api.getMe(),
        throwsA(
          isA<ServerApiException>().having(
            (error) => error.code,
            'code',
            'REFRESH_TOKEN_INVALID',
          ),
        ),
      );

      expect(await store.read(), isNull);
      expect(invalidations, 1);
    });

    test('a 401 never replays with a different account session', () async {
      final store = MemoryTokenStore(
        AuthSessionDto.fromJson(_authJson('alice-access', 'alice-refresh')),
      );
      final bobSession = AuthSessionDto.fromJson(
        _authJson(
          'bob-access',
          'bob-refresh',
          user: _userJsonFor(id: 'user-2', username: 'bob'),
        ),
      );
      var meCalls = 0;
      var refreshCalls = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/auth/me') {
          meCalls += 1;
          expect(request.headers['authorization'], 'Bearer alice-access');
          await store.write(bobSession);
          return _apiError(401, 'TOKEN_EXPIRED');
        }
        if (request.url.path == '/api/v1/auth/refresh') {
          refreshCalls += 1;
        }
        fail('Unexpected request: ${request.method} ${request.url}');
      });
      final api = _api(store: store, client: client);

      await expectLater(
        api.getMe(),
        throwsA(
          isA<ServerApiException>()
              .having((error) => error.code, 'code', 'AUTH_CONTEXT_CHANGED')
              .having((error) => error.requestId, 'requestId', 'client')
              .having((error) => error.statusCode, 'statusCode', isNull),
        ),
      );

      expect(meCalls, 1);
      expect(refreshCalls, 0);
      expect((await store.read())?.user.id, 'user-2');
    });

    test('refreshes for different tokens do not share or overwrite sessions',
        () async {
      final aliceSession = AuthSessionDto.fromJson(
        _authJson('alice-access', 'alice-refresh'),
      );
      final bobSession = AuthSessionDto.fromJson(
        _authJson(
          'bob-access',
          'bob-refresh',
          user: _userJsonFor(id: 'user-2', username: 'bob'),
        ),
      );
      final store = MemoryTokenStore(aliceSession);
      final aliceResponse = Completer<http.Response>();
      final bobResponse = Completer<http.Response>();
      final refreshTokens = <String>[];
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/refresh');
        final token = (jsonDecode(request.body)
            as Map<String, dynamic>)['refreshToken'] as String;
        refreshTokens.add(token);
        return switch (token) {
          'alice-refresh' => aliceResponse.future,
          'bob-refresh' => bobResponse.future,
          _ => throw StateError('Unexpected refresh token: $token'),
        };
      });
      final api = _api(store: store, client: client);

      final aliceRefresh = api.refresh();
      await Future<void>.delayed(Duration.zero);
      await store.write(bobSession);
      final bobRefresh = api.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(refreshTokens, ['alice-refresh', 'bob-refresh']);
      bobResponse.complete(
        _jsonResponse(
          _authJson(
            'bob-access-2',
            'bob-refresh-2',
            user: _userJsonFor(id: 'user-2', username: 'bob'),
          ),
        ),
      );
      final refreshedBob = await bobRefresh;
      expect(refreshedBob.user.id, 'user-2');
      expect((await store.read())?.refreshToken, 'bob-refresh-2');

      aliceResponse.complete(
        _jsonResponse(_authJson('alice-access-2', 'alice-refresh-2')),
      );
      final refreshedAlice = await aliceRefresh;
      expect(refreshedAlice.user.id, 'user-1');
      expect((await store.read())?.refreshToken, 'bob-refresh-2');
      expect((await store.read())?.user.id, 'user-2');
    });
  });

  group('ServerApi account sharing', () {
    test('parses share grants and shared sessions from items envelopes',
        () async {
      final store = MemoryTokenStore(
        AuthSessionDto.fromJson(_authJson('access', 'refresh')),
      );
      final client = MockClient((request) async {
        switch ('${request.method} ${request.url.path}') {
          case 'GET /api/v1/account/session-shares':
            expect(request.url.queryParameters['box'], 'inbox');
            return _jsonResponse({
              'items': [
                {
                  'id': 'grant-1',
                  'grantorUserId': 'bob-id',
                  'granteeUserId': 'user-1',
                  'status': 'pending',
                },
              ],
            });
          case 'POST /api/v1/account/session-shares':
            return _jsonResponse({
              'share': {
                'id': 'grant-2',
                'grantorUserId': 'user-1',
                'granteeUserId': 'bob-id',
                'status': 'pending',
              },
            }, 201);
          case 'GET /api/v1/account/shared-sessions':
            return _jsonResponse({
              'items': [
                {
                  'source': 'collaboration',
                  'sessionId': 'shared-1',
                  'title': 'Bob net',
                  'status': 'active',
                  'grantorUsername': 'bob',
                  'canJoin': true,
                  'createdAt': '2026-09-13T12:00:00.000Z',
                  'updatedAt': '2026-09-13T12:00:00.000Z',
                },
              ],
            });
          default:
            fail('Unexpected request: ${request.method} ${request.url}');
        }
      });
      final api = _api(store: store, client: client);
      final inbox = await api.listSessionShares('inbox');
      expect(inbox.single.id, 'grant-1');
      final created = await api.createSessionShare(
        granteeUsername: 'bob',
        idempotencyKey: 'k1',
      );
      expect(created.id, 'grant-2');
      final shared = await api.listSharedSessions();
      expect(shared.single.sessionId, 'shared-1');
      expect(shared.single.grantorUsername, 'bob');
    });
  });

  group('ServerApi account management', () {
    test('completes required password change and persists the issued session',
        () async {
      final store = MemoryTokenStore();
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/v1/auth/complete-password-change',
        );
        expect(jsonDecode(request.body), {
          'passwordChangeToken': 'temporary-change-token',
          'newPassword': 'new-secure-password',
          'deviceId': 'device-1',
        });
        return _jsonResponse(_authJson('new-access', 'new-refresh'));
      });
      final api = _api(store: store, client: client);

      final session = await api.completeRequiredPasswordChange(
        passwordChangeToken: 'temporary-change-token',
        newPassword: 'new-secure-password',
      );

      expect(session.user.username, 'alice');
      expect((await store.read())?.refreshToken, 'new-refresh');
    });

    test('uses only current-account routes for profile, password, and devices',
        () async {
      final store = MemoryTokenStore(
        AuthSessionDto.fromJson(_authJson('access', 'refresh')),
      );
      final seen = <String>[];
      final client = MockClient((request) async {
        final key = '${request.method} ${request.url.path}';
        seen.add(key);
        expect(request.headers['authorization'], 'Bearer access');
        switch (key) {
          case 'GET /api/v1/account':
            return _jsonResponse(_accountJson());
          case 'PATCH /api/v1/account/username':
            expect(jsonDecode(request.body), {
              'username': 'alice-new',
              'currentPassword': 'old-secure-password',
            });
            return _jsonResponse(_accountJson(username: 'alice-new'));
          case 'PATCH /api/v1/account/password':
            expect(jsonDecode(request.body), {
              'currentPassword': 'old-secure-password',
              'newPassword': 'new-secure-password',
            });
            return _jsonResponse({
              'passwordChangedAt': _now,
              'revokedDeviceSessionCount': 2,
              'reauthenticationRequired': true,
            });
          case 'GET /api/v1/account/sessions':
            return _jsonResponse({
              'items': [_deviceSessionJson],
            });
          case 'DELETE /api/v1/account/sessions/refresh-session-1':
            return http.Response('', 204);
          default:
            fail('Unexpected request: $key');
        }
      });
      final api = _api(store: store, client: client);

      expect((await api.getAccount()).username, 'alice');
      expect(
        (await api.changeUsername(
          username: 'alice-new',
          currentPassword: 'old-secure-password',
        ))
            .username,
        'alice-new',
      );
      expect(
        (await api.changePassword(
          currentPassword: 'old-secure-password',
          newPassword: 'new-secure-password',
        ))
            .reauthenticationRequired,
        isTrue,
      );
      final devices = await api.listDeviceSessions();
      expect(devices.single.current, isTrue);
      await api.revokeDeviceSession(devices.single.sessionId);

      expect(seen, [
        'GET /api/v1/account',
        'PATCH /api/v1/account/username',
        'PATCH /api/v1/account/password',
        'GET /api/v1/account/sessions',
        'DELETE /api/v1/account/sessions/refresh-session-1',
      ]);
    });
  });

  group('ServerApi collaboration v1 routes', () {
    test('uses typed responses and idempotency keys for Stage 1 routes',
        () async {
      final store = MemoryTokenStore(
        AuthSessionDto.fromJson(_authJson('access', 'refresh')),
      );
      final seen = <String>[];
      final expectedKeys = <String, String>{
        'PUT /api/v1/sessions/session-1': 'put-1',
        'POST /api/v1/sessions/session-1/bootstrap/logs': 'bootstrap-1',
        'POST /api/v1/sessions/session-1/activate': 'activate-1',
        'PATCH /api/v1/sessions/session-1/members/user-2': 'role-1',
        'DELETE /api/v1/sessions/session-1/members/user-2': 'remove-1',
        'POST /api/v1/sessions/session-1/transfer-ownership': 'transfer-1',
        'POST /api/v1/sessions/session-1/invites': 'invite-1',
        'DELETE /api/v1/sessions/session-1/invites/invite-1': 'revoke-1',
        'POST /api/v1/collaboration-invites/redeem': 'join-1',
      };
      final client = MockClient((request) async {
        final key = '${request.method} ${request.url.path}';
        seen.add(key);
        expect(request.headers['authorization'], 'Bearer access');
        expect(request.headers['x-device-id'], 'device-1');
        if (expectedKeys.containsKey(key)) {
          expect(request.headers['idempotency-key'], expectedKeys[key]);
        }

        switch (key) {
          case 'GET /api/v1/sessions':
            return _jsonResponse([_sessionJson]);
          case 'PUT /api/v1/sessions/session-1':
            expect(jsonDecode(request.body), {'title': 'Field Day'});
            return _jsonResponse({'session': _sessionJson}, 201);
          case 'POST /api/v1/sessions/session-1/bootstrap/logs':
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['items'], hasLength(1));
            expect(body['items'][0]['syncId'], 'log-1');
            return _jsonResponse({
              'accepted': 1,
              'inserted': 1,
              'existing': 0,
              'totalLogCount': 1,
            });
          case 'POST /api/v1/sessions/session-1/activate':
            return _jsonResponse({
              'session': _sessionJson,
              'highWatermarkSeq': 3,
              'logCount': 1,
            });
          case 'GET /api/v1/sessions/session-1/snapshot':
            return _jsonResponse({
              'protocolVersion': 1,
              'session': _sessionJson,
              'highWatermarkSeq': 3,
              'includesDeletedLogs': false,
              'logs': [_logJson],
            });
          case 'GET /api/v1/sessions/session-1/membership':
            return _jsonResponse({'membership': _membershipJson()});
          case 'GET /api/v1/sessions/session-1/members':
            return _jsonResponse({
              'members': [_membershipJson(username: 'alice')],
            });
          case 'PATCH /api/v1/sessions/session-1/members/user-2':
            return _jsonResponse({
              'membership': _membershipJson(
                userId: 'user-2',
                role: 'viewer',
              ),
            });
          case 'DELETE /api/v1/sessions/session-1/members/user-2':
            return _jsonResponse({
              'removed': true,
              'sessionId': 'session-1',
              'userId': 'user-2',
              'removedAt': _now,
            });
          case 'POST /api/v1/sessions/session-1/transfer-ownership':
            return _jsonResponse({
              'sessionId': 'session-1',
              'previousOwner': _membershipJson(role: 'editor'),
              'owner': _membershipJson(userId: 'user-2'),
            });
          case 'POST /api/v1/sessions/session-1/invites':
            return _jsonResponse(
                {'invite': _inviteJson(includeSecret: true)}, 201);
          case 'GET /api/v1/sessions/session-1/invites':
            return _jsonResponse({
              'invites': [_inviteJson()]
            });
          case 'DELETE /api/v1/sessions/session-1/invites/invite-1':
            return _jsonResponse({
              'invite': _inviteJson(revokedAt: _now),
            });
          case 'GET /api/v1/account/shared-sessions':
            return _jsonResponse({
              'items': [
                {
                  'source': 'collaboration',
                  'sessionId': 'shared-1',
                  'title': 'Shared net',
                  'status': 'active',
                  'grantorUsername': 'bob',
                  'canJoin': false,
                  'createdAt': _now,
                  'updatedAt': _now,
                },
              ],
            });
          case 'POST /api/v1/collaboration-invites/redeem':
            return _jsonResponse({
              'membership': _membershipJson(role: 'editor'),
              'roleGranted': 'editor',
              'session': _sessionJson,
              'highWatermarkSeq': 3,
            }, 201);
          default:
            fail('Unexpected request: $key');
        }
      });
      final api = _api(store: store, client: client);

      expect(await api.listSessions(), hasLength(1));
      expect(await api.listSharedSessions(), hasLength(1));
      expect(
        (await api.putSession(
          sessionId: 'session-1',
          title: 'Field Day',
          idempotencyKey: 'put-1',
        ))
            .sessionId,
        'session-1',
      );
      expect(
        (await api.bootstrapLogs(
          sessionId: 'session-1',
          items: [
            BootstrapLogDto(
              syncId: 'log-1',
              time: DateTime.parse(_now),
              controller: 'BG5CRL',
              callsign: 'K1ABC',
            ),
          ],
          idempotencyKey: 'bootstrap-1',
        ))
            .inserted,
        1,
      );
      expect(
        (await api.activateSession(
          sessionId: 'session-1',
          expectedLogCount: 1,
          idempotencyKey: 'activate-1',
        ))
            .logCount,
        1,
      );
      expect((await api.getSessionSnapshot('session-1')).logs.single.syncId,
          'log-1');
      expect((await api.getMembership('session-1')).role, SessionRole.owner);
      expect((await api.listMembers('session-1')).single.username, 'alice');
      expect(
        (await api.updateMemberRole(
          sessionId: 'session-1',
          userId: 'user-2',
          role: InviteRole.viewer,
          idempotencyKey: 'role-1',
        ))
            .role,
        SessionRole.viewer,
      );
      expect(
        (await api.removeMember(
          sessionId: 'session-1',
          userId: 'user-2',
          idempotencyKey: 'remove-1',
        ))
            .removed,
        isTrue,
      );
      expect(
        (await api.transferOwnership(
          sessionId: 'session-1',
          newOwnerUserId: 'user-2',
          idempotencyKey: 'transfer-1',
        ))
            .owner
            .userId,
        'user-2',
      );
      expect(
        (await api.createInvite(
          sessionId: 'session-1',
          request: const CreateInviteRequestDto(
            role: InviteRole.editor,
            includeLinkToken: true,
          ),
          idempotencyKey: 'invite-1',
        ))
            .code,
        'ABCDE-FG123',
      );
      expect((await api.listInvites('session-1')).single.code, isNull);
      expect(
        (await api.revokeInvite(
          sessionId: 'session-1',
          inviteId: 'invite-1',
          idempotencyKey: 'revoke-1',
        ))
            .revokedAt,
        isNotNull,
      );
      expect(
        (await api.redeemInvite(
          RedeemInviteRequestDto(
            code: 'ABCDE-FG123',
            joinRequestId: 'join-1',
          ),
        ))
            .roleGranted,
        InviteRole.editor,
      );

      expect(seen, hasLength(15));
    });

    test('server-info is public and supports a base URI already at api/v1',
        () async {
      final client = MockClient((request) async {
        expect(
            request.url.toString(), 'https://example.test/api/v1/server-info');
        expect(request.headers.containsKey('authorization'), isFalse);
        return _jsonResponse({
          'serverInstanceId': 'server-1',
          'protocolMin': 1,
          'protocolMax': 1,
          'features': ['authRefresh', 'sessionSnapshots'],
          'serverTime': _now,
          'environment': 'test',
        });
      });
      final api = ServerApi(
        baseUri: Uri.parse('https://example.test/api/v1/'),
        tokenStore: MemoryTokenStore(),
        httpClient: client,
      );

      final info = await api.getServerInfo();

      expect(info.serverInstanceId, 'server-1');
      expect(info.features, contains('sessionSnapshots'));
    });

    test('Stage 2 routes preserve cursors, mutation IDs, and ticket secrecy',
        () async {
      final store = MemoryTokenStore(
        AuthSessionDto.fromJson(_authJson('access', 'refresh')),
      );
      final operation = CollaborationMutationDto(
        mutationId: 'mutation-1',
        entityType: 'log',
        entityId: 'log-1',
        operation: 'update',
        baseVersion: 1,
        observedSeq: 3,
        patch: const {'remarks': 'mobile'},
        queuedAt: DateTime.parse(_now),
      );
      final event = {
        'protocolVersion': 1,
        'eventId': 'event-4',
        'sessionId': 'session-1',
        'seq': 4,
        'type': 'log.updated',
        'entityType': 'log',
        'entityId': 'log-1',
        'entityVersion': 2,
        'mutationId': 'mutation-1',
        'occurredAt': _now,
        'payload': {..._logJson, 'version': 2, 'remarks': 'mobile'},
      };
      final client = MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer access');
        switch ('${request.method} ${request.url.path}') {
          case 'GET /prefix/api/v1/sessions/session-1/snapshot':
            expect(request.url.queryParameters, {
              'includeDeleted': 'true',
            });
            return _jsonResponse({
              'protocolVersion': 1,
              'session': _sessionJson,
              'highWatermarkSeq': 3,
              'includesDeletedLogs': true,
              'logs': [_logJson],
            });
          case 'GET /prefix/api/v1/sessions/session-1/events':
            expect(request.url.queryParameters, {
              'afterSeq': '3',
              'limit': '250',
            });
            return _jsonResponse({
              'afterSeq': 3,
              'toSeq': 4,
              'headSeq': 4,
              'minAvailableSeq': 0,
              'hasMore': false,
              'events': [event],
            });
          case 'POST /prefix/api/v1/sessions/session-1/mutations':
            expect(jsonDecode(request.body), {
              'protocolVersion': 1,
              'deviceId': 'device-1',
              'operations': [operation.toJson()],
            });
            return _jsonResponse({
              'headSeq': 4,
              'results': [
                {
                  'mutationId': 'mutation-1',
                  'status': 'accepted',
                  'event': event,
                },
              ],
            });
          case 'POST /prefix/api/v1/sessions/session-1/ws-ticket':
            expect(jsonDecode(request.body), {
              'deviceId': 'device-1',
              'afterSeq': 4,
            });
            return _jsonResponse({
              'ticket': 'single-use-ticket',
              'expiresAt': '2026-07-11T08:01:00.000Z',
              'sessionId': 'session-1',
              'role': 'editor',
              'membershipVersion': 2,
              'afterSeq': 4,
            });
          default:
            fail('Unexpected request: ${request.method} ${request.url}');
        }
      });
      final api = ServerApi(
        baseUri: Uri.parse('https://example.test/prefix'),
        tokenStore: store,
        httpClient: client,
        deviceId: 'device-1',
      );

      final events = await api.getSessionEvents(
        sessionId: 'session-1',
        afterSeq: 3,
        limit: 250,
      );
      expect(events.events.single.seq, 4);
      final snapshot = await api.getSessionSnapshot(
        'session-1',
        includeDeleted: true,
      );
      expect(snapshot.includesDeletedLogs, isTrue);
      final result = await api.submitMutations(
        sessionId: 'session-1',
        deviceId: 'device-1',
        operations: [operation],
      );
      expect(result.results.single.event?.mutationId, 'mutation-1');
      final ticket = await api.createCollaborationWebSocketTicket(
        sessionId: 'session-1',
        deviceId: 'device-1',
        afterSeq: 4,
      );
      expect(ticket.role, SessionRole.editor);

      final socketUri = api.collaborationWebSocketUri(ticket.ticket);
      expect(socketUri.scheme, 'wss');
      expect(socketUri.path, '/prefix/ws/collaboration');
      expect(socketUri.queryParameters, {'ticket': 'single-use-ticket'});
      expect(socketUri.toString(), isNot(contains('access')));
    });

    test('live-draft routes match the v13 DTO and mutation contract', () async {
      final store = MemoryTokenStore(
        AuthSessionDto.fromJson(_authJson('access', 'refresh')),
      );
      final lock = {
        'leaseId': 'lease-1',
        'sessionId': 'session-1',
        'field': 'callsign',
        'userId': 'user-1',
        'username': 'alice',
        'deviceId': 'device-1',
        'expiresAt': '2026-07-13T08:00:30.000Z',
      };
      final event = {
        'protocolVersion': 1,
        'eventId': 'event-4',
        'sessionId': 'session-1',
        'seq': 4,
        'type': 'log.created',
        'entityType': 'log',
        'entityId': 'log-1',
        'entityVersion': 1,
        'mutationId': 'commit-1',
        'actor': {
          'userId': 'user-1',
          'deviceId': 'device-1',
          'displayName': 'alice',
        },
        'occurredAt': _now,
        'payload': _logJson,
      };
      final client = MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer access');
        switch ('${request.method} ${request.url.path}') {
          case 'GET /api/v1/sessions/session-1/live-draft':
            return _jsonResponse({
              'draft': _liveDraftJson(),
              'locks': [lock],
              'currentOrdinal': 1,
              'totalRecords': 0,
              'previousRecord': null,
            });
          case 'POST /api/v1/sessions/session-1/live-draft/locks':
            expect(jsonDecode(request.body), {
              'field': 'callsign',
              'deviceId': 'device-1',
            });
            return _jsonResponse({
              'lock': lock,
              'draft': _liveDraftJson(version: 2),
            }, 201);
          case 'POST /api/v1/sessions/session-1/live-draft/locks/lease-1/renew':
            expect(jsonDecode(request.body), {'deviceId': 'device-1'});
            return _jsonResponse({'lock': lock});
          case 'DELETE /api/v1/sessions/session-1/live-draft/locks/lease-1':
            expect(jsonDecode(request.body), {'deviceId': 'device-1'});
            return _jsonResponse({'released': true});
          case 'PUT /api/v1/sessions/session-1/live-draft/history-preview':
            expect(jsonDecode(request.body), {
              'deviceId': 'device-1',
              'leaseId': 'lease-1',
              'draftId': 'draft-1',
              'callsign': 'K1ABC',
              'candidates': [
                {
                  'candidateId': 'history-1',
                  'sourceTime': _now,
                  'qth': 'Hangzhou',
                  'device': '',
                  'power': '5W',
                  'antenna': '',
                  'height': '',
                },
              ],
            });
            return _jsonResponse({
              'historyPreview': _historyPreviewJson(),
              'draft': _liveDraftJson(),
              'locks': [lock],
            });
          case 'DELETE /api/v1/sessions/session-1/live-draft/history-preview':
            expect(jsonDecode(request.body), {
              'deviceId': 'device-1',
              'previewId': 'preview-1',
            });
            return _jsonResponse({
              'cleared': true,
              'historyPreview': null,
            });
          case 'POST /api/v1/sessions/session-1/live-draft/history-preview/preview-1/select':
            expect(request.headers['idempotency-key'], 'reuse-1');
            expect(jsonDecode(request.body), {
              'deviceId': 'device-1',
              'leaseId': 'lease-1',
              'candidateId': 'history-1',
            });
            return _jsonResponse({
              'draft': _liveDraftJson(version: 2),
              'updatedFields': ['qth', 'power'],
              'releasedLeases': [
                {'field': 'qth', 'leaseId': 'lease-qth'},
              ],
              'locks': [lock],
              'historyPreview': null,
              'historyReuse': {
                'previewId': 'preview-1',
                'candidateId': 'history-1',
                'affectedFields': ['qth', 'power'],
              },
            });
          case 'PATCH /api/v1/sessions/session-1/live-draft':
            expect(
              request.headers['prefer'],
              'openlogtool-consume-live-draft-leases',
            );
            expect(jsonDecode(request.body), {
              'deviceId': 'device-1',
              'clientSeq': 7,
              'updates': [
                {
                  'field': 'callsign',
                  'value': null,
                  'expectedRevision': 0,
                  'leaseId': 'lease-1',
                },
              ],
            });
            return _jsonResponse({
              'draft': _liveDraftJson(version: 2),
              'appliedClientSeq': 7,
              'replayed': false,
              'releasedLeases': [
                {'field': 'callsign', 'leaseId': 'lease-1'},
              ],
            });
          case 'POST /api/v1/sessions/session-1/live-draft/commit':
            expect(request.headers['idempotency-key'], 'commit-1');
            expect(jsonDecode(request.body), {
              'deviceId': 'device-1',
              'expectedDraftVersion': 2,
              'syncId': 'log-1',
            });
            return _jsonResponse({
              'record': _logJson,
              'event': event,
              'committedDraftId': 'draft-1',
              'nextDraft': _liveDraftJson(draftId: 'draft-2', version: 3),
              'committedOrdinal': 1,
              'currentOrdinal': 2,
              'totalRecords': 1,
            }, 201);
          case 'DELETE /api/v1/sessions/session-1/live-draft':
            expect(request.headers['idempotency-key'], 'discard-1');
            expect(jsonDecode(request.body), {
              'deviceId': 'device-1',
              'expectedDraftVersion': 3,
            });
            return _jsonResponse({
              'discardedDraftId': 'draft-2',
              'nextDraft': _liveDraftJson(draftId: 'draft-3', version: 4),
              'currentOrdinal': 2,
              'totalRecords': 1,
            });
          default:
            fail('Unexpected request: ${request.method} ${request.url}');
        }
      });
      final api = _api(store: store, client: client);

      final snapshot = await api.getLiveDraft('session-1');
      expect(snapshot.draft.createdAt, DateTime.parse(_now));
      expect(snapshot.locks.single.sessionId, 'session-1');
      final acquisition = await api.acquireLiveDraftLockWithDraft(
        sessionId: 'session-1',
        field: 'callsign',
        deviceId: 'device-1',
      );
      expect(acquisition.lock.leaseId, 'lease-1');
      expect(acquisition.draft?.version, 2);
      await api.renewLiveDraftLock(
        sessionId: 'session-1',
        leaseId: 'lease-1',
        deviceId: 'device-1',
      );
      await api.releaseLiveDraftLock(
        sessionId: 'session-1',
        leaseId: 'lease-1',
        deviceId: 'device-1',
      );
      final preview = await api.publishLiveDraftHistoryPreview(
        sessionId: 'session-1',
        deviceId: 'device-1',
        leaseId: 'lease-1',
        draftId: 'draft-1',
        callsign: 'K1ABC',
        candidates: const [
          LiveDraftHistoryCandidateDto(
            candidateId: 'history-1',
            sourceTime: _now,
            qth: 'Hangzhou',
            device: '',
            power: '5W',
            antenna: '',
            height: '',
          ),
        ],
      );
      expect(preview.historyPreview.actor.username, 'alice');
      final reuse = await api.selectLiveDraftHistoryCandidate(
        sessionId: 'session-1',
        previewId: 'preview-1',
        deviceId: 'device-1',
        leaseId: 'lease-1',
        candidateId: 'history-1',
        idempotencyKey: 'reuse-1',
      );
      expect(reuse.updatedFields, {'qth', 'power'});
      expect(reuse.releasedLeases.single.field, 'qth');
      await api.clearLiveDraftHistoryPreview(
        sessionId: 'session-1',
        deviceId: 'device-1',
        previewId: 'preview-1',
      );
      final patched = await api.updateLiveDraft(
        sessionId: 'session-1',
        deviceId: 'device-1',
        clientSeq: 7,
        updates: [
          LiveDraftPatchUpdateDto(
            field: 'callsign',
            value: null,
            expectedRevision: 0,
            leaseId: 'lease-1',
          ),
        ],
      );
      expect(patched.appliedClientSeq, 7);
      expect(patched.releasedLeases.single.leaseId, 'lease-1');
      final committed = await api.commitLiveDraft(
        sessionId: 'session-1',
        deviceId: 'device-1',
        expectedDraftVersion: 2,
        syncId: 'log-1',
        idempotencyKey: 'commit-1',
      );
      expect(committed.committedOrdinal, 1);
      final discarded = await api.discardLiveDraft(
        sessionId: 'session-1',
        deviceId: 'device-1',
        expectedDraftVersion: 3,
        idempotencyKey: 'discard-1',
      );
      expect(discarded.currentOrdinal, 2);
      expect(discarded.totalRecords, 1);
    });

    test('self-leave and safe public-share management preserve capabilities',
        () async {
      final store = MemoryTokenStore(
        AuthSessionDto.fromJson(_authJson('access', 'refresh')),
      );
      final client = MockClient((request) async {
        final route = '${request.method} ${request.url.path}';
        switch (route) {
          case 'DELETE /api/v1/sessions/session-1/membership':
            expect(request.headers['idempotency-key'], 'leave-1');
            expect(jsonDecode(request.body), <String, Object?>{});
            return _jsonResponse({
              'left': true,
              'membership': {
                ..._membershipJson(role: 'editor'),
                'version': 2,
                'removedAt': _now,
              },
            });
          case 'POST /api/v1/sessions/session-1/public-shares':
            expect(request.headers['idempotency-key'], 'share-1');
            expect(jsonDecode(request.body), {'expiresInHours': 24});
            return _jsonResponse({
              'publicShare': _publicShareJson(secret: 'link-secret'),
            }, 201);
          case 'GET /api/v1/sessions/session-1/public-shares':
            expect(request.url.queryParameters, {
              'limit': '25',
              'after': 'cursor-1',
            });
            return _jsonResponse({
              'publicShares': [_publicShareJson()],
              'nextCursor': null,
            });
          case 'DELETE /api/v1/sessions/session-1/public-shares/share-1':
            expect(request.headers['idempotency-key'], 'revoke-share-1');
            return _jsonResponse({
              'publicShare': _publicShareJson(revokedAt: _now),
            });
          default:
            fail('Unexpected request: $route');
        }
      });
      final api = _api(store: store, client: client);

      final left = await api.leaveSession(
        sessionId: 'session-1',
        idempotencyKey: 'leave-1',
      );
      expect(left.left, isTrue);
      expect(left.membership.removedAt, isNotNull);
      final created = await api.createPublicShare(
        sessionId: 'session-1',
        expiresInHours: 24,
        idempotencyKey: 'share-1',
      );
      expect(created.secret, 'link-secret');
      expect(
        api.publicSharePageUri(created).toString(),
        'https://example.test/live/share-1#token=link-secret',
      );
      final page = await api.listPublicShares(
        sessionId: 'session-1',
        limit: 25,
        after: 'cursor-1',
      );
      expect(page.publicShares, hasLength(1));
      expect(page.publicShares.single.secret, isNull);
      final revoked = await api.revokePublicShare(
        sessionId: 'session-1',
        publicShareId: 'share-1',
        idempotencyKey: 'revoke-share-1',
      );
      expect(revoked.revokedAt, isNotNull);
    });
  });

  group('ServerApi failures', () {
    test('preserves the unified error envelope and retry classification',
        () async {
      final store = MemoryTokenStore(
        AuthSessionDto.fromJson(_authJson('access', 'refresh')),
      );
      final client = MockClient((_) async => _jsonResponse({
            'error': {
              'code': 'LOG_COUNT_MISMATCH',
              'message': 'Bootstrap Log count does not match',
              'requestId': 'request-7',
              'details': {'expectedLogCount': 4, 'actualLogCount': 3},
            },
          }, 409));
      final api = _api(store: store, client: client);

      await expectLater(
        api.activateSession(
          sessionId: 'session-1',
          expectedLogCount: 4,
          idempotencyKey: 'activate-1',
        ),
        throwsA(
          isA<ServerApiException>()
              .having((error) => error.code, 'code', 'LOG_COUNT_MISMATCH')
              .having((error) => error.requestId, 'requestId', 'request-7')
              .having((error) => error.statusCode, 'statusCode', 409)
              .having((error) => error.retryable, 'retryable', isFalse)
              .having(
            (error) => error.details,
            'details',
            {'expectedLogCount': 4, 'actualLogCount': 3},
          ),
        ),
      );
    });

    test('maps request timeouts to a retryable client error', () async {
      final client = MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _jsonResponse(_userJson);
      });
      final api = ServerApi(
        baseUri: Uri.parse('https://example.test'),
        tokenStore: MemoryTokenStore(
          AuthSessionDto.fromJson(_authJson('access', 'refresh')),
        ),
        httpClient: client,
        timeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        api.getMe(),
        throwsA(
          isA<ServerApiException>()
              .having((error) => error.code, 'code', 'NETWORK_TIMEOUT')
              .having((error) => error.retryable, 'retryable', isTrue),
        ),
      );
    });
  });
}

const _now = '2026-07-11T08:00:00.000Z';

const _userJson = {
  'id': 'user-1',
  'username': 'alice',
  'role': 'user',
};

Map<String, Object?> _accountJson({String username = 'alice'}) => {
      'id': 'user-1',
      'username': username,
      'role': 'user',
      'mustChangePassword': false,
      'createdAt': _now,
      'updatedAt': _now,
      'passwordChangedAt': null,
      'usernameChangedAt': null,
    };

const _deviceSessionJson = {
  'sessionId': 'refresh-session-1',
  'deviceId': 'device-1',
  'createdAt': _now,
  'expiresAt': '2026-08-11T08:00:00.000Z',
  'lastUsedAt': _now,
  'userAgent': 'OpenLogTool test',
  'ipAddress': '127.0.0.1',
  'current': true,
};

Map<String, Object?> _authJson(
  String accessToken,
  String refreshToken, {
  Map<String, Object?> user = _userJson,
}) =>
    {
      'accessToken': accessToken,
      'accessTokenExpiresIn': 900,
      'refreshToken': refreshToken,
      'refreshTokenExpiresAt': '2026-08-11T08:00:00.000Z',
      'user': user,
    };

Map<String, Object?> _userJsonFor({
  required String id,
  required String username,
}) =>
    {
      'id': id,
      'username': username,
      'role': 'user',
    };

const _sessionJson = {
  'sessionId': 'session-1',
  'title': 'Field Day',
  'status': 'active',
  'version': 2,
  'role': 'owner',
  'highWatermarkSeq': 3,
  'createdAt': _now,
  'updatedAt': _now,
  'closedAt': null,
  'deletedAt': null,
};

Map<String, Object?> _membershipJson({
  String userId = 'user-1',
  String role = 'owner',
  String? username,
}) =>
    {
      'membershipId': 'membership-$userId',
      'sessionId': 'session-1',
      'userId': userId,
      'role': role,
      'version': 1,
      'joinedAt': _now,
      'updatedAt': _now,
      'removedAt': null,
      if (username != null) 'username': username,
    };

Map<String, Object?> _inviteJson({
  bool includeSecret = false,
  String? revokedAt,
}) =>
    {
      'inviteId': 'invite-1',
      'sessionId': 'session-1',
      'codeHint': 'G123',
      'role': 'editor',
      'maxUses': 1,
      'usedCount': 0,
      'expiresAt': '2026-07-12T08:00:00.000Z',
      'createdBy': 'user-1',
      'createdAt': _now,
      'revokedAt': revokedAt,
      'revokedBy': revokedAt == null ? null : 'user-1',
      if (includeSecret) 'code': 'ABCDE-FG123',
      if (includeSecret) 'linkToken': 'link-token',
    };

Map<String, Object?> _publicShareJson({
  String? secret,
  String? revokedAt,
}) =>
    {
      'publicShareId': 'share-1',
      'sessionId': 'session-1',
      'expiresAt': '2026-07-14T08:00:00.000Z',
      'createdBy': 'user-1',
      'createdAt': _now,
      'revokedAt': revokedAt,
      'revokedBy': revokedAt == null ? null : 'user-1',
      if (secret != null) 'secret': secret,
    };

const _logJson = {
  'syncId': 'log-1',
  'sessionId': 'session-1',
  'version': 1,
  'time': _now,
  'controller': 'BG5CRL',
  'callsign': 'K1ABC',
  'rstSent': null,
  'rstRcvd': null,
  'qth': null,
  'device': null,
  'power': null,
  'antenna': null,
  'height': null,
  'remarks': null,
  'createdAt': _now,
  'updatedAt': _now,
  'deletedAt': null,
};

Map<String, Object?> _liveDraftJson({
  String draftId = 'draft-1',
  int version = 1,
}) =>
    {
      'draftId': draftId,
      'sessionId': 'session-1',
      'version': version,
      'fields': {
        'time': _now,
        'controller': 'BG5CRL',
        'callsign': 'K1ABC',
        'rstSent': '59',
        'rstRcvd': '59',
        'qth': null,
        'device': null,
        'power': null,
        'antenna': null,
        'height': null,
        'remarks': null,
      },
      'fieldRevisions': {
        for (final field in liveDraftFieldNames) field: 0,
      },
      'lastUpdatedBy': {'userId': 'user-1', 'username': 'alice'},
      'createdAt': _now,
      'lastUpdatedAt': _now,
    };

Map<String, Object?> _historyPreviewJson() => {
      'previewId': 'preview-1',
      'draftId': 'draft-1',
      'deviceId': 'device-1',
      'callsign': 'K1ABC',
      'actor': {'userId': 'user-1', 'username': 'alice'},
      'expiresAt': '2026-07-13T08:00:20.000Z',
      'candidates': [
        {
          'candidateId': 'history-1',
          'sourceTime': _now,
          'qth': 'Hangzhou',
          'device': null,
          'power': '5W',
          'antenna': null,
          'height': null,
        },
      ],
    };

ServerApi _api({
  required TokenStore store,
  required http.Client client,
  void Function()? onAuthInvalidated,
}) =>
    ServerApi(
      baseUri: Uri.parse('https://example.test'),
      tokenStore: store,
      httpClient: client,
      deviceId: 'device-1',
      onAuthInvalidated: onAuthInvalidated,
    );

http.Response _jsonResponse(Object? body, [int statusCode = 200]) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    );

http.Response _apiError(int statusCode, String code) => _jsonResponse({
      'error': {
        'code': code,
        'message': code,
        'requestId': 'request-1',
      },
    }, statusCode);
