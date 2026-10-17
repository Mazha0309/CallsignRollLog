import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'errors.dart';
import 'models.dart';
import 'providers.dart';

final class AiHttpTransport {
  static const int maxResponseBytes = 2 * 1024 * 1024;

  AiHttpTransport({
    required this.profile,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  })  : _client = httpClient ?? http.Client(),
        _ownsClient = httpClient == null {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'must be positive');
    }
  }

  final AiProviderProfile profile;
  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;
  final Set<_ActiveRequest> _activeRequests = {};
  bool _closed = false;

  Future<http.Response> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    List<int>? bodyBytes,
    required AiRequestOptions options,
  }) async {
    if (_closed) throw _closedError();
    options.cancellationToken?.throwIfCancelled(providerId: profile.id);

    final operation = _ActiveRequest(
      providerId: profile.id,
      timeout: timeout,
      cancellationToken: options.cancellationToken,
    );
    _activeRequests.add(operation);
    try {
      final credentials = await _resolveCredentials(options, operation);
      final prepared = _applyCredentials(uri, headers, credentials);
      final request = http.AbortableRequest(
        method,
        prepared.uri,
        abortTrigger: operation.abortSignal,
      )
        // Provider credentials must never be forwarded by an implicit HTTP
        // redirect. A profile must name its final endpoint explicitly.
        ..followRedirects = false
        ..headers.addAll(prepared.headers);
      if (bodyBytes != null) request.bodyBytes = bodyBytes;

      final streamedResponse = await operation.race(_client.send(request));
      final response = await operation.race(
        _readBoundedResponse(streamedResponse, profile.id),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiRecognitionException(
          kind: AiRecognitionErrorKind.httpStatus,
          message: 'The AI provider returned HTTP ${response.statusCode}',
          providerId: profile.id,
          statusCode: response.statusCode,
          responseBody: aiResponseSnippet(response.bodyBytes),
        );
      }
      return response;
    } on AiRecognitionException {
      rethrow;
    } on http.RequestAbortedException catch (error) {
      throw operation.abortError ??
          AiRecognitionException(
            kind: AiRecognitionErrorKind.cancelled,
            message: 'The AI request was aborted',
            providerId: profile.id,
            cause: error,
          );
    } on TimeoutException catch (error) {
      throw AiRecognitionException(
        kind: AiRecognitionErrorKind.timeout,
        message: 'The AI request timed out',
        providerId: profile.id,
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw operation.abortError ??
          AiRecognitionException(
            kind: AiRecognitionErrorKind.network,
            message: 'The AI provider request failed',
            providerId: profile.id,
            cause: error,
          );
    } catch (error) {
      throw operation.abortError ??
          AiRecognitionException(
            kind: AiRecognitionErrorKind.network,
            message: 'The AI provider request failed',
            providerId: profile.id,
            cause: error,
          );
    } finally {
      operation.dispose();
      _activeRequests.remove(operation);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    for (final operation in _activeRequests.toList(growable: false)) {
      operation.abort(_closedError());
    }
    if (_ownsClient) _client.close();
  }

  Future<AiCredentials?> _resolveCredentials(
    AiRequestOptions options,
    _ActiveRequest operation,
  ) async {
    if (profile.credentialTransport.location == AiCredentialLocation.none) {
      return null;
    }
    if (options.credentials != null) return options.credentials;
    final resolver = options.credentialResolver;
    AiCredentials? resolved;
    if (resolver != null) {
      try {
        resolved = await operation.race(
          Future<AiCredentials?>.sync(
            () => resolver(
              AiCredentialRequest(
                providerId: profile.id,
                credentialId: profile.credentialId,
              ),
            ),
          ),
        );
      } on AiRecognitionException {
        rethrow;
      } catch (error) {
        throw AiRecognitionException(
          kind: AiRecognitionErrorKind.missingCredentials,
          message: 'The provider credential could not be resolved',
          providerId: profile.id,
          cause: error,
        );
      }
    }
    if (resolved == null && profile.credentialTransport.isRequired) {
      throw AiRecognitionException(
        kind: AiRecognitionErrorKind.missingCredentials,
        message: 'The provider requires an API credential',
        providerId: profile.id,
      );
    }
    return resolved;
  }

  _PreparedRequest _applyCredentials(
    Uri uri,
    Map<String, String> headers,
    AiCredentials? credentials,
  ) {
    final resultHeaders = <String, String>{...profile.headers, ...headers};
    if (credentials == null) {
      return _PreparedRequest(uri, resultHeaders);
    }

    final transport = profile.credentialTransport;
    final value = '${transport.prefix}${credentials.apiKey}';
    if (uri.scheme != 'https' && !_isLoopback(uri.host)) {
      throw AiRecognitionException(
        kind: AiRecognitionErrorKind.invalidConfiguration,
        message: 'Credentials cannot be sent over an insecure HTTP endpoint',
        providerId: profile.id,
      );
    }
    switch (transport.location) {
      case AiCredentialLocation.none:
        break;
      case AiCredentialLocation.bearerHeader:
      case AiCredentialLocation.header:
        resultHeaders[transport.name] = value;
        break;
      case AiCredentialLocation.queryParameter:
        uri = uri.replace(
          queryParameters: {
            ...uri.queryParameters,
            transport.name: value,
          },
        );
        break;
    }
    return _PreparedRequest(uri, resultHeaders);
  }

  AiRecognitionException _closedError() => AiRecognitionException(
        kind: AiRecognitionErrorKind.closed,
        message: 'The AI provider has been closed',
        providerId: profile.id,
      );
}

Future<http.Response> _readBoundedResponse(
  http.StreamedResponse response,
  String providerId,
) async {
  final declaredLength = response.contentLength;
  if (declaredLength != null &&
      declaredLength > AiHttpTransport.maxResponseBytes) {
    final subscription = response.stream.listen(null);
    try {
      await subscription.cancel();
    } catch (_) {
      // Preserve the stable response-size failure even if a custom transport
      // also fails while releasing its response stream.
    }
    throw AiRecognitionException(
      kind: AiRecognitionErrorKind.invalidResponse,
      message: 'The AI provider response is too large',
      providerId: providerId,
    );
  }

  final bytes = BytesBuilder(copy: false);
  await for (final chunk in response.stream) {
    if (bytes.length + chunk.length > AiHttpTransport.maxResponseBytes) {
      throw AiRecognitionException(
        kind: AiRecognitionErrorKind.invalidResponse,
        message: 'The AI provider response is too large',
        providerId: providerId,
      );
    }
    bytes.add(chunk);
  }
  return http.Response.bytes(
    bytes.takeBytes(),
    response.statusCode,
    request: response.request,
    headers: response.headers,
    isRedirect: response.isRedirect,
    persistentConnection: response.persistentConnection,
    reasonPhrase: response.reasonPhrase,
  );
}

final class _PreparedRequest {
  const _PreparedRequest(this.uri, this.headers);

  final Uri uri;
  final Map<String, String> headers;
}

final class _ActiveRequest {
  _ActiveRequest({
    required this.providerId,
    required Duration timeout,
    required AiCancellationToken? cancellationToken,
  }) {
    _timeoutTimer = Timer(
      timeout,
      () => abort(
        AiRecognitionException(
          kind: AiRecognitionErrorKind.timeout,
          message: 'The AI request timed out',
          providerId: providerId,
        ),
      ),
    );
    if (cancellationToken != null) {
      if (cancellationToken.isCancelled) {
        abort(
          AiRecognitionException(
            kind: AiRecognitionErrorKind.cancelled,
            message: 'The AI request was cancelled',
            providerId: providerId,
          ),
        );
      } else {
        cancellationToken.whenCancelled.then((_) {
          abort(
            AiRecognitionException(
              kind: AiRecognitionErrorKind.cancelled,
              message: 'The AI request was cancelled',
              providerId: providerId,
            ),
          );
        });
      }
    }
  }

  final String providerId;
  final Completer<void> _abortSignal = Completer<void>();
  final Completer<AiRecognitionException> _abortError =
      Completer<AiRecognitionException>();
  late final Timer _timeoutTimer;
  bool _disposed = false;

  Future<void> get abortSignal => _abortSignal.future;
  AiRecognitionException? get abortError =>
      _abortError.isCompleted ? _completedError : null;
  AiRecognitionException? _completedError;

  Future<T> race<T>(Future<T> future) => Future.any([
        future,
        _abortError.future.then<T>((error) => throw error),
      ]);

  void abort(AiRecognitionException error) {
    if (_disposed || _abortSignal.isCompleted) return;
    _completedError = error;
    _abortSignal.complete();
    _abortError.complete(error);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timeoutTimer.cancel();
  }
}

String aiResponseSnippet(List<int> bodyBytes) {
  const limit = 4096;
  final bytes =
      bodyBytes.length <= limit ? bodyBytes : bodyBytes.sublist(0, limit);
  return utf8.decode(bytes, allowMalformed: true);
}

bool _isLoopback(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}
