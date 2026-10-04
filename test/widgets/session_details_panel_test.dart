import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:openlogtool/theme/app_theme.dart';
import 'package:openlogtool/widgets/session_details_panel.dart';

const _session = Session(
  sessionId: '246d2b08-87b9-464e-a71a-7106425dbd63',
  title: 'BG5CRL',
  status: 'closed',
  createdAt: '2026-10-04T01:00:00Z',
  updatedAt: '2026-10-04T02:00:00Z',
  closedAt: '2026-10-04T03:00:00Z',
);

void main() {
  for (final brightness in Brightness.values) {
    for (final width in [320.0, 900.0]) {
      testWidgets(
          'details use ${width < 600 ? 'one column' : 'two columns'} with a full-width ID in $brightness',
          (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pumpDetails(tester, brightness: brightness);
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();

        final type = find.byKey(const ValueKey('session-detail-type'));
        final status = find.byKey(const ValueKey('session-detail-status'));
        final ended = find.byKey(const ValueKey('session-detail-ended'));
        final id = find.byKey(const ValueKey('session-detail-id'));
        final typeRect = tester.getRect(type);
        final statusRect = tester.getRect(status);
        final idRect = tester.getRect(id);
        if (width < 600) {
          expect(statusRect.left, typeRect.left);
          expect(statusRect.top, greaterThan(typeRect.bottom));
        } else {
          expect(statusRect.top, typeRect.top);
          expect(statusRect.left, greaterThan(typeRect.right));
          expect(idRect.width, greaterThan(typeRect.width * 2));
        }
        expect(idRect.left, typeRect.left);
        expect(idRect.top, greaterThan(tester.getRect(ended).bottom));
        expect(
            find.text('Local recording · No server required'), findsOneWidget);
        expect(find.byType(SelectableText), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('expansion and selectable ID keep independent stored state',
      (tester) async {
    final showPanel = ValueNotifier(true);
    addTearDown(showPanel.dispose);
    await _pumpDetails(tester, showPanel: showPanel);
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.byType(SelectableText), findsOneWidget);

    showPanel.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(SessionDetailsPanel), findsNothing);
    showPanel.value = true;
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    expect(
        find.byKey(PageStorageKey('session-details-id-${_session.sessionId}')),
        findsOneWidget);
    expect(
        find.byKey(
            PageStorageKey('session-details-expanded-${_session.sessionId}')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDetails(WidgetTester tester,
    {Brightness brightness = Brightness.light,
    ValueNotifier<bool>? showPanel}) async {
  const details = SessionDetailsPanel(
      session: _session, recordCount: 42, collaborative: false);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(brightness: brightness, seedColor: Colors.teal),
    locale: const Locale('en', 'US'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.3,
        maxScaleFactor: 1.3,
        child: ListView(
          key: const PageStorageKey('session-details-test-list'),
          padding: const EdgeInsets.all(AppSpace.md),
          children: [
            if (showPanel != null)
              ValueListenableBuilder(
                valueListenable: showPanel,
                builder: (context, visible, _) =>
                    visible ? details : const SizedBox.shrink(),
              )
            else
              details,
          ],
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}
