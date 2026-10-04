import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/log_entry.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/utils/dictionary_usage_store.dart';
import 'package:openlogtool/widgets/callsign_history_field.dart';
import 'package:openlogtool/widgets/dictionary_autocomplete_field.dart';
import 'package:openlogtool/widgets/record_editor_dialog.dart';
import 'package:openlogtool/widgets/scroll_safe_unfocus.dart';

void main() {
  for (final kind in ['dictionary', 'callsign']) {
    testWidgets(
        '$kind field keeps its draft and keyboard during parent scrolling',
        (tester) async {
      tester.view.physicalSize = const Size(375, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final focus = FocusNode();
      final controllers = List.generate(6, (_) => TextEditingController());
      final scroll = ScrollController();
      addTearDown(() {
        focus.dispose();
        scroll.dispose();
        for (final controller in controllers) {
          controller.dispose();
        }
      });
      final field = kind == 'dictionary'
          ? DictionaryAutocompleteField(
              controller: controllers[0],
              focusNode: focus,
              label: 'Radio',
              hintText: 'Radio',
              options: const [],
              usageStore: DictionaryUsageStore.memory())
          : CallsignHistoryField(
              callsignController: controllers[0],
              deviceController: controllers[1],
              antennaController: controllers[2],
              qthController: controllers[3],
              powerController: controllers[4],
              heightController: controllers[5],
              focusNode: focus,
              label: 'Callsign',
              hintText: 'Callsign',
              historyLoader: (_, __) async => []);
      await tester.pumpWidget(_app(SingleChildScrollView(
        controller: scroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
        child: Column(children: [
          field,
          const SizedBox(height: 1200, width: double.infinity)
        ]),
      )));
      await tester.enterText(find.byType(TextFormField), 'BG5CRL');
      await tester.pumpAndSettle();
      await tester.dragFrom(const Offset(12, 280), const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(focus.hasFocus, isTrue);
      expect(controllers[0].text, 'BG5CRL');
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  for (final fieldName in ['callsign', 'qth']) {
    testWidgets(
        'record editor preserves $fieldName focus when its content scrolls',
        (tester) async {
      tester.view.physicalSize = const Size(375, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => DictionaryProvider(autoload: false),
        child: _app(RecordEditorDialog(
            log: LogEntry(
          id: 'log-one',
          sessionId: 'session-one',
          time: '12:00',
          controller: 'BG5CRL',
          callsign: 'BA1ABC',
          report: '59',
          qth: 'Local QTH',
          device: '',
          power: '',
          antenna: '',
          height: '',
        ))),
      ));
      await tester.pumpAndSettle();
      final target = find.byKey(Key('record-editor-field-$fieldName'));
      await tester.ensureVisible(target);
      final input =
          find.descendant(of: target, matching: find.byType(EditableText));
      final editable = tester.widget<EditableText>(input);
      await tester.enterText(input, 'Draft value');
      await tester.pumpAndSettle();
      final scrollFinder =
          find.ancestor(of: target, matching: find.byType(Scrollable)).first;
      final scroll = tester.state<ScrollableState>(scrollFinder);
      final bounds = tester.getRect(scrollFinder);
      final before = scroll.position.pixels;
      final scrollBack = before > 0;
      await tester.dragFrom(
          Offset(
              bounds.left + 2, scrollBack ? bounds.top + 4 : bounds.bottom - 4),
          Offset(0, scrollBack ? 110 : -110));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels,
          scrollBack ? lessThan(before) : greaterThan(before));
      expect(editable.focusNode.hasFocus, isTrue);
      expect(editable.controller.text, 'Draft value');
      expect(tester.testTextInput.isVisible, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'outside taps dismiss only on release; drags back to origin do not',
      (tester) async {
    final focus = FocusNode();
    final controller = TextEditingController();
    final outsideTap = ScrollSafeUnfocus();
    addTearDown(() {
      outsideTap.dispose();
      focus.dispose();
      controller.dispose();
    });
    await tester.pumpWidget(_app(Column(children: [
      TextField(
          focusNode: focus,
          controller: controller,
          onTapOutside: (event) => outsideTap.onTapOutside(event, focus)),
      const Expanded(child: ColoredBox(color: Colors.transparent)),
    ])));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final drag = await tester.startGesture(const Offset(20, 300),
        kind: PointerDeviceKind.touch);
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await drag.moveBy(const Offset(0, -100));
    await drag.moveBy(const Offset(0, 100));
    await drag.up();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    final tap = await tester.startGesture(const Offset(20, 300),
        kind: PointerDeviceKind.touch);
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tap.up();
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  });

  testWidgets(
      'cancelled or disposed outside gestures do not dismiss a later input',
      (tester) async {
    final focus = FocusNode();
    final outsideTap = ScrollSafeUnfocus();
    addTearDown(() {
      outsideTap.dispose();
      focus.dispose();
    });
    await tester.pumpWidget(_app(Column(children: [
      TextField(
          focusNode: focus,
          onTapOutside: (event) => outsideTap.onTapOutside(event, focus)),
      const Expanded(child: ColoredBox(color: Colors.transparent)),
    ])));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final cancel = await tester.startGesture(const Offset(20, 300));
    await cancel.cancel();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    final pending = await tester.startGesture(const Offset(20, 300));
    outsideTap.dispose();
    await pending.up();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('en', 'US'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
