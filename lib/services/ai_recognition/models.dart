import 'dart:convert';

typedef AiJsonObject = Map<String, Object?>;

enum AiProviderKind {
  speechRecognition,
  fieldExtraction,

  /// 音频直接产出字段：一次调用同时返回转写与字段。设计的模式 A 用它。
  audioFieldExtraction;

  static AiProviderKind fromJson(Object? value) => _enumFromJson(
        values,
        value,
        'kind',
      );
}

enum AiProtocol {
  openAiAudioTranscriptions,
  openAiChatCompletionsAudio,
  openAiChatCompletions,
  jsonHttp;

  bool supports(AiProviderKind kind) => switch (kind) {
        AiProviderKind.speechRecognition => this == openAiAudioTranscriptions ||
            this == openAiChatCompletionsAudio ||
            this == jsonHttp,
        AiProviderKind.fieldExtraction =>
          this == openAiChatCompletions || this == jsonHttp,
        // 音频必须在请求体里，因此只有能携带 input_audio 的协议可用。
        // jsonHttp 靠 requestTemplate 自行携带。
        AiProviderKind.audioFieldExtraction =>
          this == openAiChatCompletionsAudio || this == jsonHttp,
      };

  static AiProtocol fromJson(Object? value) => _enumFromJson(
        values,
        value,
        'protocol',
      );
}

/// Declares behavior callers can rely on without knowing a concrete model.
final class AiProviderCapabilities {
  const AiProviderCapabilities({
    this.supportsAudioTranscription = false,
    this.supportsFieldExtraction = false,
    this.supportsAudioFieldExtraction = false,
    this.supportsStreaming = false,
    this.supportsLanguageHint = false,
    this.supportsPrompt = false,
    this.supportedAudioMimeTypes = const {},
    this.maxAudioBytes,
  }) : assert(maxAudioBytes == null || maxAudioBytes > 0);

  factory AiProviderCapabilities.fromJson(Object? value) {
    final json = _jsonObject(value, 'capabilities');
    final maxAudioBytes = _nullableInt(json['maxAudioBytes'], 'maxAudioBytes');
    if (maxAudioBytes != null && maxAudioBytes <= 0) {
      throw const FormatException('maxAudioBytes must be positive');
    }
    return AiProviderCapabilities(
      supportsAudioTranscription: _bool(
        json['supportsAudioTranscription'],
        'supportsAudioTranscription',
        fallback: false,
      ),
      supportsFieldExtraction: _bool(
        json['supportsFieldExtraction'],
        'supportsFieldExtraction',
        fallback: false,
      ),
      supportsAudioFieldExtraction: _bool(
        json['supportsAudioFieldExtraction'],
        'supportsAudioFieldExtraction',
        fallback: false,
      ),
      supportsStreaming: _bool(
        json['supportsStreaming'],
        'supportsStreaming',
        fallback: false,
      ),
      supportsLanguageHint: _bool(
        json['supportsLanguageHint'],
        'supportsLanguageHint',
        fallback: false,
      ),
      supportsPrompt: _bool(
        json['supportsPrompt'],
        'supportsPrompt',
        fallback: false,
      ),
      supportedAudioMimeTypes: _stringSet(
        json['supportedAudioMimeTypes'],
        'supportedAudioMimeTypes',
      ),
      maxAudioBytes: maxAudioBytes,
    );
  }

  final bool supportsAudioTranscription;
  final bool supportsFieldExtraction;

  /// 一次调用直接从音频产出结构化字段，区别于
  /// [supportsAudioTranscription] + [supportsFieldExtraction] 的两跳组合。
  ///
  /// 仅作能力声明，不参与 provider 选择：判断档案是否用于该用途一律以
  /// [AiProviderKind.audioFieldExtraction] 为准，避免标志与 kind 变成两个
  /// 必须同时设置的开关。
  final bool supportsAudioFieldExtraction;
  final bool supportsStreaming;
  final bool supportsLanguageHint;
  final bool supportsPrompt;
  final Set<String> supportedAudioMimeTypes;
  final int? maxAudioBytes;

