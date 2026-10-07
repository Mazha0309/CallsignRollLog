import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'errors.dart';
import 'http_transport.dart';
import 'json_support.dart';
import 'models.dart';
import 'providers.dart';

abstract final class AiProviderFactory {
  static AsrProvider createAsr(
    AiProviderProfile profile, {
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
  }) =>
      ProtocolAsrProvider(
        profile: profile,
        httpClient: httpClient,
        timeout: timeout,
      );

  static FieldExtractionProvider createFieldExtraction(
    AiProviderProfile profile, {
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
  }) =>
      ProtocolFieldExtractionProvider(
        profile: profile,
        httpClient: httpClient,
        timeout: timeout,
      );

  static AudioFieldExtractionProvider createAudioFieldExtraction(
    AiProviderProfile profile, {
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 60),
  }) =>
      ProtocolAudioFieldExtractionProvider(
        profile: profile,
        httpClient: httpClient,
        timeout: timeout,
      );
}

/// Batch ASR client selected entirely by [profile].
final class ProtocolAsrProvider implements AsrProvider {
  ProtocolAsrProvider({
    required this.profile,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
  }) : _transport = AiHttpTransport(
          profile: profile,
          httpClient: httpClient,
          timeout: timeout,
        ) {
    if (profile.kind != AiProviderKind.speechRecognition) {
      throw ArgumentError.value(
        profile.kind,
        'profile.kind',
        'must be speechRecognition',
      );
    }
    if (!_supportedProtocols.contains(profile.protocol)) {
      throw AiRecognitionException(
        kind: AiRecognitionErrorKind.unsupportedProtocol,
        message: '${profile.protocol.name} is not an ASR protocol',
        providerId: profile.id,
      );
    }
  }

  static const _supportedProtocols = {
    AiProtocol.openAiAudioTranscriptions,
    AiProtocol.openAiChatCompletionsAudio,
    AiProtocol.jsonHttp,
  };

  @override
  final AiProviderProfile profile;
  final AiHttpTransport _transport;

  @override
  AiProviderCapabilities get capabilities => profile.capabilities;

  @override
  Future<Transcription> transcribe(
    AudioSegment audio, {
    String? languageHint,
    String? prompt,
    AiRequestOptions options = const AiRequestOptions(),
  }) async {
    _validateAudio(profile, audio);
    try {
      return await switch (profile.protocol) {
        AiProtocol.openAiAudioTranscriptions => _transcribeMultipart(
            audio,
            languageHint: languageHint,
            prompt: prompt,
            options: options,
          ),
        AiProtocol.openAiChatCompletionsAudio => _transcribeChatAudio(
            audio,
            languageHint: languageHint,
            prompt: prompt,
            options: options,
          ),
        AiProtocol.jsonHttp => _transcribeJson(
            audio,
            languageHint: languageHint,
            prompt: prompt,
            options: options,
          ),
        AiProtocol.openAiChatCompletions => throw AiRecognitionException(
            kind: AiRecognitionErrorKind.unsupportedProtocol,
            message: '${profile.protocol.name} is not an ASR protocol',
            providerId: profile.id,
          ),
      };
    } on AiRecognitionException {
      rethrow;
    } on FormatException catch (error) {
      throw _invalidConfiguration(error.message, error);
    } on ArgumentError catch (error) {
      throw _invalidConfiguration(error.message.toString(), error);
    }
  }

