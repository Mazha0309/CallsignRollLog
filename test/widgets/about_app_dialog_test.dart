import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/services/github_release_service.dart';
import 'package:openlogtool/widgets/about_app_dialog.dart';

void main() {
  testWidgets('shows complete app and project information in zh_CN',
      (tester) async {
    await _setSurface(tester, const Size(800, 760));

    await tester.pumpWidget(
      _TestApp(
        locale: const Locale('zh', 'CN'),
        launcher: (_) async => true,
      ),
    );
    await tester.tap(find.byKey(const Key('open-about')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('about-app-dialog')), findsOneWidget);
    expect(find.text('Callsign Roll Log'), findsOneWidget);
    expect(find.text('版本 2.1.0-R+42'), findsOneWidget);
    expect(find.text('2.1.0-R+42'), findsOneWidget);
    expect(find.text('418'), findsOneWidget);
    expect(find.text('abc1234'), findsOneWidget);
    expect(find.text('GNU AGPL-3.0'), findsOneWidget);
    expect(find.byKey(const Key('about-repository')), findsOneWidget);
    expect(find.byKey(const Key('about-issues')), findsOneWidget);
    expect(find.byKey(const Key('about-licenses')), findsOneWidget);
    expect(find.byKey(const Key('about-check-updates')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('about-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about-app-dialog')), findsNothing);
  });

  testWidgets('fits a narrow English screen and opens the repository',
      (tester) async {
    await _setSurface(tester, const Size(320, 568));
    Uri? openedUri;

    await tester.pumpWidget(
      _TestApp(
        locale: const Locale('en', 'US'),
        textScaleFactor: 2,
        launcher: (uri) async {
          openedUri = uri;
          return true;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('open-about')));
    await tester.pumpAndSettle();

    expect(find.text('Callsign Roll Log'), findsOneWidget);
    expect(find.byKey(const Key('about-app-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final repository = find.byKey(const Key('about-repository'));
    await tester.ensureVisible(repository);
    await tester.tap(repository);
    await tester.pump();

    expect(openedUri, AboutAppDialog.repositoryUri);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const Key('about-licenses')));
    expect(find.byKey(const Key('about-close')).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const Key('about-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about-app-dialog')), findsNothing);
  });

  testWidgets('shows an available update and opens its trusted release page',
      (tester) async {
    await _setSurface(tester, const Size(800, 760));
    final releaseUri = Uri.parse(
      'https://github.com/Mazha0309/OpenLogTool/releases/tag/v2.2.0-R',
    );
    Uri? openedUri;

    await tester.pumpWidget(
      _TestApp(
        locale: const Locale('zh', 'CN'),
        launcher: (uri) async {
          openedUri = uri;
          return true;
        },
        updateChecker: (currentVersion) async => ReleaseUpdateCheck(
          currentVersion: currentVersion,
          latestVersion: '2.2.0-R',
          releaseUri: releaseUri,
          updateAvailable: true,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open-about')));
    await tester.pumpAndSettle();

    final checkButton = find.byKey(const Key('about-check-updates'));
    await tester.ensureVisible(checkButton);
    await tester.tap(checkButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('about-update-available-dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('最新版本：2.2.0-R'), findsOneWidget);

    await tester.tap(find.byKey(const Key('about-open-release')));
    await tester.pumpAndSettle();

    expect(openedUri, releaseUri);
    expect(
      find.byKey(const Key('about-update-available-dialog')),
      findsNothing,
    );
  });

  testWidgets('prevents duplicate checks and reports the current version',
      (tester) async {
    await _setSurface(tester, const Size(800, 760));
    final result = Completer<ReleaseUpdateCheck>();
    var calls = 0;

    await tester.pumpWidget(
      _TestApp(
        locale: const Locale('en', 'US'),
        launcher: (_) async => true,
        updateChecker: (currentVersion) {
          calls += 1;
          return result.future;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('open-about')));
    await tester.pumpAndSettle();

    final checkButton = find.byKey(const Key('about-check-updates'));
    await tester.ensureVisible(checkButton);
    await tester.tap(checkButton);
    await tester.pump();

    expect(calls, 1);
    expect(find.text('Checking…'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(checkButton).onPressed,
      isNull,
    );

    await tester.tap(checkButton, warnIfMissed: false);
    expect(calls, 1);

    result.complete(
      ReleaseUpdateCheck(
        currentVersion: '2.1.0-R+42',
        latestVersion: '2.1.0-R',
        releaseUri: Uri.parse(
          'https://github.com/Mazha0309/OpenLogTool/releases/tag/v2.1.0-R',
        ),
        updateAvailable: false,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('You’re up to date (2.1.0-R)'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(checkButton).onPressed,
      isNotNull,
    );
  });

  testWidgets('shows a localized failure when the update request fails',
      (tester) async {
    await _setSurface(tester, const Size(800, 760));

    await tester.pumpWidget(
      _TestApp(
        locale: const Locale('zh', 'CN'),
        launcher: (_) async => true,
        updateChecker: (_) async => throw Exception('offline'),
      ),
    );
    await tester.tap(find.byKey(const Key('open-about')));
    await tester.pumpAndSettle();

    final checkButton = find.byKey(const Key('about-check-updates'));
    await tester.ensureVisible(checkButton);
    await tester.tap(checkButton);
    await tester.pump();
    await tester.pump();

    expect(find.text('检查更新失败，请检查网络后重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.locale,
    required this.launcher,
    this.textScaleFactor = 1,
    this.updateChecker,
  });

  final Locale locale;
  final AboutLinkLauncher launcher;
  final double textScaleFactor;
  final AboutUpdateChecker? updateChecker;

  @override
  Widget build(BuildContext context) => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                key: const Key('open-about'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AboutAppDialog(
                    appName: 'Callsign Roll Log',
                    fullVersion: '2.1.0-R+42',
                    buildNumber: '418',
                    commitHash: 'abc1234',
                    linkLauncher: launcher,
                    updateChecker: updateChecker,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
}
