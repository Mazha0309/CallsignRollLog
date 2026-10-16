import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:openlogtool/services/ai_credential_store.dart';
import 'package:openlogtool/services/ai_recognition/models.dart';
import 'package:openlogtool/services/ai_recognition/providers.dart';
import 'package:openlogtool/services/text_assistant.dart';
import 'package:openlogtool/services/key_value_store.dart';

/// On-device AI configuration. Provider profiles are ordinary exportable JSON;
/// credentials are referenced by ID and live only in [AiCredentialStore].
final class AiRecognitionSettingsProvider with ChangeNotifier {
  AiRecognitionSettingsProvider({
    Future<KeyValueStore> Function()? preferencesLoader,
    AiCredentialStore? credentialStore,
  })  : _preferencesLoader = preferencesLoader ?? openKeyValueStore,
        _credentialStore = credentialStore ?? AiCredentialStore() {
    unawaited(_load());
  }

  static const int schemaVersion = 1;
  static const String _storageKey = 'openlogtool.ai.settings.v1';

  final Future<KeyValueStore> Function() _preferencesLoader;
  final AiCredentialStore _credentialStore;
  final Completer<void> _initialized = Completer<void>();
  Future<void> _mutationTail = Future<void>.value();
  Future<void> _saveTail = Future<void>.value();

  List<AiProviderProfile> _profiles = const [];
  String? _activeAsrProfileId;
  String? _activeFieldExtractionProfileId;
  String? _activeAudioFieldExtractionProfileId;
  bool _enabled = false;
  bool _useLocalReferenceContext = true;
  TextAssistantConfig? _textAssistantConfig;
  bool _textAssistantEnabled = false;
  bool _inlineTextSuggestionsEnabled = true;
  Object? _loadError;
  bool _disposed = false;

  Future<void> get initialized => _initialized.future;
  bool get enabled => _enabled;
  bool get useLocalReferenceContext => _useLocalReferenceContext;
  TextAssistantConfig? get textAssistantConfig => _textAssistantConfig;
  bool get textAssistantEnabled => _textAssistantEnabled;
  bool get inlineTextSuggestionsEnabled => _inlineTextSuggestionsEnabled;
  Object? get loadError => _loadError;
  List<AiProviderProfile> get profiles => _profiles;
  Iterable<AiProviderProfile> get asrProfiles => _profiles.where(
        (profile) => profile.kind == AiProviderKind.speechRecognition,
      );
  Iterable<AiProviderProfile> get fieldExtractionProfiles => _profiles.where(
        (profile) => profile.kind == AiProviderKind.fieldExtraction,
      );
  Iterable<AiProviderProfile> get audioFieldExtractionProfiles =>
      _profiles.where(
        (profile) => profile.kind == AiProviderKind.audioFieldExtraction,
      );
  String? get activeAsrProfileId => _activeAsrProfileId;
  String? get activeFieldExtractionProfileId => _activeFieldExtractionProfileId;
  String? get activeAudioFieldExtractionProfileId =>
      _activeAudioFieldExtractionProfileId;
  AiProviderProfile? get activeAsrProfile => _profileById(_activeAsrProfileId);
  AiProviderProfile? get activeFieldExtractionProfile =>
      _profileById(_activeFieldExtractionProfileId);

  /// 当前用于模式 A 的多模态档案；未配置时返回 null。
  ///
  /// 只按 [AiProviderKind.audioFieldExtraction] 判定：`kind` 是这一用途的唯一
  /// 权威来源。`capabilities.supportsAudioFieldExtraction` 只是给界面看的声明，
  /// 不参与选择——否则会出现「档案配好了却选不中」这种难查的问题。
  AiProviderProfile? get activeAudioFieldExtractionProfile => _profileById(
        _activeAudioFieldExtractionProfileId,
        AiProviderKind.audioFieldExtraction,
      );

  AiCredentialResolver get credentialResolver => resolveCredentials;

  Future<void> _load() async {
    try {
      final preferences = await _preferencesLoader();
      if (_disposed) return;
      final encoded = await preferences.getString(_storageKey);
      if (encoded != null) _restore(jsonDecode(encoded));
    } catch (error) {
      _loadError = error;
      _profiles = const [];
      _activeAsrProfileId = null;
      _activeFieldExtractionProfileId = null;
      _activeAudioFieldExtractionProfileId = null;
      _enabled = false;
      _useLocalReferenceContext = true;
      _textAssistantConfig = null;
      _textAssistantEnabled = false;
      _inlineTextSuggestionsEnabled = true;
    } finally {
      if (!_initialized.isCompleted) _initialized.complete();
      if (!_disposed) notifyListeners();
    }
  }

