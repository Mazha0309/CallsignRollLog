import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/ai_recognition_settings_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/models/export_settings.dart';
import 'package:openlogtool/models/log_entry.dart';
import 'package:openlogtool/services/excel_import_service.dart';
import 'package:openlogtool/services/export_service.dart';
import 'package:openlogtool/utils/app_snack_bar.dart';
import 'package:openlogtool/config/app_config.dart';
import 'package:openlogtool/theme/app_theme.dart';
import 'package:openlogtool/widgets/settings/settings_ui.dart';
import 'package:openlogtool/widgets/theme_color_picker_dialog.dart';

class ExportPanel extends StatefulWidget {
  const ExportPanel({super.key, this.embedded = false});

  /// Omits the page-level title when hosted by the tabbed data workspace.
  final bool embedded;

  @override
  State<ExportPanel> createState() => _ExportPanelState();
}

class _ExportPanelState extends State<ExportPanel> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > 700;
        final isNarrow = constraints.maxWidth < 400;
        final cardPadding = isNarrow ? 16.0 : 20.0;
        final sectionSpacing = isNarrow ? 16.0 : 20.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 12 : 16,
            vertical: isNarrow ? 8 : 12,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimensions.standardContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.embedded) ...[
                    SettingsPageHeader(
                      key: const Key('data-transfer-page-header'),
                      icon: Icons.import_export_outlined,
                      title: context.l10n.dataTransferTitle,
                      description: context.l10n.dataTransferSubtitle,
                    ),
                    SizedBox(height: sectionSpacing),
                  ],
                  if (isWideScreen)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildQuickActionsCard(context, cardPadding),
                        ),
                        SizedBox(width: sectionSpacing),
                        Expanded(
                          child: _buildExcelSettingsCard(context, cardPadding),
                        ),
                      ],
                    )
                  else ...[
                    _buildQuickActionsCard(context, cardPadding),
                    SizedBox(height: sectionSpacing),
                    _buildExcelSettingsCard(context, cardPadding),
                  ],
                  SizedBox(height: sectionSpacing),
                  _buildFormatInfoCard(context, cardPadding),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsCard(BuildContext context, double cardPadding) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return SettingsSectionCard(
      icon: Icons.swap_horiz,
      title: l10n.dataTransferActionsTitle,
      description: l10n.dataTransferActionsHint,
      padding: cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Export section
          _buildActionGroup(
            context,
            title: l10n.exportDataTitle,
            icon: Icons.file_download,
            description: l10n.exportDataHint,
            children: [
              _buildActionButton(
                context,
                label: l10n.exportJson,
                icon: Icons.code,
                color: theme.colorScheme.primary,
                onPressed: () => _exportJSON(context),
              ),
              _buildActionButton(
                context,
                label: l10n.exportExcel,
                icon: Icons.table_chart,
                color: theme.colorScheme.secondary,
                onPressed: () => _exportExcel(context),
              ),
              _buildActionButton(
                context,
                label: l10n.exportAdif,
                icon: Icons.radio,
                color: theme.colorScheme.tertiary,
                onPressed: () => _exportAdif(context),
              ),
            ],
          ),
          SizedBox(height: cardPadding),

          // Import section
          _buildActionGroup(
            context,
            title: l10n.importDataTitle,
            icon: Icons.file_upload,
            description: l10n.importDataHint,
            children: [
              _buildActionButton(
                context,
                label: l10n.importJson,
                icon: Icons.code,
                color: theme.colorScheme.tertiary,
                onPressed: () => _importJSON(context),
              ),
              if (context
                  .watch<AiRecognitionSettingsProvider>()
                  .textAssistantEnabled) ...[
                _buildActionButton(
                  context,
                  label: l10n.importExcel,
                  icon: Icons.table_chart,
                  color: theme.colorScheme.outline,
                  onPressed: () => _importExcel(context),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionGroup(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String description,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(title,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.only(left: 22),
          child: Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children,
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _buildExcelSettingsCard(BuildContext context, double cardPadding) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final settings = settingsProvider.exportSettings;
    final l10n = context.l10n;
    final currentSessionTitle =
        Provider.of<SessionProvider>(context).currentSession?.title.trim();

    return SettingsSectionCard(
      icon: Icons.preview_outlined,
      title: l10n.excelConfigurationOverview,
      description: l10n.excelConfigurationOverviewHint,
      padding: cardPadding,
      headerTrailing: OutlinedButton.icon(
        onPressed: () => _showExportSettingsDialog(context),
        icon: const Icon(Icons.edit_outlined, size: 16),
        label: Text(l10n.editSettings),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingRow(
            context,
            label: l10n.fileNameTemplate,
            value: settings.fileNameTemplate,
            icon: Icons.insert_drive_file,
          ),
          const Divider(height: 24),
          _buildSettingRow(
            context,
            label: l10n.excelHeader,
            value: settings.useSessionTitleAsHeader
                ? (currentSessionTitle?.isNotEmpty == true
                    ? currentSessionTitle!
                    : settings.headerText)
                : settings.headerText,
            icon: Icons.title,
          ),
          const Divider(height: 24),
          _buildSettingRow(
            context,
            label: l10n.exportPath,
            value: settings.exportPath.isEmpty
                ? l10n.systemDownloadsDirectory
                : settings.exportPath,
            icon: Icons.folder,
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildColorChip(
                context,
                l10n.headerBackground,
                settings.headerBackgroundColor,
              ),
              _buildColorChip(
                context,
                l10n.tableHeaderBackground,
                settings.headerRowBackgroundColor,
              ),
              _buildColorChip(
                context,
                l10n.controllerRow,
                settings.controllerBackgroundColor,
              ),
              _buildToggleChip(
                context,
                label: l10n.alternatingRows,
                value: settings.useAlternateColors,
                onChanged: (v) {
                  final updated = settings.copyWith(useAlternateColors: v);
                  settingsProvider.updateExportSettings(updated);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorChip(BuildContext context, String label, Color color) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleChip(
    BuildContext context, {
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
                value: value,
                onChanged: onChanged,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatInfoCard(BuildContext context, double cardPadding) {
    final theme = Theme.of(context);

    return SettingsSectionCard(
      icon: Icons.info_outline,
      title: context.l10n.fileFormatInformation,
      padding: cardPadding,
      tone: SettingsTone.tertiary,
      child: Text(
        '• ${context.l10n.jsonFormatDescription}\n'
        '• ${context.l10n.excelFormatDescription}\n'
        '• ${context.l10n.adifFormatDescription}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
    );
  }

  void _showExportSettingsDialog(BuildContext context) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    ExportSettings settings =
        ExportSettings.fromJson(settingsProvider.exportSettings.toJson());

    final exportPathController =
        TextEditingController(text: settings.exportPath);
    final fileNameController =
        TextEditingController(text: settings.fileNameTemplate);
    final headerTextController =
        TextEditingController(text: settings.headerText);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final mediaSize = MediaQuery.sizeOf(context);
          final compact = mediaSize.width < 600;
          final horizontalInset = compact ? 16.0 : 40.0;
          final dialogWidth = math.min(
            520.0,
            math.max(240.0, mediaSize.width - horizontalInset * 2),
          );
          final dialogHeight = math.min(
            620.0,
            math.max(260.0, mediaSize.height - 200.0),
          );

          return AlertDialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: horizontalInset,
              vertical: 24,
            ),
            title: Text(context.l10n.excelExportSettingsTitle),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.folder_outlined),
                          text: context.l10n.fileTab,
                        ),
                        Tab(
                          icon: const Icon(Icons.palette_outlined),
                          text: context.l10n.tableStyleTab,
                        ),
                        Tab(
                          icon: const Icon(Icons.help_outline),
                          text: context.l10n.templateVariablesTab,
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildFileSettingsTab(
                            context,
                            settings,
                            exportPathController,
                            fileNameController,
                            headerTextController,
                            setState,
                          ),
                          _buildStyleSettingsTab(context, settings, setState),
                          _buildTemplateHelpTab(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  exportPathController.dispose();
                  fileNameController.dispose();
                  headerTextController.dispose();
                  Navigator.pop(context);
                },
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  settings.exportPath = exportPathController.text;
                  settings.fileNameTemplate = fileNameController.text;
                  settings.headerText = headerTextController.text;
                  settingsProvider.updateExportSettings(settings);
                  exportPathController.dispose();
                  fileNameController.dispose();
                  headerTextController.dispose();
                  Navigator.pop(context);
                  context.showLoggedSnackBar(
                    SnackBar(content: Text(context.l10n.exportSettingsSaved)),
                  );
                },
                child: Text(context.l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFileSettingsTab(
    BuildContext context,
    ExportSettings settings,
    TextEditingController exportPathController,
    TextEditingController fileNameController,
    TextEditingController headerTextController,
    StateSetter setState,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextFieldGroup(
            context,
            label: context.l10n.exportPath,
            controller: exportPathController,
            hintText: context.l10n.systemDownloadsDirectory,
            readOnly: true,
            helperText: context.l10n.exportPathDefaultHint,
            trailing: FilledButton(
              onPressed: () async {
                final result = await FilePicker.platform.getDirectoryPath();
                if (result != null) {
                  exportPathController.text = result;
                  settings.exportPath = result;
                  setState(() {});
                }
              },
              child: Text(context.l10n.select),
            ),
          ),
          const SizedBox(height: 20),
          _buildTextFieldGroup(
            context,
            label: context.l10n.fileNameTemplate,
            controller: fileNameController,
            hintText: context.l10n.fileNameTemplateExample(
              '{MM}',
              '{dd}',
              '{yyyy}',
            ),
            helperText: context.l10n.fileNameTemplateHint,
          ),
          const SizedBox(height: 20),
          _buildSwitchTile(
            context,
            title: context.l10n.fileNameUseSessionTitle,
            subtitle: context.l10n.fileNameUseSessionTitleHint,
            value: settings.useSessionTitleAsFileName,
            onChanged: (value) {
              setState(() => settings.useSessionTitleAsFileName = value);
            },
          ),
          const SizedBox(height: 20),
          _buildSwitchTile(
            context,
            title: context.l10n.excelUseSessionTitleAsHeader,
            subtitle: context.l10n.excelUseSessionTitleAsHeaderHint,
            value: settings.useSessionTitleAsHeader,
            onChanged: (value) {
              setState(() => settings.useSessionTitleAsHeader = value);
            },
          ),
          const SizedBox(height: 20),
          _buildTextFieldGroup(
            context,
            label: context.l10n.headerTemplate,
            controller: headerTextController,
            hintText: context.l10n.headerTemplateExample(
              '{MM}',
              '{dd}',
              '{yyyy}',
            ),
            helperText: context.l10n.headerTemplateHint,
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldGroup(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    String? hintText,
    String? helperText,
    bool readOnly = false,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                readOnly: readOnly,
                decoration: InputDecoration(
                  hintText: hintText,
                  helperText: helperText,
                  border: const OutlineInputBorder(),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            controller.text = '';
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildStyleSettingsTab(
      BuildContext context, ExportSettings settings, StateSetter setState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildColorSetting(
            context,
            context.l10n.headerBackgroundColor,
            settings.headerBackgroundColor,
            (color) => setState(() => settings.headerBackgroundColor = color),
            settings.fontFamily,
          ),
          const SizedBox(height: 16),
          _buildColorSetting(
            context,
            context.l10n.tableHeaderBackgroundColor,
            settings.headerRowBackgroundColor,
            (color) =>
                setState(() => settings.headerRowBackgroundColor = color),
            settings.fontFamily,
          ),
          const SizedBox(height: 16),
          _buildColorSetting(
            context,
            context.l10n.controllerRowBackgroundColor,
            settings.controllerBackgroundColor,
            (color) =>
                setState(() => settings.controllerBackgroundColor = color),
            settings.fontFamily,
          ),
          const SizedBox(height: 16),
          _buildColorSetting(
            context,
            context.l10n.tableBackgroundColor,
            settings.tableBackgroundColor,
            (color) => setState(() => settings.tableBackgroundColor = color),
            settings.fontFamily,
          ),
          if (settings.useAlternateColors) ...[
            const SizedBox(height: 16),
            _buildColorSetting(
              context,
              context.l10n.alternatingRowColor,
              settings.alternateRowColor,
              (color) => setState(() => settings.alternateRowColor = color),
              settings.fontFamily,
            ),
          ],
          const SizedBox(height: 20),
          _buildSwitchTile(
            context,
            title: context.l10n.alternatingRowColor,
            subtitle: context.l10n.alternatingRowColorHint,
            value: settings.useAlternateColors,
            onChanged: (value) =>
                setState(() => settings.useAlternateColors = value),
          ),
          _buildSwitchTile(
            context,
            title: context.l10n.footerInformation,
            subtitle: context.l10n.footerInformationHint,
            value: settings.showFooter,
            onChanged: (value) => setState(() => settings.showFooter = value),
          ),
          const SizedBox(height: 16),
          _buildFontDropdown(context, settings, setState),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.restore, size: 18),
            label: Text(context.l10n.restoreDefaultColors),
            onPressed: () {
              setState(() {
                settings.headerBackgroundColor = const Color(0xFF1E84D2);
                settings.headerRowBackgroundColor = const Color(0xFFCFE7FF);
                settings.controllerBackgroundColor = const Color(0xFFFFFFC3);
                settings.tableBackgroundColor = Colors.white;
                settings.alternateRowColor = const Color(0xFFC0E5F2);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14)),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildFontDropdown(
      BuildContext context, ExportSettings settings, StateSetter setState) {
    final availableFonts =
        Provider.of<SettingsProvider>(context, listen: false).availableFonts;
    final normalizedFamily = AppConfig.normalizeFontFamily(settings.fontFamily);
    final initialValue =
        normalizedFamily.isEmpty ? 'SarasaGothicSC' : normalizedFamily;
    final fontOptions = <String>{
      'SarasaGothicSC',
      ...availableFonts,
      initialValue,
    }.toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.tableFont, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: initialValue,
          isExpanded: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: [
            DropdownMenuItem(
                value: '',
                child: Text(context.l10n.fontSystemDefault,
                    overflow: TextOverflow.ellipsis)),
            ...fontOptions.map((font) => DropdownMenuItem(
                  value: font,
                  child: Text(
                    font == 'SarasaGothicSC'
                        ? '$font (${context.l10n.fontBuiltIn})'
                        : font,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => settings.fontFamily = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildTemplateHelpTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.templateVariablesTitle,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTemplateHelpItem(
              context, '{yyyy}', context.l10n.templateYearDescription),
          _buildTemplateHelpItem(
              context, '{MM}', context.l10n.templateMonthDescription),
          _buildTemplateHelpItem(
              context, '{dd}', context.l10n.templateDayDescription),
          _buildTemplateHelpItem(
              context, '{HH}', context.l10n.templateHourDescription),
          _buildTemplateHelpItem(
              context, '{mm}', context.l10n.templateMinuteDescription),
          _buildTemplateHelpItem(
              context, '{ss}', context.l10n.templateSecondDescription),
          _buildTemplateHelpItem(
              context, '{session}', context.l10n.templateSessionDescription),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            context.l10n.templateExamplesTitle,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildExampleItem(
            context,
            context.l10n.templateFileNameExampleOne(
              '{MM}',
              '{dd}',
              '{yyyy}',
            ),
            context.l10n.templateFileNameExampleOneResult,
          ),
          _buildExampleItem(
            context,
            context.l10n.templateFileNameExampleTwo(
              '{HH}',
              '{MM}',
              '{dd}',
              '{mm}',
              '{ss}',
              '{yyyy}',
            ),
            context.l10n.templateFileNameExampleTwoResult,
          ),
          _buildExampleItem(
            context,
            context.l10n.templateHeaderExample(
              '{MM}',
              '{dd}',
              '{yyyy}',
            ),
            context.l10n.templateHeaderExampleResult,
          ),
          const SizedBox(height: 16),
          _buildInfoBox(
            context,
            context.l10n.templateVariablesTip,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(128),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSetting(
    BuildContext context,
    String label,
    Color color,
    Function(Color) onColorChanged,
    String fontFamily,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(fontSize: 14)),
        ),
        _buildColorButton(color, () async {
          final newColor = await _showColorPickerDialog(
            context,
            context.l10n.chooseColor(label),
            color,
          );
          if (newColor != null) {
            onColorChanged(newColor);
          }
        }),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
            style: TextStyle(
              fontSize: 12,
              fontFamily: fontFamily.isEmpty ? 'monospace' : fontFamily,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateHelpItem(
      BuildContext context, String variable, String description) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.colorScheme.outline.withAlpha(128),
                width: 1,
              ),
            ),
            child: Text(
              variable,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleItem(
      BuildContext context, String template, String result) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(180),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(100),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            template,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.arrow_forward,
                  size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.colorize, size: 20, color: Colors.white),
        ),
      ),
    );
  }

  Future<Color?> _showColorPickerDialog(
    BuildContext context,
    String title,
    Color initialColor,
  ) {
    return showDialog<Color>(
      context: context,
      builder: (_) => ThemeColorPickerDialog(
        initialColor: initialColor,
        title: title,
        allowOpacity: true,
      ),
    );
  }

  Future<void> _exportJSON(BuildContext context) async {
    final l10n = context.l10n;
    final logProvider = Provider.of<LogProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final settings = settingsProvider.exportSettings;
    final logs = logProvider.logs;

    if (logs.isEmpty) {
      _showSnackBar(l10n.noDataToExport);
      return;
    }

    try {
      final jsonBytes = ExportService.generateJsonBytes(logs);
      final now = DateTime.now();
      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);
      String filename = ExportService.generateFileName(
        settings.fileNameTemplate,
        now,
        sessionTitle: sessionProvider.currentSession?.title,
        useSessionTitle: settings.useSessionTitleAsFileName,
      );
      if (!filename.endsWith('.json')) {
        filename += '.json';
      }

      final saveResult = await ExportService.saveFile(
        configuredPath: settings.exportPath,
        filename: filename,
        bytes: jsonBytes,
        dialogTitle: l10n.saveExportFileDialog('JSON'),
        allowedExtensions: const ['json'],
      );

      if (saveResult.cancelled) return;
      if (saveResult.path == null) {
        _showSnackBar(l10n.downloadsDirectoryUnavailable);
        return;
      }

      if (saveResult.usedSaf) {
        _showSnackBar(l10n.exportSavedViaSystemPicker('JSON'));
      } else {
        _showSuccessDialog(
          l10n.exportSucceeded('JSON'),
          l10n.fileSavedTo(saveResult.path!),
          saveResult.path!,
        );
      }
    } catch (e) {
      _showSnackBar(l10n.exportFailed('$e'));
    }
  }

  Future<void> _exportAdif(BuildContext context) async {
    final l10n = context.l10n;
    final logProvider = Provider.of<LogProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final settings = settingsProvider.exportSettings;
    final logs = logProvider.logs;

    if (logs.isEmpty) {
      _showSnackBar(l10n.noDataToExport);
      return;
    }

    try {
      final now = DateTime.now();
      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);
      final files =
          ExportService.generateAdifByController(logs, createdAt: now);
      if (files.isEmpty) {
        _showSnackBar(l10n.noDataToExport);
        return;
      }

      String baseName = ExportService.generateFileName(
        settings.fileNameTemplate,
        now,
        sessionTitle: sessionProvider.currentSession?.title,
        useSessionTitle: settings.useSessionTitleAsFileName,
      );
      final singleStation = files.length == 1 ? files.keys.single : null;
      final filename = files.length == 1
          ? (baseName.toLowerCase().endsWith('.adi')
              ? baseName.replaceAll(RegExp(r'\.adi$', caseSensitive: false),
                  '_${singleStation!}.adi')
              : '${baseName}_$singleStation.adi')
          : (baseName.toLowerCase().endsWith('.zip')
              ? baseName
              : '$baseName.zip');
      final bytes = files.length == 1
          ? Uint8List.fromList(utf8.encode(files.values.single))
          : ExportService.generateAdifArchiveBytes(
              files,
              fileNameForStation: (station) => '${baseName}_$station.adi',
            );

      final saveResult = await ExportService.saveFile(
        configuredPath: settings.exportPath,
        filename: filename,
        bytes: bytes,
        dialogTitle: l10n.saveExportFileDialog('ADIF'),
        allowedExtensions: files.length == 1 ? const ['adi'] : const ['zip'],
      );

      if (saveResult.cancelled) return;
      if (saveResult.path == null) {
        _showSnackBar(l10n.downloadsDirectoryUnavailable);
        return;
      }

      if (saveResult.usedSaf) {
        _showSnackBar(l10n.exportSavedViaSystemPicker('ADIF'));
      } else {
        _showSuccessDialog(
          l10n.exportSucceeded('ADIF'),
          l10n.fileSavedTo(saveResult.path!),
          saveResult.path!,
        );
      }
    } catch (e) {
      _showSnackBar(l10n.exportFailed('$e'));
    }
  }

  Future<void> _exportExcel(BuildContext context) async {
    final l10n = context.l10n;
    final logProvider = Provider.of<LogProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    final settings = settingsProvider.exportSettings;
    final logs = logProvider.logs;

    if (logs.isEmpty) {
      _showSnackBar(l10n.noDataToExport);
      return;
    }

    try {
      final now = DateTime.now();
      final bytes = ExportService.generateExcelBytes(
        logs,
        settings,
        now,
        sessionTitle: sessionProvider.currentSession?.title,
      );
      if (bytes == null) {
        _showSnackBar(l10n.excelGenerationFailed);
        return;
      }

      String filename = ExportService.generateFileName(
        settings.fileNameTemplate,
        now,
        sessionTitle: sessionProvider.currentSession?.title,
        useSessionTitle: settings.useSessionTitleAsFileName,
      );
      if (!filename.endsWith('.xlsx')) {
        filename += '.xlsx';
      }

      final saveResult = await ExportService.saveFile(
        configuredPath: settings.exportPath,
        filename: filename,
        bytes: Uint8List.fromList(bytes),
        dialogTitle: l10n.saveExportFileDialog('Excel'),
        allowedExtensions: const ['xlsx'],
      );

      if (saveResult.cancelled) return;
      if (saveResult.path == null) {
        _showSnackBar(l10n.downloadsDirectoryUnavailable);
        return;
      }

      if (saveResult.usedSaf) {
        _showSnackBar(l10n.exportSavedViaSystemPicker('Excel'));
      } else {
        _showSuccessDialog(
          l10n.exportSucceeded('Excel'),
          l10n.fileSavedTo(saveResult.path!),
          saveResult.path!,
        );
      }
    } catch (e) {
      _showSnackBar(l10n.exportFailed('$e'));
    }
  }

  Future<void> _importJSON(BuildContext context) async {
    final l10n = context.l10n;
    final logProvider = Provider.of<LogProvider>(context, listen: false);
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) return;

      final selected = result.files.single;
      final content = selected.bytes != null
          ? utf8.decode(selected.bytes!)
          : await File(selected.path!).readAsString();

      final importResult = parseJsonImport(content);

      await logProvider.importLogs(importResult.logs,
          sessionId: sessionProvider.currentSessionId);
      scaffoldMessenger.showLoggedSnackBar(
        SnackBar(
          content: Text(l10n.importSucceeded(importResult.logs.length)),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showLoggedSnackBar(
        SnackBar(
          content: Text(l10n.importFailed('$e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importExcel(BuildContext context) async {
    final l10n = context.l10n;
    final logProvider = Provider.of<LogProvider>(context, listen: false);
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);
    final aiSettings =
        Provider.of<AiRecognitionSettingsProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (!mounted) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;
      final selected = result.files.single;
      final bytes =
          selected.bytes ?? (await File(selected.path!).readAsBytes());
      if (bytes.isEmpty) {
        throw const FormatException('EXCEL_IMPORT_EMPTY_FILE');
      }

      final rows = parseExcelRows(bytes);
      if (rows.isEmpty) {
        throw const FormatException('EXCEL_IMPORT_NO_ROWS');
      }

      final client = aiSettings.createTextAssistantClient(
        timeout: const Duration(seconds: 60),
      );
      scaffoldMessenger.showLoggedSnackBar(
        SnackBar(
          content: Text(l10n.excelImportLlmProcessing),
          duration: const Duration(seconds: 5),
        ),
      );
      final records = await structureWithLlm(client, buildSheetText(rows));
      if (records.isEmpty) {
        throw const FormatException('EXCEL_IMPORT_NO_RECORDS');
      }

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(l10n.excelImportPreviewTitle),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.excelImportPreviewCount(records.length)),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final record in records)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '${record['callsign']}'
                                '${record['qth'] != null && (record['qth'] as String).isNotEmpty ? ' · ${record['qth']}' : ''}'
                                '${record['time'] != null && (record['time'] as String).isNotEmpty ? ' · ${record['time']}' : ''}',
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .bodyMedium,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                key: const Key('excel-import-confirm'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.excelImportConfirm),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;

      final logs = records
          .map(
            (record) => LogEntry(
              time: record['time']?.toString() ?? '',
              controller: '',
              callsign: record['callsign'].toString(),
              report: record['rstSent']?.toString() ?? '',
              rstRcvd: record['rstRcvd']?.toString() ?? '',
              qth: record['qth']?.toString() ?? '',
              device: record['device']?.toString() ?? '',
              power: record['power']?.toString() ?? '',
              antenna: '',
              height: '',
              remarks: record['remarks']?.toString() ?? '',
            ),
          )
          .toList(growable: false);
      await logProvider.importLogs(
        logs,
        sessionId: sessionProvider.currentSessionId,
      );
      scaffoldMessenger.showLoggedSnackBar(
        SnackBar(
          content: Text(l10n.excelImportSuccess(logs.length)),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showLoggedSnackBar(
        SnackBar(
          content: Text(l10n.excelImportFailed('$e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    context.showLoggedSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessDialog(String title, String content, String path) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    path,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: path));
                    messenger.showLoggedSnackBar(
                      SnackBar(content: Text(context.l10n.pathCopied)),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
  }
}
