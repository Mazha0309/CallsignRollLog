import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/services/key_value_store.dart';
import 'package:openlogtool/widgets/app_scale.dart';
import 'package:openlogtool/widgets/settings/theme_settings.dart';

SettingsProvider settings() => SettingsProvider(
      preferencesLoader: () async =>
          PrefsKeyValueStore(await SharedPreferences.getInstance()),
      systemFontsLoader: () async => [],
    );

void main() {
  testWidgets(
      'zoom scales layout, insets, pointer targets and dialogs without losing edits',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scale = ValueNotifier(1.0);
    addTearDown(scale.dispose);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    MediaQueryData? media;
    await tester.pumpWidget(MaterialApp(
      builder: (_, child) => ValueListenableBuilder<double>(
          valueListenable: scale,
          child: child,
          builder: (_, value, child) => AppScale(scale: value, child: child!)),
      home: Builder(builder: (context) {
        media = MediaQuery.of(context);
        return Scaffold(
            body: Column(children: [
          TextField(focusNode: focus),
          SizedBox(
              key: const Key('sized-control'),
              width: 100,
              height: 40,
              child: FilledButton(
                  onPressed: () => showDialog<void>(
                      context: context,
                      builder: (c) =>
                          AlertDialog(content: const Text('弹窗'), actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(c),
                                child: const Text('关闭')),
                          ])),
                  child: const Text('打开'))),
        ]));
      }),
    ));
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'BG5CRL');
    scale.value = 1.25;
    await tester.pumpAndSettle();
    expect(media!.size, const Size(640, 480));
    expect(focus.hasFocus, isTrue);
    expect(find.text('BG5CRL'), findsOneWidget);
    final box =
        tester.renderObject<RenderBox>(find.byKey(const Key('sized-control')));
    expect(
        (box.localToGlobal(const Offset(100, 0)) -
                box.localToGlobal(Offset.zero))
            .dx,
        125);
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    scale.value = .8;
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(MediaQuery.sizeOf(tester.element(find.byType(AlertDialog))),
        const Size(1000, 750));
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(media!.viewInsets.bottom, 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scale persists, clamps and ignores a late settings load',
      (tester) async {
    SharedPreferences.setMockInitialValues({'interfaceScalePercent': 125});
    final provider = settings();
    addTearDown(provider.dispose);
    await tester.pumpAndSettle();
    expect(provider.interfaceScalePercent, 125);
    await provider.setInterfaceScalePercent(999);
    expect(provider.interfaceScalePercent, 150);
    await provider.setInterfaceScalePercent(1);
    expect(provider.interfaceScalePercent, 80);
    await Future.wait([
      provider.setInterfaceScalePercent(110),
      provider.setInterfaceScalePercent(120)
    ]);
    expect(
        (await SharedPreferences.getInstance()).getInt('interfaceScalePercent'),
        120);
    final ready = Completer<KeyValueStore>();
    final delayed = SettingsProvider(
        preferencesLoader: () => ready.future,
        systemFontsLoader: () async => []);
    addTearDown(delayed.dispose);
    final changed = delayed.setInterfaceScalePercent(105);
    ready.complete(PrefsKeyValueStore(await SharedPreferences.getInstance()));
    await changed;
    await tester.pumpAndSettle();
    expect(delayed.interfaceScalePercent, 105);
  });

  testWidgets(
      'phone can enlarge the entire settings page and reset to 100 percent',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final provider = settings();
    addTearDown(provider.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) => Consumer<SettingsProvider>(
              child: child,
              builder: (_, p, child) =>
                  AppScale(scale: p.interfaceScale, child: child!)),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: ThemeSettings(
            isNarrow: true,
            cardPadding: 12,
            onPickColor: () {},
            onPickFont: () {},
          ))),
        )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('interface-scale-up')));
    await tester.tap(find.byKey(const Key('interface-scale-up')));
    await tester.pumpAndSettle();
    expect(provider.interfaceScalePercent, 105);
    await provider.setInterfaceScalePercent(150);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('interface-scale-reset')));
    await tester.tap(find.byKey(const Key('interface-scale-reset')));
    await tester.pumpAndSettle();
    expect(provider.interfaceScalePercent, 100);
    expect(tester.takeException(), isNull);
  });
}
