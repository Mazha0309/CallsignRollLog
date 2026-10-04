import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openlogtool/models/account_dto.dart';
import 'package:openlogtool/models/account_share_dto.dart';
import 'package:openlogtool/models/social_dto.dart';
import 'package:openlogtool/models/collaboration_dto.dart';
import 'package:openlogtool/models/live_draft.dart';
import 'package:openlogtool/models/personal_cloud_dto.dart';
import 'package:openlogtool/models/personal_dictionary_snapshot_dto.dart';
import 'package:openlogtool/services/app_logger.dart';

/// Persistence boundary for authentication state.
///
/// The protocol layer intentionally does not choose a storage plugin. Callers can
/// provide a secure persistent implementation; tests can use [MemoryTokenStore].
abstract interface class TokenStore {
  Future<AuthSessionDto?> read();

  Future<void> write(AuthSessionDto session);

  Future<void> clear();
}

final class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._session]);

  AuthSessionDto? _session;

  @override
  Future<AuthSessionDto?> read() async => _session;

  @override
  Future<void> write(AuthSessionDto session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}

final class ServerApiException implements Exception {
  const ServerApiException({
    required this.error,
    required this.statusCode,
    required this.retryable,
    this.cause,
  });

  final ApiErrorDto error;
  final int? statusCode;
  final bool retryable;
  final Object? cause;

  String get code => error.code;
  String get message => error.message;
  String get requestId => error.requestId;
  Object? get details => error.details;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' ($statusCode)';
    return 'ServerApiException$status: ${error.code}: ${error.message}';
  }
}

