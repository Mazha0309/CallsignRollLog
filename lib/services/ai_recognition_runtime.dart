import 'package:openlogtool/providers/ai_recognition_settings_provider.dart';
import 'package:openlogtool/services/ai_recognition/ai_recognition.dart';

typedef AiRecognitionExecutor = Future<AiRecognitionResult> Function(
  AudioSegment audio,
  AiRecognitionSettingsProvider settings,
  AiCancellationToken cancellationToken,
);
typedef AiTranscriptionExecutor = Future<Transcription> Function(
  AudioSegment audio,
  AiRecognitionSettingsProvider settings,
  AiCancellationToken cancellationToken,
);
typedef AiFieldExtractionExecutor = Future<AiRecognitionResult> Function(
  Transcription transcription,
  AiRecognitionSettingsProvider settings,
  AiCancellationToken cancellationToken, {
  String? referenceContext,
});

abstract final class AiRecognitionRuntime {
  static const transcriptionPrompt =
      'Amateur radio net check-in audio. Preserve callsigns, RST reports, '
      'QTH names, equipment, antennas, power, height, and remarks exactly as '
      'heard. The speech may contain Chinese and English.';

  static const extractionInstructions = '''
Extract one amateur-radio net check-in record from the transcript.
Return only one JSON object. Use only these optional string keys:
callsign, device, antenna, power, qth, height, rstSent, rstRcvd, remarks.
Never return time. Omit any field that was not clearly spoken. Do not infer or invent values.
Never return the net controller or main-control callsign; it belongs to the session context.
Every returned value must be directly supported by the transcript.
If the transcript contains only filler, noise, or no identifiable check-in data, return {}.
Never return null or an empty string; omit that key instead.
Normalize an explicitly spoken transmit power to digits plus W. For example,
"五个瓦特功率发射" must produce {"power":"5 W"}.
Decode NATO phonetic spelling when it clearly forms a callsign. Return callsigns
in uppercase without spaces, for example "Bravo Golf Five Echo Uniform Uniform"
as "BG5EUU". Extract the caller's final confirmed callsign, never a controller
prompt, partial suffix, or uncertain readback. Check the entire transcript for
explicit equipment and QTH statements before omitting those fields.
Keep RST sent and received separate.
''';

  /// 模式 A 的指令：一次调用同时要转写与字段。
  static const audioFieldExtractionInstructions = '''
Listen to one amateur-radio net check-in and return a single JSON object:
{"transcript":"<verbatim transcript>","fields":{...},"uncertain":[...]}

"fields" accepts only these optional string keys:
callsign, device, antenna, power, qth, height, rstSent, rstRcvd, remarks.
Never return time. Never return the net controller callsign; it belongs to the
session context. Omit any field not clearly spoken. Do not infer or invent
values. Normalize explicitly spoken transmit power to digits plus W.
Decode NATO phonetic spelling when it clearly forms a callsign, and return
callsigns uppercase without spaces.
List in "uncertain" any field you had to guess or that was hard to hear.
Return {"transcript":"…","fields":{}} when the audio has no check-in data.
''';

  static Future<AiRecognitionResult> recognize(
    AudioSegment audio,
    AiRecognitionSettingsProvider settings,
    AiCancellationToken cancellationToken,
  ) async {
    final transcription = await transcribe(audio, settings, cancellationToken);
    return extractFields(transcription, settings, cancellationToken);
  }

  /// 模式 A 的入口：一次调用拿到转写与字段。
  ///
  /// 与 [recognize] 的区别是不经过独立的 ASR 与文字助手两次网络往返。
  static Future<AiRecognitionResult> recognizeRecord(
    AudioSegment audio,
    AiRecognitionSettingsProvider settings,
    AiCancellationToken cancellationToken,
  ) async {
    await settings.initialized;
    return recognizeRecordWith(
      audio,
      (segment, instructions) async {
        final profile = settings.activeAudioFieldExtractionProfile;
        if (profile == null) {
          throw StateError('AI_AUDIO_FIELD_EXTRACTION_PROFILE_REQUIRED');
        }
        final provider = AiProviderFactory.createAudioFieldExtraction(profile);
        try {
          return await provider.extractFieldsFromAudio(
            segment,
            instructions: instructions,
            options: AiRequestOptions(
              credentialResolver: settings.credentialResolver,
              cancellationToken: cancellationToken,
            ),
          );
        } finally {
          provider.close();
        }
      },
      instructions: audioFieldExtractionInstructions,
    );
  }

  /// 与 [recognizeRecord] 相同，但执行器可由调用方注入，便于测试。
  static Future<AiRecognitionResult> recognizeRecordWith(
    AudioSegment audio,
    Future<AiRecognitionResult> Function(
            AudioSegment audio, String? instructions)
        execute, {
    String? instructions,
  }) {
    return execute(audio, instructions);
  }

  static Future<Transcription> transcribe(
    AudioSegment audio,
    AiRecognitionSettingsProvider settings,
    AiCancellationToken cancellationToken,
  ) async {
    await settings.initialized;
    final asrProfile = settings.activeAsrProfile;
    if (!settings.enabled || asrProfile == null) {
      throw StateError('AI_RECOGNITION_DISABLED');
    }
    final provider = AiProviderFactory.createAsr(asrProfile);
    try {
      return await provider.transcribe(
        audio,
        prompt: transcriptionPrompt,
        options: AiRequestOptions(
          credentialResolver: settings.credentialResolver,
          cancellationToken: cancellationToken,
        ),
      );
    } finally {
      provider.close();
    }
  }