  void _restore(Object? value) {
    if (value is! Map) {
      throw const FormatException('AI settings must be a JSON object');
    }
    final json = Map<String, Object?>.from(value);
    if (json['schemaVersion'] != schemaVersion) {
      throw FormatException(
        'Unsupported AI settings schema: ${json['schemaVersion']}',
      );
    }
    final rawProfiles = json['profiles'];
    if (rawProfiles is! List) {
      throw const FormatException('AI settings profiles must be a list');
    }
    final restored =
        rawProfiles.map(AiProviderProfile.fromJson).toList(growable: false);
    _ensureUniqueIds(restored);
    _profiles = List.unmodifiable(restored);
    _activeAsrProfileId = _validActiveId(
      json['activeAsrProfileId'],
      AiProviderKind.speechRecognition,
    );
    _activeFieldExtractionProfileId = _validActiveId(
      json['activeFieldExtractionProfileId'],
      AiProviderKind.fieldExtraction,
    );
    _activeAudioFieldExtractionProfileId = _validActiveId(
      json['activeAudioFieldExtractionProfileId'],
      AiProviderKind.audioFieldExtraction,
    );
    _enabled = json['enabled'] == true &&
        (_activeAsrProfileId != null ||
            _activeAudioFieldExtractionProfileId != null);
    _useLocalReferenceContext = json['useLocalReferenceContext'] != false;
    final textAssistant = json['textAssistant'];
    if (textAssistant != null) {
      _textAssistantConfig = TextAssistantConfig.fromJson(textAssistant);
    } else {
      _textAssistantConfig = _migrateTextAssistantProfile();
    }
    _textAssistantEnabled = _textAssistantConfig != null &&
        (json['textAssistantEnabled'] == true ||
            (textAssistant == null && _activeFieldExtractionProfileId != null));
    _inlineTextSuggestionsEnabled =
        json['inlineTextSuggestionsEnabled'] != false;
  }

  Future<void> setEnabled(bool value) => _mutate(() async {
        await initialized;
        if (value &&
            activeAsrProfile == null &&
            activeAudioFieldExtractionProfile == null) {
          throw StateError('AI_ASR_PROFILE_REQUIRED');
        }
        if (_enabled == value) return;
        _enabled = value;
        notifyListeners();
        await _persist();
      });

  Future<void> setUseLocalReferenceContext(bool value) => _mutate(() async {
        await initialized;
        if (_useLocalReferenceContext == value) return;
        _useLocalReferenceContext = value;
        notifyListeners();
        await _persist();
      });

  Future<void> saveTextAssistant({
    required TextAssistantProvider provider,
    required Uri baseUrl,
    required String model,
    String? secret,
  }) =>
      _mutate(() async {
        await initialized;
        final previous = _textAssistantConfig;
        final sameCredentialDestination = previous != null &&
            previous.provider == provider &&
            previous.baseUrl.origin == baseUrl.origin;
        final credentialId = sameCredentialDestination
            ? previous.credentialId
            : 'text-assistant-${DateTime.now().microsecondsSinceEpoch}';
        final next = TextAssistantConfig(
          provider: provider,
          baseUrl: baseUrl,
          model: model,
          credentialId: credentialId,
        );
        final normalizedSecret = secret?.trim();
        if (!sameCredentialDestination &&
            (normalizedSecret == null || normalizedSecret.isEmpty)) {
          throw StateError('TEXT_ASSISTANT_API_KEY_REQUIRED');
        }
        if (normalizedSecret != null && normalizedSecret.isNotEmpty) {
          await _credentialStore.write(credentialId, normalizedSecret);
        }
        _textAssistantConfig = next;
        _textAssistantEnabled = true;
        if (previous == null) _inlineTextSuggestionsEnabled = true;
        notifyListeners();
        await _persist();
        if (previous != null && previous.credentialId != credentialId) {
          await _credentialStore.delete(previous.credentialId);
        }
      });

  Future<void> setTextAssistantEnabled(bool value) => _mutate(() async {
        await initialized;
        if (value && _textAssistantConfig == null) {
          throw StateError('TEXT_ASSISTANT_CONFIG_REQUIRED');
        }
        if (_textAssistantEnabled == value) return;
        _textAssistantEnabled = value;
        notifyListeners();
        await _persist();
      });

