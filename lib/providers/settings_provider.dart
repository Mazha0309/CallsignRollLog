import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:openlogtool/config/app_config.dart';
import 'package:openlogtool/models/controller_display.dart';
import 'package:openlogtool/models/export_settings.dart';
import 'package:openlogtool/services/key_value_store.dart';

enum AppLocalePreference { system, simplifiedChinese, english }

class SettingsProvider with ChangeNotifier {
  static const String _themeColorKey = 'themeColor';
  static const String _isDarkModeKey = 'isDarkMode';
  static const String _fontFamilyKey = 'fontFamily';
  static const String _exportSettingsKey = 'exportSettings';
  static const String _sessionTitleExportDefaultsV1Key =
      'sessionTitleExportDefaultsV1';
  static const String _callSignQthLinkKey = 'callSignQthLinkEnabled';
  static const String _paginationEnabledKey = 'paginationEnabled';
  static const String _duplicateCallsignWarningKey =
      'duplicateCallsignWarningEnabled';
  static const String _controllerDeviceModeEnabledKey =
      'controllerDeviceModeEnabled';
  static const String _autoAppendPowerWKey = 'autoAppendPowerW';
  static const String _primarySidebarExpandedKey = 'primarySidebarExpanded';
  static const String _limitWorkbenchWidthKey = 'limitWorkbenchWidth';
  static const String _recordEditorDialogEnabledKey =
      'recordEditorDialogEnabled';
  static const String _appLocalePreferenceKey = 'appLocalePreference';
  static const String _tablePageSizeKey = 'tablePageSize';
  static const String _interfaceScaleKey = 'interfaceScalePercent';
  static const int minInterfaceScale = 80;
  static const int maxInterfaceScale = 150;

  static const List<int> tablePageSizeOptions = [5, 10, 15, 20, 25];

  Color _themeColor = const Color(0xFF2196F3);
  bool _isDarkMode = false;
  String _fontFamily = '';
  List<String> _availableFonts = [];
  ExportSettings _exportSettings = ExportSettings();
  bool _callSignQthLinkEnabled = true;
  bool _paginationEnabled = true;
  bool _duplicateCallsignWarningEnabled = true;
  bool _controllerDeviceModeEnabled = false;
  bool _autoAppendPowerW = true;
  bool _primarySidebarExpanded = true;
  bool _limitWorkbenchWidth = true;
  bool _recordEditorDialogEnabled = true;
  AppLocalePreference _appLocalePreference = AppLocalePreference.system;
  int _tablePageSize = 10;
  int _interfaceScalePercent = 100;
  int _scaleRevision = 0;
  Future<void> _scaleSave = Future<void>.value();
  ControllerDisplayPreferences _controllerDisplayPreferences =
      const ControllerDisplayPreferences();
  final Future<KeyValueStore> Function() _preferencesLoader;
  final Future<List<String>> Function() _systemFontsLoader;
  var _localePreferenceRevision = 0;
  var _disposed = false;

  Color get themeColor => _themeColor;
  bool get isDarkMode => _isDarkMode;
  String? get fontFamily => _fontFamily.isEmpty ? null : _fontFamily;
  List<String> get availableFonts => _availableFonts;
  ExportSettings get exportSettings => _exportSettings;
  bool get callSignQthLinkEnabled => _callSignQthLinkEnabled;
  bool get paginationEnabled => _paginationEnabled;
  bool get duplicateCallsignWarningEnabled => _duplicateCallsignWarningEnabled;
  bool get autoAppendPowerW => _autoAppendPowerW;
  bool get controllerDeviceModeEnabled => _controllerDeviceModeEnabled;
  bool get primarySidebarExpanded => _primarySidebarExpanded;
  bool get limitWorkbenchWidth => _limitWorkbenchWidth;
  bool get recordEditorDialogEnabled => _recordEditorDialogEnabled;
  AppLocalePreference get appLocalePreference => _appLocalePreference;
  int get tablePageSize => _tablePageSize;
  int get interfaceScalePercent => _interfaceScalePercent;
  double get interfaceScale => _interfaceScalePercent / 100;
  Locale? get locale => switch (_appLocalePreference) {
        AppLocalePreference.system => null,
        AppLocalePreference.simplifiedChinese => const Locale('zh', 'CN'),
        AppLocalePreference.english => const Locale('en', 'US'),
      };
  ControllerDisplayPreferences get controllerDisplayPreferences =>
      _controllerDisplayPreferences;

