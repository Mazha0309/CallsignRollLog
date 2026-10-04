import 'dart:async';
import 'package:openlogtool/utils/app_snack_bar.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/ai_recognition_settings_provider.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/models/log_entry.dart';
import 'package:openlogtool/models/dictionary_item.dart';
import 'package:openlogtool/models/live_draft.dart';
import 'package:openlogtool/utils/dictionary_ranking.dart';
import 'package:openlogtool/utils/dictionary_usage_store.dart';
import 'package:openlogtool/utils/field_format_suggestions.dart';
import 'package:openlogtool/utils/ime_safe_upper_case_formatter.dart';
import 'package:openlogtool/utils/log_time.dart';
import 'package:openlogtool/utils/power_normalizer.dart';
import 'package:openlogtool/services/ai_candidate_guard.dart';
import 'package:openlogtool/services/ai_audio_recorder.dart';
import 'package:openlogtool/services/ai_database_context.dart';
import 'package:openlogtool/services/ai_recognition_runtime.dart';
import 'package:openlogtool/services/ai_recognition/providers.dart';
import 'package:openlogtool/services/text_assistant_tasks.dart';
import 'package:openlogtool/services/app_logger.dart';
import 'package:openlogtool/widgets/ai_recognition_control.dart';
import 'package:openlogtool/widgets/autocomplete_options_list.dart';
import 'package:openlogtool/widgets/callsign_history_field.dart';
import 'package:openlogtool/widgets/scroll_safe_unfocus.dart';
import 'package:openlogtool/src/bridge/models/log_entry.dart' as bridge;

/// 日志表单组件
/// 用于添加和编辑点名记录
class LogForm extends StatefulWidget {
  const LogForm({
    super.key,
    this.readOnly = false,
    this.saveShortcutEnabled = true,
    this.sessionId,
    this.aiAudioRecorder,
    this.aiRecognitionExecutor,
    this.aiTranscriptionExecutor,
    this.aiFieldExtractionExecutor,
    this.inlineTextSuggestionExecutor,
  });

  final bool readOnly;
  final bool saveShortcutEnabled;
  final String? sessionId;
  final AiAudioRecorder? aiAudioRecorder;
  final AiRecognitionExecutor? aiRecognitionExecutor;
  final AiTranscriptionExecutor? aiTranscriptionExecutor;
  final AiFieldExtractionExecutor? aiFieldExtractionExecutor;
  final InlineTextSuggestionExecutor? inlineTextSuggestionExecutor;

  @override
  State<LogForm> createState() => _LogFormState();
}

class _LogFormState extends State<LogForm> with AutomaticKeepAliveClientMixin {
  LogEntry? _pendingSubmission;
  Map<String, String>? _pendingSubmissionFields;
  LogProvider? _pendingSubmissionProvider;
  String? _pendingSubmissionSession;
  static final List<DictionaryItem> _heightPresetOptions =
      List<DictionaryItem>.unmodifiable(<DictionaryItem>[
    DictionaryItem(
      raw: '地面',
      pinyin: 'dimian',
      abbreviation: 'DM',
      type: 'height',
      origin: 'builtin',
    ),
    DictionaryItem(
      raw: '高架',
      pinyin: 'gaojia',
      abbreviation: 'GJ',
      type: 'height',
      origin: 'builtin',
    ),
  ]);

  static const _upperCaseDraftFields = {'controller', 'callsign'};
  static const _clearableDraftFields = <String>{
    'time',
    'callsign',
    'rstSent',
    'rstRcvd',
    'qth',
    'device',
    'power',
    'antenna',
    'height',
    'remarks',
  };
  static const _clearedDraftDefaults = <String, String>{
    'rstSent': '59',
    'rstRcvd': '59',
  };

  final _formKey = GlobalKey<FormState>();
  final _outsideTap = ScrollSafeUnfocus();
  final _controllerController = TextEditingController();
  final _callsignController = TextEditingController();
  final FocusNode _callsignFocusNode = FocusNode();
  final _deviceController = TextEditingController();
  final _antennaController = TextEditingController();
  final _powerController = TextEditingController();
  final _qthController = TextEditingController();
  final _heightController = TextEditingController();
  final _timeController = TextEditingController();
  final _reportController = TextEditingController();
  final _rstRcvdController = TextEditingController();
  final _remarksController = TextEditingController();
  final Map<String, Timer> _draftDebounce = {};
  Timer? _duplicateCallsignDebounce;
  bool _duplicatePromptInProgress = false;
  String? _lastDuplicatePromptedCallsign;

  /// The last callsign an operator typed into *this* device's form.
  ///
  /// A shared draft also receives callsigns from collaborators and from the
  /// reset draft the server publishes after a commit. Those values are not
  /// input on this device, and the record they duplicate is frequently the one
  /// the draft itself just created, so they must never raise the duplicate
  /// prompt here.
  String? _locallyTypedCallsign;

