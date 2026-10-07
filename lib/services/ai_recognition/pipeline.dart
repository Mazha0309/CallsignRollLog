import 'errors.dart';
import 'models.dart';
import 'providers.dart';

/// Runs one already-segmented audio turn through the configured stages.
///
/// This class deliberately stops at local candidates. Applying a candidate to
/// an editor or collaboration draft requires a fresh UI/CAS guard check.
final class AiRecognitionPipeline {
  AiRecognitionPipeline({
    required AsrProvider asr,
    FieldExtractionProvider? fieldExtraction,
    AiCredentialResolver? credentialResolver,
  })  : _asr = asr,
        _fieldExtraction = fieldExtraction,
        _credentialResolver = credentialResolver;

  final AsrProvider _asr;
  final FieldExtractionProvider? _fieldExtraction;
  final AiCredentialResolver? _credentialResolver;
  bool _closed = false;

  AiProviderProfile get asrProfile => _asr.profile;
  AiProviderProfile? get fieldExtractionProfile => _fieldExtraction?.profile;

  Future<AiRecognitionResult> recognize(
    AudioSegment audio, {
    String? languageHint,
    String? transcriptionPrompt,
    String? extractionInstructions,
    bool Function(Transcription transcription)? shouldExtract,
    AiCancellationToken? cancellationToken,
  }) async {
    if (_closed) {
      throw const AiRecognitionException(
        kind: AiRecognitionErrorKind.closed,
        message: 'The AI recognition pipeline has been closed',
      );
    }
    final options = AiRequestOptions(
      credentialResolver: _credentialResolver,
      cancellationToken: cancellationToken,
    );
    final transcription = await _asr.transcribe(
      audio,
      languageHint: languageHint,
      prompt: transcriptionPrompt,
      options: options,
    );
    _throwIfClosed(providerId: _asr.profile.id);
    cancellationToken?.throwIfCancelled(providerId: _asr.profile.id);

    final extractor = _fieldExtraction;
    if (extractor == null ||
        (shouldExtract != null && !shouldExtract(transcription))) {
      return AiRecognitionResult(
        transcription: transcription,
        candidates: const [],
      );
    }
    final candidates = await extractor.extract(
      transcription,
      instructions: extractionInstructions,
      options: options,
    );
    _throwIfClosed(providerId: extractor.profile.id);
    cancellationToken?.throwIfCancelled(providerId: extractor.profile.id);
    return AiRecognitionResult(
      transcription: transcription,
      candidates: List.unmodifiable(candidates),
    );
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _asr.close();
    _fieldExtraction?.close();
  }

  void _throwIfClosed({required String providerId}) {
    if (!_closed) return;
    throw AiRecognitionException(
      kind: AiRecognitionErrorKind.closed,
      message: 'The AI recognition pipeline has been closed',
      providerId: providerId,
    );
  }
}