  SettingsProvider({
    Future<KeyValueStore> Function()? preferencesLoader,
    Future<List<String>> Function()? systemFontsLoader,
  })  : _preferencesLoader = preferencesLoader ?? openKeyValueStore,
        _systemFontsLoader = systemFontsLoader ?? AppConfig.getSystemFonts {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final localePreferenceRevision = _localePreferenceRevision;
    final scaleRevision = _scaleRevision;
    final prefs = await _preferencesLoader();
    if (_disposed) return;
    final storedScale = await prefs.get(_interfaceScaleKey);
    if (_disposed) return;
    if (_scaleRevision == scaleRevision &&
        storedScale is num &&
        storedScale.isFinite) {
      _interfaceScalePercent =
          storedScale.round().clamp(minInterfaceScale, maxInterfaceScale);
    }

    _isDarkMode = await prefs.getBool(_isDarkModeKey);
    _fontFamily = await prefs.getString(_fontFamilyKey) ?? '';

    final colorValue = await prefs.getInt(_themeColorKey);
    if (colorValue != null) {
      _themeColor = Color(colorValue);
    }

    final exportSettingsJson = await prefs.getString(_exportSettingsKey);
    if (exportSettingsJson != null) {
      try {
        _exportSettings =
            ExportSettings.fromJson(json.decode(exportSettingsJson));
      } catch (_) {
        _exportSettings = ExportSettings();
      }
    }
    if (!await prefs.getBool(_sessionTitleExportDefaultsV1Key)) {
      // Earlier releases persisted both switches as false by default. Apply
      // the new default once to existing installations; later explicit
      // opt-outs remain untouched because the migration marker is retained.
      _exportSettings = _exportSettings.copyWith(
        useSessionTitleAsHeader: true,
        useSessionTitleAsFileName: true,
      );
      await prefs.setString(
        _exportSettingsKey,
        json.encode(_exportSettings.toJson()),
      );
      await prefs.setBool(_sessionTitleExportDefaultsV1Key, true);
    }

    _callSignQthLinkEnabled =
        await prefs.getBool(_callSignQthLinkKey, defaultValue: true);
    _paginationEnabled =
        await prefs.getBool(_paginationEnabledKey, defaultValue: true);
    _duplicateCallsignWarningEnabled = await prefs.getBool(
      _duplicateCallsignWarningKey,
      defaultValue: true,
    );
    _autoAppendPowerW =
        await prefs.getBool(_autoAppendPowerWKey, defaultValue: true);
    _controllerDeviceModeEnabled =
        await prefs.getBool(_controllerDeviceModeEnabledKey);
    _primarySidebarExpanded =
        await prefs.getBool(_primarySidebarExpandedKey, defaultValue: true);
    _limitWorkbenchWidth =
        await prefs.getBool(_limitWorkbenchWidthKey, defaultValue: true);
    _recordEditorDialogEnabled =
        await prefs.getBool(_recordEditorDialogEnabledKey, defaultValue: true);
    if (_localePreferenceRevision == localePreferenceRevision) {
      final storedLocalePreference =
          await prefs.getString(_appLocalePreferenceKey);
      _appLocalePreference = AppLocalePreference.values.firstWhere(
        (preference) => preference.name == storedLocalePreference,
        orElse: () => AppLocalePreference.system,
      );
    }
    final storedTablePageSize = await prefs.getInt(_tablePageSizeKey);
    if (storedTablePageSize != null &&
        tablePageSizeOptions.contains(storedTablePageSize)) {
      _tablePageSize = storedTablePageSize;
    }
    final controllerPreferencesJson =
        await prefs.getString(controllerDisplayPreferencesStorageKey);
    if (controllerPreferencesJson != null) {
      try {
        _controllerDisplayPreferences = ControllerDisplayPreferences.fromJson(
          json.decode(controllerPreferencesJson),
        );
      } catch (_) {
        _controllerDisplayPreferences = const ControllerDisplayPreferences();
      }
    }

    notifyListeners();

    final availableFonts = await _systemFontsLoader();
    if (_disposed) return;
    _availableFonts = availableFonts;
    notifyListeners();
  }

  Future<void> setThemeColor(Color color) async {
    _themeColor = color;
    await _saveSetting(_themeColorKey, color.toARGB32());
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await _saveSetting(_isDarkModeKey, _isDarkMode);
    notifyListeners();
  }