  /// Callsign text this state last observed. A [TextEditingController] also
  /// notifies for selection and composing changes, so authorship may only be
  /// reassigned when the text itself actually changed.
  String _observedCallsign = '';
  late final Map<String, TextEditingController> _draftControllers;
  late final Map<String, GlobalKey> _autocompleteOptionKeys;
  late final DictionaryUsageStore _dictionaryUsage;
  late final Map<String, FocusNode> _draftFocusNodes;
  late final Map<String, VoidCallback> _draftControllerListeners;
  late final Map<String, VoidCallback> _draftFocusListeners;
  final Set<String> _focusedDraftFields = <String>{};
  final Set<String> _acquiringDraftFields = <String>{};
  bool _disposing = false;
  CollaborationProvider? _collaborationProvider;
  bool _validationAttempted = false;
  Timer? _lockExpiryTimer;
  bool _applyingSharedDraft = false;
  bool _historyReuseInProgress = false;
  bool _submissionInProgress = false;
  bool _clearInProgress = false;
  String? _lastSharedDraftSignature;
  String? _lastSharedDraftId;
  bool _sharedDraftSyncScheduled = false;
  final Set<String> _deferredSharedDraftFields = <String>{};
  final Set<String> _suppressFocusFlushFields = <String>{};
  Future<LiveDraftHistoryPreviewDto?>? _historyPreviewPublish;
  String? _historyPreviewPublishCallsign;
  int _historyPreviewGeneration = 0;
  int _lastHistoryReuseEpoch = 0;
  late final Map<String, int> _aiFieldRevisions;
  int _aiRecordEpoch = 0;
  static const Set<String> _inlineAiFields = <String>{
    'device',
    'antenna',
    'qth',
    'height',
    'power',
  };
  final Map<String, Timer> _inlineAiDebounce = <String, Timer>{};
  final Map<String, AiCancellationToken> _inlineAiTokens =
      <String, AiCancellationToken>{};
  final Map<String, int> _inlineAiGenerations = <String, int>{};
  final Map<String, String> _inlineAiSuggestions = <String, String>{};
  final Map<String, String> _acceptedInlineAiValues = <String, String>{};
  final Map<String, String?> _inlineAiCache = <String, String?>{};
  final Set<String> _inlineAiPending = <String>{};
  bool _refreshingInlineAiOptions = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalShortcut);
    _reportController.text = '59';
    _rstRcvdController.text = '59';
    _draftControllers = {
      'time': _timeController,
      'controller': _controllerController,
      'callsign': _callsignController,
      'rstSent': _reportController,
      'rstRcvd': _rstRcvdController,
      'qth': _qthController,
      'device': _deviceController,
      'power': _powerController,
      'antenna': _antennaController,
      'height': _heightController,
      'remarks': _remarksController,
    };
    _dictionaryUsage = DictionaryUsageStore.shared()..ensureLoaded();
    _autocompleteOptionKeys = {
      for (final field in _draftControllers.keys) field: GlobalKey(),
    };
    _draftFocusNodes = {
      for (final field in _draftControllers.keys)
        field: field == 'callsign' ? _callsignFocusNode : FocusNode(),
    };
    _aiFieldRevisions = {
      for (final field in AiCandidateGuard.supportedFields) field: 0,
    };
    _draftControllerListeners = {
      for (final field in _draftControllers.keys)
        field: () => _onDraftFieldChanged(field),
    };
    _draftFocusListeners = {
      for (final field in _draftFocusNodes.keys)
        field: () => _onDraftFocusChanged(field),
    };
    for (final entry in _draftControllers.entries) {
      entry.value.addListener(_draftControllerListeners[entry.key]!);
    }
    for (final entry in _draftFocusNodes.entries) {
      entry.value.addListener(_draftFocusListeners[entry.key]!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _collaborationProvider = context.read<CollaborationProvider>();
  }

  bool _handleGlobalShortcut(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return false;
    }
    if (!HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      return false;
    }
    if (!mounted ||
        !widget.saveShortcutEnabled ||
        _submissionInProgress ||
        ModalRoute.of(context)?.isCurrent == false) {
      return false;
    }
    final collaboration = context.read<CollaborationProvider>();
    if (widget.readOnly ||
        (collaboration.liveDraftSnapshot != null &&
            !collaboration.canEditLiveDraft)) {
      return false;
    }
    final hasForeignLock = collaboration.liveDraftLocks.any(
      (lock) =>
          lock.expiresAt.isAfter(DateTime.now()) &&
          collaboration.fieldLockedByAnotherUser(lock.field),
    );
    if (hasForeignLock || _historyReuseInProgress || _clearInProgress) {
      return false;
    }
    unawaited(_submitForm());
    return true;
  }

  @override
  void dispose() {
    _outsideTap.dispose();
    _disposing = true;
    _historyPreviewGeneration += 1;
    HardwareKeyboard.instance.removeHandler(_handleGlobalShortcut);
    _lockExpiryTimer?.cancel();
    _duplicateCallsignDebounce?.cancel();
    for (final timer in _inlineAiDebounce.values) {
      timer.cancel();
    }
    for (final token in _inlineAiTokens.values) {
      token.cancel();
    }
    for (final timer in _draftDebounce.values) {
      timer.cancel();
    }
    final collaboration = _collaborationProvider;
    if (collaboration != null) {
      if (collaboration.liveDraftHistoryPreviewOwnedHere) {
        unawaited(
          collaboration.clearLiveDraftHistoryPreview().catchError((_) {}),
        );
      }
      for (final field in collaboration.ownedLiveDraftLocks.keys) {
        unawaited(collaboration.releaseLiveDraftField(field));
      }
    }
    for (final entry in _draftControllers.entries) {
      entry.value.removeListener(_draftControllerListeners[entry.key]!);
    }
    for (final entry in _draftFocusNodes.entries) {
      entry.value.removeListener(_draftFocusListeners[entry.key]!);
      if (entry.key != 'callsign') entry.value.dispose();
    }
    _controllerController.dispose();
    _callsignController.dispose();
    _callsignFocusNode.dispose();
    _deviceController.dispose();
    _antennaController.dispose();
    _powerController.dispose();
    _qthController.dispose();
    _heightController.dispose();
    _timeController.dispose();
    _reportController.dispose();
    _rstRcvdController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _syncSharedDraft(CollaborationProvider collaboration) {
    final snapshot = collaboration.liveDraftSnapshot;
    final fields = collaboration.liveDraftDisplayFields;
    final historyReuseEpoch = collaboration.liveDraftHistoryReuseEpoch;
    final forcedHistoryFields = historyReuseEpoch == _lastHistoryReuseEpoch
        ? const <String>{}
        : collaboration.liveDraftHistoryReuseAffectedFields;
    if (snapshot == null || fields == null) {
      _lastSharedDraftId = null;
      _lastSharedDraftSignature = null;
      _deferredSharedDraftFields.clear();
      _lastHistoryReuseEpoch = historyReuseEpoch;
      return;
    }
    final signature = '${snapshot.draft.draftId}:${snapshot.draft.version}:'
        '${fields.toJson()}';
    if (_lastSharedDraftSignature == signature &&
        _deferredSharedDraftFields.isEmpty &&
        forcedHistoryFields.isEmpty) {
      return;
    }
    final draftChanged = _lastSharedDraftId != snapshot.draft.draftId;
    if (draftChanged) {
      _deferredSharedDraftFields.clear();
      _aiRecordEpoch += 1;
    }
    _lastSharedDraftId = snapshot.draft.draftId;
    _lastSharedDraftSignature = signature;
    _lastHistoryReuseEpoch = historyReuseEpoch;
    _applyingSharedDraft = true;
    try {
      for (final entry in _draftControllers.entries) {
        final rawValue = fields[entry.key];
        final value =
            entry.key == 'time' ? _displayLiveDraftTime(rawValue) : rawValue;
        if (forcedHistoryFields.contains(entry.key)) {
          _draftDebounce.remove(entry.key)?.cancel();
          _deferredSharedDraftFields.remove(entry.key);
          final focusNode = _draftFocusNodes[entry.key];
          if (focusNode?.hasFocus ?? false) {
            _suppressFocusFlushFields.add(entry.key);
            focusNode!.unfocus();
            _focusedDraftFields.remove(entry.key);
          }
          if (entry.value.text != value ||
              !entry.value.value.composing.isCollapsed) {
            entry.value.value = TextEditingValue(
              text: value,
              selection: TextSelection.collapsed(offset: value.length),
            );
          }
          _suppressFocusFlushFields.remove(entry.key);
          continue;
        }
        if (_hasActiveUpperCaseComposition(entry.key)) {
          if (entry.value.text != value) {
            _deferredSharedDraftFields.add(entry.key);
          } else {
            _deferredSharedDraftFields.remove(entry.key);
          }
          continue;
        }
        if (!draftChanged &&
            _focusedDraftFields.contains(entry.key) &&
            collaboration.isLiveDraftFieldDirty(entry.key)) {
          if (entry.value.text != value) {
            _deferredSharedDraftFields.add(entry.key);
          } else {
            _deferredSharedDraftFields.remove(entry.key);
          }
          continue;
        }
        _deferredSharedDraftFields.remove(entry.key);
        if (entry.value.text == value) continue;
        entry.value.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    } finally {
      _applyingSharedDraft = false;
    }
  }

  void _scheduleSharedDraftSync() {
    if (_sharedDraftSyncScheduled) return;
    _sharedDraftSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sharedDraftSyncScheduled = false;
      if (!mounted) return;
      // A provider notification can rebuild this form while Windows is still
      // dispatching a resize or IME callback. Updating TextEditingControllers
      // from build re-enters the platform text-input connection at exactly
      // that point. Apply the canonical draft only after the frame instead.
      _syncSharedDraft(context.read<CollaborationProvider>());
    });
  }

  void _onDraftFieldChanged(String field) {
    if (!mounted) return;
    if (_refreshingInlineAiOptions) return;
    if (field == 'callsign') {
      _duplicateCallsignDebounce?.cancel();
      _duplicateCallsignDebounce = null;
      final callsign = _callsignController.text.trim().toUpperCase();
      if (_lastDuplicatePromptedCallsign != callsign) {
        _lastDuplicatePromptedCallsign = null;
      }
      // Selection, focus, and composing updates also notify this listener.
      // Authorship may only change when the text itself changed.
      final textChanged = callsign != _observedCallsign;
      _observedCallsign = callsign;
      if (textChanged) {
        // A collaborator's keystroke or a post-commit reset draft arrives
        // through _applyingSharedDraft. It is not input on this device, so the
        // record it duplicates must not raise the prompt here.
        _locallyTypedCallsign = _applyingSharedDraft ? null : callsign;
      }
    }
    if (_aiFieldRevisions.containsKey(field)) {
      _aiFieldRevisions[field] = _aiFieldRevisions[field]! + 1;
    }
    if (_applyingSharedDraft) return;
    if (_hasActiveUpperCaseComposition(field)) {
      _draftDebounce.remove(field)?.cancel();
      return;
    }
    if (field == 'callsign') {
      _scheduleDuplicateCallsignCheck();
    }
    if (_inlineAiFields.contains(field)) {
      _scheduleInlineAiSuggestion(field);
    }
    final collaboration = context.read<CollaborationProvider>();
    if (field == 'time') collaboration.cancelAutomaticLiveDraftTime();
    if (collaboration.liveDraftSnapshot == null ||
        !collaboration.canEditLiveDraft) {
      return;
    }
    collaboration.stageLiveDraftField(
      field,
      _draftControllers[field]!.text,
    );
    if (collaboration.isLiveDraftFieldDirty(field) &&
        !collaboration.ownedLiveDraftLocks.containsKey(field)) {
      unawaited(_acquireDraftField(field, collaboration));
    }
    _draftDebounce.remove(field)?.cancel();
    _draftDebounce[field] = Timer(const Duration(milliseconds: 250), () {
      _draftDebounce.remove(field);
      if (!mounted) return;
      final value = _draftControllers[field]!.text;
      unawaited(() async {
        try {
          final flushedLeaseId =
              collaboration.ownedLiveDraftLocks[field]?.leaseId;
          await collaboration.flushLiveDraftField(field);
          if (!mounted ||
              _draftControllers[field]!.text != value ||
              collaboration.isLiveDraftFieldDirty(field)) {
            return;
          }
          // Keep the lease only while an edit is crossing the network. An
          // idle cursor must not block another scribe from saving the record;
          // a later keystroke acquires a fresh lease.
          await collaboration.releaseLiveDraftFieldIfClean(
            field,
            expectedLeaseId: flushedLeaseId,
          );
        } catch (_) {
          // The provider retains the dirty value and exposes the final error.
        }
      }());
    });
  }

  void _scheduleInlineAiSuggestion(String field) {
    _inlineAiDebounce.remove(field)?.cancel();
    _inlineAiTokens.remove(field)?.cancel();
    final generation = (_inlineAiGenerations[field] ?? 0) + 1;
    _inlineAiGenerations[field] = generation;
    final controller = _draftControllers[field]!;
    final value = controller.text.trim();
    if (!(_draftFocusNodes[field]?.hasFocus ?? false) ||
        value.isEmpty ||
        _acceptedInlineAiValues[field] == value) {
      _clearInlineAiSuggestion(field);
      return;
    }
    if ((field == 'power' || field == 'height') && containsCjkText(value)) {
      // Descriptive values such as 地面 / 高架 / 中功率 are already useful as
      // entered and should not be interrupted by a formatting suggestion.
      _clearInlineAiSuggestion(field);
      return;
    }
    final settings = Provider.of<AiRecognitionSettingsProvider?>(
      context,
      listen: false,
    );
    if (settings == null ||
        !settings.textAssistantEnabled ||
        !settings.inlineTextSuggestionsEnabled) {
      _clearInlineAiSuggestion(field);
      return;
    }
    final references = _inlineDictionaryReferences(field, value);
    if (references.any((item) => item == value)) {
      _clearInlineAiSuggestion(field);
      return;
    }
    _inlineAiDebounce[field] = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(
        _requestInlineAiSuggestion(
          field: field,
          value: value,
          references: references,
          generation: generation,
          settings: settings,
        ),
      ),
    );
  }

  List<String> _inlineDictionaryReferences(String field, String value) {
    final provider = context.read<DictionaryProvider>();
    final items = switch (field) {
      'device' => provider.filterDevices(value),
      'antenna' => provider.filterAntennas(value),
      'qth' => provider.filterQths(value),
      _ => const <DictionaryItem>[],
    };
    return items.take(8).map((item) => item.raw).toList(growable: false);
  }

  Future<void> _requestInlineAiSuggestion({
    required String field,
    required String value,
    required List<String> references,
    required int generation,
    required AiRecognitionSettingsProvider settings,
  }) async {
    if (!mounted || _inlineAiGenerations[field] != generation) return;
    final signature = settings.textAssistantConfig?.signature ?? '';
    final cacheKey = '$signature\u0000$field\u0000$value';
    if (_inlineAiCache.containsKey(cacheKey)) {
      _adoptInlineAiSuggestion(
        field,
        value,
        generation,
        _inlineAiCache[cacheKey],
      );
      return;
    }
    final token = AiCancellationToken();
    _inlineAiTokens[field] = token;
    setState(() => _inlineAiPending.add(field));
    try {
      final executor = widget.inlineTextSuggestionExecutor ??
          TextAssistantTasks.suggestInline;
      final suggestion = await executor(
        settings: settings,
        field: field,
        value: value,
        localReferences: references,
        cancellationToken: token,
      );
      _inlineAiCache[cacheKey] = suggestion;
      _adoptInlineAiSuggestion(field, value, generation, suggestion);
    } catch (_) {
      // Inline assistance is opportunistic and must never interrupt typing.
    } finally {
      if (_inlineAiTokens[field] == token) _inlineAiTokens.remove(field);
      if (mounted && _inlineAiGenerations[field] == generation) {
        setState(() => _inlineAiPending.remove(field));
      }
    }
  }

  void _adoptInlineAiSuggestion(
    String field,
    String source,
    int generation,
    String? suggestion,
  ) {
    if (!mounted ||
        _inlineAiGenerations[field] != generation ||
        !(_draftFocusNodes[field]?.hasFocus ?? false) ||
        _draftControllers[field]!.text.trim() != source) {
      return;
    }
    setState(() {
      if (suggestion == null || suggestion == source) {
        _inlineAiSuggestions.remove(field);
      } else {
        _inlineAiSuggestions[field] = suggestion;
      }
    });
    _queueInlineAiOptionsRefresh(field);
  }

  void _clearInlineAiSuggestion(String field) {
    if (!_inlineAiSuggestions.containsKey(field) &&
        !_inlineAiPending.contains(field)) {
      return;
    }
    if (mounted) {
      setState(() {
        _inlineAiSuggestions.remove(field);
        _inlineAiPending.remove(field);
      });
      _queueInlineAiOptionsRefresh(field);
    }
  }

  void _queueInlineAiOptionsRefresh(String field) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !(_draftFocusNodes[field]?.hasFocus ?? false)) return;
      final controller = _draftControllers[field];
      if (controller == null || controller.text.isEmpty) return;
      final original = controller.value;
      _refreshingInlineAiOptions = true;
      try {
        // RawAutocomplete only reevaluates options after the text changes.
        // This synchronous pulse occurs after the new options builder is
        // installed, so no empty value reaches a frame or the live draft.
        controller.value = const TextEditingValue();
        controller.value = original;
      } finally {
        _refreshingInlineAiOptions = false;
      }
    });
  }

  void _onDraftFocusChanged(String field) {
    if (!mounted) return;
    final focused = _draftFocusNodes[field]?.hasFocus ?? false;
    if (_inlineAiFields.contains(field) && !focused) {
      _inlineAiDebounce.remove(field)?.cancel();
      _inlineAiTokens.remove(field)?.cancel();
      _inlineAiGenerations[field] = (_inlineAiGenerations[field] ?? 0) + 1;
      _clearInlineAiSuggestion(field);
    }
    if (field == 'callsign' && !focused) {
      _duplicateCallsignDebounce?.cancel();
      _duplicateCallsignDebounce = null;
      unawaited(_maybePromptDuplicateUpdate());
    }
    final collaboration = context.read<CollaborationProvider>();
    if (collaboration.liveDraftSnapshot == null) return;
    focused
        ? _focusedDraftFields.add(field)
        : _focusedDraftFields.remove(field);
    if (!focused && !_suppressFocusFlushFields.remove(field)) {
      unawaited(_flushAndReleaseDraftField(field, collaboration));
    }
  }

  void _scheduleDuplicateCallsignCheck() {
    final callsign = _callsignController.text.trim().toUpperCase();
    if (callsign.isEmpty) return;
    _duplicateCallsignDebounce = Timer(
      const Duration(milliseconds: 700),
      () {
        _duplicateCallsignDebounce = null;
        if (!mounted ||
            _callsignController.text.trim().toUpperCase() != callsign) {
          return;
        }
        unawaited(_maybePromptDuplicateUpdate(expectedCallsign: callsign));
      },
    );
  }

  Future<void> _maybePromptDuplicateUpdate({String? expectedCallsign}) async {
    if (!mounted || _duplicatePromptInProgress) return;
    final settingsProvider = context.read<SettingsProvider>();
    if (!settingsProvider.duplicateCallsignWarningEnabled) return;
    final collaboration = context.read<CollaborationProvider>();
    if (collaboration.liveDraftSnapshot != null &&
        !collaboration.canEditLiveDraft) {
      return;
    }
    if (widget.readOnly ||
        _historyReuseInProgress ||
        _submissionInProgress ||
        _clearInProgress) {
      return;
    }
    final callsign = _callsignController.text.trim().toUpperCase();
    if (callsign.isEmpty ||
        (expectedCallsign != null && callsign != expectedCallsign) ||
        // Only a callsign this operator typed can be a duplicate *entry*. A
        // collaborator's value or a post-commit reset draft must not prompt.
        _locallyTypedCallsign != callsign ||
        _lastDuplicatePromptedCallsign == callsign) {
      return;
    }
    final logProvider = context.read<LogProvider>();
    final existing = logProvider.logs
        .where((log) => log.callsign.trim().toUpperCase() == callsign)
        .toList(growable: false);
    if (existing.isEmpty || !mounted) return;
    final l10n = context.l10n;
    final ordinal = logProvider.logs.indexOf(existing.last) + 1;
    _duplicatePromptInProgress = true;
    _lastDuplicatePromptedCallsign = callsign;
    bool? continueAdding;
    try {
      continueAdding = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.duplicateContinueDialogTitle),
          content: Text(l10n.duplicateContinueDialogMessage(callsign, ordinal)),
          actions: [
            TextButton(
              key: const Key('duplicate-continue-cancel'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const Key('duplicate-continue-add'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.duplicateContinueAdd),
            ),
          ],
        ),
      );
    } finally {
      _duplicatePromptInProgress = false;
    }
    if (!mounted || continueAdding == true) return;
    // 用户选择不继续，清空呼号让书记员重录或改录。
    if (collaboration.liveDraftSnapshot != null) {
      try {
        await collaboration.updateLiveDraftFieldsAtomically(
          const {'callsign': ''},
        );
        if (!mounted) return;
        _syncSharedDraft(collaboration);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showLoggedSnackBar(
          SnackBar(content: Text(context.l10n.operationFailed('$error'))),
        );
        return;
      }
    } else {
      _callsignController.clear();
    }
    FocusScope.of(context).requestFocus(_callsignFocusNode);
  }

  Future<void> _updateExistingLog(
    LogEntry existing,
    String callsign,
    ScaffoldMessengerState? messenger,
    AppLocalizations l10n,
  ) async {
    final logProvider = context.read<LogProvider>();
    final dictionaryProvider =
        Provider.of<DictionaryProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    if (existing.sessionId == null || existing.id.isEmpty) {
      messenger?.showLoggedSnackBar(
        SnackBar(content: Text(l10n.operationFailed('missing id'))),
      );
      return;
    }
    // 保留旧记录的时间，只更新其余字段。
    final patch = existing.copyWith(
      controller: _controllerController.text.trim(),
      callsign: callsign,
      report: _reportController.text.trim(),
      rstRcvd: _rstRcvdController.text.trim(),
      qth: _qthController.text.trim(),
      device: _deviceController.text.trim(),
      power: settingsProvider.autoAppendPowerW
          ? normalizePower(_powerController.text.trim())
          : _powerController.text.trim(),
      antenna: _antennaController.text.trim(),
      height: _heightController.text.trim(),
    )..remarks = _remarksController.text.trim();
    if (_deviceController.text.trim().isNotEmpty) {
      await dictionaryProvider.addDevice(_deviceController.text.trim());
    }
    if (_antennaController.text.trim().isNotEmpty) {
      await dictionaryProvider.addAntenna(_antennaController.text.trim());
    }
    if (_qthController.text.trim().isNotEmpty) {
      await dictionaryProvider.addQth(_qthController.text.trim());
    }
    try {
      await logProvider.updateLogFromOriginal(existing, patch);
    } catch (error) {
      if (!mounted) return;
      messenger?.showLoggedSnackBar(
        SnackBar(content: Text(l10n.operationFailed('$error'))),
      );
      return;
    }
    if (!mounted) return;
    _resetForm();
    messenger?.showLoggedSnackBar(
      SnackBar(content: Text(l10n.recordUpdated)),
    );
  }

  Future<void> _acquireDraftField(
    String field,
    CollaborationProvider collaboration,
  ) async {
    if (!_acquiringDraftFields.add(field)) return;
    try {
      final acquired = await collaboration.acquireLiveDraftField(field);
      if (_disposing ||
          !mounted ||
          !collaboration.isLiveDraftFieldDirty(field)) {
        await collaboration.releaseLiveDraftFieldIfClean(
          field,
          expectedLeaseId: acquired.leaseId,
        );
      }
    } catch (_) {
      if (_disposing || !mounted) return;
      // Refreshing exposes the holder and disables the field after a lock race.
      try {
        await collaboration.refreshLiveDraft();
      } catch (_) {}
      if (mounted) setState(() {});
    } finally {
      _acquiringDraftFields.remove(field);
    }
  }

  Future<void> _flushAndReleaseDraftField(
    String field,
    CollaborationProvider collaboration,
  ) async {
    _commitUpperCaseDraftField(field);
    _draftDebounce.remove(field)?.cancel();
    if (collaboration.canEditLiveDraft) {
      try {
        await collaboration.updateLiveDraftField(
          field,
          _draftControllers[field]!.text,
        );
      } catch (_) {
        // The provider exposes the protocol error and retains the local value.
      }
    }
    await collaboration.releaseLiveDraftFieldIfClean(field);
    if (mounted && _deferredSharedDraftFields.contains(field)) {
      _syncSharedDraft(collaboration);
    }
  }

  bool _hasActiveUpperCaseComposition(String field) {
    final controller = _draftControllers[field];
    return _upperCaseDraftFields.contains(field) &&
        controller != null &&
        ImeSafeUpperCaseTextFormatter.hasActiveComposition(controller.value);
  }

  void _commitUpperCaseDraftField(String field) {
    if (!_upperCaseDraftFields.contains(field)) return;
    final controller = _draftControllers[field];
    if (controller == null) return;
    final committed = ImeSafeUpperCaseTextFormatter.commit(controller.value);
    if (committed != controller.value) controller.value = committed;
  }

  void _commitUpperCaseIdentifiers() {
    for (final field in _upperCaseDraftFields) {
      _commitUpperCaseDraftField(field);
    }
  }

  String _displayLiveDraftTime(String value) {
    return formatLogTimeForDisplay(value);
  }

  void _unfocusDraftFields() {
    FocusManager.instance.primaryFocus?.unfocus();
    for (final focusNode in _draftFocusNodes.values) {
      if (focusNode.hasFocus) focusNode.unfocus();
    }
  }

  Future<void> _publishHistoryPreview(
    String callsign,
    List<bridge.LogEntry> records,
  ) async {
    if (!mounted || records.isEmpty) return;
    final collaboration = context.read<CollaborationProvider>();
    final normalizedCallsign = callsign.trim().toUpperCase();
    if (normalizedCallsign.isEmpty ||
        collaboration.liveDraftSnapshot == null ||
        !collaboration.canEditLiveDraft ||
        !_callsignFocusNode.hasFocus ||
        _callsignController.text.trim().toUpperCase() != normalizedCallsign) {
      return;
    }
    final candidates = <LiveDraftHistoryCandidateDto>[];
    final seenIds = <String>{};
    for (final record in records) {
      final sourceTime = DateTime.tryParse(record.time)?.toUtc();
      if (sourceTime == null ||
          record.syncId.isEmpty ||
          !seenIds.add(record.syncId)) {
        continue;
      }
      final candidate = LiveDraftHistoryCandidateDto(
        candidateId: record.syncId,
        sourceTime: sourceTime.toIso8601String(),
        qth: record.qth?.trim() ?? '',
        device: record.device?.trim() ?? '',
        power: record.power?.trim() ?? '',
        antenna: record.antenna?.trim() ?? '',
        height: record.height?.trim() ?? '',
      );
      if (candidate.reusableValues.isEmpty) continue;
      candidates.add(candidate);
      if (candidates.length == 10) break;
    }
    if (candidates.isEmpty) return;

    final generation = ++_historyPreviewGeneration;
    _historyPreviewPublishCallsign = normalizedCallsign;
    late final Future<LiveDraftHistoryPreviewDto?> operation;
    operation = () async {
      try {
        // History lookup may finish before the normal 250 ms PATCH debounce.
        // Commit the callsign first, then publish under a freshly held lease.
        _draftDebounce.remove('callsign')?.cancel();
        await collaboration.flushLiveDraftField('callsign');
        if (!mounted ||
            generation != _historyPreviewGeneration ||
            !_callsignFocusNode.hasFocus ||
            _callsignController.text.trim().toUpperCase() !=
                normalizedCallsign) {
          return null;
        }
        final preview = await collaboration.publishLiveDraftHistoryPreview(
          callsign: normalizedCallsign,
          candidates: candidates,
        );
        if (!mounted || generation != _historyPreviewGeneration) {
          if (preview != null) {
            await collaboration.clearLiveDraftHistoryPreview(
              expectedPreviewId: preview.previewId,
            );
          }
          return null;
        }
        return preview;
      } catch (_) {
        // Cross-device preview is an enhancement. Local history reuse remains
        // available when the server is old, offline, or temporarily slow.
        return null;
      }
    }();
    _historyPreviewPublish = operation;
    await operation;
    if (identical(_historyPreviewPublish, operation)) {
      _historyPreviewPublish = null;
      _historyPreviewPublishCallsign = null;
    }
  }

  Future<void> _dismissHistoryPreview() async {
    _historyPreviewGeneration += 1;
    final collaboration = _collaborationProvider;
    if (collaboration != null) {
      try {
        await collaboration.clearLiveDraftHistoryPreview();
      } catch (_) {
        // The preview expires server-side and must never block local input.
      }
    }
  }

  Future<void> _reuseHistoryRecord(bridge.LogEntry record) async {
    final values = <String, String>{
      if (record.device?.isNotEmpty ?? false) 'device': record.device!,
      if (record.antenna?.isNotEmpty ?? false) 'antenna': record.antenna!,
      if (record.qth?.isNotEmpty ?? false) 'qth': record.qth!,
      if (record.power?.isNotEmpty ?? false) 'power': record.power!,
      if (record.height?.isNotEmpty ?? false) 'height': record.height!,
    };
    if (values.isEmpty || !mounted) return;

    final collaboration = context.read<CollaborationProvider>();
    if (collaboration.liveDraftSnapshot != null) {
      setState(() => _historyReuseInProgress = true);
      try {
        final pendingPreview = _historyPreviewPublishCallsign ==
                _callsignController.text.trim().toUpperCase()
            ? _historyPreviewPublish
            : null;
        if (pendingPreview != null) await pendingPreview;
        if (!mounted) return;
        final preview = collaboration.liveDraftHistoryPreview;
        if (preview != null &&
            collaboration.liveDraftHistoryPreviewOwnedHere &&
            preview.candidates.any(
              (candidate) => candidate.candidateId == record.syncId,
            )) {
          final selected = await collaboration.selectLiveDraftHistoryCandidate(
            previewId: preview.previewId,
            candidateId: record.syncId,
          );
          if (selected) {
            _callsignFocusNode.unfocus();
            await collaboration.releaseLiveDraftFieldIfClean('callsign');
            return;
          }
        }
        if (!mounted) return;

        // Compatibility path for servers without shared history previews.
        // Unlike the canonical select route, a legacy atomic PATCH may not
        // override fields actively leased by another member.
        for (final field in values.keys) {
          final holder = collaboration.lockForField(field);
          if (holder != null &&
              holder.expiresAt.isAfter(DateTime.now()) &&
              collaboration.fieldLockedByAnotherUser(field)) {
            ScaffoldMessenger.of(context).showLoggedSnackBar(
              SnackBar(
                content: Text(context.l10n.fieldLockedBy(holder.username)),
              ),
            );
            return;
          }
        }

        for (final field in values.keys) {
          _draftDebounce.remove(field)?.cancel();
        }
        _unfocusDraftFields();
        await collaboration.updateLiveDraftFieldsOptimistically(values);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showLoggedSnackBar(
            SnackBar(
                content: Text(context.l10n.operationFailed(error.toString()))),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _historyReuseInProgress = false);
      }
      if (!mounted) return;
      // The provider stages the batch immediately, then adopts the canonical
      // response. Let _syncSharedDraft drive the controllers so a newer edit
      // made while the request was in flight is never overwritten here.
      return;
    }

    _applyingSharedDraft = true;
    try {
      for (final entry in values.entries) {
        final controller = _draftControllers[entry.key];
        if (controller == null || controller.text == entry.value) continue;
        controller.value = TextEditingValue(
          text: entry.value,
          selection: TextSelection.collapsed(offset: entry.value.length),
        );
      }
    } finally {
      _applyingSharedDraft = false;
    }
  }

  Future<void> _submitForm() async {
    if (_submissionInProgress) return;
    _commitUpperCaseIdentifiers();
    final collaboration = context.read<CollaborationProvider>();
    if (widget.readOnly ||
        (collaboration.binding != null &&
            collaboration.liveDraftSnapshot != null &&
            !collaboration.canEditLiveDraft)) {
      return;
    }
    setState(() => _validationAttempted = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submissionInProgress = true);
    try {
      await _submitValidatedForm(collaboration);
    } catch (error, stackTrace) {
      AppLogger.instance.log(
        AppLogLevel.error,
        'Record form submission failed',
        source: 'LogForm',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showLoggedSnackBar(
          SnackBar(content: Text(context.l10n.operationFailed('$error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _submissionInProgress = false);
    }
  }

  Future<void> _clearEnteredFields() async {
    if (_clearInProgress || _historyReuseInProgress || _submissionInProgress) {
      return;
    }
    final collaboration = context.read<CollaborationProvider>();
    if (widget.readOnly ||
        (collaboration.liveDraftSnapshot != null &&
            !collaboration.canEditLiveDraft)) {
      return;
    }
    final updates = <String, String>{};
    for (final field in _clearableDraftFields) {
      final clearedValue = _clearedDraftDefaults[field] ?? '';
      if (_draftControllers[field]!.text != clearedValue) {
        updates[field] = clearedValue;
      }
    }
    if (updates.isEmpty) return;

    for (final field in _clearableDraftFields) {
      _draftDebounce.remove(field)?.cancel();
    }
    collaboration.cancelAutomaticLiveDraftTime();
    _unfocusDraftFields();
    setState(() => _clearInProgress = true);
    try {
      if (collaboration.liveDraftSnapshot != null) {
        // Do not make the UI look cleared until the shared draft accepts the
        // whole operation. This also prevents one field from being left behind
        // when a collaborator owns a lock.
        await collaboration.updateLiveDraftFieldsAtomically(updates);
      }
      if (!mounted) return;
      _applyClearedFieldsLocally();
      FocusScope.of(context).requestFocus(_callsignFocusNode);
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(context.l10n.enteredFieldsCleared),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showLoggedSnackBar(
          SnackBar(content: Text(context.l10n.operationFailed('$error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _clearInProgress = false);
    }
  }

  void _applyClearedFieldsLocally() {
    _aiRecordEpoch += 1;
    for (final timer in _inlineAiDebounce.values) {
      timer.cancel();
    }
    _inlineAiDebounce.clear();
    for (final token in _inlineAiTokens.values) {
      token.cancel();
    }
    _inlineAiTokens.clear();
    _inlineAiSuggestions.clear();
    _inlineAiPending.clear();
    _acceptedInlineAiValues.clear();

    final controllerCallsign = _controllerController.text;
    _applyingSharedDraft = true;
    try {
      _formKey.currentState?.reset();
      _controllerController.text = controllerCallsign;
      for (final field in _clearableDraftFields) {
        _draftControllers[field]!.text = _clearedDraftDefaults[field] ?? '';
      }
    } finally {
      _applyingSharedDraft = false;
    }
  }

  Future<void> _submitValidatedForm(
    CollaborationProvider collaboration,
  ) async {
    final logProvider = Provider.of<LogProvider>(context, listen: false);
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    final dictionaryProvider =
        Provider.of<DictionaryProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final enteredTime = _timeController.text.trim();
    final usesAutomaticTime = enteredTime.isEmpty;
    final submittedTime = resolveLogTimeForSubmission(enteredTime);
    final submittedFields = <String, String>{
      for (final entry in _draftControllers.entries)
        entry.key: entry.key == 'time'
            ? submittedTime
            : entry.key == 'power' && settingsProvider.autoAppendPowerW
                ? normalizePower(entry.value.text)
                : entry.value.text,
    };

    final normalizedCallsign =
        submittedFields['callsign']!.trim().toUpperCase();
    final duplicate = normalizedCallsign.isNotEmpty &&
        logProvider.logs.any(
          (log) => log.callsign.trim().toUpperCase() == normalizedCallsign,
        );
    if (settingsProvider.duplicateCallsignWarningEnabled && duplicate) {
      final existing = logProvider.logs
          .where(
            (log) => log.callsign.trim().toUpperCase() == normalizedCallsign,
          )
          .toList(growable: false);
      final latest = existing.isEmpty ? null : existing.last;
      final action = await showDialog<_DuplicateAction>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(l10n.duplicateUpdateDialogTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.duplicateUpdateDialogMessage(normalizedCallsign)),
                  if (latest != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(dialogContext)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        l10n.duplicateOldRecordSummary(
                          logProvider.logs.indexOf(latest) + 1,
                          formatLogTimeForDisplay(latest.time),
                          latest.callsign,
                          latest.report,
                          latest.rstRcvd,
                          latest.qth,
                        ),
                        style: Theme.of(dialogContext).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  key: const Key('duplicate-save-cancel'),
                  onPressed: () =>
                      Navigator.pop(dialogContext, _DuplicateAction.cancel),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  key: const Key('duplicate-save-add-new'),
                  onPressed: () =>
                      Navigator.pop(dialogContext, _DuplicateAction.add),
                  child: Text(l10n.duplicateAddNewRecord),
                ),
                FilledButton(
                  key: const Key('duplicate-save-update-old'),
                  onPressed: () =>
                      Navigator.pop(dialogContext, _DuplicateAction.update),
                  child: Text(l10n.duplicateUpdateOldRecord),
                ),
              ],
            ),
          ) ??
          _DuplicateAction.cancel;
      if (!mounted) return;
      if (action == _DuplicateAction.cancel) return;
      if (action == _DuplicateAction.update) {
        if (latest != null) {
          await _updateExistingLog(
            latest,
            normalizedCallsign,
            ScaffoldMessenger.maybeOf(context),
            l10n,
          );
        }
        return;
      }
    }

    if (submittedFields['device']!.isNotEmpty) {
      await dictionaryProvider.addDevice(submittedFields['device']!);
    }
    if (submittedFields['antenna']!.isNotEmpty) {
      await dictionaryProvider.addAntenna(submittedFields['antenna']!);
    }
    if (submittedFields['callsign']!.isNotEmpty) {
      await dictionaryProvider.addCallsign(submittedFields['callsign']!);
    }
    if (submittedFields['qth']!.isNotEmpty) {
      await dictionaryProvider.addQth(submittedFields['qth']!);
    }
    if (!mounted) return;

    if (collaboration.binding != null &&
        collaboration.liveDraftSnapshot != null) {
      if (usesAutomaticTime) {
        collaboration.beginAutomaticLiveDraftTime(submittedTime);
      } else {
        collaboration.cancelAutomaticLiveDraftTime();
      }
      for (final timer in _draftDebounce.values) {
        timer.cancel();
      }
      _draftDebounce.clear();
      for (final entry in submittedFields.entries) {
        try {
          await collaboration.updateLiveDraftField(
            entry.key,
            entry.value,
          );
          if (usesAutomaticTime && entry.key == 'time') {
            collaboration.confirmAutomaticLiveDraftTime();
          }
        } catch (_) {
          // commitCurrentLiveDraft retries retained dirty values and decides
          // whether a network failure should enter the offline review queue.
        }
      }
      final disposition = await collaboration.commitCurrentLiveDraft();
      if (usesAutomaticTime) {
        collaboration.completeAutomaticLiveDraftTime(disposition);
      }
      if (!mounted) return;
      _syncSharedDraft(collaboration);
      messenger.showLoggedSnackBar(
        SnackBar(
          content: Text(
            disposition == LiveDraftCommitDisposition.committed
                ? l10n.recordAdded
                : l10n.recordQueuedOffline,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      FocusScope.of(context).requestFocus(_callsignFocusNode);
      return;
    }

    final log = LogEntry(
      time: submittedTime,
      controller: submittedFields['controller']!,
      callsign: submittedFields['callsign']!,
      report: submittedFields['rstSent']!,
      rstRcvd: submittedFields['rstRcvd']!,
      qth: submittedFields['qth']!,
      device: submittedFields['device']!,
      power: submittedFields['power']!,
      antenna: submittedFields['antenna']!,
      height: submittedFields['height']!,
    );
    log.remarks = submittedFields['remarks']!;

    final targetSession = widget.sessionId ?? sessionProvider.currentSessionId;
    final retryFields = Map<String, String>.of(submittedFields);
    if (usesAutomaticTime) retryFields['time'] = '';
    // On an ambiguous network failure, keep the same ID and automatic time.
    // Re-clicking Save must not create a second remote record.
    final retry = identical(_pendingSubmissionProvider, logProvider) &&
        _pendingSubmissionSession == targetSession &&
        _pendingSubmissionFields?.length == retryFields.length &&
        retryFields.entries
            .every((e) => _pendingSubmissionFields?[e.key] == e.value);
    _pendingSubmission = retry ? _pendingSubmission ?? log : log;
    _pendingSubmissionFields = retryFields;
    _pendingSubmissionProvider = logProvider;
    _pendingSubmissionSession = targetSession;
    await logProvider.addLog(_pendingSubmission!, sessionId: targetSession);
    if (!mounted) return;
    _resetForm();

    messenger.showLoggedSnackBar(
      SnackBar(
        content: Text(l10n.recordAdded),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetForm() {
    _pendingSubmission = null;
    _pendingSubmissionFields = null;
    _pendingSubmissionProvider = null;
    _pendingSubmissionSession = null;
    setState(() => _validationAttempted = false);
    _aiRecordEpoch += 1;
    for (final timer in _inlineAiDebounce.values) {
      timer.cancel();
    }
    _inlineAiDebounce.clear();
    for (final token in _inlineAiTokens.values) {
      token.cancel();
    }
    _inlineAiTokens.clear();
    _inlineAiSuggestions.clear();
    _inlineAiPending.clear();
    _acceptedInlineAiValues.clear();
    // 主控呼号在连续添加时应保留，先保存再恢复。
    final controllerCallsign = _controllerController.text;
    _formKey.currentState?.reset();
    _controllerController.text = controllerCallsign;
    _callsignController.clear();
    _deviceController.clear();
    _antennaController.clear();
    _powerController.clear();
    _qthController.clear();
    _heightController.clear();
    _timeController.clear();
    _reportController.text = '59';
    _rstRcvdController.text = '59';
    _remarksController.clear();
    FocusScope.of(context).requestFocus(_callsignFocusNode);
  }

  AiDraftSnapshot _captureAiDraft(int captureGeneration) {
    final sessionProvider = context.read<SessionProvider>();
    final collaboration = context.read<CollaborationProvider>();
    final remoteRevisions =
        collaboration.liveDraftSnapshot?.draft.fieldRevisions;
    return AiDraftSnapshot(
      sessionId: widget.sessionId ?? sessionProvider.currentSessionId ?? '',
      recordEpoch: _aiRecordEpoch,
      captureGeneration: captureGeneration,
      draftId: collaboration.liveDraftSnapshot?.draft.draftId,
      fields: {
        for (final field in AiCandidateGuard.supportedFields)
          field: AiDraftFieldSnapshot(
            value: _draftControllers[field]?.text ?? '',
            revision: Object.hash(
              _aiFieldRevisions[field] ?? 0,
              remoteRevisions?[field] ?? 0,
            ),
            remoteRevision: remoteRevisions?[field],
          ),
      },
    );
  }

  AiCandidateApplicationState _currentAiDraftState(
    int captureGeneration,
    CollaborationProvider collaboration,
    bool readOnly,
  ) {
    final composingFields = <String>{};
    for (final entry in _draftControllers.entries) {
      final composing = entry.value.value.composing;
      if (composing.isValid && !composing.isCollapsed) {
        composingFields.add(entry.key);
      }
    }
    final lockedFields = <String>{
      for (final field in AiCandidateGuard.supportedFields)
        if (collaboration.fieldLockedByAnotherUser(field)) field,
    };
    return AiCandidateApplicationState(
      snapshot: _captureAiDraft(captureGeneration),
      focusedFields: {
        for (final entry in _draftFocusNodes.entries)
          if (entry.value.hasFocus) entry.key,
      },
      composingFields: composingFields,
      lockedFields: lockedFields,
      readOnly: readOnly,
      busy:
          _historyReuseInProgress || _clearInProgress || _submissionInProgress,
    );
  }

  Future<void> _applyAiCandidateFields(
    Map<String, String> values,
    AiDraftSnapshot expectedSnapshot,
    CollaborationProvider collaboration,
  ) async {
    final normalized = <String, String>{
      for (final entry in values.entries)
        if (AiCandidateGuard.supportedFields.contains(entry.key))
          entry.key: _upperCaseDraftFields.contains(entry.key)
              ? entry.value.trim().toUpperCase()
              : entry.value.trim(),
    };
    if (normalized.isEmpty) return;

    if (collaboration.liveDraftSnapshot != null) {
      final expectedDraftId = expectedSnapshot.draftId;
      if (expectedDraftId == null) {
        throw StateError('LIVE_DRAFT_SUGGESTION_STALE');
      }
      final expectedValues = <String, String>{};
      final expectedRevisions = <String, int>{};
      for (final field in normalized.keys) {
        final expected = expectedSnapshot.fields[field];
        final remoteRevision = expected?.remoteRevision;
        if (expected == null || remoteRevision == null) {
          throw StateError('LIVE_DRAFT_SUGGESTION_STALE');
        }
        expectedValues[field] = expected.value;
        expectedRevisions[field] = remoteRevision;
      }
      // AI suggestions are never rebased over a collaborator's newer edit.
      await collaboration.updateLiveDraftFieldsStrict(
        normalized,
        expectedDraftId: expectedDraftId,
        expectedValues: expectedValues,
        expectedRevisions: expectedRevisions,
      );
      return;
    }

    _applyingSharedDraft = true;
    try {
      for (final entry in normalized.entries) {
        final controller = _draftControllers[entry.key];
        if (controller == null || controller.text == entry.value) continue;
        controller.value = TextEditingValue(
          text: entry.value,
          selection: TextSelection.collapsed(offset: entry.value.length),
        );
      }
    } finally {
      _applyingSharedDraft = false;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dictionaryProvider = Provider.of<DictionaryProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final collaboration = Provider.of<CollaborationProvider>(context);
    final aiSettings = Provider.of<AiRecognitionSettingsProvider?>(context);
    _scheduleSharedDraftSync();
    final sharedDraft = collaboration.liveDraftSnapshot != null;
    final readOnly =
        widget.readOnly || (sharedDraft && !collaboration.canEditLiveDraft);

    bool isActiveForeignLock(String field) {
      final lock = collaboration.lockForField(field);
      return lock != null &&
          lock.expiresAt.isAfter(DateTime.now()) &&
          collaboration.fieldLockedByAnotherUser(field);
    }

    final activeForeignLocks = collaboration.liveDraftLocks
        .where(
          (lock) =>
              lock.expiresAt.isAfter(DateTime.now()) &&
              collaboration.fieldLockedByAnotherUser(lock.field),
        )
        .toList(growable: false);
    _scheduleLockExpiryRefresh(activeForeignLocks);
    final firstForeignLock =
        activeForeignLocks.isEmpty ? null : activeForeignLocks.first;
    final clearableForeignLocks = activeForeignLocks
        .where((lock) => _clearableDraftFields.contains(lock.field))
        .toList(growable: false);
    final canSubmit = !readOnly &&
        firstForeignLock == null &&
        !_historyReuseInProgress &&
        !_clearInProgress &&
        !_submissionInProgress;
    final canClear = !readOnly &&
        clearableForeignLocks.isEmpty &&
        !_historyReuseInProgress &&
        !_clearInProgress &&
        !_submissionInProgress;

    bool fieldEnabled(String field) => !readOnly && !isActiveForeignLock(field);

    String fieldLabel(String field, String fallback) {
      final lock = collaboration.lockForField(field);
      if (lock == null || !isActiveForeignLock(field)) {
        return fallback;
      }
      return '$fallback · ${context.l10n.fieldLockedBy(lock.username)}';
    }

    final content = LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用宽度计算每行显示几个字段
        final availableWidth = constraints.maxWidth;
        final isNarrow = availableWidth < 600;
        final fieldWidth = isNarrow ? 160.0 : 200.0;
        final spacing = isNarrow ? 8.0 : 12.0;
        final fieldsPerRow =
            ((availableWidth + spacing) / (fieldWidth + spacing))
                .floor()
                .clamp(1, 5);
        final calculatedFieldWidth =
            (availableWidth - (spacing * (fieldsPerRow - 1))) / fieldsPerRow;
        final primaryFieldWidth =
            isNarrow ? availableWidth : calculatedFieldWidth;
        final clearButtonWidth = isNarrow
            ? (availableWidth * 0.38).clamp(112.0, 144.0).toDouble()
            : 180.0;

        return AbsorbPointer(
          key: const Key('history-reuse-guard'),
          absorbing: _historyReuseInProgress || _clearInProgress,
          child: Form(
            autovalidateMode: _validationAttempted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FocusTraversalGroup(
                  policy: _LoopingWidgetOrderTraversalPolicy(),
                  child: Wrap(
                    spacing: spacing,
                    runSpacing: isNarrow ? 8 : spacing,
                    alignment: WrapAlignment.start,
                    children: [
                      SizedBox(
                        width: primaryFieldWidth,
                        child: _buildMaterialTextField(
                          controller: _controllerController,
                          label: fieldLabel(
                            'controller',
                            '${context.l10n.fieldControllerCallsign} *',
                          ),
                          hintText: context.l10n.inputFieldHint(
                            context.l10n.fieldControllerCallsign,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return context.l10n.fieldRequired;
                            }
                            return null;
                          },
                          isCompact: isNarrow,
                          textInputAction: TextInputAction.next,
                          focusNode: _draftFocusNodes['controller'],
                          enabled: fieldEnabled('controller'),
                        ),
                      ),
                      SizedBox(
                        width: primaryFieldWidth,
                        child: CallsignHistoryField(
                          callsignController: _callsignController,
                          deviceController: _deviceController,
                          antennaController: _antennaController,
                          qthController: _qthController,
                          powerController: _powerController,
                          heightController: _heightController,
                          reportController: _reportController,
                          rstRcvdController: _rstRcvdController,
                          controllerController: _controllerController,
                          label: fieldLabel(
                            'callsign',
                            context.l10n.fieldCallsign,
                          ),
                          hintText: context.l10n.inputFieldHint(
                            context.l10n.fieldCallsign,
                          ),
                          focusNode: _callsignFocusNode,
                          isCompact: isNarrow,
                          textInputAction: TextInputAction.next,
                          enabled: fieldEnabled('callsign'),
                          historyEnabled:
                              settingsProvider.callSignQthLinkEnabled,
                          onReuseRecord: _reuseHistoryRecord,
                          remotePreview: sharedDraft &&
                                  !collaboration
                                      .liveDraftHistoryPreviewOwnedHere
                              ? collaboration.liveDraftHistoryPreview
                              : null,
                          onLocalCandidatesLoaded:
                              sharedDraft && collaboration.canEditLiveDraft
                                  ? _publishHistoryPreview
                                  : null,
                          onLocalPreviewClosed:
                              sharedDraft && collaboration.canEditLiveDraft
                                  ? _dismissHistoryPreview
                                  : null,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return context.l10n.callsignRequired;
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(
                        width: calculatedFieldWidth,
                        child: _buildAutocompleteField(
                          controller: _deviceController,
                          label: fieldLabel('device', context.l10n.fieldDevice),
                          hintText: context.l10n.inputFieldHint(
                            context.l10n.fieldDevice,
                          ),
                          options: dictionaryProvider.deviceDict,
                          upperCase: false,
                          isCompact: isNarrow,
                          textInputAction: TextInputAction.next,
                          draftField: 'device',
                          enabled: fieldEnabled('device'),
                        ),
                      ),
                      SizedBox(
                        width: calculatedFieldWidth,
                        child: _buildAutocompleteField(
                          controller: _antennaController,
                          label:
                              fieldLabel('antenna', context.l10n.fieldAntenna),
                          hintText: context.l10n.inputFieldHint(
                            context.l10n.fieldAntenna,
                          ),
                          options: dictionaryProvider.antennaDict,
                          upperCase: false,
                          isCompact: isNarrow,
                          textInputAction: TextInputAction.next,
                          draftField: 'antenna',
                          enabled: fieldEnabled('antenna'),
                        ),
                      ),
                      SizedBox(
                        width: calculatedFieldWidth,
                        child: _buildAutocompleteField(
                          controller: _powerController,
                          label: fieldLabel('power', context.l10n.fieldPower),
                          hintText: context.l10n.inputFieldHint(
                            context.l10n.fieldPower,
                          ),
                          options: const <DictionaryItem>[],
                          upperCase: false,
                          isCompact: isNarrow,
                          textInputAction: TextInputAction.next,
                          draftField: 'power',
                          enabled: fieldEnabled('power'),
                        ),
                      ),
                      SizedBox(
                        width: calculatedFieldWidth,
                        child: _buildAutocompleteField(
                          controller: _qthController,
                          label: fieldLabel('qth', context.l10n.fieldQth),
                          hintText: context.l10n.inputFieldHint(
                            context.l10n.fieldQth,
                          ),
                          options: dictionaryProvider.qthDict,
                          upperCase: false,
                          isCompact: isNarrow,
                          textInputAction: TextInputAction.next,
                          draftField: 'qth',
                          enabled: fieldEnabled('qth'),
                        ),
                      ),
                      SizedBox(
                        width: calculatedFieldWidth,
                        child: _buildAutocompleteField(
                          controller: _heightController,
                          label: fieldLabel('height', context.l10n.fieldHeight),
                          hintText: context.l10n.inputFieldHint(
                            context.l10n.fieldHeight,
                          ),
                          options: _heightPresetOptions,
                          upperCase: false,
                          isCompact: isNarrow,
                          textInputAction: TextInputAction.next,
                          draftField: 'height',
                          enabled: fieldEnabled('height'),
                        ),
                      ),
                      SizedBox(
                        width: calculatedFieldWidth,
                        child: _buildMaterialTextField(
                          key: const Key('log-time-field'),
                          controller: _timeController,
                          label: fieldLabel('time', context.l10n.fieldTime),
                          hintText: 'HH:mm',
                          upperCase: false,
                          validator: (value) => isValidLogTimeInput(
                            value ?? '',
                            allowEmpty: true,
                          )
                              ? null
                              : context.l10n.logTimeInvalid,
                          isCompact: isNarrow,
                          textInputAction: TextInputAction.next,
                          focusNode: _draftFocusNodes['time'],
                          enabled: fieldEnabled('time'),
                        ),
                      ),
                      SizedBox(
                        width: calculatedFieldWidth,
                        child: _buildMaterialTextField(
                          controller: _reportController,
                          label:
                              fieldLabel('rstSent', context.l10n.fieldRstSent),
                          hintText: '59',
                          upperCase: false,
                          isCompact: isNarrow,
                          textInputAction: TextInputAction.next,
                          focusNode: _draftFocusNodes['rstSent'],
                          enabled: fieldEnabled('rstSent'),
                        ),
                      ),
                      SizedBox(
                        width: calculatedFieldWidth,
                        child: _buildMaterialTextField(
                          controller: _rstRcvdController,
                          label:
                              fieldLabel('rstRcvd', context.l10n.fieldRstRcvd),
                          hintText: '59',
                          upperCase: false,
                          isCompact: isNarrow,
                          textInputAction: TextInputAction.next,
                          focusNode: _draftFocusNodes['rstRcvd'],
                          enabled: fieldEnabled('rstRcvd'),
                        ),
                      ),
                      SizedBox(
                        width: primaryFieldWidth,
                        child: _buildMaterialTextField(
                          controller: _remarksController,
                          label:
                              fieldLabel('remarks', context.l10n.fieldRemarks),
                          hintText: context.l10n.optionalFieldHint(
                            context.l10n.fieldRemarks,
                          ),
                          upperCase: false,
                          isCompact: isNarrow,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _unfocusDraftFields(),
                          focusNode: _draftFocusNodes['remarks'],
                          enabled: fieldEnabled('remarks'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                if (aiSettings?.enabled == true &&
                    aiSettings?.activeAsrProfile != null) ...[
                  Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    descendantsAreTraversable: false,
                    child: AiRecognitionControl(
                      captureSnapshot: _captureAiDraft,
                      currentState: (generation) => _currentAiDraftState(
                        generation,
                        collaboration,
                        readOnly,
                      ),
                      applyFields: (values, expectedSnapshot) =>
                          _applyAiCandidateFields(
                        values,
                        expectedSnapshot,
                        collaboration,
                      ),
                      readOnly: readOnly,
                      busy: _historyReuseInProgress ||
                          _clearInProgress ||
                          _submissionInProgress,
                      audioRecorder: widget.aiAudioRecorder,
                      executor: widget.aiRecognitionExecutor,
                      transcriptionExecutor: widget.aiTranscriptionExecutor ??
                          AiRecognitionRuntime.transcribe,
                      fieldExtractionExecutor:
                          widget.aiFieldExtractionExecutor ??
                              AiRecognitionRuntime.extractFields,
                      referenceContextBuilder:
                          aiSettings?.useLocalReferenceContext == true
                              ? (transcript) => AiDatabaseContextBuilder.build(
                                    transcript: transcript,
                                    devices: dictionaryProvider.deviceDict,
                                    antennas: dictionaryProvider.antennaDict,
                                    callsigns: dictionaryProvider.callsignDict,
                                    qths: dictionaryProvider.qthDict,
                                    recentLogs:
                                        context.read<LogProvider>().logs,
                                  )
                              : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (sharedDraft &&
                    collaboration.ownedLiveDraftLocks.isNotEmpty) ...[
                  Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    descendantsAreTraversable: false,
                    child: OutlinedButton.icon(
                      key: const Key('finish-draft-editing'),
                      onPressed: _historyReuseInProgress || _clearInProgress
                          ? null
                          : _unfocusDraftFields,
                      icon: const Icon(Icons.keyboard_hide_outlined),
                      label: Text(context.l10n.finishEditing),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // 当前草稿操作；清空保留主控呼号。
                Row(
                  key: const Key('log-form-actions'),
                  children: [
                    SizedBox(
                      width: clearButtonWidth,
                      child: Tooltip(
                        message: context.l10n.clearEnteredFields,
                        child: SizedBox(
                          height: isNarrow ? 44 : 48,
                          child: Focus(
                            canRequestFocus: false,
                            skipTraversal: true,
                            descendantsAreTraversable: false,
                            child: OutlinedButton.icon(
                              key: const Key('clear-log-fields'),
                              onPressed: canClear ? _clearEnteredFields : null,
                              icon: _clearInProgress
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.backspace_outlined),
                              label: Text(
                                context.l10n.clearEnteredFields,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Tooltip(
                        message: 'Ctrl/⌘ + Enter',
                        child: SizedBox(
                          height: isNarrow ? 44 : 48,
                          child: Focus(
                            canRequestFocus: false,
                            skipTraversal: true,
                            descendantsAreTraversable: false,
                            child: FilledButton.icon(
                              key: const Key('save-log-record'),
                              onPressed: canSubmit ? _submitForm : null,
                              icon: _submissionInProgress
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      _historyReuseInProgress
                                          ? Icons.auto_fix_high
                                          : readOnly || firstForeignLock != null
                                              ? Icons.lock_outline
                                              : Icons.add,
                                    ),
                              label: Text(
                                _submissionInProgress
                                    ? context.l10n.savingRecord
                                    : _historyReuseInProgress
                                        ? context.l10n.reuseDatabaseInformation
                                        : readOnly
                                            ? context.l10n.sharedDraftReadOnly
                                            : firstForeignLock != null
                                                ? context.l10n.fieldLockedBy(
                                                    firstForeignLock.username,
                                                  )
                                                : context.l10n.saveRecord,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: isNarrow ? 10 : 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return content;
  }

  Widget _buildMaterialTextField({
    Key? key,
    required TextEditingController controller,
    required String label,
    required String hintText,
    TextInputType? keyboardType,
    String? error,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    void Function(String)? onSubmitted,
    TextInputAction? textInputAction,
    bool upperCase = true,
    bool isCompact = false,
    FocusNode? focusNode,
    bool enabled = true,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: error,
        isDense: true,
        contentPadding:
            EdgeInsets.symmetric(horizontal: 12, vertical: isCompact ? 10 : 14),
      ),
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      textInputAction: textInputAction ?? TextInputAction.next,
      textCapitalization:
          upperCase ? TextCapitalization.characters : TextCapitalization.none,
      inputFormatters:
          upperCase ? const [ImeSafeUpperCaseTextFormatter()] : const [],
      onTapOutside: (event) {
        if (_autocompleteOptionKeys.values
            .any((key) => isGlobalOffsetInside(event.position, key))) {
          return;
        }
        _outsideTap.onTapOutside(event, focusNode);
      },
    );
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required List<DictionaryItem> options,
    void Function(String)? onChanged,
    TextInputAction? textInputAction,
    bool upperCase = true,
    bool isCompact = false,
    required String draftField,
    bool enabled = true,
  }) {
    final textCapitalization =
        upperCase ? TextCapitalization.characters : TextCapitalization.none;
    final List<TextInputFormatter> inputFormatters = upperCase
        ? const [ImeSafeUpperCaseTextFormatter()]
        : const <TextInputFormatter>[];

    final draftFocusNode = _draftFocusNodes[draftField]!;
    final aiSuggestion = _inlineAiSuggestions[draftField];
    final autocomplete = Autocomplete<_FormSuggestion>(
      key: ValueKey<String>('log-autocomplete-$draftField'),
      textEditingController: controller,
      focusNode: draftFocusNode,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<_FormSuggestion>.empty();
        }
        if ((draftField == 'power' || draftField == 'height') &&
            containsCjkText(textEditingValue.text)) {
          return const Iterable<_FormSuggestion>.empty();
        }
        final formatValues = fieldFormatSuggestions(
          draftField,
          textEditingValue.text,
        );
        final ranked = rankDictionaryMatches(
          query: textEditingValue.text,
          options: options,
          usageCount: (item) => _dictionaryUsage.countFor(item.type, item.raw),
        );
        return <_FormSuggestion>[
          for (final value in formatValues) _FormSuggestion.format(value),
          for (final option in ranked)
            if (!formatValues.contains(option.raw))
              _FormSuggestion.local(option),
          if (aiSuggestion != null &&
              aiSuggestion.isNotEmpty &&
              !formatValues.contains(aiSuggestion) &&
              !ranked.any((item) => item.raw == aiSuggestion))
            _FormSuggestion.ai(aiSuggestion),
        ];
      },
      displayStringForOption: (option) => option.value,
      onSelected: (_FormSuggestion selection) {
        if (selection.isAi) {
          _acceptedInlineAiValues[draftField] = selection.value;
        }
        if (!selection.isAi && !selection.isFormat) {
          _dictionaryUsage.recordSelection(draftField, selection.value);
        }
        controller.value = TextEditingValue(
          text: selection.value,
          selection: TextSelection.collapsed(offset: selection.value.length),
        );
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldController,
        FocusNode fieldFocusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return AppAutocompleteKeyboardSubmit(
          controller: fieldController,
          onSubmitted: onFieldSubmitted,
          child: TextFormField(
            controller: fieldController,
            focusNode: fieldFocusNode,
            enabled: enabled,
            decoration: InputDecoration(
              labelText: label,
              hintText: hintText,
              isDense: true,
              suffixIcon: _inlineAiPending.contains(draftField)
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 12, vertical: isCompact ? 10 : 14),
            ),
            onChanged: (value) {
              onChanged?.call(value);
            },
            onFieldSubmitted: (_) => onFieldSubmitted(),
            textInputAction: textInputAction ?? TextInputAction.next,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            onTapOutside: (event) {
              if (isGlobalOffsetInside(
                event.position,
                _autocompleteOptionKeys[draftField]!,
              )) {
                return;
              }
              _outsideTap.onTapOutside(event, fieldFocusNode);
            },
          ),
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<_FormSuggestion> onSelected,
        Iterable<_FormSuggestion> options,
      ) {
        final theme = Theme.of(context);
        final optionList = options.toList(growable: false);
        final highlightedIndex = AutocompleteHighlightedOption.of(context);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            key: _autocompleteOptionKeys[draftField],
            elevation: 3,
            color: theme.colorScheme.surfaceContainer,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 320),
              child: AppAutocompleteOptionsList<_FormSuggestion>(
                options: optionList,
                highlightedIndex: highlightedIndex,
                onSelected: onSelected,
                optionBuilder: (context, item) {
                  return ListTile(
                    key: item.isAi
                        ? Key('inline-ai-suggestion-$draftField')
                        : item.isFormat
                            ? Key(
                                'format-suggestion-$draftField-${item.value}',
                              )
                            : null,
                    dense: true,
                    leading: item.isAi
                        ? Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: theme.colorScheme.primary,
                          )
                        : item.isFormat
                            ? Icon(
                                Icons.straighten_outlined,
                                size: 18,
                                color: theme.colorScheme.secondary,
                              )
                            : null,
                    title: Text(item.value),
                    subtitle: item.isAi
                        ? Text(
                            context.l10n.textAssistantSuggestionLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : item.isFormat
                            ? Text(
                                context.l10n.fieldFormatSuggestionLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              )
                            : item.item!.abbreviation.isNotEmpty ||
                                    item.item!.pinyin.isNotEmpty
                                ? Text(
                                    [
                                      if (item.item!.abbreviation.isNotEmpty)
                                        item.item!.abbreviation,
                                      if (item.item!.pinyin.isNotEmpty)
                                        item.item!.pinyin,
                                    ].join(' · '),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
    return autocomplete;
  }

  void _scheduleLockExpiryRefresh(List<dynamic> activeForeignLocks) {
    _lockExpiryTimer?.cancel();
    _lockExpiryTimer = null;
    if (activeForeignLocks.isEmpty) return;
    final earliest = activeForeignLocks
        .map((lock) => lock.expiresAt as DateTime)
        .reduce((left, right) => left.isBefore(right) ? left : right);
    final delay = earliest.difference(DateTime.now());
    _lockExpiryTimer = Timer(
      delay.isNegative
          ? Duration.zero
          : delay + const Duration(milliseconds: 20),
      () {
        if (mounted) setState(() {});
      },
    );
  }
}

class _FormSuggestion {
  factory _FormSuggestion.local(DictionaryItem item) =>
      _FormSuggestion._(item, item.raw, _FormSuggestionKind.local);

  const _FormSuggestion.ai(this.value)
      : item = null,
        kind = _FormSuggestionKind.ai;

  const _FormSuggestion.format(this.value)
      : item = null,
        kind = _FormSuggestionKind.format;

  const _FormSuggestion._(this.item, this.value, this.kind);

  final DictionaryItem? item;
  final String value;
  final _FormSuggestionKind kind;

  bool get isAi => kind == _FormSuggestionKind.ai;
  bool get isFormat => kind == _FormSuggestionKind.format;
}

enum _FormSuggestionKind { local, format, ai }

enum _DuplicateAction { add, update, cancel }

class _LoopingWidgetOrderTraversalPolicy extends WidgetOrderTraversalPolicy {
  @override
  bool next(FocusNode currentNode) => _cycle(currentNode, forward: true);

  @override
  bool previous(FocusNode currentNode) => _cycle(currentNode, forward: false);

  bool _cycle(FocusNode currentNode, {required bool forward}) {
    final scope = currentNode.nearestScope;
    if (scope == null) return false;
    final nodes = sortDescendants(scope.traversalDescendants, scope)
        .where((node) => node.canRequestFocus && !node.skipTraversal)
        .toList(growable: false);
    if (nodes.isEmpty) return false;
    final currentIndex = nodes.indexOf(currentNode);
    final start = currentIndex < 0 ? 0 : currentIndex;
    final nextIndex = forward
        ? (start + 1) % nodes.length
        : (start - 1 + nodes.length) % nodes.length;
    nodes[nextIndex].requestFocus();
    return true;
  }
}
