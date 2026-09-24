import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/app_info_provider.dart';
import 'package:openlogtool/providers/ai_recognition_settings_provider.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/personal_cloud_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/screens/home_screen.dart';
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:openlogtool/widgets/log_form.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('mobile navigation releases the focused workbench field',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      tester.view.physicalSize = const Size(600, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const _HomeScreenTestApp());
      await tester.pumpAndSettle();

      final field =
          tester.widget<EditableText>(find.byType(EditableText).first);
      final focusNode = field.focusNode;
      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      final navigation = find.byKey(const Key('mobile-navigation'));
      await tester.tap(
        find.descendant(
          of: navigation,
          matching: find.byIcon(Icons.groups_outlined),
        ),
      );
      await tester.pump();

      expect(focusNode.hasFocus, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('workbench dismisses the keyboard when dragged', (tester) async {
    tester.view.physicalSize = const Size(600, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const _HomeScreenTestApp());
    await tester.pumpAndSettle();

    final workbenchScroll = tester.widget<SingleChildScrollView>(
      find
          .ancestor(
            of: find.byType(LogForm),
            matching: find.byType(SingleChildScrollView),
          )
          .first,
    );
    expect(
      workbenchScroll.keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
  });

  testWidgets(
    'resizing across navigation breakpoints preserves the focused form',
    (tester) async {
      tester.view.physicalSize = const Size(680, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const _HomeScreenTestApp());
      await tester.pumpAndSettle();

      final formFinder = find.byType(LogForm);
      final initialState = tester.state(formFinder);
      final editableFinder = find.byType(EditableText).first;
      final editable = tester.widget<EditableText>(editableFinder);
      editable.focusNode.requestFocus();
      await tester.enterText(editableFinder, 'BG5CRL');
      expect(editable.focusNode.hasFocus, isTrue);

      for (final size in const <Size>[
        Size(900, 960),
        Size(1280, 960),
        Size(650, 960),
        Size(1440, 960),
        Size(700, 960),
      ]) {
        tester.view.physicalSize = size;
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.state(formFinder), same(initialState));
        expect(
          tester.widget<EditableText>(editableFinder).controller.text,
          'BG5CRL',
        );
        expect(editable.focusNode.hasFocus, isTrue);
      }
    },
  );
}

class _HomeScreenTestApp extends StatelessWidget {
  const _HomeScreenTestApp();

  @override
  Widget build(BuildContext context) {
    const session = Session(
      sessionId: 'session-1',
      title: 'Test session',
      status: 'active',
      createdAt: '2026-07-13T10:00:00Z',
      updatedAt: '2026-07-13T10:00:00Z',
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppInfoProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AiRecognitionSettingsProvider()),
        ChangeNotifierProvider<SessionProvider>(
          create: (_) => _TestSessionProvider(session),
        ),
        ChangeNotifierProvider(
          create: (_) => ServerProvider(autoLoadSettings: false),
        ),
        ChangeNotifierProvider(
          create: (_) => DictionaryProvider(autoload: false),
        ),
        ChangeNotifierProvider(
          create: (_) => LogProvider(
            sessionListLoader: () async => [session],
            sessionLogPageLoader: (_, __, ___) async => [],
          ),
        ),
        ChangeNotifierProvider(create: (_) => CollaborationProvider()),
        ChangeNotifierProvider(create: (_) => AccountShareProvider()),
        ChangeNotifierProvider(
          create: (_) => PersonalCloudProvider(
            exporter: () async => '{"version":1,"sessions":[],"logs":[]}',
          ),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(),
      ),
    );
  }
}

class _TestSessionProvider extends SessionProvider {
  _TestSessionProvider(this.session);

  final Session session;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  String get currentSessionId => session.sessionId;

  @override
  Session get currentSession => session;
}