  Future<void> setDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    await _saveSetting(_isDarkModeKey, isDark);
    notifyListeners();
  }

  Future<void> setFontFamily(String? fontFamily) async {
    final normalized = fontFamily?.trim() ?? '';
    if (_fontFamily == normalized) return;
    _fontFamily = normalized;
    // Apply the selected font immediately. Persisting first made the picker
    // feel unresponsive, especially on slower desktop storage.
    notifyListeners();
    await _saveSetting(_fontFamilyKey, _fontFamily);
  }

  Future<void> setCallSignQthLink(bool enabled) async {
    _callSignQthLinkEnabled = enabled;
    await _saveSetting(_callSignQthLinkKey, enabled);
    notifyListeners();
  }

  Future<void> setPaginationEnabled(bool enabled) async {
    _paginationEnabled = enabled;
    await _saveSetting(_paginationEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setDuplicateCallsignWarningEnabled(bool enabled) async {
    _duplicateCallsignWarningEnabled = enabled;
    await _saveSetting(_duplicateCallsignWarningKey, enabled);
    notifyListeners();
  }

  Future<void> setAutoAppendPowerW(bool enabled) async {
    _autoAppendPowerW = enabled;
    await _saveSetting(_autoAppendPowerWKey, enabled);
    notifyListeners();
  }

  Future<void> setControllerDeviceModeEnabled(bool enabled) async {
    _controllerDeviceModeEnabled = enabled;
    await _saveSetting(_controllerDeviceModeEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> setPrimarySidebarExpanded(bool expanded) async {
    if (_primarySidebarExpanded == expanded) return;
    _primarySidebarExpanded = expanded;
    notifyListeners();
    await _saveSetting(_primarySidebarExpandedKey, expanded);
  }

  Future<void> setLimitWorkbenchWidth(bool enabled) async {
    if (_limitWorkbenchWidth == enabled) return;
    _limitWorkbenchWidth = enabled;
    notifyListeners();
    await _saveSetting(_limitWorkbenchWidthKey, enabled);
  }

  Future<void> setRecordEditorDialogEnabled(bool enabled) async {
    if (_recordEditorDialogEnabled == enabled) return;
    _recordEditorDialogEnabled = enabled;
    notifyListeners();
    await _saveSetting(_recordEditorDialogEnabledKey, enabled);
  }

  Future<void> setAppLocalePreference(
    AppLocalePreference preference,
  ) async {
    _localePreferenceRevision += 1;
    _appLocalePreference = preference;
    notifyListeners();
    await _saveSetting(_appLocalePreferenceKey, preference.name);
  }

  Future<void> setTablePageSize(int value) async {
    if (!tablePageSizeOptions.contains(value)) return;
    _tablePageSize = value;
    notifyListeners();
    await _saveSetting(_tablePageSizeKey, value);
  }

  Future<void> setInterfaceScalePercent(int value) async {
    _scaleRevision++;
    final next = value.clamp(minInterfaceScale, maxInterfaceScale);
    _interfaceScalePercent = next;
    notifyListeners();
    // Fast +/- clicks must not let a slower old storage write win.
    _scaleSave = _scaleSave
        .catchError((Object _) {})
        .then((_) => _saveSetting(_interfaceScaleKey, next));
    await _scaleSave;
  }

  Future<void> setControllerDisplayPreferences(
    ControllerDisplayPreferences preferences,
  ) async {
    _controllerDisplayPreferences = preferences;
    notifyListeners();
    await _saveSetting(
      controllerDisplayPreferencesStorageKey,
      json.encode(preferences.toJson()),
    );
  }

  Future<void> updateExportSettings(ExportSettings settings) async {
    _exportSettings = settings;
    await _saveSetting(_exportSettingsKey, json.encode(settings.toJson()));
    notifyListeners();
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await _preferencesLoader();

    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    }
  }

  Future<void> resetToDefaults() async {
    _localePreferenceRevision += 1;
    await setInterfaceScalePercent(100);
    _themeColor = const Color(0xFF2196F3);
    _isDarkMode = false;
    _fontFamily = '';
    _exportSettings = ExportSettings();
    _callSignQthLinkEnabled = true;
    _paginationEnabled = true;
    _autoAppendPowerW = true;
    _controllerDeviceModeEnabled = false;
    _primarySidebarExpanded = true;
    _limitWorkbenchWidth = true;
    _appLocalePreference = AppLocalePreference.system;
    _tablePageSize = 10;
    _duplicateCallsignWarningEnabled = true;
    _controllerDisplayPreferences = const ControllerDisplayPreferences();

    final prefs = await _preferencesLoader();
    await prefs.remove(_themeColorKey);
    await prefs.remove(_isDarkModeKey);
    await prefs.remove(_fontFamilyKey);
    await prefs.remove(_exportSettingsKey);
    await prefs.setBool(_sessionTitleExportDefaultsV1Key, true);
    await prefs.remove(_callSignQthLinkKey);
    await prefs.remove(_paginationEnabledKey);
    await prefs.remove(_controllerDeviceModeEnabledKey);
    await prefs.remove(_primarySidebarExpandedKey);
    await prefs.remove(_limitWorkbenchWidthKey);
    await prefs.remove(_appLocalePreferenceKey);
    await prefs.remove(_tablePageSizeKey);
    await prefs.remove(_duplicateCallsignWarningKey);
    await prefs.remove(_autoAppendPowerWKey);
    await prefs.remove(controllerDisplayPreferencesStorageKey);

    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