  Future<void> setInlineTextSuggestionsEnabled(bool value) => _mutate(() async {
        await initialized;
        if (_inlineTextSuggestionsEnabled == value) return;
        _inlineTextSuggestionsEnabled = value;
        notifyListeners();
        await _persist();
      });

  Future<bool> hasTextAssistantCredential() async {
    await initialized;
    final credentialId = _textAssistantConfig?.credentialId;
    return credentialId != null &&
        (await _credentialStore.read(credentialId)) != null;
  }

  Future<String?> resolveTextAssistantSecret(String credentialId) async {
    await initialized;
    if (_textAssistantConfig?.credentialId != credentialId) return null;
    return _credentialStore.read(credentialId);
  }

  TextAssistantClient createTextAssistantClient({
    Duration timeout = const Duration(seconds: 30),
  }) {
    final config = _textAssistantConfig;
    if (!_textAssistantEnabled || config == null) {
      throw StateError('TEXT_ASSISTANT_DISABLED');
    }
    return TextAssistantClient(
      config: config,
      secretResolver: resolveTextAssistantSecret,
      timeout: timeout,
    );
  }

  Future<void> setActiveAsrProfile(String? profileId) => _mutate(() async {
        await initialized;
        _requireKind(profileId, AiProviderKind.speechRecognition);
        if (_activeAsrProfileId == profileId) return;
        _activeAsrProfileId = profileId;
        if (profileId == null) _enabled = false;
        notifyListeners();
        await _persist();
      });

  Future<void> setActiveFieldExtractionProfile(String? profileId) =>
      _mutate(() async {
        await initialized;
        _requireKind(profileId, AiProviderKind.fieldExtraction);
        if (_activeFieldExtractionProfileId == profileId) return;
        _activeFieldExtractionProfileId = profileId;
        notifyListeners();
        await _persist();
      });

  Future<void> setActiveAudioFieldExtractionProfile(String? profileId) =>
      _mutate(() async {
        await initialized;
        _requireKind(profileId, AiProviderKind.audioFieldExtraction);
        if (_activeAudioFieldExtractionProfileId == profileId) return;
        _activeAudioFieldExtractionProfileId = profileId;
        notifyListeners();
        await _persist();
      });

  Future<void> upsertProfile(AiProviderProfile profile) => _mutate(() async {
        await initialized;
        _ensureSharedCredentialDestination(profile);
        final updated = List<AiProviderProfile>.from(_profiles);
        final index =
            updated.indexWhere((candidate) => candidate.id == profile.id);
        final previous = index < 0 ? null : updated[index];
        if (previous != null &&
            _credentialBindingChanged(previous, profile) &&
            previous.credentialId != null &&
            previous.credentialId == profile.credentialId) {
          throw StateError('AI_CREDENTIAL_REBIND_REQUIRED');
        }
        if (index < 0) {
          updated.add(profile);
        } else {
          updated[index] = profile;
        }
        _profiles = List.unmodifiable(updated);

        if (_activeAsrProfileId == profile.id &&
            profile.kind != AiProviderKind.speechRecognition) {
          _activeAsrProfileId = null;
          _enabled = false;
        }
        if (_activeFieldExtractionProfileId == profile.id &&
            profile.kind != AiProviderKind.fieldExtraction) {
          _activeFieldExtractionProfileId = null;
        }
        if (_activeAudioFieldExtractionProfileId == profile.id &&
            profile.kind != AiProviderKind.audioFieldExtraction) {
          _activeAudioFieldExtractionProfileId = null;
        }
        notifyListeners();
        await _persist();

        final previousCredentialId = previous?.credentialId;
        if (previousCredentialId != null &&
            previousCredentialId != profile.credentialId &&
            !_profiles
                .any((item) => item.credentialId == previousCredentialId)) {
          await _credentialStore.delete(previousCredentialId);
        }
      });

  Future<void> removeProfile(String profileId) => _mutate(() async {
        await initialized;
        final profile = _profileById(profileId);
        if (profile == null) return;
        _profiles = List.unmodifiable(
          _profiles.where((candidate) => candidate.id != profileId),
        );
        if (_activeAsrProfileId == profileId) {
          _activeAsrProfileId = null;
          _enabled = false;
        }
        if (_activeFieldExtractionProfileId == profileId) {
          _activeFieldExtractionProfileId = null;
        }
        if (_activeAudioFieldExtractionProfileId == profileId) {
          _activeAudioFieldExtractionProfileId = null;
        }
        notifyListeners();
        await _persist();

        final credentialId = profile.credentialId;
        if (credentialId != null &&
            _textAssistantConfig?.credentialId != credentialId &&
            !_profiles.any((item) => item.credentialId == credentialId)) {
          await _credentialStore.delete(credentialId);
        }
      });

