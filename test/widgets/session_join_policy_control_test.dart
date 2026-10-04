import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/social_dto.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/theme/app_theme.dart';
import 'package:openlogtool/widgets/session_join_policy_control.dart';

void main() {
  testWidgets('legacy servers only receive the visibility field',
      (tester) async {
    final calls = <Map<String, Object?>>[];
    await _pump(tester, calls: calls, supportsDirectJoin: false);
    await _select(tester, 'session-join-mode', 'Friends request approval');
    expect(calls, [
      {'visibility': 'friends'}
    ]);
    expect(find.text('Friends join directly'), findsNothing);
  });

  testWidgets('enabling direct joining requires consent with the default role',
      (tester) async {
    final calls = <Map<String, Object?>>[];
    await _pump(tester, calls: calls);
    await _select(tester, 'session-join-mode', 'Friends join directly');
    expect(calls, isEmpty);
    expect(find.byKey(const Key('session-direct-join-confirmation')),
        findsOneWidget);
    expect(find.textContaining('View only'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(
        tester
            .widget<DropdownButton<String>>(
                find.byKey(const Key('session-join-mode')))
            .value,
        'private');
    await _select(tester, 'session-join-mode', 'Friends join directly');
    await tester.tap(find.byKey(const Key('confirm-session-direct-join')));
    await tester.pumpAndSettle();
    expect(calls, [
      {'visibility': 'friends', 'joinPolicy': 'direct', 'defaultRole': 'viewer'}
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('increasing the default role to editor requires a second consent',
      (tester) async {
    final calls = <Map<String, Object?>>[];
    await _pump(tester,
        calls: calls,
        session: _session(visibility: 'friends', joinPolicy: 'direct'));
    await _select(tester, 'session-direct-join-role', 'Record together');
    expect(calls, isEmpty);
    expect(find.byKey(const Key('session-direct-join-confirmation')),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-session-direct-join')));
    await tester.pumpAndSettle();
    expect(calls.single['defaultRole'], 'editor');
  });

  testWidgets('reducing access needs no broad-access confirmation',
      (tester) async {
    final calls = <Map<String, Object?>>[];
    await _pump(tester,
        calls: calls,
        session: _session(
            visibility: 'friends', joinPolicy: 'direct', role: 'editor'));
    await _select(tester, 'session-direct-join-role', 'View only');
    expect(calls.single['defaultRole'], 'viewer');
    expect(find.byKey(const Key('session-direct-join-confirmation')),
        findsNothing);
  });

  testWidgets('account switches invalidate consent and hide the previous title',
      (tester) async {
    final calls = <Map<String, Object?>>[];
    final server = _Server();
    await _pump(tester, calls: calls, server: server);
    await _select(tester, 'session-join-mode', 'Friends join directly');
    server.switchAccount();
    await tester.pumpAndSettle();
    expect(find.text('Private net'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.byKey(const Key('confirm-session-direct-join')))
            .onPressed,
        isNull);
    expect(calls, isEmpty);
  });

  testWidgets('switching the target session cannot submit the old consent',
      (tester) async {
    final calls = <Map<String, Object?>>[];
    final target = ValueNotifier(_session());
    await _pump(tester, calls: calls, target: target);
    await _select(tester, 'session-join-mode', 'Friends join directly');
    target.value = _session(id: 'other-session');
    await tester.pumpAndSettle();
    final confirm = find.byKey(const Key('confirm-session-direct-join'));
    if (tester.widget<FilledButton>(confirm).onPressed != null) {
      await tester.tap(confirm);
      await tester.pumpAndSettle();
    }
    expect(calls, isEmpty);
  });

  testWidgets('pending changes disable further submissions', (tester) async {
    final calls = <Map<String, Object?>>[];
    final pending = Completer<void>();
    await _pump(tester, calls: calls, onChanged: (_) => pending.future);
    await _select(tester, 'session-join-mode', 'Friends request approval');
    expect(calls.length, 1);
    expect(
        tester
            .widget<DropdownButton<String>>(
                find.byKey(const Key('session-join-mode')))
            .onChanged,
        isNull);
    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('small dark English screens keep the policy and consent readable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <Map<String, Object?>>[];
    await _pump(tester,
        calls: calls,
        session: _session(visibility: 'friends', joinPolicy: 'direct'));
    expect(tester.takeException(), isNull);
    await _select(tester, 'session-direct-join-role', 'Record together');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _select(WidgetTester tester, String key, String label) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

FriendSession _session(
        {String id = 'session-one',
        String visibility = 'private',
        String joinPolicy = 'approval',
        String role = 'viewer'}) =>
    FriendSession.fromJson({
      'sessionId': id,
      'title': 'Private net',
      'ownerId': 'owner',
      'ownerUsername': 'BG5CRL',
      'visibility': visibility,
      'joinPolicy': joinPolicy,
      'defaultRole': role,
    });

Future<void> _pump(
  WidgetTester tester, {
  required List<Map<String, Object?>> calls,
  bool supportsDirectJoin = true,
  FriendSession? session,
  _Server? server,
  ValueNotifier<FriendSession>? target,
  Future<void> Function(Map<String, Object?>)? onChanged,
}) async {
  final account = server ?? _Server();
  final selection = target ?? ValueNotifier(session ?? _session());
  addTearDown(account.dispose);
  addTearDown(selection.dispose);
  await tester.pumpWidget(ChangeNotifierProvider<ServerProvider>.value(
    value: account,
    child: MaterialApp(
      theme: buildAppTheme(brightness: Brightness.dark, seedColor: Colors.teal),
      locale: const Locale('en', 'US'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder(
          valueListenable: selection,
          builder: (context, value, _) => SessionJoinPolicyControl(
            session: value,
            disabled: false,
            supportsDirectJoin: supportsDirectJoin,
            onChanged: (body) async {
              calls.add(body);
              await onChanged?.call(body);
            },
          ),
        ),
      )),
    ),
  ));
  await tester.pumpAndSettle();
}

class _Server extends ServerProvider {
  _Server() : super(autoLoadSettings: false);
  String id = 'owner';
  @override
  bool get isLoggedIn => true;
  @override
  String get serverUrl => 'https://example.test';
  @override
  String get accountId => id;
  void switchAccount() {
    id = 'other-owner';
    notifyListeners();
  }
}
