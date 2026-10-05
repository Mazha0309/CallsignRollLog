import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/utils/windows_accessibility_guard.dart';

void main() {
  test('guards Windows 10 and Windows 11 when accessibility is not enabled',
      () {
    expect(
      shouldGuardWindowsAccessibility(
        operatingSystem: 'windows',
        environment: const {},
      ),
      isTrue,
    );
  });

  test('explicit accessibility opt-in disables the guard', () {
    expect(
      shouldGuardWindowsAccessibility(
        operatingSystem: 'windows',
        environment: const {
          'OPENLOGTOOL_ENABLE_WINDOWS_ACCESSIBILITY': '1',
        },
      ),
      isFalse,
    );
  });

  test('does not guard other platforms', () {
    expect(
      shouldGuardWindowsAccessibility(
        operatingSystem: 'linux',
        environment: const {},
      ),
      isFalse,
    );
  });

  test('startup status is omitted where the guard does not apply', () {
    if (Platform.operatingSystem != 'windows') {
      expect(windowsAccessibilityGuardStatus(), isNull);
    }
  });

  testWidgets('guard excludes descendant semantics', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const WindowsAccessibilityCrashGuard(
        enabled: true,
        child: MaterialApp(
          home: Scaffold(
            body: TextField(
              decoration: InputDecoration(labelText: 'Callsign'),
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Callsign'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('guard leaves the root semantics node without children',
      (tester) async {
    final semantics = tester.ensureSemantics();

    Widget build({required bool guarded}) => WindowsAccessibilityCrashGuard(
          enabled: guarded,
          child: const MaterialApp(
            home: Scaffold(
              body: TextField(
                decoration: InputDecoration(labelText: 'Callsign'),
              ),
            ),
          ),
        );

    await tester.pumpWidget(build(guarded: false));
    final unguarded = tester
        .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;
    expect(
      unguarded.childrenCount,
      greaterThan(0),
      reason: 'control: the unguarded tree has children the bridge would '
          'reparent (the crash path).',
    );

    await tester.pumpWidget(build(guarded: true));
    await tester.pump();
    final guarded = tester
        .binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;
    expect(
      guarded.childrenCount,
      0,
      reason: 'the engine crash loop iterates children, so an empty child '
          'list means CreateRemoveReparentedNodesUpdate is skipped.',
    );

    semantics.dispose();
  });
}