  AiJsonObject toJson() => {
        'supportsAudioTranscription': supportsAudioTranscription,
        'supportsFieldExtraction': supportsFieldExtraction,
        'supportsAudioFieldExtraction': supportsAudioFieldExtraction,
        'supportsStreaming': supportsStreaming,
        'supportsLanguageHint': supportsLanguageHint,
        'supportsPrompt': supportsPrompt,
        'supportedAudioMimeTypes': supportedAudioMimeTypes.toList()..sort(),
        if (maxAudioBytes != null) 'maxAudioBytes': maxAudioBytes,
      };
}

enum AiCredentialLocation {
  none,
  bearerHeader,
  header,
  queryParameter;

  static AiCredentialLocation fromJson(Object? value) => _enumFromJson(
        values,
        value,
        'credential location',
      );
}

/// Describes where a runtime credential is sent, never the credential itself.
final class AiCredentialTransport {
  const AiCredentialTransport.none()
      : location = AiCredentialLocation.none,
        name = '',
        prefix = '',
        isRequired = false;

  const AiCredentialTransport.bearer({this.isRequired = true})
      : location = AiCredentialLocation.bearerHeader,
        name = 'Authorization',
        prefix = 'Bearer ';

  factory AiCredentialTransport.header({
    required String name,
    String prefix = '',
    bool isRequired = true,
  }) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    return AiCredentialTransport._(
      location: AiCredentialLocation.header,
      name: normalizedName,
      prefix: prefix,
      isRequired: isRequired,
    );
  }

  factory AiCredentialTransport.queryParameter({
    required String name,
    String prefix = '',
    bool isRequired = true,
  }) {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    return AiCredentialTransport._(
      location: AiCredentialLocation.queryParameter,
      name: normalizedName,
      prefix: prefix,
      isRequired: isRequired,
    );
  }

  const AiCredentialTransport._({
    required this.location,
    required this.name,
    required this.prefix,
    required this.isRequired,
  });

  factory AiCredentialTransport.fromJson(Object? value) {
    final json = _jsonObject(value, 'credentialTransport');
    final location = AiCredentialLocation.fromJson(json['location']);
    final isRequired = _bool(
      json['isRequired'],
      'isRequired',
      fallback: location != AiCredentialLocation.none,
    );
    final prefix = _nullableString(json['prefix'], 'prefix') ?? '';
    final name = _nullableString(json['name'], 'name') ?? '';

    return switch (location) {
      AiCredentialLocation.none => const AiCredentialTransport.none(),
      AiCredentialLocation.bearerHeader => AiCredentialTransport._(
          location: location,
          name: 'Authorization',
          prefix: prefix.isEmpty ? 'Bearer ' : prefix,
          isRequired: isRequired,
        ),
      AiCredentialLocation.header => AiCredentialTransport.header(
          name: name,
          prefix: prefix,
          isRequired: isRequired,
        ),
      AiCredentialLocation.queryParameter =>
        AiCredentialTransport.queryParameter(
          name: name,
          prefix: prefix,
          isRequired: isRequired,
        ),
    };
  }

  final AiCredentialLocation location;
  final String name;
  final String prefix;
  final bool isRequired;

  AiJsonObject toJson() => {
        'location': location.name,
        if (name.isNotEmpty) 'name': name,
        if (prefix.isNotEmpty) 'prefix': prefix,
        'isRequired': isRequired,
      };
}

