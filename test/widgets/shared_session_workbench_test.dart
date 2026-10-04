import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/providers/shared_workbench_provider.dart';
import 'package:openlogtool/screens/home_screen.dart';
import 'package:openlogtool/widgets/log_form.dart';
import 'package:openlogtool/widgets/log_table.dart';
import '../providers/shared_workbench_provider_test.dart'
    show RemoteFixture, shared;

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets(
        'shared workbench uses normal form/table and reacts to permissions at $width',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sharing = RemoteFixture();
      addTearDown(sharing.dispose);
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AccountShareProvider>.value(value: sharing),
            ChangeNotifierProvider(
                create: (_) => DictionaryProvider(autoload: false)),
            ChangeNotifierProvider(create: (_) => SessionProvider()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ],
          child: MaterialApp(
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: SharedSessionWorkbench(
                    session: sharing.catalog.first,
                    onOpenSessions: () {},
                    saveShortcutEnabled: true)),
          )));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(LogForm), findsOneWidget);
      expect(find.byType(LogTable), findsOneWidget);
      expect(tester.widget<LogForm>(find.byType(LogForm)).sessionId,
          'same-local-id');
      final provider = tester.element(find.byType(LogForm)).read<LogProvider>()
          as SharedWorkbenchProvider;
      expect(provider.canDeleteLog(provider.logs.single), false);
      expect(tester.widget<LogForm>(find.byType(LogForm)).readOnly, false);
      sharing.catalog = [shared(edit: false)];
      sharing.update();
      await tester.pumpAndSettle();
      expect(tester.widget<LogForm>(find.byType(LogForm)).readOnly, true);
      sharing.catalog = [];
      sharing.update();
      await tester.pumpAndSettle();
      expect(provider.logs, isEmpty);
      expect(provider.hasReadAccess, false);
      expect(sharing.writes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