  Future<Transcription> _transcribeMultipart(
    AudioSegment audio, {
    required String? languageHint,
    required String? prompt,
    required AiRequestOptions options,
  }) async {
    final endpoint = _openAiEndpoint(profile, const [
      'v1',
      'audio',
      'transcriptions',
    ]);
    final fields = <String, String>{};
    final extraFields = profile.requestOptions['fields'];
    if (extraFields != null) {
      if (extraFields is! Map) {
        throw const FormatException('fields must be a JSON object');
      }
      for (final entry in extraFields.entries) {
        if (entry.key is! String ||
            (entry.value is! String &&
                entry.value is! num &&
                entry.value is! bool)) {
          throw const FormatException('multipart fields must be scalar values');
        }
        fields[entry.key as String] = entry.value.toString();
      }
    }

    fields[_optionString(profile, 'modelField', fallback: 'model')] =
        profile.model;
    if (_nonEmptyOrNull(languageHint) case final language?) {
      fields[_optionString(profile, 'languageField', fallback: 'language')] =
          language;
    }
    if (_nonEmptyOrNull(prompt) case final promptText?) {
      fields[_optionString(profile, 'promptField', fallback: 'prompt')] =
          promptText;
    }

    final multipart = _encodeMultipart(
      fields: fields,
      fileField: _optionString(profile, 'fileField', fallback: 'file'),
      audio: audio,
    );
    final response = await _transport.send(
      method: 'POST',
      uri: endpoint,
      headers: {
        'content-type': 'multipart/form-data; boundary=${multipart.boundary}',
        'accept': 'application/json',
      },
      bodyBytes: multipart.bytes,
      options: options,
    );
    return _parseTranscription(response, profile);
  }

  Future<Transcription> _transcribeChatAudio(
    AudioSegment audio, {
    required String? languageHint,
    required String? prompt,
    required AiRequestOptions options,
  }) async {
    final endpoint = _openAiEndpoint(profile, const [
      'v1',
      'chat',
      'completions',
    ]);
    final content = buildChatAudioContent(profile, audio, prompt: prompt);

    final messages = <Object?>[];
    if (_optionStringOrNull(profile, 'systemPrompt') case final systemPrompt?) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': content});

    final body = <String, Object?>{
      ..._optionJsonObject(profile, 'body'),
      'model': profile.model,
      'messages': messages,
      if (_nonEmptyOrNull(languageHint) case final language?)
        if (_optionStringOrNull(profile, 'languageField') case final field?)
          field: language,
    };
    final response = await _sendJson(
      _transport,
      endpoint,
      'POST',
      body,
      options,
    );
    return _parseTranscription(response, profile);
  }

  Future<Transcription> _transcribeJson(
    AudioSegment audio, {
    required String? languageHint,
    required String? prompt,
    required AiRequestOptions options,
  }) async {
    final template = profile.requestOptions['requestTemplate'];
    if (template == null) {
      throw const FormatException('requestTemplate is required for jsonHttp');
    }
    final variables = <String, Object?>{
      'model': profile.model,
      'audio': {
        'base64': base64Encode(audio.bytes),
        'dataUrl': 'data:${audio.mimeType};base64,${base64Encode(audio.bytes)}',
        'mimeType': audio.mimeType,
        'fileName': audio.fileName,
        'byteLength': audio.bytes.length,
      },
      'language': _nonEmptyOrNull(languageHint),
      'prompt': _nonEmptyOrNull(prompt),
    };
    final body = renderAiJsonTemplate(template, variables);
    final response = await _sendJson(
      _transport,
      _configuredEndpoint(profile),
      _optionString(profile, 'method', fallback: 'POST').toUpperCase(),
      body,
      options,
    );
    return _parseTranscription(response, profile);
  }

  AiRecognitionException _invalidConfiguration(
    String message,
    Object cause,
  ) =>
      AiRecognitionException(
        kind: AiRecognitionErrorKind.invalidConfiguration,
        message: message,
        providerId: profile.id,
        cause: cause,
      );

  @override
  void close() => _transport.close();
}