/// Serializable provider configuration.
///
/// Authentication credentials belong in [credentialId] and are supplied to
/// each operation with `AiRequestOptions`. Custom headers and request options
/// are portable provider metadata and are emitted by [toJson], so credential-
/// shaped keys are rejected during validation.
final class AiProviderProfile {
  AiProviderProfile({
    required String id,
    required String name,
    required this.kind,
    required this.protocol,
    required this.baseUrl,
    required String model,
    Map<String, String> headers = const {},
    AiJsonObject requestOptions = const {},
    this.capabilities = const AiProviderCapabilities(),
    String? credentialId,
    this.credentialTransport = const AiCredentialTransport.bearer(),
  })  : id = _nonEmpty(id, 'id'),
        name = _nonEmpty(name, 'name'),
        model = _nonEmpty(model, 'model'),
        headers = Map.unmodifiable(_validatedHeaders(headers)),
        requestOptions = Map.unmodifiable(
          _validatedJsonObject(requestOptions, 'requestOptions'),
        ),
        credentialId = _trimToNull(credentialId) {
    if (!baseUrl.hasScheme ||
        (baseUrl.scheme != 'http' && baseUrl.scheme != 'https') ||
        baseUrl.host.isEmpty) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'must be an absolute HTTP(S) URL',
      );
    }
    if (baseUrl.userInfo.isNotEmpty || baseUrl.fragment.isNotEmpty) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'must not contain user credentials or a fragment',
      );
    }
    for (final name in baseUrl.queryParameters.keys) {
      if (_isSecretConfigKey(name)) {
        throw ArgumentError.value(
          baseUrl,
          'baseUrl',
          'credentials must use AiCredentialTransport',
        );
      }
    }
    if (!protocol.supports(kind)) {
      throw ArgumentError.value(
        protocol,
        'protocol',
        'does not support ${kind.name}',
      );
    }
  }

  factory AiProviderProfile.fromJson(Object? value) {
    final json = _jsonObject(value, 'provider profile');
    final baseUrlText = _requiredString(json['baseUrl'], 'baseUrl');
    final baseUrl = Uri.tryParse(baseUrlText);
    if (baseUrl == null) {
      throw const FormatException('baseUrl must be a valid URL');
    }

    final headersValue = json['headers'];
    final headers = <String, String>{};
    if (headersValue != null) {
      final headerJson = _jsonObject(headersValue, 'headers');
      for (final entry in headerJson.entries) {
        if (entry.value is! String) {
          throw FormatException('header ${entry.key} must be a string');
        }
        headers[entry.key] = entry.value! as String;
      }
    }

    return AiProviderProfile(
      id: _requiredString(json['id'], 'id'),
      name: _requiredString(json['name'], 'name'),
      kind: AiProviderKind.fromJson(json['kind']),
      protocol: AiProtocol.fromJson(json['protocol']),
      baseUrl: baseUrl,
      model: _requiredString(json['model'], 'model'),
      headers: headers,
      requestOptions: json['requestOptions'] == null
          ? const {}
          : _jsonObject(json['requestOptions'], 'requestOptions'),
      capabilities: json['capabilities'] == null
          ? const AiProviderCapabilities()
          : AiProviderCapabilities.fromJson(json['capabilities']),
      credentialId: _nullableString(json['credentialId'], 'credentialId'),
      credentialTransport: json['credentialTransport'] == null
          ? const AiCredentialTransport.bearer()
          : AiCredentialTransport.fromJson(json['credentialTransport']),
    );
  }

  final String id;
  final String name;
  final AiProviderKind kind;
  final AiProtocol protocol;
  final Uri baseUrl;
  final String model;
  final Map<String, String> headers;
  final AiJsonObject requestOptions;
  final AiProviderCapabilities capabilities;
  final String? credentialId;
  final AiCredentialTransport credentialTransport;

  AiJsonObject toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'protocol': protocol.name,
        'baseUrl': baseUrl.toString(),
        'model': model,
        'headers': Map<String, String>.from(headers),
        'requestOptions': _copyJsonObject(requestOptions),
        'capabilities': capabilities.toJson(),
        if (credentialId != null) 'credentialId': credentialId,
        'credentialTransport': credentialTransport.toJson(),
      };
}