  static Future<AiRecognitionResult> extractFields(
    Transcription transcription,
    AiRecognitionSettingsProvider settings,
    AiCancellationToken cancellationToken, {
    String? referenceContext,
  }) async {
    await settings.initialized;
    if (!settings.enabled) throw StateError('AI_RECOGNITION_DISABLED');
    if (settings.textAssistantEnabled &&
        settings.textAssistantConfig != null &&
        isActionableTranscription(transcription.text)) {
      final client = settings.createTextAssistantClient();
      try {
        final fields = await client.completeJson(
          systemPrompt: _instructionsWithContext(referenceContext),
          userPrompt: transcription.text,
          cancellationToken: cancellationToken,
          maxOutputTokens: 700,
        );
        final candidateFields = <String, Object?>{
          for (final entry in fields.entries)
            if (entry.value is String &&
                (entry.value as String).trim().isNotEmpty)
              entry.key: (entry.value as String).trim(),
        };
        return _withExplicitPowerFallback(
          AiRecognitionResult(
            transcription: transcription,
            candidates: candidateFields.isEmpty
                ? const []
                : <RecognitionCandidate>[
                    RecognitionCandidate(
                      fields: candidateFields,
                      sourceText: transcription.text,
                      metadata: <String, Object?>{
                        'provider': settings.textAssistantConfig!.provider.name,
                        'model': settings.textAssistantConfig!.model,
                      },
                    ),
                  ],
          ),
        );
      } finally {
        client.close();
      }
    }
    final extractionProfile = settings.activeFieldExtractionProfile;
    if (extractionProfile == null ||
        !isActionableTranscription(transcription.text)) {
      return _withExplicitPowerFallback(
        AiRecognitionResult(
          transcription: transcription,
          candidates: const [],
        ),
      );
    }
    final provider = AiProviderFactory.createFieldExtraction(extractionProfile);
    try {
      final candidates = await provider.extract(
        transcription,
        instructions: _instructionsWithContext(referenceContext),
        options: AiRequestOptions(
          credentialResolver: settings.credentialResolver,
          cancellationToken: cancellationToken,
        ),
      );
      return _withExplicitPowerFallback(
        AiRecognitionResult(
          transcription: transcription,
          candidates: List.unmodifiable(candidates),
        ),
      );
    } finally {
      provider.close();
    }
  }

  static String _instructionsWithContext(String? referenceContext) {
    final context = referenceContext?.trim();
    if (context == null || context.isEmpty) return extractionInstructions;
    return '''
$extractionInstructions

The following JSON contains a small set of spelling references selected from
the user's local dictionaries and recent records. It is not evidence that a
field was spoken. Use a reference only when it closely matches explicit speech
in the transcript; otherwise omit the field. Never copy an unrelated value.
LOCAL_REFERENCE_CONTEXT:
$context
END_LOCAL_REFERENCE_CONTEXT
''';
  }

  static bool isActionableTranscription(String text) {
    final normalized =
        text.toLowerCase().replaceAll(RegExp(r'[\s，。,.!?！？、~～…]'), '');
    if (normalized.isEmpty) return false;
    if (RegExp(r'^[嗯呃啊哦唔哎诶]+$').hasMatch(normalized)) return false;
    return !const {'uh', 'um', 'hmm', 'hm'}.contains(normalized);
  }

  static AiRecognitionResult _withExplicitPowerFallback(
    AiRecognitionResult result,
  ) {
    final power = extractExplicitPower(result.transcription.text);
    if (power == null) return result;
    if (result.candidates.isEmpty) {
      return AiRecognitionResult(
        transcription: result.transcription,
        candidates: [
          RecognitionCandidate(
            fields: {'power': power},
            sourceText: result.transcription.text,
          ),
        ],
      );
    }
    return AiRecognitionResult(
      transcription: result.transcription,
      candidates: [
        for (final candidate in result.candidates)
          if (candidate.fields['power'] is! String ||
              (candidate.fields['power'] as String).trim().isEmpty)
            RecognitionCandidate(
              fields: {...candidate.fields, 'power': power},
              confidence: candidate.confidence,
              sourceText: candidate.sourceText,
              warnings: candidate.warnings,
              metadata: candidate.metadata,
            )
          else
            candidate,
      ],
    );
  }

  static String? extractExplicitPower(String text) {
    final numeric = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:w(?:atts?)?|瓦(?:特)?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (numeric != null) {
      final value = double.tryParse(numeric.group(1)!);
      if (value != null && value > 0) return '${numeric.group(1)} W';
    }
    final chinese = RegExp(
      r'([零〇一二两三四五六七八九十百千]+)(?:个)?\s*瓦(?:特)?',
    ).firstMatch(text);
    if (chinese == null) return null;
    final value = _parseChineseInteger(chinese.group(1)!);
    return value == null || value <= 0 ? null : '$value W';
  }

  static int? _parseChineseInteger(String source) {
    const digits = {
      '零': 0,
      '〇': 0,
      '一': 1,
      '二': 2,
      '两': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };
    const units = {'十': 10, '百': 100, '千': 1000};
    if (!source.split('').any(units.containsKey)) {
      final encoded = source.split('').map((char) => digits[char]).toList();
      if (encoded.any((value) => value == null)) return null;
      return int.tryParse(encoded.join());
    }
    var total = 0;
    var current = 0;
    for (final char in source.split('')) {
      if (digits[char] case final digit?) {
        current = digit;
      } else if (units[char] case final unit?) {
        total += (current == 0 ? 1 : current) * unit;
        current = 0;
      } else {
        return null;
      }
    }
    return total + current;
  }
}
