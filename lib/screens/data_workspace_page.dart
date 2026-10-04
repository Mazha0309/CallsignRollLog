import 'package:flutter/material.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/personal_cloud_provider.dart';
import 'package:openlogtool/theme/app_theme.dart';
import 'package:openlogtool/widgets/dictionary_manager.dart';
import 'package:openlogtool/widgets/export_panel.dart';
import 'package:openlogtool/widgets/local_database_panel.dart';
import 'package:openlogtool/widgets/personal_cloud_conflict_page.dart';
import 'package:openlogtool/widgets/settings/settings_ui.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/widgets/app_section_tabs.dart';

enum _DataWorkspaceView { records, libraries, database, syncConflicts }

/// The single home for record transfer, lookup libraries, and device data.
class DataWorkspacePage extends StatefulWidget {
  const DataWorkspacePage({super.key});

  @override
  State<DataWorkspacePage> createState() => _DataWorkspacePageState();
}

class _DataWorkspacePageState extends State<DataWorkspacePage> {
  _DataWorkspaceView _selected = _DataWorkspaceView.records;

  @override
  Widget build(BuildContext context) {
    final conflictCount = context.select<PersonalCloudProvider, int>(
      (cloud) => cloud.conflicts.length,
    );
    return Column(
      key: const PageStorageKey('data-workspace-page'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildNavigation(context, conflictCount),
        Expanded(
          child: IndexedStack(
            index: _selected.index,
            children: [
              const ExportPanel(embedded: true),
              const AppPageFrame(
                scrollKey: PageStorageKey('lookup-libraries-page'),
                child: DictionaryManager(embedded: true),
              ),
              AppPageFrame(
                scrollKey: const PageStorageKey('local-database-page'),
                child: LayoutBuilder(
                  builder: (context, constraints) => LocalDatabasePanel(
                    isNarrow: constraints.maxWidth < AppBreakpoints.compact,
                    onOpenPersonalCloudConflicts: () => setState(
                      () => _selected = _DataWorkspaceView.syncConflicts,
                    ),
                  ),
                ),
              ),
              PersonalCloudConflictPage(
                onOpenDatabase: () => setState(
                  () => _selected = _DataWorkspaceView.database,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigation(BuildContext context, int conflictCount) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xs,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.standardContentWidth,
            ),
            child: AppSectionTabs<_DataWorkspaceView>(
              key: const Key('data-workspace-selector'),
              segments: [
                ButtonSegment(
                  value: _DataWorkspaceView.records,
                  icon: const Icon(Icons.swap_vert_outlined),
                  label: Text(context.l10n.dataRecordsExportTab),
                ),
                ButtonSegment(
                  value: _DataWorkspaceView.libraries,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(context.l10n.dataLookupLibrariesTab),
                ),
                ButtonSegment(
                  value: _DataWorkspaceView.database,
                  icon: const Icon(Icons.storage_outlined),
                  label: Text(context.l10n.dataLocalDatabaseTab),
                ),
                ButtonSegment(
                  value: _DataWorkspaceView.syncConflicts,
                  icon: const Icon(Icons.rule_folder_outlined),
                  label: Text(
                    conflictCount == 0
                        ? context.l10n.dataSyncConflictsTab
                        : '${context.l10n.dataSyncConflictsTab} '
                            '($conflictCount)',
                  ),
                ),
              ],
              selected: {_selected},
              onSelectionChanged: (selection) {
                if (selection.isEmpty || selection.first == _selected) {
                  return;
                }
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() => _selected = selection.first);
              },
            ),
          ),
        ),
      ),
    );
  }
}
