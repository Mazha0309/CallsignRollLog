import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/widgets/app_section_tabs.dart';

void main() {
  for (final width in [320.0, 900.0, 1600.0]) {
    testWidgets('page tabs share geometry at width $width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            const DefaultTabController(
              length: 3,
              child: AppSectionTabBar(tabs: [
                AppSectionTab(
                    icon: Icon(Icons.people_outline), label: Text('A')),
                AppSectionTab(icon: Icon(Icons.mail_outline), label: Text('B')),
                AppSectionTab(
                    icon: Icon(Icons.forum_outlined), label: Text('C')),
              ]),
            ),
            for (final count in [3, 4])
              AppSectionTabs<int>(
                segments: [
                  for (var index = 0; index < count; index++)
                    ButtonSegment(
                      value: index,
                      icon: const Icon(Icons.folder_outlined),
                      label: Text('$index'),
                    ),
                ],
                selected: const {0},
                onSelectionChanged: (_) {},
              ),
          ]),
        ),
      ));
      final bars = find.byType(TabBar);
      expect(bars, findsNWidgets(3));
      final reference = tester.getRect(bars.first);
      for (final bar in bars.evaluate()) {
        final finder = find.byWidget(bar.widget);
        final rect = tester.getRect(finder);
        expect(rect.left, reference.left);
        expect(rect.size, reference.size);
        expect(rect.width, lessThanOrEqualTo(1120));
        final tabBar = bar.widget as TabBar;
        expect(tabBar.isScrollable, isTrue);
        expect(tabBar.indicatorSize, TabBarIndicatorSize.tab);
        final tabs = find.descendant(of: finder, matching: find.byType(Tab));
        expect(tester.getSize(tabs.first).width, 128);
        final spacing =
            tester.getTopLeft(tabs.at(1)).dx - tester.getTopLeft(tabs.first).dx;
        expect(spacing, 160);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shared bar keeps external controller and swipe navigation',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            bottom: const AppSectionTabBar(tabs: [
              AppSectionTab(label: Text('First')),
              AppSectionTab(label: Text('Second')),
            ]),
          ),
          body: const TabBarView(children: [
            Center(child: Text('First page')),
            Center(child: Text('Second page')),
          ]),
        ),
      ),
    ));
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    final controller =
        DefaultTabController.of(tester.element(find.byType(TabBar)));
    expect(controller.index, 1);
    expect(find.text('Second page').hitTestable(), findsOneWidget);
    await tester.drag(find.byType(TabBarView), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(controller.index, 0);
    expect(find.text('First page').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long scaled labels scroll and remain selectable on a phone',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
        return Column(children: [
          AppSectionTabs<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Records')),
              ButtonSegment(value: 1, label: Text('Lookup libraries')),
              ButtonSegment(value: 2, label: Text('Local database')),
              ButtonSegment(value: 3, label: Text('Sync conflicts (12)')),
            ],
            selected: {selected},
            onSelectionChanged: (value) =>
                setState(() => selected = value.single),
          ),
        ]);
      })),
    ));
    final last = find.text('Sync conflicts (12)');
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(selected, 3);
    expect(tester.takeException(), isNull);
  });
}
