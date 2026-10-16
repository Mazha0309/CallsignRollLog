import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/widgets/server_qr_scan_controls.dart';

void main() {
  testWidgets('unsupported torch and camera switch take no space',
      (tester) async {
    await _pump(tester, torch: false, switchCamera: false);
    expect(find.byKey(const Key('server-scan-torch')), findsNothing);
    expect(find.byKey(const Key('server-scan-switch-camera')), findsNothing);
    expect(find.byKey(const Key('server-scan-image')), findsOneWidget);
  });

  testWidgets('available torch and camera switch are shown', (tester) async {
    var torch = 0;
    var switched = 0;
    var images = 0;
    await _pump(
      tester,
      torch: true,
      switchCamera: true,
      onTorch: () => torch++,
      onSwitchCamera: () => switched++,
      onPickImage: () => images++,
    );
    await tester.tap(find.byKey(const Key('server-scan-torch')));
    await tester.tap(find.byKey(const Key('server-scan-switch-camera')));
    await tester.tap(find.byKey(const Key('server-scan-image')));
    expect(torch, 1);
    expect(switched, 1);
    expect(images, 1);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required bool torch,
  required bool switchCamera,
  VoidCallback? onTorch,
  VoidCallback? onSwitchCamera,
  VoidCallback? onPickImage,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ServerQrScanControls(
          torchVisible: torch,
          switchVisible: switchCamera,
          onTorch: onTorch ?? () {},
          onSwitchCamera: onSwitchCamera ?? () {},
          onPickImage: onPickImage ?? () {},
        ),
      ),
    ),
  );
}
