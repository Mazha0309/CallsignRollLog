import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/account_share_dto.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/widgets/invitation_notice.dart';
import 'package:openlogtool/widgets/share_invitations_panel.dart';

AccountShareGrantDto invite(String id) => AccountShareGrantDto(
      id: id,
      grantorUserId: 'alice',
      granteeUserId: 'bob',
      grantorUsername: 'Alice',
      status: 'pending',
      canEditLogs: true,
    );

class Invitations extends AccountShareProvider {
  String scope = 'one';
  List<AccountShareGrantDto> received = [];
  final actions = <String>[];
  @override
  String? get accountScope => scope;
  @override
  List<AccountShareGrantDto> get inbox => received;
  @override
  Future<void> refresh() async {
    notifyListeners();
  }

  @override
  Future<void> respondShare(String id, String action,
      {required String? expectedScope}) async {
    expect(expectedScope, scope);
    actions.add('$id:$action');
    received = received.where((g) => g.id != id).toList();
    notifyListeners();
  }

  void receive(String id) {
    received = [...received, invite(id)];
    notifyListeners();
  }

  void switchAccount() {
    scope = 'two';
    received = [];
    notifyListeners();
  }
}

Widget app(Invitations provider, Widget child,
        {Widget Function(BuildContext)? bodyBuilder}) =>
    ChangeNotifierProvider<AccountShareProvider>.value(
      value: provider,
      child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
              builder: (context) =>
                  Scaffold(body: bodyBuilder?.call(context) ?? child))),
    );

void main() {
  testWidgets(
      'a queued invitation toast never closes another message or survives an account switch',
      (tester) async {
    final provider = Invitations();
    addTearDown(provider.dispose);
    await tester.pumpWidget(app(provider, InvitationNotice(onOpen: () {})));
    final context = tester.element(find.byType(InvitationNotice));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('已有消息'),
      duration: Duration(seconds: 1),
    ));
    await tester.pumpAndSettle();
    provider.receive('one');
    await tester.pumpAndSettle();
    expect(find.text('已有消息'), findsOneWidget);
    provider.switchAccount();
    await tester.pumpAndSettle();
    expect(find.text('已有消息'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'keyboard keeps the invitation banner from squeezing a small editor',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final provider = Invitations();
    addTearDown(provider.dispose);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(app(provider, const SizedBox.shrink(),
        bodyBuilder: (context) => Column(children: [
              InvitationNotice(
                  onOpen: () {},
                  keyboardVisible: MediaQuery.viewInsetsOf(context).bottom > 0),
              Expanded(child: TextField(focusNode: focus)),
            ])));
    await tester.tap(find.byType(TextField));
    provider.receive('one');
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    expect(find.byKey(const Key('incoming-invitations-notice')), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(
        find.byKey(const Key('incoming-invitations-notice')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'incoming share is prominent without stealing focus or repeating on refresh',
      (tester) async {
    final provider = Invitations();
    addTearDown(provider.dispose);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    var opened = 0;
    await tester.pumpWidget(app(
        provider,
        Column(children: [
          InvitationNotice(onOpen: () => opened++),
          TextField(focusNode: focus),
        ])));
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '未保存的输入');
    provider.receive('one');
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue);
    expect(find.text('未保存的输入'), findsOneWidget);
    expect(find.text('Alice 向你发来了共享邀请'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    await provider.refresh();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(
        find.byKey(const Key('incoming-invitations-notice')), findsOneWidget);
    await tester.tap(find.byKey(const Key('view-incoming-invitations')));
    expect(opened, 1);
    await tester.tap(find.byKey(const Key('dismiss-invitation-notice')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('incoming-invitations-notice')), findsNothing);
    expect(provider.inbox, hasLength(1));
    provider.receive('two');
    await tester.pumpAndSettle();
    expect(
        find.byKey(const Key('incoming-invitations-notice')), findsOneWidget);
    provider.switchAccount();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.textContaining('Alice'), findsNothing);
  });

  testWidgets(
      'inbox accepts/rejects directly on a narrow screen and clears pending items',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = Invitations()..receive('one');
    addTearDown(provider.dispose);
    await tester.pumpWidget(app(
        provider, const SingleChildScrollView(child: ShareInvitationsPanel())));
    await tester.pumpAndSettle();
    expect(find.text('收到的共享邀请 (1)'), findsOneWidget);
    expect(find.textContaining('允许新增、修改记录'), findsOneWidget);
    await tester.tap(find.byKey(const Key('accept-share-one')));
    await tester.pumpAndSettle();
    expect(provider.actions, ['one:accept']);
    expect(find.text('暂无待处理的共享邀请'), findsOneWidget);
    expect(find.textContaining('历史会话 → 共享'), findsOneWidget);
    provider.receive('two');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reject-share-two')));
    await tester.pumpAndSettle();
    expect(provider.actions.last, 'two:reject');
    expect(tester.takeException(), isNull);
  });
}
