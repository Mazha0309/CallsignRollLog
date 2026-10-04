import 'package:flutter/material.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/widgets/settings/settings_ui.dart';
import 'package:provider/provider.dart';

class ThemeSettings extends StatelessWidget {
  final bool isNarrow;
  final double cardPadding;
  final VoidCallback onPickColor;
  final VoidCallback onPickFont;

  const ThemeSettings({
    super.key,
    required this.isNarrow,
    required this.cardPadding,
    required this.onPickColor,
    required this.onPickFont,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return SettingsSectionCard(
      icon: Icons.palette_outlined,
      title: l10n.settingsAppearanceTitle,
      description: l10n.settingsAppearanceHint,
      padding: cardPadding,
      contentSpacing: isNarrow ? 10 : 14,
      child: SettingsTileGroup(
        children: [
          SettingsActionTile(
            icon: Icons.color_lens_outlined,
            title: l10n.themeColorSetting,
            subtitle: l10n.themeColorSettingHint,
            trailing: SizedBox(
              width: isNarrow ? 200 : 220,
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: settingsProvider.themeColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onPickColor,
                      child: Text(
                        l10n.chooseThemeColor,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SettingsActionTile(
            icon: Icons.dark_mode_outlined,
            title: l10n.darkModeSetting,
            subtitle: l10n.darkModeSettingHint,
            trailing: Switch(
              value: settingsProvider.isDarkMode,
              onChanged: settingsProvider.setDarkMode,
            ),
          ),
          SettingsActionTile(
            icon: Icons.font_download_outlined,
            title: l10n.appFontSetting,
            subtitle: l10n.appFontSettingHint,
            trailing: SizedBox(
              width: isNarrow ? 200 : 220,
              child: OutlinedButton(
                onPressed: onPickFont,
                child: Text(
                  settingsProvider.fontFamily ?? l10n.fontSystemDefault,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          SettingsActionTile(
            icon: Icons.translate_outlined,
            title: l10n.appLanguageSetting,
            subtitle: l10n.appLanguageSettingHint,
            trailing: SizedBox(
              width: isNarrow ? 200 : 220,
              child: DropdownButton<AppLocalePreference>(
                key: const Key('app-language-picker'),
                value: settingsProvider.appLocalePreference,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(12),
                items: [
                  DropdownMenuItem(
                    value: AppLocalePreference.system,
                    child: Text(
                      l10n.languageFollowSystem,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: AppLocalePreference.simplifiedChinese,
                    child: Text(
                      l10n.languageSimplifiedChinese,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: AppLocalePreference.english,
                    child: Text(
                      l10n.languageEnglish,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (preference) {
                  if (preference != null) {
                    settingsProvider.setAppLocalePreference(preference);
                  }
                },
              ),
            ),
          ),
          SettingsActionTile(
            icon: Icons.zoom_in_outlined,
            title: l10n.interfaceScaleTitle,
            subtitle: l10n.interfaceScaleHint,
            trailing: Wrap(
              key: const Key('interface-scale-control'),
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                    key: const Key('interface-scale-down'),
                    tooltip: l10n.interfaceScaleDown,
                    onPressed: settingsProvider.interfaceScalePercent <=
                            SettingsProvider.minInterfaceScale
                        ? null
                        : () => settingsProvider.setInterfaceScalePercent(
                            settingsProvider.interfaceScalePercent - 5),
                    icon: const Icon(Icons.remove)),
                Text('${settingsProvider.interfaceScalePercent}%',
                    key: const Key('interface-scale-value')),
                IconButton(
                    key: const Key('interface-scale-up'),
                    tooltip: l10n.interfaceScaleUp,
                    onPressed: settingsProvider.interfaceScalePercent >=
                            SettingsProvider.maxInterfaceScale
                        ? null
                        : () => settingsProvider.setInterfaceScalePercent(
                            settingsProvider.interfaceScalePercent + 5),
                    icon: const Icon(Icons.add)),
                TextButton(
                    key: const Key('interface-scale-reset'),
                    onPressed: settingsProvider.interfaceScalePercent == 100
                        ? null
                        : () => settingsProvider.setInterfaceScalePercent(100),
                    child: Text(l10n.interfaceScaleReset)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
