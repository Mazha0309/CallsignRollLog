import 'dart:async';
import 'package:openlogtool/utils/app_snack_bar.dart';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/dictionary_item.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/providers/ai_recognition_settings_provider.dart';
import 'package:openlogtool/services/ai_recognition/errors.dart';
import 'package:openlogtool/services/ai_recognition/providers.dart';
import 'package:openlogtool/services/text_assistant_tasks.dart';
import 'package:openlogtool/src/bridge/rust_api.dart';
import 'package:openlogtool/theme/app_theme.dart';
import 'package:openlogtool/widgets/settings/settings_ui.dart';
import 'package:provider/provider.dart';

const double _wideDictionaryBreakpoint = 720;

// Kept for compatibility with callers that used the previous grid helper.
int dictionaryGridColumnCount(double width) => width >= 760 ? 2 : 1;

int dictionaryPageSize(double width) =>
    width >= _wideDictionaryBreakpoint ? 20 : 10;

/// Owns its scroll panes and must be placed in a bounded-height viewport.
class DictionaryManager extends StatefulWidget {
  const DictionaryManager({super.key, this.embedded = false});

  /// Uses a compact action toolbar when hosted by the data workspace.
  final bool embedded;

  @override
  State<DictionaryManager> createState() => _DictionaryManagerState();
}

class _DictionaryManagerState extends State<DictionaryManager> {
  String _selectedType = 'device';
  final Map<String, TextEditingController> _addControllers =
      <String, TextEditingController>{
    'device': TextEditingController(),
    'antenna': TextEditingController(),
    'callsign': TextEditingController(),
    'qth': TextEditingController(),
  };
  final Map<String, TextEditingController> _searchControllers =
      <String, TextEditingController>{
    'device': TextEditingController(),
    'antenna': TextEditingController(),
    'callsign': TextEditingController(),
    'qth': TextEditingController(),
  };
  final Map<String, String> _queries = <String, String>{};
  final Map<String, int> _pages = <String, int>{};
  final Set<String> _busyLibraries = <String>{};
  final _navigationScroll = ScrollController();
  final _libraryScroll = {
    for (final type in ['device', 'antenna', 'callsign', 'qth'])
      type: ScrollController(),
  };
  bool _importing = false;
  bool _exporting = false;
  bool _aiBusy = false;

  bool get _mutationInProgress =>
      _importing || _exporting || _aiBusy || _busyLibraries.isNotEmpty;

