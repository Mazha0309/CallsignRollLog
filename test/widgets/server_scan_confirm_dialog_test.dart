import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/widgets/server_scan_confirm_dialog.dart';

void main() {
  testWidgets('signed out and the same server use the check copy',
      (tester) async {
    await _open(
      tester,
      loggedIn: false,
      currentServerUrl: '',
      candidateUrl: 'https://server.example',
    );
    expect(find.text('连接到这台服务器？'), findsOneWidget);
    expect(find.textContaining('将检查 https://server.example'), findsOneWidget);
    expect(find.textContaining('不会登录'), findsOneWidget);
    expect(find.textContaining('当前账号会退出'), findsNothing);
  });

  testWidgets('the same signed-in server still uses the check copy',
      (tester) async {
    await _open(
      tester,
      loggedIn: true,
      currentServerUrl: 'https://server.example',
      candidateUrl: 'https://server.example',
    );
    expect(find.textContaining('不会登录'), findsOneWidget);
    expect(find.textContaining('当前账号会退出'), findsNothing);
  });

  testWidgets('a different signed-in server uses the switch copy only',
      (tester) async {
    await _open(
      tester,
      loggedIn: true,
      currentServerUrl: 'https://current.example',
      candidateUrl: 'https://other.example',
    );
    expect(find.textContaining('将连接到 https://other.example'), findsOneWidget);
    expect(find.textContaining('当前账号会退出'), findsOneWidget);
    expect(find.textContaining('不会登录'), findsNothing);
    expect(find.text('切换服务器？'), findsNothing);
  });
}

Future<void> _open(
  WidgetTester tester, {
  required bool loggedIn,
  required String currentServerUrl,
  required String candidateUrl,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmScannedServerAddress(
              context,
              loggedIn: loggedIn,
              currentServerUrl: currentServerUrl,
              candidateUrl: candidateUrl,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