/// Structured field extraction client selected entirely by [profile].
final class ProtocolFieldExtractionProvider implements FieldExtractionProvider {
  ProtocolFieldExtractionProvider({
    required this.profile,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 30),
  }) : _transport = AiHttpTransport(
          profile: profile,
          httpClient: httpClient,
          timeout: timeout,
        ) {
    if (profile.kind != AiProviderKind.fieldExtraction) {
      throw ArgumentError.value(
        profile.kind,
        'profile.kind',
        'must be fieldExtraction',
      );
    }
    if (!_supportedProtocols.contains(profile.protocol)) {
      throw AiRecognitionException(
        kind: AiRecognitionErrorKind.unsupportedProtocol,
        message: '${profile.protocol.name} is not a field extraction protocol',
        providerId: profile.id,
      );
    }
  }

  static const _supportedProtocols = {
    AiProtocol.openAiChatCompletions,
    AiProtocol.jsonHttp,
  };

  @override
  final AiProviderProfile profile;
  final AiHttpTransport _transport;

  @override
  AiProviderCapabilities get capabilities => profile.capabilities;

  @override
  Future<List<RecognitionCandidate>> extract(
    Transcription transcription, {
    String? instructions,
    AiRequestOptions options = const AiRequestOptions(),
  }) async {
    try {
      final response = switch (profile.protocol) {
        AiProtocol.openAiChatCompletions => _extractChat(
            transcription,
            instructions: instructions,
            options: options,
          ),
        AiProtocol.jsonHttp => _extractJson(
            transcription,
            instructions: instructions,
            options: options,
          ),
        AiProtocol.openAiAudioTranscriptions ||
        AiProtocol.openAiChatCompletionsAudio =>
          throw AiRecognitionException(
            kind: AiRecognitionErrorKind.unsupportedProtocol,
            message:
                '${profile.protocol.name} is not a field extraction protocol',
            providerId: profile.id,
          ),
      };
      return await response;
    } on AiRecognitionException {
      rethrow;
    } on FormatException catch (error) {
      throw AiRecognitionException(
        kind: AiRecognitionErrorKind.invalidConfiguration,
        message: error.message,
        providerId: profile.id,
        cause: error,
      );
    } on ArgumentError catch (error) {
      throw AiRecognitionException(
        kind: AiRecognitionErrorKind.invalidConfiguration,
        message: error.message.toString(),
        providerId: profile.id,
        cause: error,
      );
    }
  }

  Future<List<RecognitionCandidate>> _extractChat(
    Transcription transcription, {
    required String? instructions,
    required AiRequestOptions options,
  }) async {
    final messages = <Object?>[];
    final configuredPrompt = _optionStringOrNull(profile, 'systemPrompt');
    final instructionText = _nonEmptyOrNull(instructions);
    final systemPrompt = [
      if (configuredPrompt != null) configuredPrompt,
      if (instructionText != null) instructionText,
    ].join('\n');
    if (systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': transcription.text});
    final body = <String, Object?>{
      ..._optionJsonObject(profile, 'body'),
      'model': profile.model,
      'messages': messages,
    };
    final response = await _sendJson(
      _transport,
      _openAiEndpoint(profile, const ['v1', 'chat', 'completions']),
      'POST',
      body,
      options,
    );
    return _parseCandidates(response, profile, transcription.text);
  }

  Future<List<RecognitionCandidate>> _extractJson(
    Transcription transcription, {
    required String? instructions,
    required AiRequestOptions options,
  }) async {
    final template = profile.requestOptions['requestTemplate'];
    if (template == null) {
      throw const FormatException('requestTemplate is required for jsonHttp');
    }
    final body = renderAiJsonTemplate(template, {
      'model': profile.model,
      'transcription': {
        'text': transcription.text,
        'language': transcription.language,
        'confidence': transcription.confidence,
      },
      'instructions': _nonEmptyOrNull(instructions),
    });
    final response = await _sendJson(
      _transport,
      _configuredEndpoint(profile),
      _optionString(profile, 'method', fallback: 'POST').toUpperCase(),
      body,
      options,
    );
    return _parseCandidates(response, profile, transcription.text);
  }

  @override
  void close() => _transport.close();
}

