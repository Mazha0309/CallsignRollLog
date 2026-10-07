import 'dart:async';

import 'errors.dart';
import 'models.dart';

final class AiCredentials {
  AiCredentials({required String apiKey}) : apiKey = apiKey.trim() {
    if (this.apiKey.isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', 'must not be empty');
    }
  }

  final String apiKey;
}

final class AiCredentialRequest {
  const AiCredentialRequest({
    required this.providerId,
    required this.credentialId,
  });

  final String providerId;
  final String? credentialId;
}

typedef AiCredentialResolver = FutureOr<AiCredentials?> Function(
  AiCredentialRequest request,
);

final class AiCancellationToken {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }

  void throwIfCancelled({String? providerId}) {
    if (!isCancelled) return;
    throw AiRecognitionException(
      kind: AiRecognitionErrorKind.cancelled,
      message: 'The AI request was cancelled',
      providerId: providerId,
    );
  }
}

final class AiRequestOptions {
  const AiRequestOptions({
    this.credentials,
    this.credentialResolver,
    this.cancellationToken,
  });

  final AiCredentials? credentials;
  final AiCredentialResolver? credentialResolver;
  final AiCancellationToken? cancellationToken;
}

abstract interface class AsrProvider {
  AiProviderProfile get profile;

  AiProviderCapabilities get capabilities;

  Future<Transcription> transcribe(
    AudioSegment audio, {
    String? languageHint,
    String? prompt,
    AiRequestOptions options = const AiRequestOptions(),
  });

  void close();
}

abstract interface class FieldExtractionProvider {
  AiProviderProfile get profile;

  AiProviderCapabilities get capabilities;

  Future<List<RecognitionCandidate>> extract(
    Transcription transcription, {
    String? instructions,
    AiRequestOptions options = const AiRequestOptions(),
  });

  void close();
}

/// 一次调用把音频变成字段。设计的模式 A 用它。
abstract interface class AudioFieldExtractionProvider {
  AiProviderProfile get profile;

  AiProviderCapabilities get capabilities;

  Future<AiRecognitionResult> extractFieldsFromAudio(
    AudioSegment audio, {
    String? instructions,
    AiRequestOptions options = const AiRequestOptions(),
  });

  void close();
}