final class AudioSegment {
  AudioSegment({
    required List<int> bytes,
    required String mimeType,
    required String fileName,
    this.duration,
    this.sampleRateHz,
    this.channelCount,
    AiJsonObject metadata = const {},
  })  : bytes = List.unmodifiable(bytes),
        mimeType = _nonEmpty(mimeType, 'mimeType'),
        fileName = _nonEmpty(fileName, 'fileName'),
        metadata = Map.unmodifiable(_copyJsonObject(metadata)) {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'must not be empty');
    }
    if (!this.mimeType.contains('/')) {
      throw ArgumentError.value(
        mimeType,
        'mimeType',
        'must be a MIME type',
      );
    }
    if (duration != null && duration! < Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'must not be negative');
    }
    if (sampleRateHz != null && sampleRateHz! <= 0) {
      throw ArgumentError.value(
        sampleRateHz,
        'sampleRateHz',
        'must be positive',
      );
    }
    if (channelCount != null && channelCount! <= 0) {
      throw ArgumentError.value(
        channelCount,
        'channelCount',
        'must be positive',
      );
    }
  }

  final List<int> bytes;
  final String mimeType;
  final String fileName;
  final Duration? duration;
  final int? sampleRateHz;
  final int? channelCount;
  final AiJsonObject metadata;
}

final class Transcription {
  Transcription({
    required String text,
    this.isFinal = true,
    String? language,
    this.confidence,
    AiJsonObject metadata = const {},
  })  : text = _nonEmpty(text, 'text'),
        language = _trimToNull(language),
        metadata = Map.unmodifiable(_copyJsonObject(metadata)) {
    if (confidence != null && (confidence! < 0 || confidence! > 1)) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'must be between 0 and 1',
      );
    }
  }

  final String text;
  final bool isFinal;
  final String? language;
  final double? confidence;
  final AiJsonObject metadata;
}

final class RecognitionCandidate {
  RecognitionCandidate({
    required AiJsonObject fields,
    this.confidence,
    String? sourceText,
    List<String> warnings = const [],
    AiJsonObject metadata = const {},
  })  : fields = Map.unmodifiable(_copyJsonObject(fields)),
        sourceText = _trimToNull(sourceText),
        warnings = List.unmodifiable(warnings),
        metadata = Map.unmodifiable(_copyJsonObject(metadata)) {
    if (fields.isEmpty) {
      throw ArgumentError.value(fields, 'fields', 'must not be empty');
    }
    if (confidence != null && (confidence! < 0 || confidence! > 1)) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'must be between 0 and 1',
      );
    }
  }

  final AiJsonObject fields;
  final double? confidence;
  final String? sourceText;
  final List<String> warnings;
  final AiJsonObject metadata;
}

T _enumFromJson<T extends Enum>(
  List<T> values,
  Object? value,
  String field,
) {
  if (value is! String) {
    throw FormatException('$field must be a string');
  }
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  throw FormatException('Unsupported $field: $value');
}

String _nonEmpty(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'must not be empty');
  }
  return normalized;
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string');
  }
  return value.trim();
}

String? _nullableString(Object? value, String field) {
  if (value == null) return null;
  if (value is! String) throw FormatException('$field must be a string');
  return value;
}

String? _trimToNull(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

bool _bool(Object? value, String field, {required bool fallback}) {
  if (value == null) return fallback;
  if (value is! bool) throw FormatException('$field must be a boolean');
  return value;
}

int? _nullableInt(Object? value, String field) {
  if (value == null) return null;
  if (value is! int) throw FormatException('$field must be an integer');
  return value;
}

Set<String> _stringSet(Object? value, String field) {
  if (value == null) return const {};
  if (value is! List) throw FormatException('$field must be a list');
  final result = <String>{};
  for (final item in value) {
    if (item is! String || item.trim().isEmpty) {
      throw FormatException('$field entries must be non-empty strings');
    }
    result.add(item.trim());
  }
  return Set.unmodifiable(result);
}

AiJsonObject _jsonObject(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be a JSON object');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$field keys must be strings');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

Map<String, String> _validatedHeaders(Map<String, String> value) {
  final result = <String, String>{};
  for (final entry in value.entries) {
    final name = entry.key.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(entry.key, 'headers', 'name must not be empty');
    }
    if (_isSecretConfigKey(name)) {
      throw ArgumentError.value(
        entry.key,
        'headers',
        'credential headers must use AiCredentialTransport',
      );
    }
    result[name] = entry.value;
  }
  return result;
}

