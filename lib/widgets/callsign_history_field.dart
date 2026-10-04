import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/live_draft.dart';
import 'package:openlogtool/src/bridge/rust_api.dart';
import 'package:openlogtool/src/bridge/models/log_entry.dart' as bridge;
import 'package:openlogtool/utils/ime_safe_upper_case_formatter.dart';
import 'package:openlogtool/widgets/autocomplete_options_list.dart';
import 'package:openlogtool/widgets/scroll_safe_unfocus.dart';
import 'package:openlogtool/utils/log_time.dart';

typedef CallsignHistoryLoader = Future<List<bridge.LogEntry>> Function(
  String callsign,
  int limit,
);

typedef CallsignHistoryReuseCallback = Future<void> Function(
  bridge.LogEntry record,
);

typedef CallsignHistoryCandidatesCallback = Future<void> Function(
  String callsign,
  List<bridge.LogEntry> candidates,
);

typedef CallsignHistoryPreviewClosedCallback = FutureOr<void> Function();

class CallsignHistoryField extends StatefulWidget {
  final TextEditingController callsignController;
  final TextEditingController deviceController;
  final TextEditingController antennaController;
  final TextEditingController qthController;
  final TextEditingController powerController;
  final TextEditingController heightController;
  final TextEditingController? reportController;
  final TextEditingController? rstRcvdController;
  final TextEditingController? controllerController;
  final String label;
  final String hintText;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool isCompact;
  final bool enabled;
  final bool historyEnabled;
  final String? Function(String?)? validator;
  final CallsignHistoryLoader? historyLoader;
  final bool Function(String field)? canFillField;
  final CallsignHistoryReuseCallback? onReuseRecord;
  final LiveDraftHistoryPreviewDto? remotePreview;
  final CallsignHistoryCandidatesCallback? onLocalCandidatesLoaded;
  final CallsignHistoryPreviewClosedCallback? onLocalPreviewClosed;

  const CallsignHistoryField({
    super.key,
    required this.callsignController,
    required this.deviceController,
    required this.antennaController,
    required this.qthController,
    required this.powerController,
    required this.heightController,
    this.reportController,
    this.rstRcvdController,
    this.controllerController,
    required this.label,
    required this.hintText,
    this.textInputAction,
    this.focusNode,
    this.isCompact = false,
    this.enabled = true,
    this.historyEnabled = true,
    this.validator,
    this.historyLoader,
    this.canFillField,
    this.onReuseRecord,
    this.remotePreview,
    this.onLocalCandidatesLoaded,
    this.onLocalPreviewClosed,
  });

  @override
  State<CallsignHistoryField> createState() => _CallsignHistoryFieldState();
}