  Future<void> saveCredential(String profileId, String secret) =>
      _mutate(() async {
        await initialized;
        final profile = _profileById(profileId);
        if (profile == null) throw StateError('AI_PROFILE_NOT_FOUND');
        final credentialId = profile.credentialId;
        if (credentialId == null ||
            profile.credentialTransport.location == AiCredentialLocation.none) {
          throw StateError('AI_PROFILE_DOES_NOT_USE_CREDENTIALS');
        }
        await _credentialStore.write(credentialId, secret);
        notifyListeners();
      });

  Future<bool> hasCredential(String profileId) async {
    await initialized;
    final profile = _profileById(profileId);
    final credentialId = profile?.credentialId;
    if (credentialId == null) return false;
    return (await _credentialStore.read(credentialId)) != null;
  }

  Future<AiCredentials?> resolveCredentials(AiCredentialRequest request) async {
    await initialized;
    final credentialId = request.credentialId;
    if (credentialId == null) return null;
    final profile = _profileById(request.providerId);
    if (profile == null || profile.credentialId != credentialId) return null;
    final value = await _credentialStore.read(credentialId);
    return value == null ? null : AiCredentials(apiKey: value);
  }

  /// Exports provider definitions only. Enabling state and secure credential
  /// values remain private to this installation. Custom provider metadata is
  /// intentionally portable and must not be used to store authentication.
  String exportProfiles() => const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': schemaVersion,
        'profiles': _profiles.map((profile) {
          final portable = profile.toJson();
          portable.remove('credentialId');
          return portable;
        }).toList(),
      });

  /// Replaces provider definitions from a portable, credential-free profile
  /// bundle. Imported credential IDs are references only and need a local key.
  Future<void> importProfiles(String encoded) => _mutate(() async {
        await initialized;
        final value = jsonDecode(encoded);
        if (value is! Map) {
          throw const FormatException('AI profile bundle must be an object');
        }
        final json = Map<String, Object?>.from(value);
        if (json['schemaVersion'] != schemaVersion) {
          throw FormatException(
            'Unsupported AI profile schema: ${json['schemaVersion']}',
          );
        }
        final rawProfiles = json['profiles'];
        if (rawProfiles is! List) {
          throw const FormatException('AI profiles must be a list');
        }
        final imported = rawProfiles.map((value) {
          if (value is! Map) {
            throw const FormatException(
              'AI provider profile must be an object',
            );
          }
          // A portable profile must never gain authority over a credential
          // already on this device, even when a hand-written bundle tries to
          // smuggle in a known credential reference.
          final portable = Map<String, Object?>.from(value)
            ..remove('credentialId');
          return AiProviderProfile.fromJson(portable);
        }).toList(growable: false);
        _ensureUniqueIds(imported);
        final replacedCredentialIds = _profiles
            .map((profile) => profile.credentialId)
            .whereType<String>()
            .toSet();
        _profiles = List.unmodifiable(imported);
        _activeAsrProfileId = null;
        _activeFieldExtractionProfileId = null;
        _activeAudioFieldExtractionProfileId = null;
        _enabled = false;
        _useLocalReferenceContext = true;
        notifyListeners();
        await _persist();
        for (final credentialId in replacedCredentialIds) {
          if (!_profiles.any((item) => item.credentialId == credentialId)) {
            await _credentialStore.delete(credentialId);
          }
        }
      });

  Future<void> reset() => _mutate(() async {
        await initialized;
        final credentialIds = _profiles
            .map((profile) => profile.credentialId)
            .whereType<String>()
            .toSet();
        if (_textAssistantConfig?.credentialId case final credentialId?) {
          credentialIds.add(credentialId);
        }
        _profiles = const [];
        _activeAsrProfileId = null;
        _activeFieldExtractionProfileId = null;
        _activeAudioFieldExtractionProfileId = null;
        _enabled = false;
        _textAssistantConfig = null;
        _textAssistantEnabled = false;
        _inlineTextSuggestionsEnabled = true;
        _loadError = null;
        notifyListeners();
        await _removePersistedSettings();
        for (final credentialId in credentialIds) {
          await _credentialStore.delete(credentialId);
        }
      });

  Future<void> _persist() {
    final encoded = jsonEncode({
      'schemaVersion': schemaVersion,
      'enabled': _enabled,
      'useLocalReferenceContext': _useLocalReferenceContext,
      'textAssistantEnabled': _textAssistantEnabled,
      'inlineTextSuggestionsEnabled': _inlineTextSuggestionsEnabled,
      if (_textAssistantConfig != null)
        'textAssistant': _textAssistantConfig!.toJson(),
      'activeAsrProfileId': _activeAsrProfileId,
      'activeFieldExtractionProfileId': _activeFieldExtractionProfileId,
      'activeAudioFieldExtractionProfileId':
          _activeAudioFieldExtractionProfileId,
      'profiles': _profiles.map((profile) => profile.toJson()).toList(),
    });
    return _enqueuePreferenceOperation((preferences) async {
      final saved = await preferences.setString(_storageKey, encoded);
      if (!saved) throw StateError('Unable to persist AI settings');
    });
  }

  Future<void> _removePersistedSettings() =>
      _enqueuePreferenceOperation((preferences) async {
        final removed = await preferences.remove(_storageKey);
        if (!removed) throw StateError('Unable to remove AI settings');
      });

  Future<void> _enqueuePreferenceOperation(
    Future<void> Function(KeyValueStore preferences) operation,
  ) {
    final result = Completer<void>();
    _saveTail = _saveTail.then((_) async {
      try {
        final preferences = await _preferencesLoader();
        await operation(preferences);
        result.complete();
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<void> _mutate(Future<void> Function() mutation) {
    final result = Completer<void>();
    _mutationTail = _mutationTail.then((_) async {
      try {
        await mutation();
        result.complete();
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  AiProviderProfile? _profileById(String? id, [AiProviderKind? kind]) {
    if (id == null) return null;
    for (final profile in _profiles) {
      if (profile.id == id && (kind == null || profile.kind == kind)) {
        return profile;
      }
    }
    return null;
  }

  TextAssistantConfig? _migrateTextAssistantProfile() {
    final profile = _profileById(_activeFieldExtractionProfileId);
    if (profile == null ||
        profile.protocol != AiProtocol.openAiChatCompletions ||
        profile.credentialId == null) {
      return null;
    }
    final provider = profile.baseUrl.host.toLowerCase() == 'api.openai.com'
        ? TextAssistantProvider.openAi
        : TextAssistantProvider.openAiCompatible;
    return TextAssistantConfig(
      provider: provider,
      baseUrl: profile.baseUrl,
      model: profile.model,
      credentialId: profile.credentialId!,
    );
  }

  String? _validActiveId(Object? value, AiProviderKind kind) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Active AI profile ID must be a string');
    }
    return _profileExistsWithKind(value, kind) ? value : null;
  }

  bool _profileExistsWithKind(
    String? id,
    AiProviderKind kind, {
    List<AiProviderProfile>? profiles,
  }) =>
      id != null &&
      (profiles ?? _profiles)
          .any((profile) => profile.id == id && profile.kind == kind);

  static bool _credentialBindingChanged(
    AiProviderProfile previous,
    AiProviderProfile next,
  ) =>
      previous.baseUrl.origin != next.baseUrl.origin ||
      previous.protocol != next.protocol ||
      _credentialTransportChanged(previous, next);

  static bool _credentialTransportChanged(
    AiProviderProfile previous,
    AiProviderProfile next,
  ) =>
      previous.credentialTransport.location !=
          next.credentialTransport.location ||
      previous.credentialTransport.name != next.credentialTransport.name ||
      previous.credentialTransport.prefix != next.credentialTransport.prefix;

  /// A credential may be shared by ASR and extraction profiles for one API,
  /// but an opaque ID must never silently authorize a second origin or a
  /// different credential destination.
  void _ensureSharedCredentialDestination(AiProviderProfile profile) {
    final credentialId = profile.credentialId;
    if (credentialId == null) return;
    for (final existing in _profiles) {
      if (existing.id == profile.id || existing.credentialId != credentialId) {
        continue;
      }
      if (existing.baseUrl.origin != profile.baseUrl.origin ||
          _credentialTransportChanged(existing, profile)) {
        throw StateError('AI_CREDENTIAL_REBIND_REQUIRED');
      }
    }
  }

  void _requireKind(String? id, AiProviderKind kind) {
    if (id == null) return;
    if (!_profileExistsWithKind(id, kind)) {
      throw StateError('AI_PROFILE_KIND_MISMATCH');
    }
  }

  static void _ensureUniqueIds(List<AiProviderProfile> profiles) {
    final ids = <String>{};
    for (final profile in profiles) {
      if (!ids.add(profile.id)) {
        throw FormatException('Duplicate AI profile ID: ${profile.id}');
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