/// 一次调用把音频变成「转写 + 字段」。设计的模式 A 用它。
final class ProtocolAudioFieldExtractionProvider
    implements AudioFieldExtractionProvider {
  ProtocolAudioFieldExtractionProvider({
    required this.profile,
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 60),
  }) : _transport = AiHttpTransport(
          profile: profile,
          httpClient: httpClient,
          timeout: timeout,
        ) {
    if (profile.kind != AiProviderKind.audioFieldExtraction) {
      throw ArgumentError.value(
        profile.kind,
        'profile.kind',
        'must be audioFieldExtraction',
      );
    }
    if (!_supportedProtocols.contains(profile.protocol)) {
      throw AiRecognitionException(
        kind: AiRecognitionErrorKind.unsupportedProtocol,
        message:
            '${profile.protocol.name} cannot carry audio for field extraction',
        providerId: profile.id,
      );
    }
  }

  static const _supportedProtocols = {
    AiProtocol.openAiChatCompletionsAudio,
    AiProtocol.jsonHttp,
  };

  @override
  final AiProviderProfile profile;
  final AiHttpTransport _transport;

  @override
  AiProviderCapabilities get capabilities => profile.capabilities;

  @override
  Future<AiRecognitionResult> extractFieldsFromAudio(
    AudioSegment audio, {
    String? instructions,
    AiRequestOptions options = const AiRequestOptions(),
  }) async {
    _validateAudio(profile, audio);
    try {
      final response = switch (profile.protocol) {
        AiProtocol.openAiChatCompletionsAudio => _recordChatAudio(
            audio,
            instructions: instructions,
            options: options,
          ),
        AiProtocol.jsonHttp => _recordJson(
            audio,
            instructions: instructions,
            options: options,
          ),
        AiProtocol.openAiAudioTranscriptions ||
        AiProtocol.openAiChatCompletions =>
          throw AiRecognitionException(
            kind: AiRecognitionErrorKind.unsupportedProtocol,
            message:
                '${profile.protocol.name} cannot carry audio for field extraction',
            providerId: profile.id,
          ),
      };
      return await response;
    } on AiRecognitionException {
      rethrow;
    } on FormatException catch (error) {
      throw AiRecognitionException(
        kind: AiRecognitionErrorKind.invalidConfiguration,
        message: error.message,
        providerId: profile.id,
        cause: error,
      );
    } on ArgumentError catch (error) {
      throw AiRecognitionException(
        kind: AiRecognitionErrorKind.invalidConfiguration,
        message: error.message.toString(),
        providerId: profile.id,
        cause: error,
      );
    }
  }

  Future<AiRecognitionResult> _recordChatAudio(
    AudioSegment audio, {
    required String? instructions,
    required AiRequestOptions options,
  }) async {
    final configuredPrompt = _optionStringOrNull(profile, 'systemPrompt');
    final instructionText = _nonEmptyOrNull(instructions);
    final systemPrompt = [
      if (configuredPrompt != null) configuredPrompt,
      if (instructionText != null) instructionText,
    ].join('\n');
    final messages = <Object?>[];
    if (systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({
      'role': 'user',
      'content': buildChatAudioContent(profile, audio),
    });
    final response = await _sendJson(
      _transport,
      _openAiEndpoint(profile, const ['v1', 'chat', 'completions']),
      'POST',
      <String, Object?>{
        ..._optionJsonObject(profile, 'body'),
        'model': profile.model,
        'messages': messages,
      },
      options,
    );
    return _parseAudioFieldExtraction(response, profile);
  }

  Future<AiRecognitionResult> _recordJson(
    AudioSegment audio, {
    required String? instructions,
    required AiRequestOptions options,
  }) async {
    final template = profile.requestOptions['requestTemplate'];
    if (template == null) {
      throw const FormatException('requestTemplate is required for jsonHttp');
    }
    final body = renderAiJsonTemplate(template, {
      'model': profile.model,
      'audio': {
        'base64': base64Encode(audio.bytes),
        'dataUrl': 'data:${audio.mimeType};base64,${base64Encode(audio.bytes)}',
        'mimeType': audio.mimeType,
        'fileName': audio.fileName,
        'byteLength': audio.bytes.length,
      },
      'instructions': _nonEmptyOrNull(instructions),
    });
    final response = await _sendJson(
      _transport,
      _configuredEndpoint(profile),
      _optionString(profile, 'method', fallback: 'POST').toUpperCase(),
      body,
      options,
    );
    return _parseAudioFieldExtraction(response, profile);
  }

  @override
  void close() => _transport.close();
}

