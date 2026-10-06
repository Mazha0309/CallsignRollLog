import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/ai_recognition_settings_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/services/ai_credential_store.dart';
import 'package:openlogtool/services/secure_token_store.dart';
import 'package:openlogtool/services/text_assistant.dart';
import 'package:openlogtool/widgets/export_panel.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Excel configuration summary and editor fit a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = SettingsProvider();
    final sessions = SessionProvider();
    addTearDown(settings.dispose);
    addTearDown(sessions.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<SessionProvider>.value(value: sessions),
          ChangeNotifierProvider<AiRecognitionSettingsProvider>(
            create: (_) => AiRecognitionSettingsProvider(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ExportPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Excel 配置概览'), findsOneWidget);
    expect(find.text('编辑设置'), findsOneWidget);
    expect(
      find.text('此处展示当前配置；交替行可直接切换，其他选项请打开编辑设置。'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('编辑设置'));
    await tester.tap(find.text('编辑设置'));
    await tester.pumpAndSettle();

    expect(find.text('编辑 Excel 导出设置'), findsOneWidget);
    expect(find.text('表格样式'), findsOneWidget);
    expect(find.text('模板变量'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('data transfer panel and Excel editor are localized in English',
      (tester) async {
    tester.view.physicalSize = const Size(900, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = SettingsProvider();
    final sessions = SessionProvider();
    addTearDown(settings.dispose);
    addTearDown(sessions.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<SessionProvider>.value(value: sessions),
          ChangeNotifierProvider<AiRecognitionSettingsProvider>(
            create: (_) => AiRecognitionSettingsProvider(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ExportPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Import and export'), findsOneWidget);
    expect(find.text('Record files'), findsOneWidget);
    expect(find.text('Export JSON'), findsOneWidget);
    expect(find.text('Export ADIF'), findsOneWidget);
    // LLM 未启用时隐藏 Excel 导入按钮。
    expect(find.text('Import Excel'), findsNothing);
    expect(find.text('Excel configuration'), findsOneWidget);
    expect(find.text('File formats'), findsOneWidget);
    expect(find.text('数据导入导出'), findsNothing);

    await tester.tap(find.text('Edit settings'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Excel export settings'), findsOneWidget);
    expect(find.text('File'), findsOneWidget);
    expect(find.text('Table style'), findsOneWidget);
    expect(find.text('Template variables'), findsOneWidget);
    expect(find.text('Export location'), findsWidgets);
    expect(find.text('Filename template'), findsWidgets);

    await tester.tap(find.text('Table style'));
    await tester.pumpAndSettle();
    expect(find.text('Header background color'), findsOneWidget);
    expect(find.text('Alternating row color'), findsWidgets);
    expect(find.text('Footer information'), findsOneWidget);
    expect(find.text('Table font'), findsOneWidget);

    await tester.ensureVisible(find.byIcon(Icons.colorize).first);
    await tester.tap(find.byIcon(Icons.colorize).first);
    await tester.pumpAndSettle();
    expect(find.text('Choose Header background color'), findsOneWidget);
    expect(
      find.byKey(const Key('theme-color-picker-dialog')),
      findsOneWidget,
    );
    expect(find.text('Preset colors'), findsOneWidget);
    expect(find.text('Custom color'), findsOneWidget);
    expect(
      find.byKey(const Key('theme-color-hex-field')),
      findsOneWidget,
    );
    expect(find.text('Hue'), findsOneWidget);
    expect(find.text('Opacity'), findsOneWidget);
    expect(
      find.byKey(const Key('theme-color-opacity-slider')),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Template variables'));
    await tester.pumpAndSettle();
    expect(find.text('Template variable reference'), findsOneWidget);
    expect(find.text('Four-digit year, for example 2024'), findsOneWidget);
    expect(find.text('Examples'), findsOneWidget);
    expect(find.text('Net_Log_2024-03-28.xlsx'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Excel import button appears only when LLM is enabled',
      (tester) async {
    tester.view.physicalSize = const Size(900, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final settings = SettingsProvider();
    final sessions = SessionProvider();
    final aiSettings = AiRecognitionSettingsProvider(
      credentialStore: AiCredentialStore(
        secureValues: _MemorySecureValues(),
      ),
    );
    addTearDown(settings.dispose);
    addTearDown(sessions.dispose);
    addTearDown(aiSettings.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<SessionProvider>.value(value: sessions),
          ChangeNotifierProvider<AiRecognitionSettingsProvider>.value(
            value: aiSettings,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ExportPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Import Excel'), findsNothing);

    await aiSettings.saveTextAssistant(
      provider: TextAssistantProvider.openAi,
      baseUrl: Uri.parse('https://api.openai.com/v1'),
      model: 'gpt-4o-mini',
      secret: 'test-key',
    );
    await tester.pumpAndSettle();

    expect(find.text('Import Excel'), findsOneWidget);

    await aiSettings.setTextAssistantEnabled(false);
    await tester.pumpAndSettle();

    expect(find.text('Import Excel'), findsNothing);
  });
}

final class _MemorySecureValues implements SecureValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}
