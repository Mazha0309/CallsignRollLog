import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/app_info_provider.dart';
import 'package:openlogtool/providers/ai_recognition_settings_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/screens/home_screen.dart';
import 'package:openlogtool/widgets/settings/layout_settings.dart';
import 'package:openlogtool/widgets/settings/theme_settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('categorized settings remain usable on a narrow scaled screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _usePlatformLocale(tester, const Locale('en', 'US'));
    await _setSurface(tester, const Size(320, 568));
    final providers = _SettingsProviders();
    addTearDown(providers.dispose);

    await tester.pumpWidget(
      _SettingsPanelHarness(
        providers: providers,
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-compact-layout')), findsOneWidget);
    expect(
      find.byKey(const Key('settings-category-appearance')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    final pageScrollable = find
        .descendant(
          of: find.byKey(const Key('settings-panel-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    expect(pageScrollable, findsOneWidget);

    await tester.tap(
      find.byKey(const Key('settings-category-appearance')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-category-back')), findsOneWidget);

    final languagePicker = find.byKey(const Key('app-language-picker'));
    await tester.scrollUntilVisible(
      languagePicker,
      240,
      scrollable: pageScrollable,
    );
    expect(languagePicker.hitTestable(), findsOneWidget);
    await tester.tap(languagePicker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(find.text('Appearance & language'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final back = find.byKey(const Key('settings-category-back'));
    await tester.scrollUntilVisible(
      back,
      -240,
      scrollable: pageScrollable,
    );
    await tester.tap(back);
    await tester.pumpAndSettle();

    final aboutEntry = find.byKey(const Key('about-app-entry'));
    final applicationCategory =
        find.byKey(const Key('settings-category-application'));
    await tester.scrollUntilVisible(
      applicationCategory,
      320,
      scrollable: pageScrollable,
    );
    await tester.tap(applicationCategory);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      aboutEntry,
      240,
      scrollable: pageScrollable,
    );
    expect(aboutEntry.hitTestable(), findsOneWidget);
    await tester.tap(aboutEntry);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about-app-dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('about-close')));
    await tester.pumpAndSettle();

    final logsEntry = find.byKey(const Key('view-logs-entry'));
    await tester.scrollUntilVisible(
      logsEntry,
      160,
      scrollable: pageScrollable,
    );
    expect(logsEntry.hitTestable(), findsOneWidget);
    await tester.tap(logsEntry);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('log-viewer-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('log-viewer-close')));
    await tester.pumpAndSettle();

    final restoreEntry =
        find.byKey(const Key('restore-default-settings-entry'));
    await tester.scrollUntilVisible(
      restoreEntry,
      160,
      scrollable: pageScrollable,
    );
    expect(restoreEntry.hitTestable(), findsOneWidget);
    await tester.tap(restoreEntry);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Restore default settings'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide settings use a category rail and one visible detail',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _usePlatformLocale(tester, const Locale('en', 'US'));
    await _setSurface(tester, const Size(1200, 900));
    final providers = _SettingsProviders();
    addTearDown(providers.dispose);

    await tester.pumpWidget(_SettingsPanelHarness(providers: providers));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-wide-layout')), findsOneWidget);
    final categoryNavigation =
        find.byKey(const Key('settings-category-navigation'));
    final appearanceSettings = find.byType(
      ThemeSettings,
      skipOffstage: false,
    );
    final layoutSettings = find.byType(
      LayoutSettings,
      skipOffstage: false,
    );
    final appearanceCard = find.descendant(
      of: appearanceSettings,
      matching: find.byType(Card, skipOffstage: false),
    );
    final layoutCard = find.descendant(
      of: layoutSettings,
      matching: find.byType(Card, skipOffstage: false),
    );
    expect(appearanceCard, findsOneWidget);
    expect(layoutCard, findsOneWidget);

    final appearanceOffstage = tester.widget<Offstage>(
      find
          .ancestor(
            of: appearanceSettings,
            matching: find.byType(Offstage, skipOffstage: false),
          )
          .first,
    );
    final layoutOffstage = tester.widget<Offstage>(
      find
          .ancestor(
            of: layoutSettings,
            matching: find.byType(Offstage, skipOffstage: false),
          )
          .first,
    );
    expect(appearanceOffstage.offstage, isFalse);
    expect(layoutOffstage.offstage, isTrue);
    final appearanceRect = tester.getRect(appearanceCard);
    expect(appearanceRect.size, isNot(Size.zero));
    expect(
      tester.getRect(categoryNavigation).right,
      lessThan(appearanceRect.left),
    );
    expect(find.text('Appearance & language'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-category-workbench')));
    await tester.pumpAndSettle();

    final layoutRect = tester.getRect(layoutCard);
    expect(layoutRect.size, isNot(Size.zero));
    expect(
      tester
          .widget<Offstage>(
            find
                .ancestor(
                  of: appearanceSettings,
                  matching: find.byType(Offstage, skipOffstage: false),
                )
                .first,
          )
          .offstage,
      isTrue,
    );
    expect(
      tester
          .widget<Offstage>(
            find
                .ancestor(
                  of: layoutSettings,
                  matching: find.byType(Offstage, skipOffstage: false),
                )
                .first,
          )
          .offstage,
      isFalse,
    );
    expect(find.text('Net Desk & layout'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI settings expose every supported ASR endpoint format',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _usePlatformLocale(tester, const Locale('en', 'US'));
    await _setSurface(tester, const Size(1200, 900));
    final providers = _SettingsProviders();
    addTearDown(providers.dispose);

    await tester.pumpWidget(_SettingsPanelHarness(providers: providers));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-category-ai')));
    await tester.pumpAndSettle();

    expect(find.text('AI-assisted recognition'), findsOneWidget);
    expect(find.text('Audio transcription multipart'), findsOneWidget);
    expect(find.text('Chat input_audio'), findsOneWidget);
    expect(find.text('Generic JSON HTTP'), findsWidgets);

    final addAsrProfile = find.byKey(
      const Key('ai-add-profile-speechRecognition'),
    );
    await tester.ensureVisible(addAsrProfile);
    await tester.tap(addAsrProfile);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('ai-profile-editor-dialog')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('ai-profile-protocol')));
    await tester.pumpAndSettle();
    expect(find.text('Audio transcription multipart'), findsWidgets);
    expect(find.text('Chat input_audio'), findsWidgets);
    expect(find.text('Generic JSON HTTP'), findsWidgets);
    await tester.tap(find.text('Generic JSON HTTP').last);
    await tester.pumpAndSettle();
    final optionsField = tester.widget<TextFormField>(
      find.byKey(const Key('ai-profile-request-options')),
    );
    expect(optionsField.controller!.text, contains('requestTemplate'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide settings navigation and detail scroll independently',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _usePlatformLocale(tester, const Locale('en', 'US'));
    await _setSurface(tester, const Size(1200, 420));
    final providers = _SettingsProviders();
    addTearDown(providers.dispose);
    await tester.pumpWidget(_SettingsPanelHarness(providers: providers));
    await tester.pumpAndSettle();

    final navigation = tester
        .widget<SingleChildScrollView>(
          find.byKey(const Key('settings-navigation-scroll')),
        )
        .controller!;
    final appearance = tester
        .widget<SingleChildScrollView>(
          find.byKey(const Key('settings-appearance-scroll')),
        )
        .controller!;
    expect(navigation, isNot(same(appearance)));
    expect(navigation.position.maxScrollExtent, greaterThan(0));
    expect(appearance.position.maxScrollExtent, greaterThan(0));

    final detailOffset = appearance.position.maxScrollExtent.clamp(0.0, 160.0);
    appearance.jumpTo(detailOffset);
    await tester.pumpAndSettle();
    expect(navigation.offset, 0);
    navigation.jumpTo(navigation.position.maxScrollExtent);
    await tester.pump();
    expect(appearance.offset, detailOffset);

    navigation.jumpTo(0);
    await tester.pump();
    await tester.tap(find.byKey(const Key('settings-category-workbench')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-category-appearance')));
    await tester.pumpAndSettle();
    expect(appearance.offset, detailOffset);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'compact back stays visible while detail scrolls and returns to categories',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _usePlatformLocale(tester, const Locale('en', 'US'));
    await _setSurface(tester, const Size(390, 620));
    final providers = _SettingsProviders();
    addTearDown(providers.dispose);
    await tester.pumpWidget(_SettingsPanelHarness(providers: providers));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-category-appearance')));
    await tester.pumpAndSettle();
    final back = find.byKey(const Key('settings-category-back'));
    final initialBack = tester.getRect(back);
    await tester.drag(find.byKey(const Key('settings-appearance-scroll')),
        const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getRect(back), initialBack);
    expect(back.hitTestable(), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
        find.byKey(const Key('settings-category-navigation')), findsOneWidget);
    expect(find.byKey(const Key('settings-category-back')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI settings and profile editor fit a narrow scaled screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    _usePlatformLocale(tester, const Locale('zh', 'CN'));
    await _setSurface(tester, const Size(320, 568));
    final providers = _SettingsProviders();
    addTearDown(providers.dispose);

    await tester.pumpWidget(
      _SettingsPanelHarness(
        providers: providers,
        textScaler: const TextScaler.linear(1.4),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(
          of: find.byKey(const Key('settings-panel-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final aiCategory = find.byKey(const Key('settings-category-ai'));
    await tester.scrollUntilVisible(
      aiCategory,
      240,
      scrollable: scrollable,
    );
    await tester.tap(aiCategory);
    await tester.pumpAndSettle();

    final addAsr = find.byKey(
      const Key('ai-add-profile-speechRecognition'),
    );
    await tester.scrollUntilVisible(
      addAsr,
      240,
      scrollable: scrollable,
    );
    await tester.tap(addAsr);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('ai-profile-editor-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('ai-profile-name')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void _usePlatformLocale(WidgetTester tester, Locale locale) {
  final dispatcher = tester.binding.platformDispatcher;
  dispatcher.localeTestValue = locale;
  dispatcher.localesTestValue = <Locale>[locale];
  addTearDown(() {
    dispatcher.clearLocaleTestValue();
    dispatcher.clearLocalesTestValue();
  });
}

class _SettingsProviders {
  _SettingsProviders()
      : settings = SettingsProvider(),
        server = ServerProvider(autoLoadSettings: false),
        appInfo = AppInfoProvider(),
        aiRecognition = AiRecognitionSettingsProvider();

  final SettingsProvider settings;
  final ServerProvider server;
  final AppInfoProvider appInfo;
  final AiRecognitionSettingsProvider aiRecognition;

  void dispose() {
    settings.dispose();
    server.dispose();
    appInfo.dispose();
    aiRecognition.dispose();
  }
}

class _SettingsPanelHarness extends StatelessWidget {
  const _SettingsPanelHarness({
    required this.providers,
    this.textScaler = TextScaler.noScaling,
  });

  final _SettingsProviders providers;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(
          value: providers.settings,
        ),
        ChangeNotifierProvider<ServerProvider>.value(value: providers.server),
        ChangeNotifierProvider<AppInfoProvider>.value(
          value: providers.appInfo,
        ),
        ChangeNotifierProvider<AiRecognitionSettingsProvider>.value(
          value: providers.aiRecognition,
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) => MaterialApp(
          locale: settings.locale,
          localeResolutionCallback: resolveAppLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: const Scaffold(body: _SettingsPanelHost()),
        ),
      ),
    );
  }
}

class _SettingsPanelHost extends StatelessWidget {
  const _SettingsPanelHost();

  @override
  Widget build(BuildContext context) => const SizedBox(
        key: Key('settings-panel-scroll'),
        child: SettingsPage(),
      );
}
