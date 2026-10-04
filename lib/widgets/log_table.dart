import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/models/log_entry.dart';
import 'package:openlogtool/utils/app_snack_bar.dart';
import 'package:openlogtool/utils/log_time.dart';
import 'package:openlogtool/widgets/record_editor_dialog.dart';

class LogTable extends StatefulWidget {
  const LogTable({
    super.key,
    this.readOnly = false,
    this.conflictedLogIds = const <String>{},
  });

  final bool readOnly;
  final Set<String> conflictedLogIds;

  @override
  State<LogTable> createState() => _LogTableState();
}

class _LogTableState extends State<LogTable> {
  static const double _mobileBreakpoint = 680;
  static const double _desktopActionsWidth = 128;
  int? _editingIndex;
  LogEntry? _editingOriginal;
  late Map<String, TextEditingController> _controllers;
  int _currentPage = 0;
  List<LogEntry> _lastSeenLogs = [];
  bool _editingSaveInProgress = false;
  bool _sessionContextInitialized = false;
  String? _lastSeenSessionId;
  bool _lastHadLogs = false;

  final ScrollController _horizontalController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _controllers = {};
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final logProvider = Provider.of<LogProvider>(context);
    final sessionId = logProvider.currentSessionId;
    final hasLogs = logProvider.logs.isNotEmpty;
    if (!_sessionContextInitialized) {
      _sessionContextInitialized = true;
      _lastSeenSessionId = sessionId;
      _lastHadLogs = hasLogs;
      return;
    }
    final sessionChanged = sessionId != _lastSeenSessionId;
    final becameEmpty = _lastHadLogs && !hasLogs;
    _lastSeenSessionId = sessionId;
    _lastHadLogs = hasLogs;
    if (!sessionChanged && !becameEmpty) return;