/// 校验音频是否满足 profile 声明的能力。
///
/// ASR 与音频字段抽取共用，保证能力声明的约束对两条链路一致。
void _validateAudio(AiProviderProfile profile, AudioSegment audio) {
  final capabilities = profile.capabilities;
  final maxBytes = capabilities.maxAudioBytes;
  if (maxBytes != null && audio.bytes.length > maxBytes) {
    throw AiRecognitionException(
      kind: AiRecognitionErrorKind.audioRejected,
      message: 'The audio segment exceeds the provider byte limit',
      providerId: profile.id,
    );
  }
  final mimeTypes = capabilities.supportedAudioMimeTypes;
  if (mimeTypes.isNotEmpty && !mimeTypes.contains(audio.mimeType)) {
    throw AiRecognitionException(
      kind: AiRecognitionErrorKind.audioRejected,
      message: 'The provider does not support ${audio.mimeType}',
      providerId: profile.id,
    );
  }
}

Future<http.Response> _sendJson(
  AiHttpTransport transport,
  Uri endpoint,
  String method,
  Object? body,
  AiRequestOptions options,
) =>
    transport.send(
      method: method,
      uri: endpoint,
      headers: const {
        'content-type': 'application/json; charset=utf-8',
        'accept': 'application/json',
      },
      bodyBytes: utf8.encode(jsonEncode(body)),
      options: options,
    );

Transcription _parseTranscription(
  http.Response response,
  AiProviderProfile profile,
) {
  final decoded = _decodeResponse(response, profile);
  final defaultPath = profile.protocol == AiProtocol.openAiChatCompletionsAudio
      ? 'choices[0].message.content'
      : 'text';
  final responsePath =
      _optionString(profile, 'responsePath', fallback: defaultPath);
  final Object? resolved;
  try {
    resolved = readAiJsonPath(decoded, responsePath);
  } on FormatException catch (error) {
    throw _invalidResponse(profile, 'The transcript path was not found', error);
  }
  final text = _responseText(resolved);
  if (text == null || text.trim().isEmpty) {
    throw _invalidResponse(profile, 'The provider returned no transcript');
  }

  String? language;
  if (_optionStringOrNull(profile, 'languageResponsePath') case final path?) {
    final value = _readResponsePath(decoded, path, profile);
    if (value != null && value is! String) {
      throw _invalidResponse(profile, 'The transcript language is invalid');
    }
    language = value as String?;
  }

  double? confidence;
  if (_optionStringOrNull(profile, 'confidenceResponsePath') case final path?) {
    final value = _readResponsePath(decoded, path, profile);
    if (value != null && value is! num) {
      throw _invalidResponse(profile, 'The transcript confidence is invalid');
    }
    confidence = (value as num?)?.toDouble();
  }

  try {
    return Transcription(
      text: text.trim(),
      language: language,
      confidence: confidence,
      metadata: {
        'providerId': profile.id,
        'protocol': profile.protocol.name,
        'model': profile.model,
      },
    );
  } on ArgumentError catch (error) {
    throw _invalidResponse(
        profile, 'The transcript metadata is invalid', error);
  }
}

