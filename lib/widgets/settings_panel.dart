import 'package:flutter/material.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/app_info_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/services/url_sync.dart';
import 'package:openlogtool/theme/app_theme.dart';
import 'package:openlogtool/utils/app_snack_bar.dart';
import 'package:openlogtool/widgets/about_app_dialog.dart';
import 'package:openlogtool/widgets/font_picker_dialog.dart';
import 'package:openlogtool/widgets/log_viewer_dialog.dart';
import 'package:openlogtool/widgets/settings/controller_display_settings.dart';
import 'package:openlogtool/widgets/settings/ai_recognition_settings.dart';
import 'package:openlogtool/widgets/settings/layout_settings.dart';
import 'package:openlogtool/widgets/settings/server_account_settings.dart';
import 'package:openlogtool/widgets/settings/settings_ui.dart';
import 'package:openlogtool/widgets/settings/theme_settings.dart';
import 'package:openlogtool/widgets/theme_color_picker_dialog.dart';
import 'package:provider/provider.dart';

enum _SettingsCategory {
  appearance,
  workbench,
  controller,
  ai,
  serverAccount,
  application,
}

extension on _SettingsCategory {
  IconData get icon => switch (this) {
        _SettingsCategory.appearance => Icons.palette_outlined,
        _SettingsCategory.workbench => Icons.dashboard_customize_outlined,
        _SettingsCategory.controller => Icons.cast_outlined,
        _SettingsCategory.ai => Icons.auto_awesome_outlined,
        _SettingsCategory.serverAccount => Icons.cloud_outlined,
        _SettingsCategory.application => Icons.info_outline,
      };

  String label(BuildContext context) => switch (this) {
        _SettingsCategory.appearance => context.l10n.settingsCategoryAppearance,
        _SettingsCategory.workbench => context.l10n.settingsCategoryWorkbench,
        _SettingsCategory.controller => context.l10n.settingsCategoryController,
        _SettingsCategory.ai => context.l10n.settingsCategoryAi,
        _SettingsCategory.serverAccount =>
          context.l10n.settingsCategoryServerAccount,
        _SettingsCategory.application =>
          context.l10n.settingsCategoryApplication,
      };

  String description(BuildContext context) => switch (this) {
        _SettingsCategory.appearance => context.l10n.settingsAppearanceHint,
        _SettingsCategory.workbench => context.l10n.layoutSettingsHint,
        _SettingsCategory.controller =>
          context.l10n.controllerDisplaySettingsHint,
        _SettingsCategory.ai => context.l10n.aiSettingsDescription,
        _SettingsCategory.serverAccount => context.l10n.serverSettingsHint,
        _SettingsCategory.application => context.l10n.settingsSupportHint,
      };
}

/// Categorized application settings.
///
/// The app shell owns the only page-level title. This panel presents section
/// navigation on wide screens and a category index/detail flow on phones.
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, this.handlesSystemBack = true});

  /// The home shell delegates back here instead of letting two PopScopes
  /// handle the same route notification independently.
  final bool handlesSystemBack;

  @override
  State<SettingsPanel> createState() => SettingsPanelState();
}

class SettingsPanelState extends State<SettingsPanel> {
  _SettingsCategory _desktopCategory = _SettingsCategory.appearance;
  _SettingsCategory? _compactCategory;
  bool _wide = false;
  final _navigationScroll = ScrollController();
  final _categoryScroll = {
    for (final category in _SettingsCategory.values)
      category: ScrollController(),
  };
  final _categoryKeys = {
    for (final category in _SettingsCategory.values) category: GlobalKey(),
  };

