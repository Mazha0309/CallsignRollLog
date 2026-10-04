import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/widgets/log_form.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Tab cycles through log form fields without landing on buttons',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextFormField, '主控呼号 *'));
    await tester.pump();
    expect(
      FocusManager.instance.primaryFocus?.debugLabel ??
          FocusManager.instance.primaryFocus?.context?.widget.runtimeType
              .toString(),
      isNot(equals('FilledButton')),
    );

    for (var i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus;
      expect(find.byKey(const Key('save-log-record')).evaluate(), isNotEmpty);
      expect(focused?.context?.findAncestorWidgetOfExactType<FilledButton>(),
          isNull);
      expect(focused?.context?.findAncestorWidgetOfExactType<OutlinedButton>(),
          isNull);
    }
  });
}

Widget _app() => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CollaborationProvider()),
        ChangeNotifierProvider(create: (_) => LogProvider()),
        ChangeNotifierProvider(
          create: (_) => DictionaryProvider(autoload: false),
        ),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: LogForm(),
          ),
        ),
      ),
    );