final class ServerApi {
  ServerApi({
    required Uri baseUri,
    required this.tokenStore,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
    this.deviceId,
    this.onAuthInvalidated,
  })  : _apiBaseUri = _normalizeApiBaseUri(baseUri),
        _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'must be positive');
    }
  }

  final TokenStore tokenStore;
  final Duration timeout;
  String? deviceId;
  final void Function()? onAuthInvalidated;
  final Uri _apiBaseUri;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  final Map<String, Future<AuthSessionDto>> _refreshesInFlight = {};

  /// Updates the device label used by subsequent authentication refreshes.
  /// Existing requests keep their captured request body and can still commit a
  /// rotated token into the same store, so changing the label cannot strand a
  /// newly issued refresh token.
  void updateDeviceId(String? value) {
    deviceId = value;
  }

  Future<ServerInfoDto> getServerInfo() async {
    final response = await _publicRequest('GET', '/server-info');
    return _parseResponse(response, ServerInfoDto.fromJson);
  }

  Future<AuthSessionDto> register(AuthCredentialsDto credentials) async {
    final response = await _publicRequest(
      'POST',
      '/auth/register',
      body: credentials.toJson(),
    );
    final session = _parseResponse(response, AuthSessionDto.fromJson);
    await tokenStore.write(session);
    return session;
  }

  Future<AuthSessionDto> login(AuthCredentialsDto credentials) async {
    final response = await _publicRequest(
      'POST',
      '/auth/login',
      body: credentials.toJson(),
    );
    final session = _parseResponse(response, AuthSessionDto.fromJson);
    await tokenStore.write(session);
    return session;
  }

  Future<AuthSessionDto> completeRequiredPasswordChange({
    required String passwordChangeToken,
    required String newPassword,
    String? deviceId,
  }) async {
    final resolvedDeviceId = deviceId ?? this.deviceId;
    final response = await _publicRequest(
      'POST',
      '/auth/complete-password-change',
      body: {
        'passwordChangeToken': passwordChangeToken,
        'newPassword': newPassword,
        if (resolvedDeviceId != null) 'deviceId': resolvedDeviceId,
      },
    );
    final session = _parseResponse(response, AuthSessionDto.fromJson);
    await tokenStore.write(session);
    return session;
  }

  Future<AuthSessionDto> refresh({String? deviceId}) async {
    final current = await _requireSession();
    return _refreshOnce(current.refreshToken, deviceId: deviceId);
  }

  Future<void> logout() async {
    final response = await _authorizedRequest(
      'POST',
      '/auth/logout',
      bodyForSession: (session) => {'refreshToken': session.refreshToken},
    );
    _expectEmpty(response);
    await tokenStore.clear();
  }

  Future<ApiUserDto> getMe() async {
    final response = await _authorizedRequest('GET', '/auth/me');
    return _parseResponse(response, ApiUserDto.fromJson);
  }

  Future<AccountDto> getAccount() async {
    final response = await _authorizedRequest('GET', '/account');
    return _parseResponse(response, AccountDto.fromJson);
  }

  Future<PersonalCloudSnapshotMeta> getPersonalCloudSnapshotMeta() async {
    final response = await _authorizedRequest(
      'GET',
      '/account/personal-snapshot',
    );
    return _parseResponse(response, (json) {
      final envelope = _jsonObject(json, 'personalSnapshotMetaResult');
      return PersonalCloudSnapshotMeta.fromJson(envelope['personalSnapshot']);
    });
  }

  Future<PersonalCloudSnapshotDownload> downloadPersonalCloudSnapshot() async {
    final response = await _authorizedRequest(
      'GET',
      '/account/personal-snapshot/download',
    );
    return _parseResponse(response, PersonalCloudSnapshotDownload.fromJson);
  }

  Future<PersonalCloudSnapshotReplaceResult> replacePersonalCloudSnapshot({
    required int expectedRevision,
    required PersonalCloudJsonObject snapshot,
  }) async {
    if (expectedRevision < 0) {
      throw ArgumentError.value(
        expectedRevision,
        'expectedRevision',
        'must not be negative',
      );
    }
    final response = await _authorizedRequest(
      'PUT',
      '/account/personal-snapshot',
      body: {
        'expectedRevision': expectedRevision,
        'confirmation': 'REPLACE_PERSONAL_CLOUD_SNAPSHOT',
        'snapshot': snapshot,
      },
      headers: {'If-Match': '"$expectedRevision"'},
    );
    return _parseResponse(
      response,
      PersonalCloudSnapshotReplaceResult.fromJson,
    );
  }

  Future<PersonalDictionarySnapshotMeta>
      getPersonalDictionarySnapshotMeta() async {
    final response = await _authorizedRequest(
      'GET',
      '/account/personal-dictionary-snapshot',
    );
    return _parseResponse(response, (json) {
      final envelope = _jsonObject(
        json,
        'personalDictionarySnapshotMetaResult',
      );
      return PersonalDictionarySnapshotMeta.fromJson(
        envelope['personalDictionarySnapshot'],
      );
    });
  }

  Future<PersonalDictionarySnapshotDownload>
      downloadPersonalDictionarySnapshot() async {
    final response = await _authorizedRequest(
      'GET',
      '/account/personal-dictionary-snapshot/download',
    );
    return _parseResponse(
      response,
      PersonalDictionarySnapshotDownload.fromJson,
    );
  }

  Future<PersonalDictionarySnapshotReplaceResult>
      replacePersonalDictionarySnapshot({
    required int expectedRevision,
    required PersonalDictionarySnapshotJson snapshot,
  }) async {
    if (expectedRevision < 0) {
      throw ArgumentError.value(
        expectedRevision,
        'expectedRevision',
        'must not be negative',
      );
    }
    final response = await _authorizedRequest(
      'PUT',
      '/account/personal-dictionary-snapshot',
      body: {
        'expectedRevision': expectedRevision,
        'confirmation': 'REPLACE_PERSONAL_DICTIONARY_SNAPSHOT',
        'snapshot': snapshot,
      },
      headers: {'If-Match': '"$expectedRevision"'},
    );
    return _parseResponse(
      response,
      PersonalDictionarySnapshotReplaceResult.fromJson,
    );
  }

  Future<AccountDto> changeUsername({
    required String username,
    required String currentPassword,
  }) async {
    final response = await _authorizedRequest(
      'PATCH',
      '/account/username',
      body: {
        'username': username,
        'currentPassword': currentPassword,
      },
    );
    return _parseResponse(response, AccountDto.fromJson);
  }

  Future<PasswordChangeResultDto> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _authorizedRequest(
      'PATCH',
      '/account/password',
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    return _parseResponse(response, PasswordChangeResultDto.fromJson);
  }

  Future<List<DeviceSessionDto>> listDeviceSessions() async {
    final response = await _authorizedRequest('GET', '/account/sessions');
    return _parseResponse(response, (json) {
      final values = _jsonArray(
        _jsonObject(json, 'deviceSessionsResult')['items'],
        'items',
      );
      return List.unmodifiable(values.map(DeviceSessionDto.fromJson));
    });
  }

  Future<void> revokeDeviceSession(String sessionId) async {
    final response = await _authorizedRequest(
      'DELETE',
      '/account/sessions/${_segment(sessionId)}',
    );
    _expectEmpty(response);
  }

  Future<List<CollaborationSessionDto>> listSessions() async {
    final response = await _authorizedRequest('GET', '/sessions');
    return _parseResponse(response, (json) {
      final values = _jsonArray(json, 'sessions');
      return List.unmodifiable(values.map(CollaborationSessionDto.fromJson));
    });
  }

  Future<List<SharedSessionDto>> listSharedSessions() async {
    final response =
        await _authorizedRequest('GET', '/account/shared-sessions');
    return _parseResponse(response, (json) {
      final object = _jsonObject(json, 'sharedSessions');
      final values = _jsonArray(object['items'], 'items');
      return List.unmodifiable(values.map(SharedSessionDto.fromJson));
    });
  }

  Future<SocialSnapshot> getSocialSnapshot() async {
    final response = await _authorizedRequest('GET', '/social');
    return _parseResponse(response,
        (json) => SocialSnapshot.fromJson(_jsonObject(json, 'social')));
  }

  Future<SocialUserSearchPage> searchSocialUsers(String query) async {
    final response = await _authorizedRequest('GET', '/social/users',
        queryParameters: {'query': query.trim()});
    return _parseResponse(response,
        (json) => SocialUserSearchPage.fromJson(_jsonObject(json, 'users')));
  }

  Future<void> socialMutation(
    String method,
    String path, {
    Map<String, Object?> body = const {},
    required String idempotencyKey,
  }) async {
    final response = await _authorizedRequest(method, '/social$path',
        body: body, headers: _idempotencyHeaders(idempotencyKey));
    _throwForError(response);
  }

  Future<List<AccountShareGrantDto>> listSessionShares(String box) async {
    final response = await _authorizedRequest(
      'GET',
      '/account/session-shares',
      queryParameters: {'box': box},
    );
    return _parseResponse(response, (json) {
      final object = _jsonObject(json, 'sessionShares');
      final values = _jsonArray(object['items'], 'items');
      return List.unmodifiable(values.map(AccountShareGrantDto.fromJson));
    });
  }

  Future<List<ShareSessionRef>> listShareCandidates() async {
    final items = <ShareSessionRef>[];
    for (var page = 1;; page++) {
      final response = await _authorizedRequest(
          'GET', '/account/session-catalog',
          queryParameters: {'page': '$page', 'pageSize': '100'});
      final object =
          _parseResponse(response, (json) => _jsonObject(json, 'catalog'));
      for (final raw in _jsonArray(object['items'], 'items')) {
        final row = _jsonObject(raw, 'session');
        if (row['source'] == 'personal' || row['role'] == 'owner') {
          items.add(ShareSessionRef.fromJson(row));
        }
      }
      if (page >= (object['totalPages'] as num? ?? 0)) break;
    }
    return items;
  }

  Future<void> accountShareMutation(
    String method,
    String path, {
    required Map<String, Object?> body,
    required String idempotencyKey,
  }) async {
    final response = await _authorizedRequest(method, '/account$path',
        body: body, headers: _idempotencyHeaders(idempotencyKey));
    _throwForError(response);
  }

  Future<SharedRecordsPage> sharedRecordsPage(SharedSessionDto session,
      {int page = 1, String query = ''}) async {
    final response = await _authorizedRequest('GET',
        '/account/shared-sessions/${_segment(session.source)}/${_segment(session.sessionId)}/logs',
        queryParameters: {
          'page': '$page',
          'pageSize': '50',
          'sort': 'timeDesc',
          if (session.grantId.isNotEmpty) 'grantId': session.grantId,
          if (query.isNotEmpty) 'q': query
        });
    return _parseResponse(response,
        (json) => SharedRecordsPage.fromJson(_jsonObject(json, 'records')));
  }

  Future<AccountShareGrantDto> createSessionShare({
    required String granteeUsername,
    required String idempotencyKey,
  }) async {
    final response = await _authorizedRequest(
      'POST',
      '/account/session-shares',
      body: {
        'granteeUsername': granteeUsername,
        'includePersonal': true,
        'includeOwned': true,
        'includeEditor': true,
        'canJoinAs': 'editor',
      },
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _parseResponse(
      response,
      (json) => AccountShareGrantDto.fromJson(
        _jsonObject(json, 'createSessionShare')['share'] ?? json,
      ),
    );
  }

  Future<AccountShareGrantDto> acceptSessionShare({
    required String shareId,
    required String idempotencyKey,
  }) async {
    final response = await _authorizedRequest(
      'POST',
      '/account/session-shares/${_segment(shareId)}/accept',
      body: const <String, Object?>{},
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _parseResponse(
      response,
      (json) => AccountShareGrantDto.fromJson(
        _jsonObject(json, 'acceptSessionShare')['share'] ?? json,
      ),
    );
  }

  Future<List<Map<String, Object?>>> listSharedSessionLogs({
    required String source,
    required String sessionId,
  }) async {
    final response = await _authorizedRequest(
      'GET',
      '/account/shared-sessions/${_segment(source)}/${_segment(sessionId)}/logs',
    );
    return _parseResponse(response, (json) {
      final object = _jsonObject(json, 'sharedSessionLogs');
      final values = _jsonArray(object['items'], 'items');
      return [
        for (final value in values) Map<String, Object?>.from(value as Map),
      ];
    });
  }

  Future<void> joinWithShare({
    required String sessionId,
    required String passphrase,
    required String idempotencyKey,
  }) async {
    final response = await _authorizedRequest(
      'POST',
      '/sessions/${_segment(sessionId)}/join-with-share',
      body: {'passphrase': passphrase},
      headers: _idempotencyHeaders(idempotencyKey),
    );
    _throwForError(response);
  }

  Future<CollaborationSessionDto> putSession({
    required String sessionId,
    required String title,
    required String idempotencyKey,
  }) async {
    final response = await _authorizedRequest(
      'PUT',
      '/sessions/${_segment(sessionId)}',
      body: {'title': title},
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _parseResponse(
      response,
      (json) => CollaborationSessionDto.fromJson(
        _jsonObject(json, 'putSessionResult')['session'],
      ),
    );
  }

  Future<BootstrapLogsResultDto> bootstrapLogs({
    required String sessionId,
    required List<BootstrapLogDto> items,
    required String idempotencyKey,
  }) async {
    final response = await _authorizedRequest(
      'POST',
      '/sessions/${_segment(sessionId)}/bootstrap/logs',
      body: {'items': items.map((item) => item.toJson()).toList()},
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _parseResponse(response, BootstrapLogsResultDto.fromJson);
  }

  Future<ActivateSessionResultDto> activateSession({
    required String sessionId,
    required int expectedLogCount,
    required String idempotencyKey,
  }) async {
    final response = await _authorizedRequest(
      'POST',
      '/sessions/${_segment(sessionId)}/activate',
      body: {'expectedLogCount': expectedLogCount},
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _parseResponse(response, ActivateSessionResultDto.fromJson);
  }

  Future<SessionSnapshotDto> getSessionSnapshot(
    String sessionId, {
    bool includeDeleted = false,
  }) async {
    final response = await _authorizedRequest(
      'GET',
      '/sessions/${_segment(sessionId)}/snapshot',
      queryParameters: includeDeleted ? {'includeDeleted': 'true'} : null,
    );
    return _parseResponse(response, SessionSnapshotDto.fromJson);
  }

  Future<SessionEventsPageDto> getSessionEvents({
    required String sessionId,
    required int afterSeq,
    int limit = 500,
  }) async {
    if (afterSeq < 0) {
      throw ArgumentError.value(afterSeq, 'afterSeq', 'must not be negative');
    }
    if (limit < 1 || limit > 500) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 500');
    }
    final response = await _authorizedRequest(
      'GET',
      '/sessions/${_segment(sessionId)}/events',
      queryParameters: {
        'afterSeq': '$afterSeq',
        'limit': '$limit',
      },
    );
    return _parseResponse(response, SessionEventsPageDto.fromJson);
  }

  Future<MutationBatchResultDto> submitMutations({
    required String sessionId,
    required String deviceId,
    required List<CollaborationMutationDto> operations,
  }) async {
    if (operations.isEmpty || operations.length > 100) {
      throw ArgumentError.value(
        operations.length,
        'operations',
        'must contain between 1 and 100 mutations',
      );
    }
    final response = await _authorizedRequest(
      'POST',
      '/sessions/${_segment(sessionId)}/mutations',
      body: {
        'protocolVersion': 1,
        'deviceId': deviceId,
        'operations':
            operations.map((operation) => operation.toJson()).toList(),
      },
    );
    return _parseResponse(response, MutationBatchResultDto.fromJson);
  }

  Future<WebSocketTicketDto> createCollaborationWebSocketTicket({
    required String sessionId,
    required String deviceId,
    required int afterSeq,
  }) async {
    if (afterSeq < 0) {
      throw ArgumentError.value(afterSeq, 'afterSeq', 'must not be negative');
    }
    final response = await _authorizedRequest(
      'POST',
      '/sessions/${_segment(sessionId)}/ws-ticket',
      body: {
        'deviceId': deviceId,
        'afterSeq': afterSeq,
      },
    );
    return _parseResponse(response, WebSocketTicketDto.fromJson);
  }

  Future<Uri> socialWebSocketTicketUri() async {
    final response =
        await _authorizedRequest('POST', '/social/ws-ticket', body: const {});
    final ticket = _parseResponse(response,
        (json) => _jsonObject(json, 'socialTicket')['ticket'] as String);
    return _webSocketUri(ticket, 'social');
  }

  Uri collaborationWebSocketUri(String ticket) =>
      _webSocketUri(ticket, 'collaboration');

  Uri _webSocketUri(String ticket, String channel) {
    final normalized = ticket.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(ticket, 'ticket', 'must not be empty');
    }
    const apiSuffix = '/api/v1';
    final apiPath = _apiBaseUri.path;
    final rootPath = apiPath.endsWith(apiSuffix)
        ? apiPath.substring(0, apiPath.length - apiSuffix.length)
        : '';
    return _apiBaseUri.replace(
      scheme: _apiBaseUri.scheme == 'https' ? 'wss' : 'ws',
      path: '$rootPath/ws/$channel',
      queryParameters: {'ticket': normalized},
      fragment: null,
    );
  }

  Future<MembershipDto> getMembership(String sessionId) async {
    final response = await _authorizedRequest(
      'GET',
      '/sessions/${_segment(sessionId)}/membership',
    );
    return _parseResponse(
      response,
      (json) => MembershipDto.fromJson(
        _jsonObject(json, 'membershipResult')['membership'],
      ),
    );
  }

  Future<LeaveSessionResultDto> leaveSession({
    required String sessionId,
    required String idempotencyKey,
  }) async {
    final response = await _authorizedRequest(
      'DELETE',
      '/sessions/${_segment(sessionId)}/membership',
      body: const <String, Object?>{},
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _parseResponse(response, LeaveSessionResultDto.fromJson);
  }

  Future<LiveDraftSnapshotDto> getLiveDraft(String sessionId) async {
    final response = await _authorizedRequest(
      'GET',
      '/sessions/${_segment(sessionId)}/live-draft',
    );
    return _parseResponse(response, LiveDraftSnapshotDto.fromJson);
  }

  Future<LiveDraftLockDto> acquireLiveDraftLock({
    required String sessionId,
    required String field,
    required String deviceId,
  }) async =>
      (await acquireLiveDraftLockWithDraft(
        sessionId: sessionId,
        field: field,
        deviceId: deviceId,
      ))
          .lock;

  Future<LiveDraftLockAcquisitionDto> acquireLiveDraftLockWithDraft({
    required String sessionId,
    required String field,
    required String deviceId,
  }) async {
    if (!liveDraftFieldNames.contains(field)) {
      throw ArgumentError.value(field, 'field', 'unknown live draft field');
    }
    final response = await _authorizedRequest(
      'POST',
      '/sessions/${_segment(sessionId)}/live-draft/locks',
      body: {'field': field, 'deviceId': deviceId},
    );
    final result = _parseResponse(
      response,
      LiveDraftLockAcquisitionDto.fromJson,
    );
    final lock = result.lock;
    if (lock.sessionId != sessionId) {
      throw _clientException(
        code: 'INVALID_RESPONSE',
        message: 'The live draft lock belongs to another Session',
        statusCode: response.statusCode,
      );
    }
    if (result.draft != null && result.draft!.sessionId != sessionId) {
      throw _clientException(
        code: 'INVALID_RESPONSE',
        message: 'The live draft snapshot belongs to another Session',
        statusCode: response.statusCode,
      );
    }
    return result;
  }

  Future<LiveDraftLockDto> renewLiveDraftLock({
    required String sessionId,
    required String leaseId,
    required String deviceId,
  }) async {
    final response = await _authorizedRequest(
      'POST',
      '/sessions/${_segment(sessionId)}/live-draft/locks/'
          '${_segment(leaseId)}/renew',
      body: {'deviceId': deviceId},
    );
    final lock = _parseResponse(
      response,
      (json) => LiveDraftLockDto.fromJson(
        _jsonObject(json, 'liveDraftLockRenewResult')['lock'],
      ),
    );
    if (lock.sessionId != sessionId || lock.leaseId != leaseId) {
      throw _clientException(
        code: 'INVALID_RESPONSE',
        message: 'The renewed live draft lock does not match the request',
        statusCode: response.statusCode,
      );
    }
    return lock;
  }

  Future<void> releaseLiveDraftLock({
    required String sessionId,
    required String leaseId,
    required String deviceId,
  }) async {
    final response = await _authorizedRequest(
      'DELETE',
      '/sessions/${_segment(sessionId)}/live-draft/locks/'
          '${_segment(leaseId)}',
      body: {'deviceId': deviceId},
    );
    _parseResponse(response, (json) {
      final result = _jsonObject(json, 'liveDraftLockReleaseResult');
      if (result['released'] != true) {
        throw const FormatException('released must be true');
      }
    });
  }

  Future<LiveDraftPatchResultDto> updateLiveDraft({
    required String sessionId,
    required String deviceId,
    required int clientSeq,
    required List<LiveDraftPatchUpdateDto> updates,
  }) async {
    if (clientSeq < 1) {
      throw ArgumentError.value(clientSeq, 'clientSeq', 'must be positive');
    }
    if (updates.isEmpty) {
      throw ArgumentError.value(updates, 'updates', 'must not be empty');
    }
    if (updates.length > liveDraftFieldNames.length) {
      throw ArgumentError.value(updates, 'updates', 'contains too many fields');
    }
    final fields = <String>{};
    if (updates.any((update) => !fields.add(update.field))) {
      throw ArgumentError.value(
          updates, 'updates', 'contains duplicate fields');
    }
    final response = await _authorizedRequest(
      'PATCH',
      '/sessions/${_segment(sessionId)}/live-draft',
      body: {
        'deviceId': deviceId,
        'clientSeq': clientSeq,
        'updates': updates.map((update) => update.toJson()).toList(),
      },
      headers: const {
        'Prefer': 'openlogtool-consume-live-draft-leases',
      },
    );
    return _parseResponse(response, LiveDraftPatchResultDto.fromJson);
  }

  Future<LiveDraftHistoryPreviewResultDto> publishLiveDraftHistoryPreview({
    required String sessionId,
    required String deviceId,
    required String leaseId,
    required String draftId,
    required String callsign,
    required List<LiveDraftHistoryCandidateDto> candidates,
  }) async {
    if (candidates.isEmpty || candidates.length > 10) {
      throw ArgumentError.value(
        candidates,
        'candidates',
        'must contain between 1 and 10 items',
      );
    }
    final response = await _authorizedRequest(
      'PUT',
      '/sessions/${_segment(sessionId)}/live-draft/history-preview',
      body: {
        'deviceId': deviceId,
        'leaseId': leaseId,
        'draftId': draftId,
        'callsign': callsign,
        'candidates': candidates
            .map((candidate) => candidate.toJson())
            .toList(growable: false),
      },
    );
    final result =
        _parseResponse(response, LiveDraftHistoryPreviewResultDto.fromJson);
    if (result.draft.sessionId != sessionId ||
        result.draft.draftId != draftId ||
        result.historyPreview.draftId != draftId ||
        result.historyPreview.deviceId != deviceId) {
      throw _clientException(
        code: 'INVALID_RESPONSE',
        message: 'The live draft history preview does not match the request',
        statusCode: response.statusCode,
      );
    }
    return result;
  }

  Future<void> clearLiveDraftHistoryPreview({
    required String sessionId,
    required String deviceId,
    required String previewId,
  }) async {
    final response = await _authorizedRequest(
      'DELETE',
      '/sessions/${_segment(sessionId)}/live-draft/history-preview',
      body: {'deviceId': deviceId, 'previewId': previewId},
    );
    _parseResponse(response, (json) {
      final result = _jsonObject(json, 'liveDraftHistoryPreviewClearResult');
      if (result['cleared'] != true || result['historyPreview'] != null) {
        throw const FormatException(
          'history preview clear response is invalid',
        );
      }
    });
  }

  Future<LiveDraftHistoryReuseResultDto> selectLiveDraftHistoryCandidate({
    required String sessionId,
    required String previewId,
    required String deviceId,
    required String leaseId,
    required String candidateId,
    required String idempotencyKey,
  }) async {
    final response = await _authorizedRequest(
      'POST',
      '/sessions/${_segment(sessionId)}/live-draft/history-preview/'
          '${_segment(previewId)}/select',
      body: {
        'deviceId': deviceId,
        'leaseId': leaseId,
        'candidateId': candidateId,
      },
      headers: _idempotencyHeaders(idempotencyKey),
    );
    final result =
        _parseResponse(response, LiveDraftHistoryReuseResultDto.fromJson);
    if (result.draft.sessionId != sessionId ||
        result.historyReuse.previewId != previewId ||
        result.historyReuse.candidateId != candidateId) {
      throw _clientException(
        code: 'INVALID_RESPONSE',
        message: 'The selected live draft history candidate is invalid',
        statusCode: response.statusCode,
      );
    }
    return result;
  }

  Future<LiveDraftCommitResultDto> commitLiveDraft({
    required String sessionId,
    required String deviceId,
    required int expectedDraftVersion,
    required String syncId,
    required String idempotencyKey,
  }) async {
    if (expectedDraftVersion < 1) {
      throw ArgumentError.value(
        expectedDraftVersion,
        'expectedDraftVersion',
        'must be positive',
      );
    }
    final response = await _authorizedRequest(
      'POST',
      '/sessions/${_segment(sessionId)}/live-draft/commit',
      body: {
        'deviceId': deviceId,
        'expectedDraftVersion': expectedDraftVersion,
        'syncId': syncId,
      },
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _parseResponse(response, LiveDraftCommitResultDto.fromJson);
  }

  Future<LiveDraftDiscardResultDto> discardLiveDraft({
    required String sessionId,
    required String deviceId,
    required int expectedDraftVersion,
    required String idempotencyKey,
  }) async {
    if (expectedDraftVersion < 1) {
      throw ArgumentError.value(
        expectedDraftVersion,
        'expectedDraftVersion',
        'must be positive',
      );
    }
    final response = await _authorizedRequest(
      'DELETE',
      '/sessions/${_segment(sessionId)}/live-draft',
      body: {
        'deviceId': deviceId,
        'expectedDraftVersion': expectedDraftVersion,
      },
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _parseResponse(response, LiveDraftDiscardResultDto.fromJson);
  }

  Future<List<MembershipDto>> listMembers(String sessionId) async {
    final response = await _authorizedRequest(
      'GET',
      '/sessions/${_segment(sessionId)}/members',
    );
    return _parseResponse(response, (json) {
      final object = _jsonObject(json, 'membersResult');
      final values = _jsonArray(object['members'], 'members');
      return List.unmodifiable(values.map(MembershipDto.fromJson));
    });
  }

  Future<MembershipDto> updateMemberRole({
    required String sessionId,
    required String userId,
    required InviteRole role,
    required String idempotencyKey,
  }) async {
    final response = await _authorizedRequest(
      'PATCH',
      '/sessions/${_segment(sessionId)}/members/${_segment(userId)}',
      body: {'role': role.toJson()},
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _parseResponse(
      response,
      (json) => MembershipDto.fromJson(
        _jsonObject(json, 'updateMemberResult')['membership'],
      ),
    );
  }

  Future<RemovedMemberDto> removeMember({
    required String sessionId,
    required String userId,
    required String idempotencyKey,
  }) async {
    final response = await _authorizedRequest(
      'DELETE',
      '/sessions/${_segment(sessionId)}/members/${_segment(userId)}',
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _parseResponse(response, RemovedMemberDto.fromJson);
  }

  Future<OwnershipTransferDto> transferOwnership({
    required String sessionId,
    required String newOwnerUserId,
    required String idempotencyKey,
  }) async {
    final response = await _authorizedRequest(
      'POST',
      '/sessions/${_segment(sessionId)}/transfer-ownership',
      body: {'newOwnerUserId': newOwnerUserId},
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _parseResponse(response, OwnershipTransferDto.fromJson);
  }

  Future<CollaborationInviteDto> createInvite({
    required String sessionId,
    required CreateInviteRequestDto request,
    required String idempotencyKey,
  }) async {
    final response = await _authorizedRequest(
      'POST',
      '/sessions/${_segment(sessionId)}/invites',
      body: request.toJson(),
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _parseResponse(
      response,
      (json) => CollaborationInviteDto.fromJson(
        _jsonObject(json, 'createInviteResult')['invite'],
      ),
    );
  }

  Future<List<CollaborationInviteDto>> listInvites(String sessionId) async {
    final response = await _authorizedRequest(
      'GET',
      '/sessions/${_segment(sessionId)}/invites',
    );
    return _parseResponse(response, (json) {
      final object = _jsonObject(json, 'invitesResult');
      final values = _jsonArray(object['invites'], 'invites');
      return List.unmodifiable(values.map(CollaborationInviteDto.fromJson));
    });
  }

  Future<CollaborationInviteDto> revokeInvite({
    required String sessionId,
    required String inviteId,
    required String idempotencyKey,
  }) async {
    final response = await _authorizedRequest(
      'DELETE',
      '/sessions/${_segment(sessionId)}/invites/${_segment(inviteId)}',
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _parseResponse(
      response,
      (json) => CollaborationInviteDto.fromJson(
        _jsonObject(json, 'revokeInviteResult')['invite'],
      ),
    );
  }

  Future<PublicShareDto> createPublicShare({
    required String sessionId,
    required int expiresInHours,
    required String idempotencyKey,
  }) async {
    if (expiresInHours < 1 || expiresInHours > 24 * 30) {
      throw ArgumentError.value(
        expiresInHours,
        'expiresInHours',
        'must be between 1 and 720',
      );
    }
    final response = await _authorizedRequest(
      'POST',
      '/sessions/${_segment(sessionId)}/public-shares',
      body: {'expiresInHours': expiresInHours},
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _parseResponse(
      response,
      (json) => PublicShareDto.fromJson(
        _jsonObject(json, 'createPublicShareResult')['publicShare'],
      ),
    );
  }

  Future<PublicSharePageDto> listPublicShares({
    required String sessionId,
    int limit = 50,
    String? after,
  }) async {
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 50');
    }
    if (after != null && after.isEmpty) {
      throw ArgumentError.value(after, 'after', 'must not be empty');
    }
    final response = await _authorizedRequest(
      'GET',
      '/sessions/${_segment(sessionId)}/public-shares',
      queryParameters: {
        'limit': '$limit',
        if (after != null) 'after': after,
      },
    );
    return _parseResponse(response, PublicSharePageDto.fromJson);
  }

  Future<PublicShareDto> revokePublicShare({
    required String sessionId,
    required String publicShareId,
    required String idempotencyKey,
  }) async {
    final response = await _authorizedRequest(
      'DELETE',
      '/sessions/${_segment(sessionId)}/public-shares/'
          '${_segment(publicShareId)}',
      headers: _idempotencyHeaders(idempotencyKey),
    );
    return _parseResponse(
      response,
      (json) => PublicShareDto.fromJson(
        _jsonObject(json, 'revokePublicShareResult')['publicShare'],
      ),
    );
  }

  Uri publicSharePageUri(PublicShareDto share) {
    final secret = share.secret;
    if (secret == null || secret.isEmpty) {
      throw ArgumentError.value(share, 'share', 'secret is required');
    }
    const apiSuffix = '/api/v1';
    final apiPath = _apiBaseUri.path;
    final rootPath = apiPath.endsWith(apiSuffix)
        ? apiPath.substring(0, apiPath.length - apiSuffix.length)
        : '';
    return _apiBaseUri.replace(
      path: '$rootPath/live/${_segment(share.publicShareId)}',
      query: null,
      // The public page intentionally reads the capability from a named
      // fragment parameter and immediately removes it from browser history.
      fragment: 'token=$secret',
    );
  }

  Future<RedeemInviteResultDto> redeemInvite(
    RedeemInviteRequestDto request,
  ) async {
    final response = await _authorizedRequest(
      'POST',
      '/collaboration-invites/redeem',
      body: request.toJson(),
      headers: _idempotencyHeaders(request.joinRequestId),
    );
    return _parseResponse(response, RedeemInviteResultDto.fromJson);
  }

  void close() {
    if (_ownsHttpClient) _httpClient.close();
  }

  Future<http.Response> _publicRequest(
    String method,
    String path, {
    Object? body,
  }) async {
    final response = await _send(method, path, body: body);
    _throwForError(response);
    return response;
  }

  Future<http.Response> _authorizedRequest(
    String method,
    String path, {
    Object? body,
    Object? Function(AuthSessionDto session)? bodyForSession,
    Map<String, String> headers = const {},
    Map<String, String>? queryParameters,
  }) async {
    final original = await _requireSession();
    var response = await _send(
      method,
      path,
      accessToken: original.accessToken,
      body: bodyForSession?.call(original) ?? body,
      headers: headers,
      queryParameters: queryParameters,
    );
    if (response.statusCode != 401) {
      _throwForError(response);
      return response;
    }

    final latest = await tokenStore.read();
    if (latest == null) {
      onAuthInvalidated?.call();
      throw _authContextChanged();
    }
    if (latest.user.id != original.user.id) {
      throw _authContextChanged();
    }

    final AuthSessionDto replacement;
    if (latest.accessToken != original.accessToken ||
        latest.refreshToken != original.refreshToken) {
      replacement = latest;
    } else {
      replacement = await _refreshOnce(original.refreshToken);
    }
    if (replacement.user.id != original.user.id) {
      throw _authContextChanged();
    }

    response = await _send(
      method,
      path,
      accessToken: replacement.accessToken,
      body: bodyForSession?.call(replacement) ?? body,
      headers: headers,
      queryParameters: queryParameters,
    );
    if (response.statusCode == 401) {
      final code = _apiErrorFromResponse(response)?.code;
      if (code == 'TOKEN_INVALID' || code == 'TOKEN_REVOKED') {
        await _clearIfCurrent(replacement.refreshToken);
      }
    }
    _throwForError(response);
    return response;
  }

  Future<AuthSessionDto> _requireSession() async {
    final session = await tokenStore.read();
    if (session != null) return session;
    throw _clientException(
      code: 'AUTH_REQUIRED',
      message: 'Authentication is required',
    );
  }

  Future<AuthSessionDto> _refreshOnce(
    String refreshToken, {
    String? deviceId,
  }) {
    final existing = _refreshesInFlight[refreshToken];
    if (existing != null) return existing;

    final refresh = _performRefresh(refreshToken, deviceId: deviceId);
    _refreshesInFlight[refreshToken] = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshesInFlight[refreshToken], refresh)) {
        _refreshesInFlight.remove(refreshToken);
      }
    });
  }

  Future<AuthSessionDto> _performRefresh(
    String refreshToken, {
    String? deviceId,
  }) async {
    final resolvedDeviceId = deviceId ?? this.deviceId;
    final response = await _send(
      'POST',
      '/auth/refresh',
      body: {
        'refreshToken': refreshToken,
        if (resolvedDeviceId != null) 'deviceId': resolvedDeviceId,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = _apiErrorFromResponse(response)?.code;
      if (response.statusCode == 401 && code == 'REFRESH_TOKEN_INVALID') {
        await _clearIfCurrent(refreshToken);
      }
      _throwForError(response);
    }
    final session = _parseResponse(response, AuthSessionDto.fromJson);
    final current = await tokenStore.read();
    if (current?.refreshToken == refreshToken) {
      await tokenStore.write(session);
    }
    return session;
  }

  ServerApiException _authContextChanged() => _clientException(
        code: 'AUTH_CONTEXT_CHANGED',
        message: 'Authentication context changed while the request was active',
      );

  Future<void> _clearIfCurrent(String refreshToken) async {
    final current = await tokenStore.read();
    if (current?.refreshToken == refreshToken) {
      await tokenStore.clear();
      onAuthInvalidated?.call();
    }
  }

  Future<http.Response> _send(
    String method,
    String path, {
    String? accessToken,
    Object? body,
    Map<String, String> headers = const {},
    Map<String, String>? queryParameters,
  }) async {
    final request = http.Request(
      method,
      _uri(path, queryParameters: queryParameters),
    );
    request.headers.addAll({
      'Accept': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      if (deviceId != null) 'X-Device-Id': deviceId!,
      ...headers,
    });
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await (() async {
        final streamed = await _httpClient.send(request);
        return http.Response.fromStream(streamed);
      })()
          .timeout(timeout);
      final errorCode = response.statusCode >= 400
          ? _apiErrorFromResponse(response)?.code ?? 'HTTP_ERROR'
          : null;
      final recoverableLiveDraftRace = (method == 'PATCH' &&
              path.endsWith('/live-draft') &&
              const {
                'LIVE_DRAFT_FIELD_CONFLICT',
                'LIVE_DRAFT_VERSION_CONFLICT',
                'LIVE_DRAFT_CLIENT_SEQ_GAP',
                'LIVE_DRAFT_CLIENT_SEQ_REUSED',
              }.contains(errorCode)) ||
          (method == 'POST' &&
              path.endsWith('/live-draft/commit') &&
              const {
                'LIVE_DRAFT_VERSION_CONFLICT',
                'LIVE_DRAFT_BUSY',
              }.contains(errorCode));
      final level = response.statusCode >= 500
          ? AppLogLevel.error
          : response.statusCode >= 400 && !recoverableLiveDraftRace
              ? AppLogLevel.warning
              : AppLogLevel.debug;
      AppLogger.instance.log(
        level,
        '$method $path -> ${response.statusCode} '
        '(${stopwatch.elapsedMilliseconds} ms)'
        '${errorCode == null ? '' : ' code=$errorCode'}',
        source: 'ServerApi',
      );
      return response;
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.instance.log(
        AppLogLevel.warning,
        '$method $path timed out after ${stopwatch.elapsedMilliseconds} ms',
        source: 'ServerApi',
        error: error,
        stackTrace: stackTrace,
      );
      throw _clientException(
        code: 'NETWORK_TIMEOUT',
        message: 'The server request timed out',
        retryable: true,
        cause: error,
      );
    } on http.ClientException catch (error, stackTrace) {
      AppLogger.instance.log(
        AppLogLevel.warning,
        '$method $path failed after ${stopwatch.elapsedMilliseconds} ms',
        source: 'ServerApi',
        error: error,
        stackTrace: stackTrace,
      );
      throw _clientException(
        code: 'NETWORK_ERROR',
        message: 'The server request failed',
        retryable: true,
        cause: error,
      );
    }
  }

  T _parseResponse<T>(http.Response response, T Function(Object? json) parse) {
    try {
      if (response.body.trim().isEmpty) {
        throw const FormatException('response body is empty');
      }
      return parse(jsonDecode(response.body));
    } on FormatException catch (error) {
      throw _clientException(
        code: 'INVALID_RESPONSE',
        message: 'The server returned an invalid protocol response',
        statusCode: response.statusCode,
        cause: error,
      );
    }
  }

  void _expectEmpty(http.Response response) {
    if (response.body.trim().isNotEmpty) {
      throw _clientException(
        code: 'INVALID_RESPONSE',
        message: 'The server returned an unexpected response body',
        statusCode: response.statusCode,
      );
    }
  }

  void _throwForError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final apiError = _apiErrorFromResponse(response);

    throw ServerApiException(
      error: apiError ??
          ApiErrorDto(
            code: 'HTTP_ERROR',
            message: 'The server returned HTTP ${response.statusCode}',
            requestId: response.headers['x-request-id'] ?? 'unknown',
          ),
      statusCode: response.statusCode,
      retryable: _isRetryableStatus(response.statusCode),
    );
  }

  ApiErrorDto? _apiErrorFromResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      final envelope = _jsonObject(decoded, 'errorEnvelope');
      return ApiErrorDto.fromJson(envelope['error']);
    } on FormatException {
      return null;
    }
  }

  ServerApiException _clientException({
    required String code,
    required String message,
    int? statusCode,
    bool retryable = false,
    Object? cause,
  }) {
    return ServerApiException(
      error: ApiErrorDto(
        code: code,
        message: message,
        requestId: 'client',
      ),
      statusCode: statusCode,
      retryable: retryable,
      cause: cause,
    );
  }

  Map<String, String> _idempotencyHeaders(String key) {
    final normalized = key.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(key, 'idempotencyKey', 'must not be empty');
    }
    return {'Idempotency-Key': normalized};
  }

  Uri _uri(
    String path, {
    Map<String, String>? queryParameters,
  }) =>
      _apiBaseUri.replace(
        path: '${_apiBaseUri.path}$path',
        queryParameters: queryParameters,
        fragment: null,
      );

  static Uri _normalizeApiBaseUri(Uri baseUri) {
    if (!baseUri.hasScheme || baseUri.host.isEmpty) {
      throw ArgumentError.value(baseUri, 'baseUri', 'must be an absolute URI');
    }
    var path = baseUri.path.replaceFirst(RegExp(r'/+$'), '');
    if (!path.endsWith('/api/v1')) path = '$path/api/v1';
    return baseUri.replace(path: path, query: null, fragment: null);
  }

  static String _segment(String value) => Uri.encodeComponent(value);

  static bool _isRetryableStatus(int statusCode) => switch (statusCode) {
        408 || 425 || 429 || 500 || 502 || 503 || 504 => true,
        _ => false,
      };
}

JsonObject _jsonObject(Object? value, String field) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    try {
      return Map<String, Object?>.from(value);
    } on TypeError {
      // Report a protocol error below.
    }
  }
  throw FormatException('$field must be a JSON object');
}

List<Object?> _jsonArray(Object? value, String field) {
  if (value is List) return List<Object?>.from(value);
  throw FormatException('$field must be a JSON array');
}