  bool popCategory() {
    if (_wide || _compactCategory == null) return false;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _compactCategory = null);
    return true;
  }

  @override
  void dispose() {
    _navigationScroll.dispose();
    for (final controller in _categoryScroll.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _scrollPane({
    required String name,
    required ScrollController controller,
    required Widget child,
  }) =>
      Scrollbar(
        controller: controller,
        child: SingleChildScrollView(
          key: Key('settings-$name-scroll'),
          controller: controller,
          primary: false,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          _wide = constraints.maxWidth >= AppBreakpoints.medium;
          if (!_wide) return _buildCompactSettings(context);

          return Row(
            key: const Key('settings-wide-layout'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 248,
                child: _scrollPane(
                  name: 'navigation',
                  controller: _navigationScroll,
                  child: _buildCategoryNavigation(
                    context,
                    selected: _desktopCategory,
                    onSelected: (category) {
                      if (_desktopCategory == category) return;
                      setState(() => _desktopCategory = category);
                    },
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: _buildCategoryStack(
                  context,
                  selected: _desktopCategory,
                  compact: false,
                ),
              ),
            ],
          );
        },
      );

  Widget _buildCompactSettings(BuildContext context) {
    final selected = _compactCategory;
    return PopScope(
      canPop: !widget.handlesSystemBack || selected == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.handlesSystemBack) popCategory();
      },
      child: Stack(
        key: const Key('settings-compact-layout'),
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: selected != null,
            child: TickerMode(
              enabled: selected == null,
              child: _scrollPane(
                name: 'navigation',
                controller: _navigationScroll,
                child: _buildCategoryNavigation(
                  context,
                  selected: null,
                  onSelected: (category) {
                    setState(() => _compactCategory = category);
                    UrlSync.checkpoint();
                  },
                ),
              ),
            ),
          ),
          Offstage(
            offstage: selected == null,
            child: TickerMode(
              enabled: selected != null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      key: const Key('settings-category-back'),
                      onPressed: popCategory,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(
                        MaterialLocalizations.of(context).backButtonTooltip,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Expanded(
                    child: _buildCategoryStack(
                      context,
                      selected: selected ?? _SettingsCategory.appearance,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryNavigation(
    BuildContext context, {
    required _SettingsCategory? selected,
    required ValueChanged<_SettingsCategory> onSelected,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('settings-category-navigation'),
      padding: const EdgeInsets.all(AppSpace.xs),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.surface),
      ),
      child: Column(
        children: [
          for (final category in _SettingsCategory.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.xxs),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.control),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  key: Key('settings-category-${category.name}'),
                  selected: selected == category,
                  selectedTileColor: colors.primaryContainer,
                  selectedColor: colors.onPrimaryContainer,
                  leading: AppIconBadge(
                    icon: category.icon,
                    tone: selected == category
                        ? AppTone.primary
                        : AppTone.neutral,
                    size: AppIconBadgeSize.action,
                  ),
                  title: Text(
                    category.label(context),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    category.description(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: selected == null
                      ? const Icon(Icons.chevron_right, size: 20)
                      : null,
                  onTap: () => onSelected(category),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Retains each category subtree while it is hidden so an in-progress server
  /// URL edit is not discarded when the user briefly opens another category.
  Widget _buildCategoryStack(
    BuildContext context, {
    required _SettingsCategory selected,
    required bool compact,
  }) {
    final padding = compact ? AppSpace.sm : AppSpace.md;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final category in _SettingsCategory.values)
          Offstage(
            offstage: selected != category,
            child: TickerMode(
              enabled: selected == category,
              child: _scrollPane(
                name: category.name,
                controller: _categoryScroll[category]!,
                child: KeyedSubtree(
                  key: _categoryKeys[category],
                  child: _buildCategoryContent(
                    context,
                    category: category,
                    compact: compact,
                    cardPadding: padding,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryContent(
    BuildContext context, {
    required _SettingsCategory category,
    required bool compact,
    required double cardPadding,
  }) =>
      switch (category) {
        _SettingsCategory.appearance => ThemeSettings(
            isNarrow: compact,
            cardPadding: cardPadding,
            onPickColor: () => _showColorPicker(context),
            onPickFont: () => _showFontPicker(context),
          ),
        _SettingsCategory.workbench => LayoutSettings(
            isNarrow: compact,
            cardPadding: cardPadding,
          ),
        _SettingsCategory.controller =>
          ControllerDisplaySettings(cardPadding: cardPadding),
        _SettingsCategory.ai => AiRecognitionSettings(cardPadding: cardPadding),
        _SettingsCategory.serverAccount =>
          ServerAccountSettings(cardPadding: cardPadding),
        _SettingsCategory.application => _buildApplicationSettings(
            context,
            cardPadding: cardPadding,
          ),
      };

  Widget _buildApplicationSettings(
    BuildContext context, {
    required double cardPadding,
  }) {
    final appInfoProvider = context.watch<AppInfoProvider>();
    return SettingsSectionCard(
      icon: Icons.info_outline,
      title: context.l10n.settingsSupportTitle,
      description: context.l10n.settingsSupportHint,
      padding: cardPadding,
      tone: SettingsTone.tertiary,
      child: SettingsTileGroup(
        children: [
          SettingsActionTile(
            key: const Key('about-app-entry'),
            icon: Icons.radio_outlined,
            title: context.l10n.aboutAppTitle,
            subtitle: '${context.l10n.aboutAppTagline}\n'
                '${appInfoProvider.fullVersion} · '
                '${context.l10n.aboutLicenseName}',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAboutDialog(context),
            tone: SettingsTone.tertiary,
          ),
          SettingsActionTile(
            key: const Key('restore-default-settings-entry'),
            icon: Icons.restore_outlined,
            title: context.l10n.restoreDefaultSettings,
            subtitle: context.l10n.restoreDefaultSettingsHint,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showResetConfirmation(context),
          ),
          SettingsActionTile(
            key: const Key('view-logs-entry'),
            icon: Icons.article_outlined,
            title: context.l10n.logsTitle,
            subtitle: context.l10n.logsView,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLogViewer(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showColorPicker(BuildContext context) async {
    final settingsProvider = context.read<SettingsProvider>();
    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (_) => ThemeColorPickerDialog(
        initialColor: settingsProvider.themeColor,
      ),
    );
    if (selectedColor != null) {
      await settingsProvider.setThemeColor(selectedColor);
    }
  }

  Future<void> _showResetConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: _dialogInsetPadding(dialogContext),
        scrollable: true,
        title: Text(dialogContext.l10n.resetSettingsTitle),
        content: Text(dialogContext.l10n.resetSettingsConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.resetSettingsConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await context.read<SettingsProvider>().resetToDefaults();
      if (!context.mounted) return;
      context.showLoggedSnackBar(
        SnackBar(
          content: Text(context.l10n.resetSettingsSucceeded),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      context.showLoggedSnackBar(
        SnackBar(
          content: Text(context.l10n.resetSettingsFailed(error.toString())),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showAboutDialog(BuildContext context) {
    final appInfoProvider = context.read<AppInfoProvider>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AboutAppDialog(
        appName: appInfoProvider.appName,
        fullVersion: appInfoProvider.fullVersion,
        buildNumber: appInfoProvider.buildNumber,
        commitHash: appInfoProvider.commitHash,
      ),
    );
  }

  void _showLogViewer(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const LogViewerDialog(),
    );
  }

  Future<void> _showFontPicker(BuildContext context) async {
    final settingsProvider = context.read<SettingsProvider>();
    final result = await showDialog<FontPickerResult>(
      context: context,
      // Applying a global font rebuilds the app. Remove the picker before that
      // rebuild starts instead of competing with an exit transition.
      animationStyle: AnimationStyle.noAnimation,
      builder: (_) => FontPickerDialog(
        availableFonts: settingsProvider.availableFonts,
        currentFont: settingsProvider.fontFamily,
      ),
    );
    if (result == null || !context.mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    await settingsProvider.setFontFamily(result.fontFamily);
  }

  static EdgeInsets _dialogInsetPadding(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppBreakpoints.compact
          ? const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.lg,
            )
          : const EdgeInsets.symmetric(
              horizontal: 40,
              vertical: AppSpace.lg,
            );
}