  @override
  void dispose() {
    _navigationScroll.dispose();
    for (final controller in _libraryScroll.values) {
      controller.dispose();
    }
    for (final controller in _addControllers.values) {
      controller.dispose();
    }
    for (final controller in _searchControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _libraryName(String type) => switch (type) {
        'device' => context.l10n.deviceLibrary,
        'antenna' => context.l10n.antennaLibrary,
        'callsign' => context.l10n.callsignLibrary,
        'qth' => context.l10n.qthLibrary,
        _ => '',
      };

  IconData _libraryIcon(String type) => switch (type) {
        'device' => Icons.radio_outlined,
        'antenna' => Icons.settings_input_antenna,
        'callsign' => Icons.badge_outlined,
        'qth' => Icons.place_outlined,
        _ => Icons.folder_outlined,
      };

  void _selectLibrary(String type) {
    if (_selectedType == type) return;
    setState(() => _selectedType = type);
  }

  Future<void> _importFromFile() async {
    if (_mutationInProgress) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<DictionaryProvider>();
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      if (bytes == null) {
        throw const FormatException('Selected file could not be read');
      }
      final counts = await provider.importFromJson(utf8.decode(bytes));
      if (!mounted) return;
      final imported = counts.entries.where((entry) => entry.value > 0);
      if (imported.isEmpty) {
        messenger.showLoggedSnackBar(
          SnackBar(content: Text(l10n.libraryImportEmpty)),
        );
        return;
      }
      final summary = imported
          .map(
            (entry) => l10n.libraryImportCount(
              _libraryName(entry.key),
              entry.value,
            ),
          )
          .join(l10n.listSeparator);
      _pages.clear();
      messenger.showLoggedSnackBar(
        SnackBar(content: Text(l10n.libraryImportSucceeded(summary))),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showLoggedSnackBar(
        SnackBar(content: Text(l10n.libraryImportFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _exportToFile() async {
    if (_mutationInProgress) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<DictionaryProvider>();
    setState(() => _exporting = true);
    try {
      final jsonData = provider.exportToJson();
      final bytes = Uint8List.fromList(utf8.encode(jsonData));
      final now = DateTime.now();
      final fileName = 'openlogtool_dictionaries_${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}.json';
      final pickerWritesBytes = kIsWeb || Platform.isAndroid || Platform.isIOS;
      final result = await FilePicker.platform.saveFile(
        dialogTitle: l10n.libraryExportDialogTitle,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
        bytes: pickerWritesBytes ? bytes : null,
      );
      if (result == null) return;
      if (!pickerWritesBytes) {
        await File(result).writeAsBytes(bytes, flush: true);
      }
      if (!mounted) return;
      messenger.showLoggedSnackBar(
        SnackBar(content: Text(l10n.libraryExportSucceeded)),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showLoggedSnackBar(
        SnackBar(content: Text(l10n.libraryExportFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _addItem(_LibraryDefinition library) async {
    final controller = _addControllers[library.type]!;
    final value = controller.text.trim();
    if (value.isEmpty || _mutationInProgress) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (library.items.any((item) => item.raw == value)) {
      messenger.showLoggedSnackBar(
        SnackBar(content: Text(l10n.libraryItemAlreadyExists(value))),
      );
      return;
    }

    setState(() => _busyLibraries.add(library.type));
    try {
      await library.onAdd(value);
      if (!mounted) return;
      controller.clear();
      messenger.showLoggedSnackBar(
        SnackBar(content: Text(l10n.libraryItemAdded(value))),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showLoggedSnackBar(
        SnackBar(content: Text(l10n.libraryItemAddFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _busyLibraries.remove(library.type));
    }
  }

  Future<void> _editItem(
    _LibraryDefinition library,
    DictionaryItem item,
  ) async {
    if (_mutationInProgress) return;
    final renamed = await showDialog<String>(
      context: context,
      builder: (_) => _EditLibraryItemDialog(
        libraryType: library.type,
        libraryName: _libraryName(library.type),
        initialValue: item.raw,
      ),
    );
    if (renamed == null || !mounted || renamed == item.raw) return;

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (library.items.any((candidate) => candidate.raw == renamed)) {
      messenger.showLoggedSnackBar(
        SnackBar(content: Text(l10n.libraryItemAlreadyExists(renamed))),
      );
      return;
    }
    setState(() => _busyLibraries.add(library.type));
    try {
      await library.onRename(item.raw, renamed);
      if (!mounted) return;
      messenger.showLoggedSnackBar(
        SnackBar(content: Text(l10n.libraryItemRenamed(renamed))),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showLoggedSnackBar(
        SnackBar(content: Text(l10n.libraryItemRenameFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _busyLibraries.remove(library.type));
    }
  }

  Future<void> _deleteItem(
    _LibraryDefinition library,
    DictionaryItem item,
  ) async {
    if (_mutationInProgress) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.deleteLibraryItemTitle),
        content: Text(
          dialogContext.l10n.deleteLibraryItemConfirmation(
            item.raw,
            _libraryName(library.type),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            key: Key('confirm-delete-library-item-${library.type}'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.deleteLibraryItemAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyLibraries.add(library.type));
    try {
      await library.onDelete(item.raw);
      if (!mounted) return;
      messenger.showLoggedSnackBar(
        SnackBar(content: Text(l10n.libraryItemDeleted(item.raw))),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showLoggedSnackBar(
        SnackBar(content: Text(l10n.libraryItemDeleteFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _busyLibraries.remove(library.type));
    }
  }

  Future<void> _clearLibrary(_LibraryDefinition library) async {
    if (_mutationInProgress || library.items.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.l10n.clearLibraryTitle(_libraryName(library.type)),
        ),
        content: Text(
          dialogContext.l10n.clearLibraryConfirmation(
            _libraryName(library.type),
            library.items.length,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            key: Key('confirm-clear-library-${library.type}'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.clearLibraryAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyLibraries.add(library.type));
    try {
      await library.onClear();
      if (!mounted) return;
      _searchControllers[library.type]?.clear();
      _queries.remove(library.type);
      _pages.remove(library.type);
      messenger.showLoggedSnackBar(
        SnackBar(
          content: Text(l10n.libraryCleared(_libraryName(library.type))),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showLoggedSnackBar(
        SnackBar(content: Text(l10n.libraryClearFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _busyLibraries.remove(library.type));
    }
  }

  List<DictionaryItem> _filteredItems(_LibraryDefinition library) {
    final query = _queries[library.type]?.trim() ?? '';
    if (query.isEmpty) return library.items;
    return library.items.where((item) => item.matches(query)).toList();
  }

  List<Widget> _buildHeaderActions() => [
        OutlinedButton.icon(
          key: const Key('ai-recognize-dictionaries'),
          onPressed: _mutationInProgress
              ? null
              : () => _runDictionaryAssistant(optimize: false),
          icon: _aiBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.manage_search_outlined, size: 18),
          label: Text(context.l10n.aiDictionaryRecognize),
        ),
        OutlinedButton.icon(
          key: const Key('ai-optimize-dictionaries'),
          onPressed: _mutationInProgress
              ? null
              : () => _runDictionaryAssistant(optimize: true),
          icon: const Icon(Icons.auto_fix_high_outlined, size: 18),
          label: Text(context.l10n.aiDictionaryOptimize),
        ),
        OutlinedButton.icon(
          key: const Key('export-library-json'),
          onPressed: _mutationInProgress ? null : _exportToFile,
          icon: _exporting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_download_outlined, size: 18),
          label: Text(context.l10n.exportLibraryJson),
        ),
        FilledButton.tonalIcon(
          key: const Key('import-library-json'),
          onPressed: _mutationInProgress ? null : _importFromFile,
          icon: _importing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.file_upload_outlined, size: 18),
          label: Text(context.l10n.importLibraryJson),
        ),
      ];

  Future<void> _runDictionaryAssistant({required bool optimize}) async {
    if (_mutationInProgress) return;
    final settings = Provider.of<AiRecognitionSettingsProvider?>(
      context,
      listen: false,
    );
    if (settings == null ||
        !settings.textAssistantEnabled ||
        settings.textAssistantConfig == null) {
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.aiDictionaryNeedsAssistant)),
      );
      return;
    }
    final token = AiCancellationToken();
    final progress = ValueNotifier<(int, int)>((0, 0));
    var progressOpen = true;
    setState(() => _aiBusy = true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _AiDictionaryProgressDialog(
          progress: progress,
          cancellationToken: token,
          optimize: optimize,
        ),
      ),
    );
    try {
      final source = DictionaryAiSource.fromJson(
        await RustApi.getDictionaryAiSource(),
      );
      final suggestions = optimize
          ? await TextAssistantTasks.optimizeDictionaries(
              settings: settings,
              source: source,
              cancellationToken: token,
              onProgress: (done, total) => progress.value = (done, total),
            )
          : await TextAssistantTasks.recognizeHistory(
              settings: settings,
              source: source,
              cancellationToken: token,
              onProgress: (done, total) => progress.value = (done, total),
            );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      progressOpen = false;
      if (suggestions.isEmpty) {
        ScaffoldMessenger.of(context).showLoggedSnackBar(
          SnackBar(content: Text(context.l10n.aiDictionaryNoSuggestions)),
        );
        return;
      }
      final selected = await showDialog<List<DictionaryAiSuggestion>>(
        context: context,
        builder: (dialogContext) => _AiDictionaryReviewDialog(
          suggestions: suggestions,
          recordCount: source.recordCount,
        ),
      );
      if (selected == null || selected.isEmpty || !mounted) return;
      await context.read<DictionaryProvider>().applyAiSuggestions(
            expectedStateToken: source.stateToken,
            suggestions: selected,
          );
      if (!mounted) return;
      _pages.clear();
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(
            context.l10n.aiDictionaryApplied(selected.length),
          ),
        ),
      );
    } on AiRecognitionException catch (error) {
      if (!mounted) return;
      if (progressOpen) Navigator.of(context, rootNavigator: true).pop();
      if (error.kind != AiRecognitionErrorKind.cancelled) {
        ScaffoldMessenger.of(context).showLoggedSnackBar(
          SnackBar(content: Text(context.l10n.aiDictionaryFailed('$error'))),
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (progressOpen) Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.aiDictionaryFailed('$error'))),
      );
    } finally {
      progress.dispose();
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Widget _buildHeader() {
    final actions = _buildHeaderActions();
    if (widget.embedded) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: actions,
        ),
      );
    }
    return SettingsPageHeader(
      key: const Key('dictionary-page-header'),
      icon: Icons.menu_book_outlined,
      title: context.l10n.dictionaryManagementTitle,
      description: context.l10n.dictionaryManagementHint,
      actions: actions,
    );
  }

  Widget _buildWideCategories(List<_LibraryDefinition> libraries) {
    return SizedBox(
      width: 236,
      child: SettingsSectionCard(
        icon: Icons.folder_copy_outlined,
        title: context.l10n.dictionaryManagementTitle,
        padding: 12,
        contentSpacing: 8,
        child: Column(
          children: libraries
              .map(
                (library) => ListTile(
                  key: Key('library-category-${library.type}'),
                  selected: _selectedType == library.type,
                  selectedTileColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  leading: Icon(_libraryIcon(library.type)),
                  title: Text(_libraryName(library.type)),
                  subtitle: Text(
                    context.l10n.libraryItemCount(library.items.length),
                  ),
                  onTap: () => _selectLibrary(library.type),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildPhoneCategories(List<_LibraryDefinition> libraries) {
    return SingleChildScrollView(
      key: const Key('library-phone-categories'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: libraries
            .map(
              (library) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  key: Key('library-category-${library.type}'),
                  selected: _selectedType == library.type,
                  avatar: Icon(_libraryIcon(library.type), size: 18),
                  label: Text(
                    '${_libraryName(library.type)} · ${library.items.length}',
                  ),
                  onSelected: (_) => _selectLibrary(library.type),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildAddRow(_LibraryDefinition library, bool isBusy) {
    final field = TextField(
      key: Key('add-library-${library.type}'),
      controller: _addControllers[library.type],
      enabled: !isBusy,
      decoration: InputDecoration(
        labelText: context.l10n.addLibraryItem(_libraryName(library.type)),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _addItem(library),
    );
    final button = FilledButton.icon(
      onPressed: isBusy ? null : () => _addItem(library),
      icon: const Icon(Icons.add, size: 18),
      label: Text(context.l10n.add),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [field, const SizedBox(height: 8), button],
          );
        }
        return Row(
          children: [
            Expanded(child: field),
            const SizedBox(width: 8),
            button,
          ],
        );
      },
    );
  }

  Widget _buildSearchField(_LibraryDefinition library) {
    final controller = _searchControllers[library.type]!;
    return TextField(
      key: Key('search-library-${library.type}'),
      controller: controller,
      decoration: InputDecoration(
        hintText: context.l10n.searchLibrary(_libraryName(library.type)),
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  setState(() {
                    _queries.remove(library.type);
                    _pages[library.type] = 0;
                  });
                },
                icon: const Icon(Icons.close, size: 18),
              ),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (value) => setState(() {
        _queries[library.type] = value;
        _pages[library.type] = 0;
      }),
    );
  }

  Widget _buildEmptyState(_LibraryDefinition library) {
    final theme = Theme.of(context);
    final hasQuery = _queries[library.type]?.trim().isNotEmpty ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(
            hasQuery ? Icons.search_off : Icons.inbox_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            hasQuery
                ? context.l10n.noLibrarySearchResults
                : context.l10n.libraryEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(
    _LibraryDefinition library,
    List<DictionaryItem> items, {
    required int startIndex,
    required bool isBusy,
  }) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListView.separated(
        primary: false,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          final searchHint = <String>{
            if (item.pinyin.trim().isNotEmpty) item.pinyin.trim(),
            if (item.abbreviation.trim().isNotEmpty) item.abbreviation.trim(),
          }.join(' · ');
          return ListTile(
            key: Key('library-item-${library.type}-${item.syncId}'),
            contentPadding: const EdgeInsetsDirectional.only(
              start: 12,
              end: 4,
            ),
            leading: CircleAvatar(
              radius: 14,
              child: Text(
                '${startIndex + index + 1}',
                style: theme.textTheme.labelSmall,
              ),
            ),
            title: Text(item.raw, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: searchHint.isEmpty ? null : Text(searchHint),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: Key('edit-library-${library.type}-${item.syncId}'),
                  tooltip: context.l10n.editLibraryItem,
                  visualDensity: VisualDensity.compact,
                  onPressed: isBusy ? null : () => _editItem(library, item),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  key: Key('delete-library-${library.type}-${item.syncId}'),
                  tooltip: context.l10n.deleteLibraryItemAction,
                  visualDensity: VisualDensity.compact,
                  onPressed: isBusy ? null : () => _deleteItem(library, item),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPagination(
    _LibraryDefinition library, {
    required int currentPage,
    required int totalPages,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: Key('library-previous-page-${library.type}'),
          tooltip: context.l10n.previousPage,
          onPressed: currentPage == 0
              ? null
              : () => setState(() => _pages[library.type] = currentPage - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              context.l10n.libraryPageStatus(currentPage + 1, totalPages),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        IconButton(
          key: Key('library-next-page-${library.type}'),
          tooltip: context.l10n.nextPage,
          onPressed: currentPage >= totalPages - 1
              ? null
              : () => setState(() => _pages[library.type] = currentPage + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _buildWorkspace(
    _LibraryDefinition library, {
    required bool isWide,
  }) {
    final pageSize = isWide ? 20 : 10;
    final filteredItems = _filteredItems(library);
    final totalPages =
        filteredItems.isEmpty ? 1 : (filteredItems.length / pageSize).ceil();
    final requestedPage = _pages[library.type] ?? 0;
    final currentPage = requestedPage.clamp(0, totalPages - 1);
    _pages[library.type] = currentPage;
    final startIndex = currentPage * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, filteredItems.length);
    final pageItems = filteredItems.sublist(startIndex, endIndex);
    final isBusy = _mutationInProgress;

    return SettingsSectionCard(
      key: Key('library-workspace-${library.type}'),
      icon: _libraryIcon(library.type),
      title: _libraryName(library.type),
      description: context.l10n.libraryItemCount(library.items.length),
      headerTrailing: IconButton.filledTonal(
        key: Key('clear-library-${library.type}'),
        tooltip: context.l10n.clearLibraryTitle(_libraryName(library.type)),
        onPressed: library.items.isEmpty || isBusy
            ? null
            : () => _clearLibrary(library),
        icon: const Icon(Icons.delete_sweep_outlined),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAddRow(library, isBusy),
          const SizedBox(height: 10),
          _buildSearchField(library),
          const SizedBox(height: 12),
          if (filteredItems.isEmpty)
            _buildEmptyState(library)
          else
            _buildItemList(
              library,
              pageItems,
              startIndex: startIndex,
              isBusy: isBusy,
            ),
          if (filteredItems.isNotEmpty && totalPages > 1) ...[
            const SizedBox(height: 8),
            _buildPagination(
              library,
              currentPage: currentPage,
              totalPages: totalPages,
            ),
          ],
        ],
      ),
    );
  }

  List<_LibraryDefinition> _libraries(DictionaryProvider provider) =>
      <_LibraryDefinition>[
        _LibraryDefinition(
          type: 'device',
          items: provider.deviceDict,
          onAdd: provider.addDevice,
          onRename: provider.renameDevice,
          onDelete: provider.deleteDevice,
          onClear: provider.clearDeviceDict,
        ),
        _LibraryDefinition(
          type: 'antenna',
          items: provider.antennaDict,
          onAdd: provider.addAntenna,
          onRename: provider.renameAntenna,
          onDelete: provider.deleteAntenna,
          onClear: provider.clearAntennaDict,
        ),
        _LibraryDefinition(
          type: 'callsign',
          items: provider.callsignDict,
          onAdd: provider.addCallsign,
          onRename: provider.renameCallsign,
          onDelete: provider.deleteCallsign,
          onClear: provider.clearCallsignDict,
        ),
        _LibraryDefinition(
          type: 'qth',
          items: provider.qthDict,
          onAdd: provider.addQth,
          onRename: provider.renameQth,
          onDelete: provider.deleteQth,
          onClear: provider.clearQthDict,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final libraries = _libraries(context.watch<DictionaryProvider>());
    final selected = libraries.firstWhere(
      (library) => library.type == _selectedType,
      orElse: () => libraries.first,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.compact;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? AppSpace.sm : AppSpace.lg,
            compact ? AppSpace.md : AppSpace.lg,
            compact ? AppSpace.sm : AppSpace.lg,
            AppSpace.lg,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimensions.standardContentWidth,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide =
                      constraints.maxWidth >= _wideDictionaryBreakpoint;
                  if (!isWide) {
                    return _scrollPane(
                      name: selected.type,
                      controller: _libraryScroll[selected.type]!,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: AppSpace.md),
                          _buildPhoneCategories(libraries),
                          const SizedBox(height: 12),
                          _buildWorkspace(
                            selected,
                            isWide: false,
                          ),
                        ],
                      ),
                    );
                  }
                  return Row(
                    key: const Key('library-wide-workspace'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 236,
                        child: _scrollPane(
                          name: 'navigation',
                          controller: _navigationScroll,
                          child: _buildWideCategories(libraries),
                        ),
                      ),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: _scrollPane(
                          name: selected.type,
                          controller: _libraryScroll[selected.type]!,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: AppSpace.md),
                              _buildWorkspace(selected, isWide: true),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _scrollPane({
    required String name,
    required ScrollController controller,
    required Widget child,
  }) =>
      Scrollbar(
        controller: controller,
        child: SingleChildScrollView(
          key: PageStorageKey('library-$name-scroll'),
          controller: controller,
          primary: false,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          child: child,
        ),
      );
}

class _LibraryDefinition {
  const _LibraryDefinition({
    required this.type,
    required this.items,
    required this.onAdd,
    required this.onRename,
    required this.onDelete,
    required this.onClear,
  });

  final String type;
  final List<DictionaryItem> items;
  final Future<void> Function(String value) onAdd;
  final Future<void> Function(String oldValue, String newValue) onRename;
  final Future<void> Function(String value) onDelete;
  final Future<void> Function() onClear;
}

class _EditLibraryItemDialog extends StatefulWidget {
  const _EditLibraryItemDialog({
    required this.libraryType,
    required this.libraryName,
    required this.initialValue,
  });

  final String libraryType;
  final String libraryName;
  final String initialValue;

  @override
  State<_EditLibraryItemDialog> createState() => _EditLibraryItemDialogState();
}

class _EditLibraryItemDialogState extends State<_EditLibraryItemDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.editLibraryItemTitle(widget.libraryName)),
      content: TextField(
        key: Key('edit-library-item-field-${widget.libraryType}'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: context.l10n.editLibraryItemLabel,
          border: const OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: Key('confirm-edit-library-item-${widget.libraryType}'),
          onPressed: _submit,
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

class _AiDictionaryProgressDialog extends StatelessWidget {
  const _AiDictionaryProgressDialog({
    required this.progress,
    required this.cancellationToken,
    required this.optimize,
  });

  final ValueListenable<(int, int)> progress;
  final AiCancellationToken cancellationToken;
  final bool optimize;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('ai-dictionary-progress'),
      title: Text(optimize
          ? context.l10n.aiDictionaryOptimizing
          : context.l10n.aiDictionaryRecognizing),
      content: ValueListenableBuilder<(int, int)>(
        valueListenable: progress,
        builder: (context, value, _) {
          final (completed, total) = value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: total <= 0 ? null : completed / total,
              ),
              const SizedBox(height: 12),
              Text(
                total <= 0
                    ? context.l10n.aiDictionaryPreparing
                    : context.l10n.aiDictionaryProgress(completed, total),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          key: const Key('cancel-ai-dictionary'),
          onPressed: cancellationToken.cancel,
          child: Text(context.l10n.cancel),
        ),
      ],
    );
  }
}

class _AiDictionaryReviewDialog extends StatefulWidget {
  const _AiDictionaryReviewDialog({
    required this.suggestions,
    required this.recordCount,
  });

  final List<DictionaryAiSuggestion> suggestions;
  final int recordCount;

  @override
  State<_AiDictionaryReviewDialog> createState() =>
      _AiDictionaryReviewDialogState();
}

class _AiDictionaryReviewDialogState extends State<_AiDictionaryReviewDialog> {
  late final Set<String> _selected = <String>{
    for (final suggestion in widget.suggestions)
      if (suggestion.action != DictionaryAiAction.merge) suggestion.id,
  };

  String _categoryLabel(DictionaryAiCategory category) => switch (category) {
        DictionaryAiCategory.device => context.l10n.deviceLibrary,
        DictionaryAiCategory.antenna => context.l10n.antennaLibrary,
        DictionaryAiCategory.callsign => context.l10n.callsignLibrary,
        DictionaryAiCategory.qth => context.l10n.qthLibrary,
      };

  String _actionLabel(DictionaryAiAction action) => switch (action) {
        DictionaryAiAction.add => context.l10n.aiDictionaryActionAdd,
        DictionaryAiAction.rename => context.l10n.aiDictionaryActionRename,
        DictionaryAiAction.merge => context.l10n.aiDictionaryActionMerge,
      };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      key: const Key('ai-dictionary-review'),
      title: Text(context.l10n.aiDictionaryReviewTitle),
      content: SizedBox(
        width: 680,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.aiDictionaryReviewHint(widget.recordCount),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final suggestion = widget.suggestions[index];
                  final selected = _selected.contains(suggestion.id);
                  final source = suggestion.source;
                  return CheckboxListTile(
                    key: Key('ai-dictionary-suggestion-${suggestion.id}'),
                    value: selected,
                    onChanged: (value) => setState(() {
                      value == true
                          ? _selected.add(suggestion.id)
                          : _selected.remove(suggestion.id);
                    }),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      source == null || source == suggestion.target
                          ? suggestion.target
                          : '$source  →  ${suggestion.target}',
                    ),
                    subtitle: Text(
                      <String>[
                        '${_categoryLabel(suggestion.category)} · '
                            '${_actionLabel(suggestion.action)}',
                        if (suggestion.evidenceCount > 0)
                          context.l10n.aiDictionaryUsedCount(
                            suggestion.evidenceCount,
                          ),
                        if (suggestion.reason.isNotEmpty) suggestion.reason,
                        if (suggestion.action == DictionaryAiAction.merge)
                          context.l10n.aiDictionaryMergeWarning,
                      ].join('\n'),
                    ),
                    isThreeLine: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('apply-ai-dictionary-suggestions'),
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(
                    context,
                    <DictionaryAiSuggestion>[
                      for (final suggestion in widget.suggestions)
                        if (_selected.contains(suggestion.id)) suggestion,
                    ],
                  ),
          child: Text(context.l10n.aiDictionaryApplySelected),
        ),
      ],
    );
  }
}
