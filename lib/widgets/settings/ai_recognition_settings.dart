import 'dart:convert';
import 'package:openlogtool/utils/app_snack_bar.dart';

import 'package:flutter/material.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/ai_recognition_settings_provider.dart';
import 'package:openlogtool/services/ai_recognition/models.dart';
import 'package:openlogtool/services/ai_recognition/providers.dart';
import 'package:openlogtool/services/text_assistant.dart';
import 'package:openlogtool/theme/app_theme.dart';
import 'package:openlogtool/widgets/settings/settings_ui.dart';
import 'package:provider/provider.dart';

class AiRecognitionSettings extends StatefulWidget {
  const AiRecognitionSettings({
    super.key,
    required this.cardPadding,
  });

  final double cardPadding;

  @override
  State<AiRecognitionSettings> createState() => _AiRecognitionSettingsState();
}

class _AiRecognitionSettingsState extends State<AiRecognitionSettings> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AiRecognitionSettingsProvider>();
    final activeAsr = settings.activeAsrProfile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionCard(
          key: const Key('ai-recognition-overview'),
          icon: Icons.auto_awesome_outlined,
          title: context.l10n.aiSettingsTitle,
          description: context.l10n.aiSettingsDescription,
          padding: widget.cardPadding,
          tone: SettingsTone.tertiary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppNotice(
                title: context.l10n.aiSettingsOptionalTitle,
                message: context.l10n.aiSettingsOptionalMessage,
                icon: Icons.privacy_tip_outlined,
                tone: AppTone.tertiary,
              ),
              const SizedBox(height: AppSpace.sm),
              SettingsActionTile(
                key: const Key('ai-recognition-enabled'),
                icon: Icons.mic_none_outlined,
                title: context.l10n.aiRecognitionEnabled,
                subtitle: activeAsr == null
                    ? context.l10n.aiRecognitionNeedsAsr
                    : context.l10n.aiRecognitionEnabledHint,
                trailing: Switch(
                  value: settings.enabled,
                  onChanged: _busy || activeAsr == null
                      ? null
                      : (value) => _run(() => settings.setEnabled(value)),
                ),
              ),
              SettingsActionTile(
                key: const Key('ai-local-reference-context'),
                icon: Icons.storage_outlined,
                title: context.l10n.aiLocalReferenceContext,
                subtitle: context.l10n.aiLocalReferenceContextHint,
                trailing: Switch(
                  value: settings.useLocalReferenceContext,
                  onChanged: _busy
                      ? null
                      : (value) => _run(
                            () => settings.setUseLocalReferenceContext(value),
                          ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.md),
        _buildTextAssistantCard(context, settings),
        const SizedBox(height: AppSpace.md),
        _buildStageCard(
          context,
          settings: settings,
          kind: AiProviderKind.speechRecognition,
          profiles: settings.asrProfiles.toList(growable: false),
          active: activeAsr,
        ),
        const SizedBox(height: AppSpace.md),
        _buildStageCard(
          context,
          settings: settings,
          kind: AiProviderKind.audioFieldExtraction,
          profiles:
              settings.audioFieldExtractionProfiles.toList(growable: false),
          active: settings.activeAudioFieldExtractionProfile,
        ),
      ],
    );
  }

  Widget _buildTextAssistantCard(
    BuildContext context,
    AiRecognitionSettingsProvider settings,
  ) {
    final config = settings.textAssistantConfig;
    return SettingsSectionCard(
      key: const Key('text-assistant-settings'),
      icon: Icons.chat_bubble_outline,
      title: context.l10n.textAssistantTitle,
      description: context.l10n.textAssistantDescription,
      padding: widget.cardPadding,
      tone: SettingsTone.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppNotice(
            title: context.l10n.textAssistantPrivacyTitle,
            message: context.l10n.textAssistantPrivacyMessage,
            icon: Icons.security_outlined,
            tone: AppTone.primary,
          ),
          const SizedBox(height: AppSpace.sm),
          SettingsTileGroup(
            children: [
              SettingsActionTile(
                key: const Key('text-assistant-enabled'),
                icon: Icons.auto_awesome_outlined,
                title: context.l10n.textAssistantEnabled,
                subtitle: config == null
                    ? context.l10n.textAssistantNotConfigured
                    : '${_textAssistantProviderLabel(context, config.provider)}'
                        ' · ${config.model}\n${config.baseUrl}',
                trailing: Switch(
                  value: settings.textAssistantEnabled,
                  onChanged: _busy || config == null
                      ? null
                      : (value) =>
                          _run(() => settings.setTextAssistantEnabled(value)),
                ),
              ),
              SettingsActionTile(
                key: const Key('text-assistant-inline-enabled'),
                icon: Icons.format_indent_increase_outlined,
                title: context.l10n.textAssistantInlineSuggestions,
                subtitle: context.l10n.textAssistantInlineSuggestionsHint,
                trailing: Switch(
                  value: settings.inlineTextSuggestionsEnabled,
                  onChanged: _busy || !settings.textAssistantEnabled
                      ? null
                      : (value) => _run(
                            () =>
                                settings.setInlineTextSuggestionsEnabled(value),
                          ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                key: const Key('text-assistant-test'),
                onPressed: _busy || config == null
                    ? null
                    : () => _testTextAssistant(settings),
                icon: const Icon(Icons.network_check_outlined),
                label: Text(context.l10n.textAssistantTest),
              ),
              FilledButton.tonalIcon(
                key: const Key('text-assistant-configure'),
                onPressed:
                    _busy ? null : () => _editTextAssistant(settings, config),
                icon: Icon(config == null ? Icons.add : Icons.edit_outlined),
                label: Text(config == null
                    ? context.l10n.textAssistantConfigure
                    : context.l10n.textAssistantEdit),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editTextAssistant(
    AiRecognitionSettingsProvider settings,
    TextAssistantConfig? existing,
  ) async {
    final draft = await showDialog<_TextAssistantDraft>(
      context: context,
      builder: (dialogContext) =>
          _TextAssistantEditorDialog(existing: existing),
    );
    if (draft == null || !mounted) return;
    await _run(
      () => settings.saveTextAssistant(
        provider: draft.provider,
        baseUrl: draft.baseUrl,
        model: draft.model,
        secret: draft.secret,
      ),
    );
  }

  Future<void> _testTextAssistant(
    AiRecognitionSettingsProvider settings,
  ) async {
    await _run(() async {
      final client = settings.createTextAssistantClient(
        timeout: const Duration(seconds: 15),
      );
      try {
        final result = await client.completeJson(
          systemPrompt: 'Return only a JSON object. Do not explain.',
          userPrompt: 'Return {"ok":true}.',
          cancellationToken: AiCancellationToken(),
          maxOutputTokens: 48,
        );
        if (result['ok'] != true) {
          throw StateError('TEXT_ASSISTANT_TEST_INVALID_RESPONSE');
        }
      } finally {
        client.close();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.textAssistantTestSucceeded)),
      );
    });
  }

  Widget _buildStageCard(
    BuildContext context, {
    required AiRecognitionSettingsProvider settings,
    required AiProviderKind kind,
    required List<AiProviderProfile> profiles,
    required AiProviderProfile? active,
  }) {
    final (icon, title, description) = switch (kind) {
      AiProviderKind.speechRecognition => (
          Icons.graphic_eq_outlined,
          context.l10n.aiAsrStageTitle,
          context.l10n.aiAsrStageDescription,
        ),
      AiProviderKind.fieldExtraction => (
          Icons.rule_folder_outlined,
          context.l10n.aiExtractionStageTitle,
          context.l10n.aiExtractionStageDescription,
        ),
      AiProviderKind.audioFieldExtraction => (
          Icons.record_voice_over_outlined,
          context.l10n.aiStageAudioFieldExtractionTitle,
          context.l10n.aiStageAudioFieldExtractionHint,
        ),
    };
    final protocols = AiProtocol.values
        .where((protocol) => protocol.supports(kind))
        .toList(growable: false);
    return SettingsSectionCard(
      key: Key('ai-stage-${kind.name}'),
      icon: icon,
      title: title,
      description: description,
      padding: widget.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.aiSupportedProtocols,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpace.xs),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: AppSpace.xs,
              runSpacing: AppSpace.xs,
              children: [
                for (final protocol in protocols)
                  _ProtocolBadge(
                    label: _protocolLabel(context, protocol),
                    maxWidth: constraints.maxWidth,
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          SettingsTileGroup(
            children: [
              SettingsActionTile(
                key: Key('ai-profile-selector-${kind.name}'),
                icon: Icons.hub_outlined,
                title: context.l10n.aiActiveProfile,
                subtitle: active == null
                    ? context.l10n.aiNoProfileConfigured
                    : _profileSummary(context, active),
                trailing: SizedBox(
                  width: 260,
                  child: DropdownButton<String>(
                    value: active?.id ?? '',
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text(context.l10n.aiNoActiveProfile),
                      ),
                      for (final profile in profiles)
                        DropdownMenuItem(
                          value: profile.id,
                          child: Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => _run(() {
                              final profileId =
                                  value == null || value.isEmpty ? null : value;
                              return switch (kind) {
                                AiProviderKind.speechRecognition =>
                                  settings.setActiveAsrProfile(profileId),
                                AiProviderKind.fieldExtraction => settings
                                    .setActiveFieldExtractionProfile(profileId),
                                AiProviderKind.audioFieldExtraction =>
                                  settings.setActiveAudioFieldExtractionProfile(
                                    profileId,
                                  ),
                              };
                            }),
                  ),
                ),
              ),
              SettingsActionTile(
                icon: Icons.vpn_key_outlined,
                title: context.l10n.aiCredentialStatus,
                subtitle: active == null
                    ? context.l10n.aiCredentialNoProfile
                    : context.l10n.aiCredentialStoredLocally,
                trailing: active == null
                    ? AppStatusPill(label: context.l10n.aiStatusNotConfigured)
                    : _CredentialStatus(
                        settings: settings,
                        profile: active,
                      ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.xs,
            runSpacing: AppSpace.xs,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                key: Key('ai-add-profile-${kind.name}'),
                onPressed: _busy
                    ? null
                    : () => _editProfile(
                          settings: settings,
                          kind: kind,
                        ),
                icon: const Icon(Icons.add),
                label: Text(context.l10n.aiAddProfile),
              ),
              if (active != null)
                OutlinedButton.icon(
                  key: Key('ai-edit-profile-${kind.name}'),
                  onPressed: _busy
                      ? null
                      : () => _editProfile(
                            settings: settings,
                            kind: kind,
                            existing: active,
                          ),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.l10n.aiEditProfile),
                ),
              if (active != null)
                OutlinedButton.icon(
                  key: Key('ai-delete-profile-${kind.name}'),
                  onPressed:
                      _busy ? null : () => _deleteProfile(settings, active),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(context.l10n.delete),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile({
    required AiRecognitionSettingsProvider settings,
    required AiProviderKind kind,
    AiProviderProfile? existing,
  }) async {
    final draft = await showDialog<_AiProfileDraft>(
      context: context,
      builder: (dialogContext) => _AiProfileEditorDialog(
        kind: kind,
        existing: existing,
      ),
    );
    if (draft == null || !mounted) return;
    await _run(() async {
      await settings.upsertProfile(draft.profile);
      if (draft.secret case final secret?) {
        await settings.saveCredential(draft.profile.id, secret);
      }
      await switch (kind) {
        AiProviderKind.speechRecognition =>
          settings.setActiveAsrProfile(draft.profile.id),
        AiProviderKind.fieldExtraction =>
          settings.setActiveFieldExtractionProfile(draft.profile.id),
        AiProviderKind.audioFieldExtraction =>
          settings.setActiveAudioFieldExtractionProfile(draft.profile.id),
      };
    });
  }

  Future<void> _deleteProfile(
    AiRecognitionSettingsProvider settings,
    AiProviderProfile profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.aiDeleteProfileTitle),
        content: Text(
          dialogContext.l10n.aiDeleteProfileMessage(profile.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => settings.removeProfile(profile.id));
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.aiSettingsFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final class _TextAssistantDraft {
  const _TextAssistantDraft({
    required this.provider,
    required this.baseUrl,
    required this.model,
    this.secret,
  });

  final TextAssistantProvider provider;
  final Uri baseUrl;
  final String model;
  final String? secret;
}

class _TextAssistantEditorDialog extends StatefulWidget {
  const _TextAssistantEditorDialog({this.existing});

  final TextAssistantConfig? existing;

  @override
  State<_TextAssistantEditorDialog> createState() =>
      _TextAssistantEditorDialogState();
}

class _TextAssistantEditorDialogState
    extends State<_TextAssistantEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextAssistantProvider _provider;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _secretController;

  @override
  void initState() {
    super.initState();
    _provider = widget.existing?.provider ?? TextAssistantProvider.openAi;
    _baseUrlController = TextEditingController(
      text:
          widget.existing?.baseUrl.toString() ?? _defaultTextBaseUrl(_provider),
    );
    _modelController =
        TextEditingController(text: widget.existing?.model ?? '');
    _secretController = TextEditingController();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('text-assistant-editor-dialog'),
      scrollable: true,
      title: Text(context.l10n.textAssistantConfigureTitle),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<TextAssistantProvider>(
                key: const Key('text-assistant-provider'),
                initialValue: _provider,
                decoration: InputDecoration(
                  labelText: context.l10n.textAssistantProvider,
                ),
                items: [
                  for (final provider in TextAssistantProvider.values)
                    DropdownMenuItem(
                      value: provider,
                      child:
                          Text(_textAssistantProviderLabel(context, provider)),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  final oldDefault = _defaultTextBaseUrl(_provider);
                  final replaceBase = _baseUrlController.text.trim().isEmpty ||
                      _baseUrlController.text.trim() == oldDefault;
                  setState(() {
                    _provider = value;
                    if (replaceBase) {
                      _baseUrlController.text = _defaultTextBaseUrl(value);
                    }
                  });
                },
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                key: const Key('text-assistant-base-url'),
                controller: _baseUrlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: context.l10n.aiBaseUrl,
                  hintText: 'https://api.example.com/v1',
                ),
                validator: (value) {
                  final uri = Uri.tryParse(value?.trim() ?? '');
                  if (uri == null ||
                      !uri.hasScheme ||
                      (uri.scheme != 'http' && uri.scheme != 'https') ||
                      uri.host.isEmpty ||
                      uri.userInfo.isNotEmpty ||
                      uri.fragment.isNotEmpty) {
                    return context.l10n.aiInvalidBaseUrl;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                key: const Key('text-assistant-model'),
                controller: _modelController,
                decoration:
                    InputDecoration(labelText: context.l10n.aiModelName),
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.l10n.aiRequiredField
                    : null,
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                key: const Key('text-assistant-api-key'),
                controller: _secretController,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: context.l10n.aiApiKey,
                  helperText: widget.existing == null
                      ? context.l10n.aiApiKeyNewHint
                      : context.l10n.aiApiKeyExistingHint,
                ),
                validator: (value) => widget.existing == null &&
                        (value == null || value.trim().isEmpty)
                    ? context.l10n.aiRequiredField
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('text-assistant-save'),
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              _TextAssistantDraft(
                provider: _provider,
                baseUrl: Uri.parse(_baseUrlController.text.trim()),
                model: _modelController.text.trim(),
                secret: _secretController.text.trim().isEmpty
                    ? null
                    : _secretController.text.trim(),
              ),
            );
          },
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

String _defaultTextBaseUrl(TextAssistantProvider provider) =>
    switch (provider) {
      TextAssistantProvider.openAi => 'https://api.openai.com/v1',
      TextAssistantProvider.anthropic => 'https://api.anthropic.com',
      TextAssistantProvider.openAiCompatible => '',
    };

String _textAssistantProviderLabel(
  BuildContext context,
  TextAssistantProvider provider,
) =>
    switch (provider) {
      TextAssistantProvider.openAi => context.l10n.textAssistantProviderOpenAi,
      TextAssistantProvider.anthropic =>
        context.l10n.textAssistantProviderAnthropic,
      TextAssistantProvider.openAiCompatible =>
        context.l10n.textAssistantProviderCompatible,
    };

class _CredentialStatus extends StatelessWidget {
  const _CredentialStatus({
    required this.settings,
    required this.profile,
  });

  final AiRecognitionSettingsProvider settings;
  final AiProviderProfile profile;

  @override
  Widget build(BuildContext context) {
    if (profile.credentialTransport.location == AiCredentialLocation.none) {
      return AppStatusPill(
        label: context.l10n.aiStatusNoCredentialNeeded,
        icon: Icons.lock_open_outlined,
        tone: AppTone.success,
      );
    }
    return FutureBuilder<bool>(
      future: settings.hasCredential(profile.id),
      builder: (context, snapshot) => AppStatusPill(
        label: snapshot.data == true
            ? context.l10n.aiStatusCredentialReady
            : context.l10n.aiStatusCredentialMissing,
        icon: snapshot.data == true
            ? Icons.lock_outline
            : Icons.warning_amber_outlined,
        tone: snapshot.data == true ? AppTone.success : AppTone.warning,
      ),
    );
  }
}

class _ProtocolBadge extends StatelessWidget {
  const _ProtocolBadge({required this.label, required this.maxWidth});

  final String label;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: AppSpace.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiProfileDraft {
  const _AiProfileDraft({required this.profile, this.secret});

  final AiProviderProfile profile;
  final String? secret;
}

class _AiProfileEditorDialog extends StatefulWidget {
  const _AiProfileEditorDialog({required this.kind, this.existing});

  final AiProviderKind kind;
  final AiProviderProfile? existing;

  @override
  State<_AiProfileEditorDialog> createState() => _AiProfileEditorDialogState();
}

class _AiProfileEditorDialogState extends State<_AiProfileEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _credentialNameController;
  late final TextEditingController _credentialPrefixController;
  late final TextEditingController _secretController;
  late final TextEditingController _requestOptionsController;
  late AiProtocol _protocol;
  late AiCredentialLocation _credentialLocation;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _protocol = existing?.protocol ??
        switch (widget.kind) {
          AiProviderKind.speechRecognition =>
            AiProtocol.openAiAudioTranscriptions,
          AiProviderKind.fieldExtraction => AiProtocol.openAiChatCompletions,
          AiProviderKind.audioFieldExtraction =>
            AiProtocol.openAiChatCompletionsAudio,
        };
    _credentialLocation = existing?.credentialTransport.location ??
        AiCredentialLocation.bearerHeader;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _baseUrlController = TextEditingController(
      text: existing?.baseUrl.toString() ?? '',
    );
    _modelController = TextEditingController(text: existing?.model ?? '');
    _credentialNameController = TextEditingController(
      text: existing?.credentialTransport.name ?? '',
    );
    _credentialPrefixController = TextEditingController(
      text: existing?.credentialTransport.prefix ?? '',
    );
    _secretController = TextEditingController();
    _requestOptionsController = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(
        existing?.requestOptions ??
            _defaultRequestOptions(_protocol, widget.kind),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _credentialNameController.dispose();
    _credentialPrefixController.dispose();
    _secretController.dispose();
    _requestOptionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsCredentialName =
        _credentialLocation == AiCredentialLocation.header ||
            _credentialLocation == AiCredentialLocation.queryParameter;
    return AlertDialog(
      key: const Key('ai-profile-editor-dialog'),
      scrollable: true,
      title: Text(
        widget.existing == null
            ? context.l10n.aiAddProfile
            : context.l10n.aiEditProfile,
      ),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('ai-profile-name'),
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.aiProfileName,
                ),
                validator: _required,
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                key: const Key('ai-profile-base-url'),
                controller: _baseUrlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: context.l10n.aiBaseUrl,
                  hintText: 'https://api.example.com/v1',
                ),
                validator: _validateBaseUrl,
              ),
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                key: const Key('ai-profile-model'),
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: context.l10n.aiModelName,
                ),
                validator: _required,
              ),
              const SizedBox(height: AppSpace.sm),
              DropdownButtonFormField<AiProtocol>(
                key: const Key('ai-profile-protocol'),
                initialValue: _protocol,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.aiProtocol,
                ),
                items: [
                  for (final protocol in AiProtocol.values)
                    if (protocol.supports(widget.kind))
                      DropdownMenuItem(
                        value: protocol,
                        child: Text(
                          _protocolLabel(context, protocol),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  _changeProtocol(value);
                },
              ),
              const SizedBox(height: AppSpace.sm),
              DropdownButtonFormField<AiCredentialLocation>(
                key: const Key('ai-profile-auth'),
                initialValue: _credentialLocation,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.aiAuthentication,
                ),
                items: [
                  for (final location in AiCredentialLocation.values)
                    DropdownMenuItem(
                      value: location,
                      child: Text(
                        _credentialLabel(context, location),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _credentialLocation = value);
                },
              ),
              if (needsCredentialName) ...[
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                  controller: _credentialNameController,
                  decoration: InputDecoration(
                    labelText: context.l10n.aiCredentialName,
                    hintText: _credentialLocation == AiCredentialLocation.header
                        ? 'X-API-Key'
                        : 'api_key',
                  ),
                  validator: _required,
                ),
              ],
              if (_credentialLocation != AiCredentialLocation.none) ...[
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                  controller: _credentialPrefixController,
                  decoration: InputDecoration(
                    labelText: context.l10n.aiCredentialPrefix,
                    hintText:
                        _credentialLocation == AiCredentialLocation.bearerHeader
                            ? 'Bearer '
                            : '',
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                TextFormField(
                  key: const Key('ai-profile-secret'),
                  controller: _secretController,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: context.l10n.aiApiKey,
                    helperText: widget.existing == null
                        ? context.l10n.aiApiKeyNewHint
                        : context.l10n.aiApiKeyExistingHint,
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.sm),
              TextFormField(
                key: const Key('ai-profile-request-options'),
                controller: _requestOptionsController,
                minLines: 6,
                maxLines: 14,
                style: const TextStyle(fontFamily: 'monospace'),
                decoration: InputDecoration(
                  alignLabelWithHint: true,
                  labelText: context.l10n.aiRequestOptions,
                  helperText: context.l10n.aiRequestOptionsHint,
                ),
                validator: _validateRequestOptions,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('ai-profile-save'),
          onPressed: _saving ? null : _submit,
          child: Text(context.l10n.save),
        ),
      ],
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? context.l10n.aiRequiredField
      : null;

  String? _validateBaseUrl(String? value) {
    final requiredError = _required(value);
    if (requiredError != null) return requiredError;
    final uri = Uri.tryParse(value!.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return context.l10n.aiInvalidBaseUrl;
    }
    return null;
  }

  String? _validateRequestOptions(String? value) {
    try {
      final source = value?.trim() ?? '';
      final decoded = jsonDecode(source.isEmpty ? '{}' : source);
      if (decoded is! Map) return context.l10n.aiRequestOptionsMustBeObject;
      Map<String, Object?>.from(decoded);
      if (_protocol == AiProtocol.jsonHttp &&
          !decoded.containsKey('requestTemplate')) {
        return context.l10n.aiJsonProtocolNeedsTemplate;
      }
      return null;
    } catch (_) {
      return context.l10n.aiInvalidJson;
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final baseUrl = Uri.parse(_baseUrlController.text.trim());
      final optionsSource = _requestOptionsController.text.trim();
      final options = Map<String, Object?>.from(
        jsonDecode(optionsSource.isEmpty ? '{}' : optionsSource) as Map,
      );
      final transport = switch (_credentialLocation) {
        AiCredentialLocation.none => const AiCredentialTransport.none(),
        AiCredentialLocation.bearerHeader => AiCredentialTransport.header(
            name: 'Authorization',
            prefix: _credentialPrefixController.text.isEmpty
                ? 'Bearer '
                : _credentialPrefixController.text,
          ),
        AiCredentialLocation.header => AiCredentialTransport.header(
            name: _credentialNameController.text,
            prefix: _credentialPrefixController.text,
          ),
        AiCredentialLocation.queryParameter =>
          AiCredentialTransport.queryParameter(
            name: _credentialNameController.text,
            prefix: _credentialPrefixController.text,
          ),
      };
      final id = widget.existing?.id ?? _newProfileId(widget.kind);
      final credentialId = _credentialLocation == AiCredentialLocation.none
          ? null
          : _credentialIdFor(
              id: id,
              existing: widget.existing,
              baseUrl: baseUrl,
              protocol: _protocol,
              transport: transport,
            );
      final profile = AiProviderProfile(
        id: id,
        name: _nameController.text,
        kind: widget.kind,
        protocol: _protocol,
        baseUrl: baseUrl,
        model: _modelController.text,
        requestOptions: options,
        credentialId: credentialId,
        credentialTransport: transport,
        capabilities: AiProviderCapabilities(
          supportsAudioTranscription:
              widget.kind == AiProviderKind.speechRecognition,
          supportsFieldExtraction:
              widget.kind == AiProviderKind.fieldExtraction,
          supportsAudioFieldExtraction:
              widget.kind == AiProviderKind.audioFieldExtraction,
          supportsLanguageHint: widget.kind == AiProviderKind.speechRecognition,
          supportsPrompt: true,
        ),
      );
      final secret = _secretController.text.trim();
      Navigator.pop(
        context,
        _AiProfileDraft(
          profile: profile,
          secret: secret.isEmpty ? null : secret,
        ),
      );
    } catch (error) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.aiSettingsFailed('$error'))),
      );
    }
  }

  void _changeProtocol(AiProtocol value) {
    final currentText = _requestOptionsController.text.trim();
    final previousDefault = const JsonEncoder.withIndent('  ')
        .convert(_defaultRequestOptions(_protocol, widget.kind));
    final shouldReplaceOptions = currentText.isEmpty ||
        currentText == '{}' ||
        currentText == previousDefault;
    setState(() {
      _protocol = value;
      if (shouldReplaceOptions) {
        _requestOptionsController.text = const JsonEncoder.withIndent('  ')
            .convert(_defaultRequestOptions(value, widget.kind));
      }
    });
  }
}

Map<String, Object?> _defaultRequestOptions(
  AiProtocol protocol,
  AiProviderKind kind,
) {
  if (protocol != AiProtocol.jsonHttp) return const {};
  return switch (kind) {
    AiProviderKind.speechRecognition => {
        'requestTemplate': {
          'model': '{{model}}',
          'audio': '{{audio.dataUrl}}',
          'language': '{{language}}',
          'prompt': '{{prompt}}',
        },
        'responsePath': 'text',
      },
    AiProviderKind.audioFieldExtraction => {
        'requestTemplate': {
          'model': '{{model}}',
          'audio': '{{audio.dataUrl}}',
          'instructions': '{{instructions}}',
        },
        'responsePath': r'$',
      },
    AiProviderKind.fieldExtraction => {
        'requestTemplate': {
          'model': '{{model}}',
          'text': '{{transcription.text}}',
          'instructions': '{{instructions}}',
        },
        'responsePath': r'$',
      },
  };
}

String _credentialIdFor({
  required String id,
  required AiProviderProfile? existing,
  required Uri baseUrl,
  required AiProtocol protocol,
  required AiCredentialTransport transport,
}) {
  final previous = existing;
  if (previous != null &&
      previous.credentialId != null &&
      previous.baseUrl.origin == baseUrl.origin &&
      previous.protocol == protocol &&
      previous.credentialTransport.location == transport.location &&
      previous.credentialTransport.name == transport.name &&
      previous.credentialTransport.prefix == transport.prefix) {
    return previous.credentialId!;
  }
  return 'credential-$id-${DateTime.now().microsecondsSinceEpoch}';
}

int _profileSequence = 0;

String _newProfileId(AiProviderKind kind) =>
    '${kind.name}-${DateTime.now().microsecondsSinceEpoch}-${_profileSequence++}';

String _profileSummary(BuildContext context, AiProviderProfile profile) =>
    '${_protocolLabel(context, profile.protocol)} · ${profile.model}\n'
    '${profile.baseUrl}';

String _protocolLabel(BuildContext context, AiProtocol protocol) =>
    switch (protocol) {
      AiProtocol.openAiAudioTranscriptions =>
        context.l10n.aiProtocolAudioTranscriptions,
      AiProtocol.openAiChatCompletionsAudio => context.l10n.aiProtocolChatAudio,
      AiProtocol.openAiChatCompletions => context.l10n.aiProtocolChatText,
      AiProtocol.jsonHttp => context.l10n.aiProtocolGenericJson,
    };

String _credentialLabel(
  BuildContext context,
  AiCredentialLocation location,
) =>
    switch (location) {
      AiCredentialLocation.none => context.l10n.aiAuthNone,
      AiCredentialLocation.bearerHeader => context.l10n.aiAuthBearer,
      AiCredentialLocation.header => context.l10n.aiAuthHeader,
      AiCredentialLocation.queryParameter => context.l10n.aiAuthQuery,
    };