List<RecognitionCandidate> _parseCandidates(
  http.Response response,
  AiProviderProfile profile,
  String sourceText,
) {
  final decoded = _decodeResponse(response, profile);
  final defaultPath = profile.protocol == AiProtocol.openAiChatCompletions
      ? 'choices[0].message.content'
      : r'$';
  final responsePath =
      _optionString(profile, 'responsePath', fallback: defaultPath);
  var resolved = _readResponsePath(decoded, responsePath, profile);
  if (resolved is String) {
    try {
      resolved = jsonDecode(resolved);
    } on FormatException catch (error) {
      throw _invalidResponse(
        profile,
        'The field extraction response is not JSON',
        error,
      );
    }
  }

  final values = resolved is List ? resolved : [resolved];
  if (values.isEmpty) {
    throw _invalidResponse(profile, 'The provider returned no candidates');
  }
  final candidates = <RecognitionCandidate>[];
  for (final value in values) {
    if (value is! Map) {
      throw _invalidResponse(profile, 'A candidate is not a JSON object');
    }
    if (value.isEmpty) continue;
    final fields = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw _invalidResponse(profile, 'A candidate has a non-string field');
      }
      fields[entry.key as String] = entry.value;
    }
    try {
      candidates.add(
        RecognitionCandidate(
          fields: fields,
          sourceText: sourceText,
          metadata: {
            'providerId': profile.id,
            'protocol': profile.protocol.name,
            'model': profile.model,
          },
        ),
      );
    } on ArgumentError catch (error) {
      throw _invalidResponse(profile, 'A candidate is invalid', error);
    }
  }
  return candidates;
}

/// 解析 `{"transcript": …, "fields": {…}, "uncertain": […]}`。
///
/// `fields` 为空或缺失时不产出候选——这是模型在说「这条没有可用信息」，
/// 与「解析失败」是两件事，后者抛 [AiRecognitionErrorKind.invalidResponse]。
/// `fields` 存在但不是对象属于契约破损，也抛 [AiRecognitionErrorKind.invalidResponse]，
/// 绝不静默降级成「空记录」。
AiRecognitionResult _parseAudioFieldExtraction(
  http.Response response,
  AiProviderProfile profile,
) {
  final decoded = _decodeResponse(response, profile);
  final defaultPath = profile.protocol == AiProtocol.openAiChatCompletionsAudio
      ? 'choices[0].message.content'
      : r'$';
  final responsePath =
      _optionString(profile, 'responsePath', fallback: defaultPath);
  var resolved = _readResponsePath(decoded, responsePath, profile);
  if (resolved is String) {
    try {
      resolved = jsonDecode(resolved);
    } on FormatException catch (error) {
      throw _invalidResponse(
        profile,
        'The audio field extraction response is not JSON',
        error,
      );
    }
  }
  if (resolved is! Map) {
    throw _invalidResponse(
      profile,
      'The audio field extraction response is not an object',
    );
  }

  final transcript = resolved['transcript'];
  if (transcript is! String || transcript.trim().isEmpty) {
    throw _invalidResponse(profile, 'The provider returned no transcript');
  }

  final rawFields = resolved['fields'];
  if (rawFields != null && rawFields is! Map) {
    throw _invalidResponse(profile, 'The fields member is not an object');
  }
  final fields = <String, Object?>{};
  if (rawFields is Map) {
    for (final entry in rawFields.entries) {
      if (entry.key is! String) {
        throw _invalidResponse(profile, 'A field has a non-string key');
      }
      final value = entry.value;
      if (value is! String || value.trim().isEmpty) continue;
      fields[entry.key as String] = value.trim();
    }
  }

  final uncertain = <String>[];
  final rawUncertain = resolved['uncertain'];
  if (rawUncertain is List) {
    for (final value in rawUncertain) {
      if (value is String && value.trim().isNotEmpty) {
        uncertain.add(value.trim());
      }
    }
  }

  final transcription = Transcription(
    text: transcript.trim(),
    metadata: {
      'providerId': profile.id,
      'protocol': profile.protocol.name,
      'model': profile.model,
    },
  );

  return AiRecognitionResult(
    transcription: transcription,
    candidates: fields.isEmpty
        ? const []
        : [
            RecognitionCandidate(
              fields: fields,
              sourceText: transcription.text,
              metadata: {
                'providerId': profile.id,
                'protocol': profile.protocol.name,
                'model': profile.model,
                if (uncertain.isNotEmpty) 'uncertain': uncertain,
              },
            ),
          ],
  );
}