AiJsonObject _validatedJsonObject(AiJsonObject value, String field) {
  _validateJsonValue(value, field);
  return _immutableJsonObject(value);
}

void _validateJsonValue(Object? value, String path) {
  if (value == null || value is String || value is num || value is bool) return;
  if (value is List) {
    for (var index = 0; index < value.length; index += 1) {
      _validateJsonValue(value[index], '$path[$index]');
    }
    return;
  }
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw ArgumentError.value(value, path, 'JSON keys must be strings');
      }
      final key = entry.key as String;
      if (_isSecretConfigKey(key)) {
        throw ArgumentError.value(
          key,
          path,
          'credential values must not be stored in provider configuration',
        );
      }
      _validateJsonValue(entry.value, '$path.$key');
    }
    return;
  }
  throw ArgumentError.value(value, path, 'must contain only JSON values');
}

const _secretConfigKeys = {
  'authorization',
  'proxyauthorization',
  'auth',
  'authentication',
  'authtoken',
  'bearertoken',
  'apikey',
  'accesskey',
  'accesstoken',
  'refreshtoken',
  'password',
  'secret',
  'clientsecret',
  'privatekey',
  'credential',
  'credentials',
  'key',
  'token',
  'signature',
  'sig',
};

String _normalizeConfigKey(String value) =>
    value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

bool _isSecretConfigKey(String value) {
  final normalized = _normalizeConfigKey(value);
  return _secretConfigKeys.contains(normalized) ||
      normalized.endsWith('authorization') ||
      normalized.endsWith('authtoken') ||
      normalized.endsWith('bearertoken') ||
      normalized.endsWith('apikey') ||
      normalized.endsWith('accesskey') ||
      normalized.endsWith('accesstoken') ||
      normalized.endsWith('refreshtoken') ||
      normalized.endsWith('clientsecret') ||
      normalized.endsWith('privatekey') ||
      normalized.endsWith('subscriptionkey');
}

AiJsonObject _copyJsonObject(Map<String, Object?> value) {
  final copied = _copyJsonValue(value);
  return copied! as AiJsonObject;
}

AiJsonObject _immutableJsonObject(Map<String, Object?> value) =>
    _immutableJsonValue(value)! as AiJsonObject;

Object? _immutableJsonValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_immutableJsonValue));
  }
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _immutableJsonValue(entry.value),
    });
  }
  throw ArgumentError.value(value, 'value', 'must contain only JSON values');
}

Object? _copyJsonValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is List) {
    return value.map(_copyJsonValue).toList(growable: false);
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw ArgumentError.value(value, 'value', 'JSON keys must be strings');
      }
      result[entry.key as String] = _copyJsonValue(entry.value);
    }
    return result;
  }
  // This should only be reachable for metadata, which has the same JSON-only
  // contract as persisted configuration.
  jsonEncode(value);
  throw ArgumentError.value(value, 'value', 'must contain only JSON values');
}

/// 一次调用的完整产出：原始转写与从中提取的字段。
///
/// 从 pipeline.dart 迁来，使 provider 能在不依赖 pipeline 的情况下返回它。
final class AiRecognitionResult {
  const AiRecognitionResult({
    required this.transcription,
    required this.candidates,
  });

  final Transcription transcription;
  final List<RecognitionCandidate> candidates;
}