class _CallsignHistoryFieldState extends State<CallsignHistoryField>
    with WidgetsBindingObserver {
  static const int _historyLimit = 10;

  List<bridge.LogEntry> _history = [];
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final GlobalKey _overlayPanelKey = GlobalKey();
  final FocusNode _ownFocusNode = FocusNode();
  final _outsideTap = ScrollSafeUnfocus();
  late final FocusOnKeyEventCallback _historyKeyHandler;
  FocusNode? _keyHandlerNode;
  FocusOnKeyEventCallback? _previousKeyHandler;
  Timer? _focusLossTimer;
  Timer? _remotePreviewExpiryTimer;
  String? _expiredRemotePreviewId;
  bool _isSelecting = false;
  int _historyRequestGeneration = 0;
  int _highlightIndex = -1;
  final ScrollController _listController = ScrollController();
  List<GlobalKey> _historyItemKeys = const [];
  _HistoryOverlayMode? _overlayMode;
  bool _localPreviewOpen = false;
  String? _localPreviewKey;
  late String _observedCallsignText;

  FocusNode get _effFocus => widget.focusNode ?? _ownFocusNode;
  bool get _canUseLocalHistory => widget.enabled && widget.historyEnabled;

  LiveDraftHistoryPreviewDto? get _activeRemotePreview {
    final preview = widget.remotePreview;
    if (preview == null ||
        preview.previewId == _expiredRemotePreviewId ||
        preview.candidates.isEmpty ||
        !preview.expiresAt.isAfter(DateTime.now())) {
      return null;
    }
    return preview;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _historyKeyHandler = _handleKeyEvent;
    _observedCallsignText = widget.callsignController.text;
    _attachKeyHandler(_effFocus);
    _effFocus.addListener(_onFocusChanged);
    widget.callsignController.addListener(_onCallsignChanged);
    _scheduleRemotePreviewRefresh();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final isKeyPress = event is KeyDownEvent || event is KeyRepeatEvent;
    if (!isKeyPress ||
        !node.hasFocus ||
        _overlayEntry == null ||
        _overlayMode != _HistoryOverlayMode.local ||
        _history.isEmpty ||
        _isSelecting) {
      return _previousKeyHandler?.call(node, event) ?? KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_highlightIndex >= 0 && _highlightIndex < _history.length) {
        unawaited(_fillFromRecord(_history[_highlightIndex]));
        return KeyEventResult.handled;
      }
      return _previousKeyHandler?.call(node, event) ?? KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape) {
      _hideOverlay();
      return KeyEventResult.handled;
    }
    return _previousKeyHandler?.call(node, event) ?? KeyEventResult.ignored;
  }

  void _attachKeyHandler(FocusNode node) {
    _keyHandlerNode = node;
    _previousKeyHandler = node.onKeyEvent;
    node.onKeyEvent = _historyKeyHandler;
  }

  void _detachKeyHandler() {
    final node = _keyHandlerNode;
    if (node != null && identical(node.onKeyEvent, _historyKeyHandler)) {
      node.onKeyEvent = _previousKeyHandler;
    }
    _keyHandlerNode = null;
    _previousKeyHandler = null;
  }

  @override
  void didUpdateWidget(CallsignHistoryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFocus = oldWidget.focusNode ?? _ownFocusNode;
    if (oldFocus != _effFocus) {
      _detachKeyHandler();
      oldFocus.removeListener(_onFocusChanged);
      _attachKeyHandler(_effFocus);
      _effFocus.addListener(_onFocusChanged);
    }
    if (oldWidget.callsignController != widget.callsignController) {
      oldWidget.callsignController.removeListener(_onCallsignChanged);
      widget.callsignController.addListener(_onCallsignChanged);
      _observedCallsignText = widget.callsignController.text;
      _invalidateLocalHistory(notifyClosed: true);
    }
    final wasUsable = oldWidget.enabled && oldWidget.historyEnabled;
    if (wasUsable && !_canUseLocalHistory) {
      _invalidateLocalHistory(notifyClosed: true);
    } else if (!wasUsable && _canUseLocalHistory) {
      _loadHistory();
    }
    if (!identical(oldWidget.remotePreview, widget.remotePreview)) {
      if (_overlayMode == _HistoryOverlayMode.remote) _hideOverlay();
      _scheduleRemotePreviewRefresh();
    }
  }

  @override
  void dispose() {
    _outsideTap.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _focusLossTimer?.cancel();
    _remotePreviewExpiryTimer?.cancel();
    _notifyLocalPreviewClosed();
    _detachKeyHandler();
    _listController.dispose();
    _hideOverlay();
    widget.callsignController.removeListener(_onCallsignChanged);
    _effFocus.removeListener(_onFocusChanged);
    if (widget.focusNode == null) _ownFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_overlayEntry == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _overlayEntry?.markNeedsBuild();
    });
  }

  void _moveHighlight(int delta) {
    if (_history.isEmpty) return;
    final next = (_highlightIndex < 0 ? 0 : _highlightIndex + delta)
        .clamp(0, _history.length - 1);
    if (next == _highlightIndex) return;
    _highlightIndex = next;
    _overlayEntry?.markNeedsBuild();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final itemContext = next < _historyItemKeys.length
          ? _historyItemKeys[next].currentContext
          : null;
      if (itemContext != null) {
        unawaited(
          Scrollable.ensureVisible(
            itemContext,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          ),
        );
        return;
      }
      if (!_listController.hasClients) return;
      const itemExtent = 58.0;
      final position = _listController.position;
      final itemTop = next * itemExtent;
      final itemBottom = itemTop + itemExtent;
      var target = position.pixels;
      if (itemTop < position.pixels) {
        target = itemTop;
      } else if (itemBottom > position.pixels + position.viewportDimension) {
        target = itemBottom - position.viewportDimension;
      }
      target = target.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (target == position.pixels) return;
      _listController.animateTo(
        target,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    });
  }

  void _onCallsignChanged() {
    final textChanged = widget.callsignController.text != _observedCallsignText;
    _observedCallsignText = widget.callsignController.text;
    if (textChanged) {
      _invalidateLocalHistory(notifyClosed: true);
    }
    if (!_canUseLocalHistory) {
      _refreshOverlayForCurrentState();
      return;
    }
    if (ImeSafeUpperCaseTextFormatter.hasActiveComposition(
      widget.callsignController.value,
    )) {
      _invalidateLocalHistory(notifyClosed: true);
      return;
    }
    _loadHistory();
    if (_overlayMode == _HistoryOverlayMode.local) _hideOverlay();
    _refreshOverlayForCurrentState();
  }

  void _onFocusChanged() {
    _focusLossTimer?.cancel();
    _focusLossTimer = null;
    if (!_canUseLocalHistory) {
      _refreshOverlayForCurrentState();
      return;
    }
    if (ImeSafeUpperCaseTextFormatter.hasActiveComposition(
      widget.callsignController.value,
    )) {
      _invalidateLocalHistory(notifyClosed: !_effFocus.hasFocus);
      return;
    }
    final callsign = widget.callsignController.text.trim().toUpperCase();
    if (callsign.length < 2) {
      if (mounted) setState(() => _history = []);
      _invalidateLocalHistory(notifyClosed: true);
      _refreshOverlayForCurrentState();
      return;
    }
    if (_effFocus.hasFocus &&
        _history.isNotEmpty &&
        _history.first.callsign.trim().toUpperCase() == callsign) {
      _showLocalOverlay();
    } else if (!_effFocus.hasFocus) {
      _focusLossTimer = Timer(const Duration(milliseconds: 300), () {
        _focusLossTimer = null;
        if (!mounted) return;
        if (!_effFocus.hasFocus && !_isSelecting) {
          _notifyLocalPreviewClosed();
          if (_overlayMode == _HistoryOverlayMode.local) _hideOverlay();
          _refreshOverlayForCurrentState();
        }
      });
    }
  }

  Future<void> _loadHistory() async {
    final requestGeneration = ++_historyRequestGeneration;
    if (!_canUseLocalHistory) return;
    if (ImeSafeUpperCaseTextFormatter.hasActiveComposition(
      widget.callsignController.value,
    )) {
      _invalidateLocalHistory(notifyClosed: true);
      return;
    }
    final callsign = widget.callsignController.text.trim().toUpperCase();
    if (callsign.length < 2) {
      if (mounted) setState(() => _history = []);
      _invalidateLocalHistory(notifyClosed: true);
      _refreshOverlayForCurrentState();
      return;
    }
    try {
      final loader = widget.historyLoader ?? _loadHistoryFromDatabase;
      final rows = await loader(callsign, _historyLimit);
      if (!mounted || !_canUseLocalHistory) return;
      if (requestGeneration != _historyRequestGeneration) return;
      if (ImeSafeUpperCaseTextFormatter.hasActiveComposition(
        widget.callsignController.value,
      )) {
        _invalidateLocalHistory(notifyClosed: true);
        return;
      }
      final current = widget.callsignController.text.trim().toUpperCase();
      if (current != callsign) {
        // Controller listener already started the request for the latest text.
        return;
      }
      setState(() => _history = rows);
      if (_effFocus.hasFocus &&
          _history.isNotEmpty &&
          _history.first.callsign.trim().toUpperCase() == current &&
          _activeRemotePreview == null) {
        _showLocalOverlay();
      } else if (_history.isEmpty) {
        _notifyLocalPreviewClosed();
        if (_overlayMode == _HistoryOverlayMode.local) _hideOverlay();
        _refreshOverlayForCurrentState();
      }
    } catch (_) {}
  }

  Future<List<bridge.LogEntry>> _loadHistoryFromDatabase(
    String callsign,
    int limit,
  ) =>
      RustApi.getRecentByCallsign(callsign: callsign, limit: limit);

  void _invalidateLocalHistory({bool notifyClosed = false}) {
    _historyRequestGeneration += 1;
    _history = const [];
    if (notifyClosed) _notifyLocalPreviewClosed();
    if (_overlayMode == _HistoryOverlayMode.local) _hideOverlay();
  }

  bool _canFill(String field) => widget.canFillField?.call(field) ?? true;

  Future<void> _fillFromRecord(bridge.LogEntry log) async {
    _isSelecting = true;
    _forgetLocalPreviewWithoutClosing();
    _hideOverlay();
    try {
      final onReuseRecord = widget.onReuseRecord;
      if (onReuseRecord != null) {
        await onReuseRecord(log);
        return;
      }

      _fillControllersFromRecord(log);
    } finally {
      _isSelecting = false;
    }
  }

  void _fillControllersFromRecord(bridge.LogEntry log) {
    if (_canFill('device') && (log.device?.isNotEmpty ?? false)) {
      widget.deviceController.text = log.device!;
    }
    if (_canFill('antenna') && (log.antenna?.isNotEmpty ?? false)) {
      widget.antennaController.text = log.antenna!;
    }
    if (_canFill('qth') && (log.qth?.isNotEmpty ?? false)) {
      widget.qthController.text = log.qth!;
    }
    if (_canFill('power') && (log.power?.isNotEmpty ?? false)) {
      widget.powerController.text = log.power!;
    }
    if (_canFill('height') && (log.height?.isNotEmpty ?? false)) {
      widget.heightController.text = log.height!;
    }
  }

  Future<void> _enqueueLocalPreviewOperation(
    FutureOr<void> Function() operation,
  ) async {
    try {
      await operation();
    } catch (_) {
      // Preview publication is best-effort. Local history must stay usable
      // when a high-latency collaboration request fails. Close callbacks also
      // run independently so a slow publish cannot keep a stale preview open.
    }
  }

  void _openLocalPreview() {
    final callback = widget.onLocalCandidatesLoaded;
    if (callback == null || _history.isEmpty) return;
    final callsign = widget.callsignController.text.trim().toUpperCase();
    final key = '$callsign:${_history.map((row) => row.syncId).join(',')}';
    if (_localPreviewOpen && _localPreviewKey == key) return;
    if (_localPreviewOpen) _notifyLocalPreviewClosed();
    _localPreviewOpen = true;
    _localPreviewKey = key;
    final candidates = List<bridge.LogEntry>.unmodifiable(_history);
    unawaited(
      _enqueueLocalPreviewOperation(
        () => callback(callsign, candidates),
      ),
    );
  }

  void _notifyLocalPreviewClosed() {
    if (!_localPreviewOpen) return;
    _localPreviewOpen = false;
    _localPreviewKey = null;
    final callback = widget.onLocalPreviewClosed;
    if (callback != null) {
      unawaited(_enqueueLocalPreviewOperation(callback));
    }
  }

  void _forgetLocalPreviewWithoutClosing() {
    _localPreviewOpen = false;
    _localPreviewKey = null;
  }

  void _scheduleRemotePreviewRefresh() {
    _remotePreviewExpiryTimer?.cancel();
    _remotePreviewExpiryTimer = null;
    _expiredRemotePreviewId = null;
    final preview = _activeRemotePreview;
    if (preview != null) {
      _remotePreviewExpiryTimer = Timer(
        preview.expiresAt.difference(DateTime.now()),
        () {
          _remotePreviewExpiryTimer = null;
          if (!mounted) return;
          _expiredRemotePreviewId = preview.previewId;
          if (_overlayMode == _HistoryOverlayMode.remote) _hideOverlay();
          setState(() {});
          _refreshOverlayForCurrentState();
        },
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshOverlayForCurrentState();
    });
  }

  bool _remotePreviewMatchesCurrentCallsign(
    LiveDraftHistoryPreviewDto preview,
  ) {
    return widget.callsignController.text.trim().toUpperCase() ==
        preview.callsign;
  }

  void _refreshOverlayForCurrentState() {
    final remote = _activeRemotePreview;
    if (remote != null && _remotePreviewMatchesCurrentCallsign(remote)) {
      if (_overlayMode != _HistoryOverlayMode.remote) {
        _showRemoteOverlay(remote);
      }
      return;
    }
    if (_overlayMode == _HistoryOverlayMode.remote) _hideOverlay();
    final callsign = widget.callsignController.text.trim().toUpperCase();
    if (_canUseLocalHistory &&
        _effFocus.hasFocus &&
        _history.isNotEmpty &&
        _history.first.callsign.trim().toUpperCase() == callsign) {
      _showLocalOverlay();
    }
  }

  void _showLocalOverlay() {
    final items =
        _history.map(_HistoryOverlayItem.fromLocal).toList(growable: false);
    if (items.isEmpty) return;
    _showOverlay(
      mode: _HistoryOverlayMode.local,
      items: items,
    );
    // Publish only after the local overlay is visible. Do not await this call:
    // the operator can select a row immediately even on a slow connection.
    _openLocalPreview();
  }

  void _showRemoteOverlay(LiveDraftHistoryPreviewDto preview) {
    final items = preview.candidates
        .map(_HistoryOverlayItem.fromRemote)
        .toList(growable: false);
    if (items.isEmpty) return;
    // A server-owned remote preview supersedes any local preview state. Forget
    // it without invoking the owner's close callback, which would otherwise
    // dismiss the remote scribe's dropdown.
    _forgetLocalPreviewWithoutClosing();
    _showOverlay(
      mode: _HistoryOverlayMode.remote,
      items: items,
    );
  }

  void _showOverlay({
    required _HistoryOverlayMode mode,
    required List<_HistoryOverlayItem> items,
  }) {
    _hideOverlay();
    if (items.isEmpty ||
        (mode == _HistoryOverlayMode.local && !_canUseLocalHistory)) {
      return;
    }
    _overlayMode = mode;
    _highlightIndex = mode == _HistoryOverlayMode.local ? 0 : -1;
    final overlay = Overlay.of(context);
    final list = List<_HistoryOverlayItem>.unmodifiable(items);
    _historyItemKeys = List<GlobalKey>.generate(
      list.length,
      (index) => GlobalKey(debugLabel: 'callsign-history-item-$index'),
      growable: false,
    );

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        final overlayObject = overlay.context.findRenderObject();
        final fieldObject = context.findRenderObject();
        if (overlayObject is! RenderBox ||
            fieldObject is! RenderBox ||
            !overlayObject.attached ||
            !fieldObject.attached) {
          return const SizedBox.shrink();
        }
        final overlaySize = overlayObject.size;
        final fieldSize = fieldObject.size;
        final fieldOrigin = fieldObject.localToGlobal(
          Offset.zero,
          ancestor: overlayObject,
        );
        const screenMargin = 8.0;
        const anchorGap = 4.0;
        final mediaQuery = MediaQuery.of(ctx);
        final view = View.of(ctx);
        final rawBottomInset = view.viewInsets.bottom / view.devicePixelRatio;
        final bottomInset = math.max(
          mediaQuery.viewInsets.bottom,
          rawBottomInset,
        );
        final availableWidth = math.max(
          0.0,
          overlaySize.width - screenMargin * 2,
        );
        final panelWidth = math.min(320.0, availableWidth);
        final maxLeft = math.max(
          screenMargin,
          overlaySize.width - screenMargin - panelWidth,
        );
        final panelLeft =
            fieldOrigin.dx.clamp(screenMargin, maxLeft).toDouble();
        final desiredHeight = math.min(260.0, 42.0 + list.length * 58.0);
        final visibleTop = mediaQuery.padding.top + screenMargin;
        final visibleBottom = overlaySize.height -
            bottomInset -
            mediaQuery.padding.bottom -
            screenMargin;
        final belowSpace = math.max(
          0.0,
          visibleBottom - (fieldOrigin.dy + fieldSize.height + anchorGap),
        );
        final aboveSpace = math.max(
          0.0,
          fieldOrigin.dy - anchorGap - visibleTop,
        );
        final openBelow = belowSpace >= math.min(desiredHeight, 120.0) ||
            belowSpace >= aboveSpace;
        final availableHeight = openBelow ? belowSpace : aboveSpace;
        final panelHeight = math.min(desiredHeight, availableHeight);
        final followerOffset = Offset(
          panelLeft - fieldOrigin.dx,
          openBelow ? fieldSize.height + anchorGap : -panelHeight - anchorGap,
        );
        return Positioned(
          width: panelWidth,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: followerOffset,
            child: TextFieldTapRegion(
              child: Material(
                key: const Key('callsign-history-overlay'),
                elevation: 8,
                borderRadius: BorderRadius.circular(10),
                surfaceTintColor: Colors.transparent,
                child: Container(
                  key: _overlayPanelKey,
                  constraints: BoxConstraints(maxHeight: panelHeight),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Theme.of(ctx).colorScheme.outlineVariant),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .outlineVariant)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.auto_fix_high,
                                size: 14,
                                color: Theme.of(ctx).colorScheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                context.l10n.reuseDatabaseInformation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Scrollbar(
                          controller: _listController,
                          child: ListView.builder(
                            key: const Key('callsign-history-list'),
                            controller: _listController,
                            primary: false,
                            physics: const ClampingScrollPhysics(),
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.manual,
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final item = list[i];
                              final details = [
                                item.qth,
                                item.device,
                                item.power,
                                item.antenna,
                                item.height,
                              ].where((value) => value.isNotEmpty).join(' · ');
                              final readOnly =
                                  mode == _HistoryOverlayMode.remote;
                              final selected =
                                  !readOnly && i == _highlightIndex;
                              return Semantics(
                                key: _historyItemKeys[i],
                                selected: selected,
                                button: !readOnly,
                                enabled: !readOnly,
                                child: InkWell(
                                  key: Key(
                                    readOnly
                                        ? 'callsign-history-remote-row-$i'
                                        : 'callsign-history-local-row-$i',
                                  ),
                                  onTap: readOnly || item.localRecord == null
                                      ? null
                                      : () => unawaited(
                                            _fillFromRecord(item.localRecord!),
                                          ),
                                  onHover: readOnly
                                      ? null
                                      : (hovered) {
                                          if (hovered && _highlightIndex != i) {
                                            _highlightIndex = i;
                                            _overlayEntry?.markNeedsBuild();
                                          }
                                        },
                                  child: Container(
                                    constraints:
                                        const BoxConstraints(minHeight: 58),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Theme.of(ctx)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.14)
                                          : null,
                                      border: i < list.length - 1
                                          ? Border(
                                              bottom: BorderSide(
                                                color: Theme.of(ctx)
                                                    .colorScheme
                                                    .outlineVariant
                                                    .withAlpha(80),
                                              ),
                                            )
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          readOnly
                                              ? Icons.visibility_outlined
                                              : Icons.history,
                                          size: 14,
                                          color:
                                              Theme.of(ctx).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _formatTime(item.sourceTime),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Theme.of(ctx)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                              ),
                                              if (details.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    top: 2,
                                                  ),
                                                  child: Text(
                                                    details,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Theme.of(ctx)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          readOnly
                                              ? Icons.lock_outline
                                              : Icons.chevron_right,
                                          size: 16,
                                          color: Theme.of(ctx)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_overlayEntry!);
  }

  void _hideOverlay() {
    final entry = _overlayEntry;
    _overlayEntry = null;
    _overlayMode = null;
    _historyItemKeys = const [];
    if (entry == null) return;
    try {
      entry.remove();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.callsignController,
        focusNode: _effFocus,
        enabled: widget.enabled,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
              horizontal: 12, vertical: widget.isCompact ? 10 : 14),
          suffixIcon: (_canUseLocalHistory || _activeRemotePreview != null)
              ? Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.search,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
        ),
        textInputAction: widget.textInputAction ?? TextInputAction.next,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: const [ImeSafeUpperCaseTextFormatter()],
        onTapOutside: (event) {
          if (isGlobalOffsetInside(event.position, _overlayPanelKey)) {
            return;
          }
          _outsideTap.onTapOutside(event, _effFocus);
        },
      ),
    );
  }
}

String _formatTime(String time) {
  return formatLogTimeForDisplay(time, includeDate: true);
}

enum _HistoryOverlayMode { local, remote }

final class _HistoryOverlayItem {
  const _HistoryOverlayItem({
    required this.sourceTime,
    required this.qth,
    required this.device,
    required this.power,
    required this.antenna,
    required this.height,
    this.localRecord,
  });

  factory _HistoryOverlayItem.fromLocal(bridge.LogEntry record) {
    return _HistoryOverlayItem(
      sourceTime: record.time,
      qth: record.qth ?? '',
      device: record.device ?? '',
      power: record.power ?? '',
      antenna: record.antenna ?? '',
      height: record.height ?? '',
      localRecord: record,
    );
  }

  factory _HistoryOverlayItem.fromRemote(
    LiveDraftHistoryCandidateDto candidate,
  ) {
    return _HistoryOverlayItem(
      sourceTime: candidate.sourceTime,
      qth: candidate.qth,
      device: candidate.device,
      power: candidate.power,
      antenna: candidate.antenna,
      height: candidate.height,
    );
  }

  final String sourceTime;
  final String qth;
  final String device;
  final String power;
  final String antenna;
  final String height;
  final bridge.LogEntry? localRecord;
}