Object? _decodeResponse(http.Response response, AiProviderProfile profile) {
  try {
    return jsonDecode(utf8.decode(response.bodyBytes));
  } on FormatException catch (error) {
    throw _invalidResponse(
        profile, 'The provider returned malformed JSON', error);
  }
}

Object? _readResponsePath(
  Object? decoded,
  String path,
  AiProviderProfile profile,
) {
  try {
    return readAiJsonPath(decoded, path);
  } on FormatException catch (error) {
    throw _invalidResponse(
        profile, 'The configured response path was not found', error);
  }
}

String? _responseText(Object? value) {
  if (value is String) return value;
  if (value is Map && value['text'] is String) return value['text'] as String;
  if (value is List) {
    final parts = <String>[];
    for (final part in value) {
      if (part is String) {
        parts.add(part);
      } else if (part is Map && part['text'] is String) {
        parts.add(part['text'] as String);
      }
    }
    if (parts.isNotEmpty) return parts.join();
  }
  return null;
}

AiRecognitionException _invalidResponse(
  AiProviderProfile profile,
  String message, [
  Object? cause,
]) =>
    AiRecognitionException(
      kind: AiRecognitionErrorKind.invalidResponse,
      message: message,
      providerId: profile.id,
      cause: cause,
    );

Uri _openAiEndpoint(AiProviderProfile profile, List<String> endpointSegments) {
  if (_optionStringOrNull(profile, 'path') case final path?) {
    return _resolvePath(profile.baseUrl, path);
  }
  final baseSegments = profile.baseUrl.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  final suffix = baseSegments.isNotEmpty &&
          baseSegments.last.toLowerCase() == 'v1' &&
          endpointSegments.first == 'v1'
      ? endpointSegments.skip(1)
      : endpointSegments;
  return profile.baseUrl.replace(pathSegments: [...baseSegments, ...suffix]);
}

Uri _configuredEndpoint(AiProviderProfile profile) {
  final path = _optionStringOrNull(profile, 'path');
  return path == null ? profile.baseUrl : _resolvePath(profile.baseUrl, path);
}