    _currentPage = 0;
    _editingIndex = null;
    _editingSaveInProgress = false;
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers = {};
    if (_searchQuery.isNotEmpty) {
      _searchQuery = '';
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _horizontalController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startEditing(int index, LogEntry log) async {
    final logProvider = context.read<LogProvider>();
    if (widget.readOnly ||
        widget.conflictedLogIds.contains(log.id) ||
        !logProvider.canMutateLog(log)) {
      return;
    }
    final settingsProvider = context.read<SettingsProvider>();
    if (settingsProvider.recordEditorDialogEnabled) {
      final patch = await showRecordEditorDialog(
        context,
        log: log,
        readOnly: false,
        accessChanges: logProvider,
        canRead: () => logProvider.hasReadAccess,
        canEdit: () => logProvider.canMutateLog(log),
      );
      if (patch == null || !mounted) return;
      await _applyEditingPatch(logProvider, log, patch);
      return;
    }
    setState(() {
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _editingIndex = index;
      _editingOriginal = log;
      _editingSaveInProgress = false;
      _controllers = {
        'time': TextEditingController(
          text: formatLogTimeForDisplay(log.time),
        ),
        'controller': TextEditingController(text: log.controller),
        'callsign': TextEditingController(text: log.callsign),
        'report': TextEditingController(text: log.report),
        'rstRcvd': TextEditingController(text: log.rstRcvd),
        'qth': TextEditingController(text: log.qth),
        'device': TextEditingController(text: log.device),
        'power': TextEditingController(text: log.power),
        'antenna': TextEditingController(text: log.antenna),
        'height': TextEditingController(text: log.height),
        'remarks': TextEditingController(text: log.remarks),
        '_id': TextEditingController(text: log.id),
        '_sessionId': TextEditingController(text: log.sessionId ?? ''),
        '_createdAt': TextEditingController(text: log.createdAt),
      };
    });
  }

  Future<void> _applyEditingPatch(
    LogProvider logProvider,
    LogEntry original,
    LogEntry patch,
  ) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final time = patch.time;
    if (!isValidLogTimeInput(time)) {
      messenger?.showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.logTimeInvalid)),
      );
      return;
    }
    final currentIndex =
        logProvider.logs.indexWhere((candidate) => candidate.id == original.id);
    final current = currentIndex < 0 ? null : logProvider.logs[currentIndex];
    if (widget.readOnly ||
        widget.conflictedLogIds.contains(original.id) ||
        current == null ||
        !logProvider.canMutateLog(current)) {
      return;
    }
    final finalPatch = patch.copyWith(
      id: original.id,
      sessionId: original.sessionId,
      createdAt: original.createdAt,
    );
    try {
      await logProvider.updateLogFromOriginal(original, finalPatch);
    } catch (error) {
      if (!mounted) return;
      messenger?.showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.operationFailed('$error'))),
      );
    }
  }

  void _cancelEditing() {
    if (!mounted) return;
    setState(() {
      _editingIndex = null;
      _editingSaveInProgress = false;
      for (var controller in _controllers.values) {
        controller.dispose();
      }
      _controllers = {};
    });
  }

  Future<void> _saveEditing() async {
    if (_editingSaveInProgress) return;
    final logId = _controllers['_id']?.text ?? '';
    final logProvider = Provider.of<LogProvider>(context, listen: false);
    final currentIndex =
        logProvider.logs.indexWhere((candidate) => candidate.id == logId);
    final original = currentIndex < 0 ? null : _editingOriginal;
    if (widget.readOnly ||
        widget.conflictedLogIds.contains(logId) ||
        original == null ||
        !logProvider.canMutateLog(original)) {
      _cancelEditing();
      return;
    }
    setState(() => _editingSaveInProgress = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final time = _controllers['time']?.text ?? '';
    if (!isValidLogTimeInput(time)) {
      setState(() => _editingSaveInProgress = false);
      messenger?.showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.logTimeInvalid)),
      );
      return;
    }
    // updateLog preserves sync_id / localId / sessionId / createdAt — only the
    // text fields below are taken from the form.
    final patch = LogEntry(
      id: _controllers['_id']?.text ?? '',
      sessionId: _controllers['_sessionId']?.text,
      time: time,
      controller: _controllers['controller']?.text ?? '',
      callsign: _controllers['callsign']?.text ?? '',
      report: _controllers['report']?.text ?? '',
      rstRcvd: _controllers['rstRcvd']?.text ?? '',
      qth: _controllers['qth']?.text ?? '',
      device: _controllers['device']?.text ?? '',
      power: _controllers['power']?.text ?? '',
      antenna: _controllers['antenna']?.text ?? '',
      height: _controllers['height']?.text ?? '',
      createdAt: _controllers['_createdAt']?.text,
    );
    patch.remarks = _controllers['remarks']?.text ?? '';
    try {
      await logProvider.updateLogFromOriginal(original, patch);
    } catch (error) {
      if (!mounted) return;
      setState(() => _editingSaveInProgress = false);
      messenger?.showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.operationFailed('$error'))),
      );
      return;
    }
    _cancelEditing();
  }

  @override
  Widget build(BuildContext context) {
    final logProvider = context.watch<LogProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    return _buildContent(context, logProvider, settingsProvider);
  }

  Widget _buildContent(
    BuildContext context,
    LogProvider logProvider,
    SettingsProvider settingsProvider,
  ) {
    if (logProvider.logs.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < _mobileBreakpoint;
          return Container(
            margin: EdgeInsets.all(compact ? 0 : 16),
            padding: EdgeInsets.all(compact ? 24 : 40),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.list_alt,
                  size: compact ? 44 : 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(height: compact ? 10 : 16),
                Text(
                  context.l10n.noSavedRecords,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.addFirstRecordHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    final horizontalController = _horizontalController;

    return LayoutBuilder(
      builder: (context, constraints) {
        final allLogs = logProvider.logs;
        final sourceEntries = _searchQuery.isEmpty
            ? allLogs.asMap().entries.toList(growable: false)
            : _filterLogEntries(allLogs, _searchQuery);
        final displayEntries = _visibleLogEntries(
          settingsProvider,
          allLogs: allLogs,
          sourceEntries: sourceEntries,
        );
        final searchField = _buildSearchField(context);
        if (constraints.maxWidth < _mobileBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              if (sourceEntries.isEmpty && _searchQuery.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      context.l10n.logTableSearchNoMatches,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                )
              else
                _buildMobileRecords(
                  context,
                  logProvider,
                  settingsProvider,
                  displayEntries,
                  totalLogs: sourceEntries.length,
                ),
            ],
          );
        }
        final visibleRows = displayEntries.length;
        final totalContentHeight = 48.0 + visibleRows * 56.0;
        // 父容器无界时表格完全展开（整页/全部记录都铺开，由外层页面滚动）；
        // 父容器有界（如固定高度容器）时表格占满可用高度，内容超高才内部滚动。
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : totalContentHeight;
        final enableInnerVerticalScroll =
            constraints.maxHeight.isFinite && totalContentHeight > maxHeight;
        final colors = Theme.of(context).colorScheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDesktopToolbar(context),
            if (sourceEntries.isEmpty && _searchQuery.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    context.l10n.logTableSearchNoMatches,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              )
            else
              _buildDesktopTableContainer(
                maxHeight: maxHeight,
                expandToRemaining: constraints.maxHeight.isFinite,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: DecoratedBox(
                    key: const Key('log-table-surface'),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SingleChildScrollView(
                      physics: enableInnerVerticalScroll
                          ? const ClampingScrollPhysics()
                          : const NeverScrollableScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Listener(
                              onPointerSignal: _handleTablePointerSignal,
                              child: Scrollbar(
                                controller: horizontalController,
                                thumbVisibility: true,
                                trackVisibility: true,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  controller: horizontalController,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: constraints.maxWidth -
                                          _desktopActionsWidth,
                                    ),
                                    child: _buildDesktopDataTable(
                                      context,
                                      logProvider,
                                      displayEntries,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _buildDesktopActionsColumn(
                            context,
                            logProvider,
                            displayEntries,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // 分页控件
            if (settingsProvider.paginationEnabled &&
                sourceEntries.length > settingsProvider.tablePageSize)
              _buildPaginationControls(
                sourceEntries.length,
                settingsProvider.tablePageSize,
              ),
          ],
        );
      },
    );
  }

  List<MapEntry<int, LogEntry>> _visibleLogEntries(
    SettingsProvider settingsProvider, {
    required List<LogEntry> allLogs,
    required List<MapEntry<int, LogEntry>> sourceEntries,
  }) {
    final indexedLogs = sourceEntries.reversed.toList(growable: false);

    // Reset page when underlying log list is replaced (e.g. session switch).
    // Use identity comparison because LogProvider rebuilds the list on every load.
    if (!identical(_lastSeenLogs, allLogs)) {
      _lastSeenLogs = allLogs;
      _currentPage = 0;
    }

    // 如果启用分页，只显示当前页的数据（按最新在上排序后的结果）
    if (settingsProvider.paginationEnabled) {
      final pageSize = settingsProvider.tablePageSize;
      final totalPages =
          (indexedLogs.length / pageSize).ceil().clamp(1, 1 << 30);
      if (_currentPage >= totalPages) {
        // Logs got shorter (session switch / clear / undo) — snap back to a
        // valid page instead of showing an empty slice.
        _currentPage = totalPages - 1;
      }
      final startIndex = _currentPage * pageSize;
      final endIndex = (startIndex + pageSize).clamp(0, indexedLogs.length);
      return indexedLogs.sublist(startIndex, endIndex);
    }
    return indexedLogs;
  }

  /// 按搜索词过滤记录：匹配呼号、时间、RST、QTH、设备、功率、天线、高度、
  /// 备注与主控（大小写不敏感）。
  List<MapEntry<int, LogEntry>> _filterLogEntries(
    List<LogEntry> logs,
    String query,
  ) {
    final needle = query.trim().toLowerCase();
    final indexedLogs = logs.asMap().entries;
    if (needle.isEmpty) return indexedLogs.toList(growable: false);
    return indexedLogs
        .where((entry) => [
              entry.value.callsign,
              entry.value.time,
              formatLogTimeForDisplay(entry.value.time),
              entry.value.report,
              entry.value.rstRcvd,
              entry.value.qth,
              entry.value.device,
              entry.value.power,
              entry.value.antenna,
              entry.value.height,
              entry.value.remarks,
              entry.value.controller,
            ].any((value) => value.toLowerCase().contains(needle)))
        .toList(growable: false);
  }

  /// 表格高度容器：父约束有限时占满剩余空间（配合外层搜索框），
  /// 无限时用计算出的 [maxHeight]。
  Widget _buildDesktopTableContainer({
    required double maxHeight,
    required bool expandToRemaining,
    required Widget child,
  }) {
    if (expandToRemaining) {
      return Expanded(
        child: SizedBox(height: double.infinity, child: child),
      );
    }
    return SizedBox(height: maxHeight, child: child);
  }

  Widget _buildSearchField(
    BuildContext context, {
    bool includeBottomPadding = true,
  }) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: includeBottomPadding ? 10 : 0),
      child: TextField(
        key: const Key('log-table-search'),
        controller: _searchController,
        onChanged: (value) => setState(() {
          _searchQuery = value;
          _currentPage = 0;
        }),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.logTableSearchHint,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  key: const Key('log-table-search-clear'),
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: l10n.logTableSearchClear,
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _currentPage = 0;
                    });
                  },
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildDesktopToolbar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: _buildSearchField(
              context,
              includeBottomPadding: false,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            key: const Key('log-table-horizontal-scroll-hint'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swipe_outlined,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Text(
                  context.l10n.logTableHorizontalScrollHint,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleTablePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        !HardwareKeyboard.instance.isShiftPressed ||
        !_horizontalController.hasClients) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (signal) {
      final position = _horizontalController.position;
      final pointer = signal as PointerScrollEvent;
      final delta = pointer.scrollDelta.dy != 0
          ? pointer.scrollDelta.dy
          : pointer.scrollDelta.dx;
      _horizontalController.jumpTo(
        (position.pixels + delta).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  DataTable _buildDesktopDataTable(
    BuildContext context,
    LogProvider logProvider,
    List<MapEntry<int, LogEntry>> displayEntries,
  ) {
    final colors = Theme.of(context).colorScheme;
    return DataTable(
      // LogProvider replaces its visible projection after every durable
      // mutation or collaboration reconciliation. Key the projection so stale
      // row render state cannot survive a synchronous refresh.
      key: ObjectKey(logProvider.logs),
      columnSpacing: 16,
      horizontalMargin: 16,
      headingRowHeight: 48,
      dataRowMinHeight: 56,
      dataRowMaxHeight: 56,
      headingRowColor: WidgetStatePropertyAll(
        colors.surfaceContainerHighest,
      ),
      headingTextStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: colors.onSurface,
        fontSize: 13,
      ),
      dataTextStyle: TextStyle(color: colors.onSurface, fontSize: 13),
      dividerThickness: 1,
      border: TableBorder(
        horizontalInside: BorderSide(color: colors.outlineVariant),
      ),
      columns: [
        DataColumn(label: _buildCenteredCell(const Text('#'), 60)),
        DataColumn(
          label: _buildCenteredCell(Text(context.l10n.fieldTime), 100),
        ),
        DataColumn(
          label: _buildCenteredCell(Text(context.l10n.fieldController), 120),
        ),
        DataColumn(
          label: _buildCenteredCell(Text(context.l10n.fieldCallsign), 120),
        ),
        DataColumn(
          label: _buildCenteredCell(Text(context.l10n.fieldRstSent), 60),
        ),
        DataColumn(
          label: _buildCenteredCell(Text(context.l10n.fieldRstRcvd), 60),
        ),
        DataColumn(
          label: _buildCenteredCell(Text(context.l10n.fieldQth), 150),
        ),
        DataColumn(
          label: _buildCenteredCell(Text(context.l10n.fieldDevice), 150),
        ),
        DataColumn(
          label: _buildCenteredCell(Text(context.l10n.fieldPower), 80),
        ),
        DataColumn(
          label: _buildCenteredCell(Text(context.l10n.fieldAntenna), 150),
        ),
        DataColumn(
          label: _buildCenteredCell(Text(context.l10n.fieldHeight), 80),
        ),
        DataColumn(
          label: _buildCenteredCell(Text(context.l10n.fieldRemarks), 120),
        ),
      ],
      rows: _buildTableRows(context, displayEntries),
    );
  }

  Widget _buildDesktopActionsColumn(
    BuildContext context,
    LogProvider logProvider,
    List<MapEntry<int, LogEntry>> displayEntries,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      key: const Key('desktop-log-actions-column'),
      width: _desktopActionsWidth,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(left: BorderSide(color: colors.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(-3, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: ColoredBox(
              color: colors.surfaceContainerHighest,
              child: Center(
                child: Text(
                  context.l10n.fieldActions,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ),
          ),
          for (final entry in displayEntries.asMap().entries)
            _buildDesktopActionRow(
              context,
              logProvider,
              entry.value,
              visualIndex: entry.key,
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopActionRow(
    BuildContext context,
    LogProvider logProvider,
    MapEntry<int, LogEntry> indexedLog, {
    required int visualIndex,
  }) {
    final originalIndex = indexedLog.key;
    final log = indexedLog.value;
    final isEditing = _editingIndex == originalIndex;
    final isConflicted = widget.conflictedLogIds.contains(log.id);
    final mutationBlockReason = widget.readOnly
        ? 'COLLABORATION_SESSION_READ_ONLY'
        : logProvider.mutationBlockReason(log);
    final canMutate = mutationBlockReason == null && !isConflicted;
    final mutationHint = isConflicted
        ? context.l10n.logConflictReadOnlyHint
        : mutationBlockReason == null
            ? ''
            : _mutationBlockLabel(context, mutationBlockReason);
    final colors = Theme.of(context).colorScheme;

    return Container(
      key: Key('desktop-log-actions-${log.id}'),
      height: 56,
      decoration: BoxDecoration(
        color: isEditing
            ? colors.primaryContainer.withValues(alpha: 0.22)
            : visualIndex.isOdd
                ? colors.surfaceContainerLowest
                : colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      alignment: Alignment.center,
      child: isEditing
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  icon: _editingSaveInProgress
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 20),
                  onPressed: !canMutate || _editingSaveInProgress
                      ? null
                      : _saveEditing,
                  tooltip: !canMutate ? mutationHint : context.l10n.save,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: _editingSaveInProgress ? null : _cancelEditing,
                  tooltip: context.l10n.cancel,
                ),
              ],
            )
          : !canMutate
              ? Tooltip(
                  message: mutationHint,
                  child: Icon(
                    Icons.lock_outline,
                    color: colors.onSurfaceVariant,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => _startEditing(originalIndex, log),
                      tooltip: context.l10n.editRecord,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: colors.error,
                      onPressed: logProvider.canDeleteLog(log)
                          ? () => _showDeleteConfirmation(context, log)
                          : null,
                      tooltip: context.l10n.deleteRecord,
                    ),
                  ],
                ),
    );
  }

  Widget _buildMobileRecords(
    BuildContext context,
    LogProvider logProvider,
    SettingsProvider settingsProvider,
    List<MapEntry<int, LogEntry>> displayEntries, {
    required int totalLogs,
  }) {
    return Column(
      key: const Key('mobile-log-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < displayEntries.length; index++) ...[
          _buildMobileRecordCard(
            context,
            logProvider,
            displayEntries[index],
          ),
          if (index != displayEntries.length - 1) const SizedBox(height: 10),
        ],
        if (settingsProvider.paginationEnabled &&
            totalLogs > settingsProvider.tablePageSize)
          _buildPaginationControls(
            totalLogs,
            settingsProvider.tablePageSize,
          ),
      ],
    );
  }

  Widget _buildMobileRecordCard(
    BuildContext context,
    LogProvider logProvider,
    MapEntry<int, LogEntry> indexedLog,
  ) {
    final originalIndex = indexedLog.key;
    final log = indexedLog.value;
    final isEditing = _editingIndex == originalIndex;
    final isConflicted = widget.conflictedLogIds.contains(log.id);
    final mutationBlockReason = widget.readOnly
        ? 'COLLABORATION_SESSION_READ_ONLY'
        : logProvider.mutationBlockReason(log);
    final canMutate = mutationBlockReason == null && !isConflicted;
    final mutationHint = isConflicted
        ? context.l10n.logConflictReadOnlyHint
        : mutationBlockReason == null
            ? ''
            : _mutationBlockLabel(context, mutationBlockReason);
    if (isEditing) {
      return _buildMobileRecordEditor(
        context,
        originalIndex: originalIndex,
        log: log,
        canMutate: canMutate,
        mutationHint: mutationHint,
      );
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final details = <MapEntry<String, String>>[
      MapEntry(context.l10n.fieldQth, log.qth),
      MapEntry(context.l10n.fieldDevice, log.device),
      MapEntry(context.l10n.fieldAntenna, log.antenna),
      MapEntry(context.l10n.fieldPower, log.power),
      MapEntry(context.l10n.fieldHeight, log.height),
      MapEntry(context.l10n.fieldRemarks, log.remarks),
    ].where((entry) => entry.value.trim().isNotEmpty).toList(growable: false);

    return Material(
      key: Key('mobile-log-card-${log.id}'),
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isConflicted ? colors.error : colors.outlineVariant,
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('mobile-log-expansion-${log.id}'),
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            constraints: const BoxConstraints(minWidth: 40),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '#${originalIndex + 1}',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  log.callsign.trim().isEmpty ? '—' : log.callsign,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!canMutate) ...[
                const SizedBox(width: 6),
                Icon(
                  isConflicted ? Icons.warning_amber : Icons.lock_outline,
                  size: 17,
                  color: isConflicted ? colors.error : colors.onSurfaceVariant,
                ),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                _buildMobileMeta(
                  context,
                  Icons.schedule_outlined,
                  formatLogTimeForDisplay(log.time),
                ),
                _buildMobileMeta(
                  context,
                  Icons.record_voice_over_outlined,
                  log.controller,
                ),
                _buildMobileMeta(
                  context,
                  Icons.cell_tower_outlined,
                  '${log.report}/${log.rstRcvd}',
                ),
              ],
            ),
          ),
          children: [
            Divider(height: 1, color: colors.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (details.isNotEmpty)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final itemWidth = (constraints.maxWidth - 8) / 2;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final detail in details)
                              SizedBox(
                                width: detail.key == context.l10n.fieldRemarks
                                    ? constraints.maxWidth
                                    : itemWidth,
                                child: _buildMobileDetail(
                                  context,
                                  detail.key,
                                  detail.value,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  if (details.isNotEmpty) const SizedBox(height: 12),
                  if (canMutate)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final editButton = OutlinedButton.icon(
                          key: Key('mobile-edit-log-${log.id}'),
                          onPressed: () => _startEditing(originalIndex, log),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(context.l10n.editRecord),
                        );
                        final deleteButton = OutlinedButton.icon(
                          key: Key('mobile-delete-log-${log.id}'),
                          onPressed: logProvider.canDeleteLog(log)
                              ? () => _showDeleteConfirmation(context, log)
                              : null,
                          icon: const Icon(Icons.delete_outline),
                          label: Text(context.l10n.deleteRecord),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.error,
                            side: BorderSide(
                              color: colors.error.withValues(alpha: 0.65),
                            ),
                          ),
                        );
                        if (constraints.maxWidth < 300) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              editButton,
                              const SizedBox(height: 8),
                              deleteButton,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: editButton),
                            const SizedBox(width: 8),
                            Expanded(child: deleteButton),
                          ],
                        );
                      },
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isConflicted
                            ? colors.errorContainer
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isConflicted
                                ? Icons.warning_amber
                                : Icons.lock_outline,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              mutationHint,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileRecordEditor(
    BuildContext context, {
    required int originalIndex,
    required LogEntry log,
    required bool canMutate,
    required String mutationHint,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      key: Key('mobile-log-editor-${log.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.18),
        border: Border.all(color: colors.primary.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '#${originalIndex + 1}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.editRecord,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final halfWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  _buildMobileEditField(
                    context,
                    field: 'controller',
                    label: context.l10n.fieldController,
                    width: constraints.maxWidth,
                  ),
                  _buildMobileEditField(
                    context,
                    field: 'callsign',
                    label: context.l10n.fieldCallsign,
                    width: constraints.maxWidth,
                  ),
                  _buildMobileEditField(
                    context,
                    field: 'time',
                    label: context.l10n.fieldTime,
                    width: constraints.maxWidth,
                  ),
                  _buildMobileEditField(
                    context,
                    field: 'report',
                    label: context.l10n.fieldRstSent,
                    width: halfWidth,
                  ),
                  _buildMobileEditField(
                    context,
                    field: 'rstRcvd',
                    label: context.l10n.fieldRstRcvd,
                    width: halfWidth,
                  ),
                  _buildMobileEditField(
                    context,
                    field: 'qth',
                    label: context.l10n.fieldQth,
                    width: constraints.maxWidth,
                  ),
                  _buildMobileEditField(
                    context,
                    field: 'device',
                    label: context.l10n.fieldDevice,
                    width: constraints.maxWidth,
                  ),
                  _buildMobileEditField(
                    context,
                    field: 'antenna',
                    label: context.l10n.fieldAntenna,
                    width: constraints.maxWidth,
                  ),
                  _buildMobileEditField(
                    context,
                    field: 'power',
                    label: context.l10n.fieldPower,
                    width: halfWidth,
                  ),
                  _buildMobileEditField(
                    context,
                    field: 'height',
                    label: context.l10n.fieldHeight,
                    width: halfWidth,
                  ),
                  _buildMobileEditField(
                    context,
                    field: 'remarks',
                    label: context.l10n.fieldRemarks,
                    width: constraints.maxWidth,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              );
            },
          ),
          if (!canMutate) ...[
            const SizedBox(height: 10),
            Text(
              mutationHint,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _editingSaveInProgress ? null : _cancelEditing,
                  child: Text(context.l10n.cancel),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  key: Key('mobile-save-log-${log.id}'),
                  onPressed: !canMutate || _editingSaveInProgress
                      ? null
                      : _saveEditing,
                  icon: _editingSaveInProgress
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _editingSaveInProgress
                        ? context.l10n.savingRecord
                        : context.l10n.save,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileEditField(
    BuildContext context, {
    required String field,
    required String label,
    required double width,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        key: Key('mobile-edit-field-$field'),
        controller: _controllers[field],
        textInputAction: textInputAction,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildMobileMeta(
    BuildContext context,
    IconData icon,
    String value,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          value.trim().isEmpty ? '—' : value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildMobileDetail(
    BuildContext context,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: label == context.l10n.fieldRemarks ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<DataRow> _buildTableRows(
    BuildContext context,
    List<MapEntry<int, LogEntry>> displayEntries,
  ) {
    return displayEntries.asMap().entries.map((entry) {
      final originalIndex = entry.value.key;
      final log = entry.value.value;
      final isEditing = _editingIndex == originalIndex;
      // 倒序序号：最新的记录显示最大序号
      final reverseIndex = originalIndex + 1;

      return DataRow(
        // Rows can move whenever a newer record is inserted at the top. Tie
        // state to the durable sync id instead of the transient row index.
        key: ValueKey(log.id),
        color: WidgetStatePropertyAll(
          isEditing
              ? Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.22)
              : entry.key.isOdd
                  ? Theme.of(context).colorScheme.surfaceContainerLowest
                  : Colors.transparent,
        ),
        cells: [
          DataCell(
            _buildCenteredCell(Text('$reverseIndex'), 60),
          ),
          DataCell(
            isEditing
                ? SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _controllers['time'],
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _buildCenteredCell(
                    Text(formatLogTimeForDisplay(log.time)), 100),
          ),
          DataCell(
            isEditing
                ? SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _controllers['controller'],
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _buildCenteredCell(Text(log.controller), 120),
          ),
          DataCell(
            isEditing
                ? SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _controllers['callsign'],
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _buildCenteredCell(Text(log.callsign), 120),
          ),
          DataCell(
            isEditing
                ? SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _controllers['report'],
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _buildCenteredCell(Text(log.report), 60),
          ),
          DataCell(
            isEditing
                ? SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _controllers['rstRcvd'],
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _buildCenteredCell(Text(log.rstRcvd), 60),
          ),
          DataCell(
            isEditing
                ? SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _controllers['qth'],
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _buildCenteredCell(Text(log.qth), 150),
          ),
          DataCell(
            isEditing
                ? SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _controllers['device'],
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _buildCenteredCell(Text(log.device), 150),
          ),
          DataCell(
            isEditing
                ? SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _controllers['power'],
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _buildCenteredCell(Text(log.power), 80),
          ),
          DataCell(
            isEditing
                ? SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _controllers['antenna'],
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _buildCenteredCell(Text(log.antenna), 150),
          ),
          DataCell(
            isEditing
                ? SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _controllers['height'],
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : _buildCenteredCell(Text(log.height), 80),
          ),
          DataCell(
            _buildCenteredCell(
              isEditing
                  ? SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _controllers['remarks'],
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        ),
                      ),
                    )
                  : Text(log.remarks),
              110,
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildCenteredCell(Widget child, double width) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _buildPaginationControls(int totalItems, int itemsPerPage) {
    final totalPages = (totalItems / itemsPerPage).ceil();

    return Container(
      key: const Key('log-pagination'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: context.l10n.previousPage,
            onPressed:
                _currentPage > 0 ? () => setState(() => _currentPage--) : null,
          ),
          const SizedBox(width: 8),
          Text('${_currentPage + 1} / $totalPages'),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: context.l10n.nextPage,
            onPressed: _currentPage < totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext tableContext,
    LogEntry log,
  ) async {
    final logProvider = tableContext.read<LogProvider>();
    if (widget.readOnly ||
        widget.conflictedLogIds.contains(log.id) ||
        !logProvider.canDeleteLog(log)) {
      return;
    }
    final deleted = await showDialog<bool>(
      context: tableContext,
      barrierDismissible: false,
      builder: (dialogContext) => _DeleteLogDialog(
        onDelete: () async {
          if (widget.readOnly ||
              widget.conflictedLogIds.contains(log.id) ||
              !logProvider.canDeleteLog(log)) {
            throw StateError(_mutationBlockLabel(
              dialogContext,
              logProvider.mutationBlockReason(log),
            ));
          }
          await logProvider.deleteLogFromOriginal(log);
        },
      ),
    );
    if (deleted != true || !mounted) return;
    context.showLoggedSnackBar(
      SnackBar(
        content: Text(context.l10n.recordDeleted),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _mutationBlockLabel(BuildContext context, String? reason) =>
      switch (reason) {
        'COLLABORATION_LOG_NOT_OWNED' => context.l10n.logNotOwnedReadOnlyHint,
        'COLLABORATION_LOG_AUTHOR_UNKNOWN' =>
          context.l10n.logAuthorUnknownReadOnlyHint,
        _ => context.l10n.logSessionReadOnlyHint,
      };
}

class _DeleteLogDialog extends StatefulWidget {
  const _DeleteLogDialog({required this.onDelete});

  final Future<void> Function() onDelete;

  @override
  State<_DeleteLogDialog> createState() => _DeleteLogDialogState();
}

class _DeleteLogDialogState extends State<_DeleteLogDialog> {
  bool _deleting = false;

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() => _deleting = true);

    try {
      await widget.onDelete();
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.maybeOf(context)?.showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.operationFailed('$error'))),
      );
      return;
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        title: Text(context.l10n.deleteRecord),
        content: Text(context.l10n.deleteRecordConfirmation),
        actions: [
          TextButton(
            onPressed: _deleting ? null : () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: _deleting ? null : _delete,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: _deleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.delete),
          ),
        ],
      ),
    );
  }
}