Uri _resolvePath(Uri baseUrl, String path) {
  final parsed = Uri.tryParse(path);
  if (parsed == null) throw const FormatException('path is not a valid URI');
  if (parsed.hasScheme || parsed.hasAuthority || path.startsWith('//')) {
    throw const FormatException('path must not change the provider origin');
  }
  _rejectCredentialQuery(parsed);
  final queryParameters = <String, String>{
    ...baseUrl.queryParameters,
    ...parsed.queryParameters,
  };
  if (path.startsWith('/')) {
    return baseUrl.replace(
      path: parsed.path,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }
  final base = baseUrl.path.endsWith('/')
      ? baseUrl
      : baseUrl.replace(path: '${baseUrl.path}/');
  final resolved = base.resolveUri(parsed);
  return resolved.replace(
    queryParameters: queryParameters.isEmpty ? null : queryParameters,
  );
}

void _rejectCredentialQuery(Uri uri) {
  const sensitiveNames = {
    'key',
    'token',
    'signature',
    'sig',
    'apikey',
    'accesskey',
    'accesstoken',
    'subscriptionkey',
  };
  for (final name in uri.queryParameters.keys) {
    final normalized = name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    if (sensitiveNames.contains(normalized) ||
        normalized.endsWith('apikey') ||
        normalized.endsWith('accesstoken')) {
      throw const FormatException(
        'path credentials must use AiCredentialTransport',
      );
    }
  }
}

String _optionString(
  AiProviderProfile profile,
  String key, {
  required String fallback,
}) {
  final value = profile.requestOptions[key];
  if (value == null) return fallback;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value.trim();
}

String? _optionStringOrNull(AiProviderProfile profile, String key) {
  final value = profile.requestOptions[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a string');
  return _nonEmptyOrNull(value);
}

bool _optionBool(
  AiProviderProfile profile,
  String key, {
  required bool fallback,
}) {
  final value = profile.requestOptions[key];
  if (value == null) return fallback;
  if (value is! bool) throw FormatException('$key must be a boolean');
  return value;
}

AiJsonObject _optionJsonObject(AiProviderProfile profile, String key) {
  final value = profile.requestOptions[key];
  if (value == null) return const {};
  if (value is! Map) throw FormatException('$key must be a JSON object');
  return <String, Object?>{
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

String? _nonEmptyOrNull(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _audioFormat(AudioSegment audio) {
  final extensionIndex = audio.fileName.lastIndexOf('.');
  if (extensionIndex >= 0 && extensionIndex < audio.fileName.length - 1) {
    return audio.fileName.substring(extensionIndex + 1).toLowerCase();
  }
  return switch (audio.mimeType.toLowerCase()) {
    'audio/mpeg' => 'mp3',
    'audio/x-wav' => 'wav',
    final mime => mime.split('/').last,
  };
}

int _multipartSequence = 0;

_MultipartBody _encodeMultipart({
  required Map<String, String> fields,
  required String fileField,
  required AudioSegment audio,
}) {
  final boundary = '----openlogtool-${DateTime.now().microsecondsSinceEpoch}-'
      '${_multipartSequence++}';
  final bytes = BytesBuilder(copy: false);
  void addText(String value) => bytes.add(utf8.encode(value));

  for (final entry in fields.entries) {
    addText('--$boundary\r\n');
    addText(
      'Content-Disposition: form-data; name="${_disposition(entry.key)}"\r\n\r\n',
    );
    addText('${entry.value}\r\n');
  }
  addText('--$boundary\r\n');
  addText(
    'Content-Disposition: form-data; name="${_disposition(fileField)}"; '
    'filename="${_disposition(audio.fileName)}"\r\n',
  );
  addText('Content-Type: ${audio.mimeType}\r\n\r\n');
  bytes.add(audio.bytes);
  addText('\r\n--$boundary--\r\n');
  return _MultipartBody(boundary, bytes.takeBytes());
}

String _disposition(String value) => value.replaceAll(RegExp(r'[\r\n"]'), '_');

final class _MultipartBody {
  const _MultipartBody(this.boundary, this.bytes);

  final String boundary;
  final Uint8List bytes;
}

/// 构造 Chat Completions 的音频消息内容块。
///
/// ASR 与音频字段抽取共享此构造，避免两份实现漂移。
List<Object?> buildChatAudioContent(
  AiProviderProfile profile,
  AudioSegment audio, {
  String? prompt,
}) {
  final content = <Object?>[];
  if (_optionBool(profile, 'includePrompt', fallback: true)) {
    if (_nonEmptyOrNull(prompt) case final promptText?) {
      content.add({'type': 'text', 'text': promptText});
    }
  }
  final base64Audio = base64Encode(audio.bytes);
  final audioDataEncoding = _optionString(
    profile,
    'audioDataEncoding',
    fallback: 'base64',
  );
  if (audioDataEncoding != 'base64' && audioDataEncoding != 'dataUrl') {
    throw const FormatException(
      'audioDataEncoding must be base64 or dataUrl',
    );
  }
  content.add({
    'type': 'input_audio',
    'input_audio': {
      'data': audioDataEncoding == 'dataUrl'
          ? 'data:${audio.mimeType};base64,$base64Audio'
          : base64Audio,
      if (_optionBool(profile, 'includeAudioFormat', fallback: true))
        'format': _optionString(
          profile,
          'audioFormat',
          fallback: _audioFormat(audio),
        ),
    },
  });
  return content;
}
