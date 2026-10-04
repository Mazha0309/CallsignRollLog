import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/social_dto.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/screens/collaboration_screen.dart';
import 'package:openlogtool/services/server_api.dart';
import 'package:openlogtool/theme/app_theme.dart';
import 'package:openlogtool/widgets/friend_search_dialog.dart';
import 'package:openlogtool/widgets/session_friend_actions.dart';
import 'package:openlogtool/widgets/session_join_policy_control.dart';
import 'package:openlogtool/widgets/settings/settings_ui.dart';
import 'package:openlogtool/widgets/session_sharing_dialog.dart';
import 'package:openlogtool/widgets/share_invitations_panel.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key, this.onSessionOpened, this.initialTab = 0})
      : assert(initialTab >= 0 && initialTab < 3);
  final VoidCallback? onSessionOpened;
  final int initialTab;
  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  bool _working = false;
  FriendSession? _pendingOpen;
  String? _pendingOpenScope;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AccountShareProvider>().refresh();
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_working) return false;
    setState(() => _working = true);
    try {
      await action();
      return true;
    } catch (error) {
      if (mounted) {
        final l = context.l10n;
        final text = error is ServerApiException
            ? switch (error.code) {
                'USER_NOT_FOUND' => l.socialErrorUser,
                'FRIEND_REQUIRED' => l.socialErrorFriends,
                'FRIEND_SELF' => l.socialErrorSelf,
                'FRIEND_BLOCKED' => l.socialErrorBlocked,
                'MEMBERSHIP_REVOKED' => l.socialDirectJoinRemoved,
                'REQUEST_CLOSED' || 'ALREADY_MEMBER' => l.socialErrorClosed,
                _ => l.operationFailed(error.message),
              }
            : l.operationFailed('$error');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
      }
      return false;
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _addFriend() async {
    await showFriendSearchDialog(context);
  }

  Future<void> _joinDirectly(FriendSession session) async {
    final social = context.read<AccountShareProvider>();
    final collaboration = context.read<CollaborationProvider>();
    final scope = social.accountScope;
    final route = ModalRoute.of(context);
    final success = await _run(() async {
      await social.mutateSocial(
          'POST', '/sessions/${Uri.encodeComponent(session.sessionId)}/join');
      if (!mounted ||
          social.accountScope != scope ||
          route?.isCurrent != true) {
        return;
      }
      setState(() {
        _pendingOpen = session;
        _pendingOpenScope = scope;
      });
      await collaboration.openJoinedSession(session.sessionId);
    });
    if (success &&
        mounted &&
        social.accountScope == scope &&
        route?.isCurrent == true) {
      Navigator.pop(context);
      widget.onSessionOpened?.call();
    }
  }

  Future<void> _invite(FriendSession session, {bool apply = false}) async {
    final provider = context.read<AccountShareProvider>();
    if (!apply) {
      final result = await showSessionInvitationDialog(context,
          sessionId: session.sessionId, sessionTitle: session.title);
      if (!mounted) return;
      if (result == SessionInvitationResult.friends) await _addFriend();
      if (result == SessionInvitationResult.sent && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.socialPending)));
      }
      return;
    }
    var role = 'editor';
    final server = context.read<ServerProvider>();
    final scope =
        '${server.contextRevision}|${server.serverUrl}|${server.accountId}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
          builder: (c, setDialogState) => AlertDialog(
                title: Text(c.l10n.socialApply),
                content: SizedBox(
                  width: 380,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(session.title),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(
                            value: 'editor', child: Text(c.l10n.socialEdit)),
                        DropdownMenuItem(
                            value: 'viewer', child: Text(c.l10n.socialView)),
                      ],
                      onChanged: (v) => setDialogState(() => role = v!),
                    ),
                  ]),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: Text(c.l10n.cancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(c.l10n.socialApply)),
                ],
              )),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      if (scope !=
          '${server.contextRevision}|${server.serverUrl}|${server.accountId}') {
        throw StateError(context.l10n.hubContextChanged);
      }
      await provider.mutateSocial(
          'POST',
          '/sessions/${Uri.encodeComponent(session.sessionId)}/applications',
          {'role': role});
    });
  }

  Future<void> _respond(SocialRequest request, String action) async {
    final provider = context.read<AccountShareProvider>();
    final collaboration = context.read<CollaborationProvider>();
    final scope = provider.accountScope;
    final route = ModalRoute.of(context);
    final shouldOpen = action == 'accept' && request.kind == 'invitation';
    final success = await _run(() async {
      await provider.mutateSocial('POST',
          '/${request.sessionId == null ? 'friend-requests' : 'session-requests'}/${Uri.encodeComponent(request.id)}/$action');
      if (shouldOpen &&
          mounted &&
          provider.accountScope == scope &&
          route?.isCurrent == true) {
        await collaboration.openJoinedSession(request.sessionId!);
      }
    });
    if (success &&
        shouldOpen &&
        mounted &&
        provider.accountScope == scope &&
        route?.isCurrent == true) {
      Navigator.pop(context);
      widget.onSessionOpened?.call();
    }
  }

  Future<void> _open(String id, {bool manage = false}) async {
    final collaboration = context.read<CollaborationProvider>();
    final social = context.read<AccountShareProvider>();
    final scope = social.accountScope;
    final route = ModalRoute.of(context);
    final ok = await _run(() => collaboration.openJoinedSession(id));
    if (!ok ||
        !mounted ||
        social.accountScope != scope ||
        route?.isCurrent != true) {
      return;
    }
    if (manage) {
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) =>
                  const CollaborationScreen(focusParticipants: true)));
    } else {
      Navigator.pop(context);
      widget.onSessionOpened?.call();
    }
  }

  Future<void> _remove(SocialPerson friend, bool block) async {
    final provider = context.read<AccountShareProvider>();
    final scope = provider.accountScope;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: Text(
                  '${block ? c.l10n.socialBlock : c.l10n.socialRemove} ${friend.username}'),
              content: Text(c.l10n.socialRemoveHint),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: Text(c.l10n.cancel)),
                TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(c.l10n.confirm))
              ],
            ));
    if (confirmed != true || !mounted) return;
    if (provider.accountScope != scope) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.hubContextChanged)));
      return;
    }
    await _run(() => provider.mutateSocial(
        block ? 'PUT' : 'DELETE',
        block
            ? '/blocks/${Uri.encodeComponent(friend.username)}'
            : '/friends/${Uri.encodeComponent(friend.userId)}'));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountShareProvider>();
    final server = context.watch<ServerProvider>();
    final l = context.l10n;
    final data = provider.social;
    if (_pendingOpenScope != provider.accountScope) _pendingOpen = null;
    final disabled = _working || provider.busy;
    return DefaultTabController(
        length: 3,
        initialIndex: widget.initialTab,
        child: Scaffold(
          appBar: AppBar(
              title: Text(l.socialTitle),
              actions: [
                IconButton(
                    tooltip: l.refresh,
                    onPressed:
                        provider.loading || disabled ? null : provider.refresh,
                    icon: const Icon(Icons.refresh)),
              ],
              bottom: TabBar(tabs: [
                Tab(text: l.socialFriends),
                Tab(
                    text:
                        '${l.socialMessages}${provider.pendingInboundCount > 0 ? ' (${provider.pendingInboundCount})' : ''}'),
                Tab(text: l.socialSessions)
              ])),
          body: !provider.supportsFriends
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(server.isLoggedIn
                          ? l.socialUpgrade
                          : l.socialConnect)))
              : Column(children: [
                  if (provider.loading || disabled)
                    const LinearProgressIndicator(),
                  if (provider.lastError != null)
                    MaterialBanner(content: Text(l.socialLoadFailed), actions: [
                      TextButton(
                          onPressed: provider.refresh, child: Text(l.retry))
                    ]),
                  Expanded(
                      child: TabBarView(children: [
                    _list('friends', [
                      SettingsSectionCard(
                        icon: Icons.people_outline,
                        title: l.socialFriends,
                        description: l.socialIntro,
                        headerTrailing: OutlinedButton.icon(
                            key: const Key('social-add-friend'),
                            onPressed: disabled ? null : _addFriend,
                            icon: const Icon(Icons.person_search_outlined),
                            label: Text(l.socialAddFriend)),
                        child: data.friends.isEmpty
                            ? AppNotice(
                                message: l.socialNoFriends,
                                icon: Icons.person_add_outlined)
                            : AppTileGroup(children: [
                                for (final friend in data.friends)
                                  ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const AppIconBadge(
                                          icon: Icons.person_outline,
                                          size: AppIconBadgeSize.action),
                                      title: Text(friend.username),
                                      trailing: PopupMenuButton<String>(
                                          enabled: !disabled,
                                          onSelected: (v) =>
                                              _remove(friend, v == 'block'),
                                          itemBuilder: (_) => [
                                                PopupMenuItem(
                                                    value: 'remove',
                                                    child:
                                                        Text(l.socialRemove)),
                                                PopupMenuItem(
                                                    value: 'block',
                                                    child: Text(l.socialBlock)),
                                              ])),
                              ]),
                      ),
                      if (data.blocks.isNotEmpty) ...[
                        const SizedBox(height: AppSpace.md),
                        SettingsSectionCard(
                            icon: Icons.block_outlined,
                            title: l.socialBlocked,
                            tone: AppTone.neutral,
                            child: AppTileGroup(children: [
                              for (final person in data.blocks)
                                ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(person.username),
                                    trailing: TextButton(
                                        onPressed: disabled
                                            ? null
                                            : () => _run(() =>
                                                provider.mutateSocial('DELETE',
                                                    '/blocks/${Uri.encodeComponent(person.username)}')),
                                        child: Text(l.socialUnblock))),
                            ])),
                      ],
                    ]),
                    _list('messages', [
                      const ShareInvitationsPanel(showEmpty: false),
                      if (data.friendRequests.isEmpty &&
                          data.sessionRequests.isEmpty &&
                          provider.inbox.isEmpty)
                        AppNotice(
                            message: l.socialNoMessages,
                            icon: Icons.inbox_outlined),
                      for (final request in [
                        ...data.friendRequests,
                        ...data.sessionRequests
                      ])
                        _requestCard(request, provider, disabled),
                      if (provider.supportsBatchSharing)
                        Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                                onPressed: () =>
                                    showSessionSharingDialog(context),
                                icon: const Icon(Icons.share_outlined),
                                label: Text(l.shareSessionsTitle))),
                    ]),
                    _list('sessions', [
                      AppNotice(
                          message: l.socialVisibilityHint,
                          icon: Icons.lock_outline),
                      const SizedBox(height: AppSpace.md),
                      if (_pendingOpen case final joined?) ...[
                        SettingsSectionCard(
                          key: const Key('social-joined-session-retry'),
                          icon: Icons.check_circle_outline,
                          title: joined.title,
                          description: l.socialAccepted,
                          child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: FilledButton.tonal(
                                  onPressed: disabled
                                      ? null
                                      : () => _open(joined.sessionId),
                                  child: Text(l.socialOpen))),
                        ),
                        const SizedBox(height: AppSpace.md),
                      ],
                      if (context
                                  .watch<SessionProvider>()
                                  .currentSession
                                  ?.status ==
                              'active' &&
                          context.watch<CollaborationProvider>().binding ==
                              null)
                        FilledButton.tonalIcon(
                            onPressed: disabled
                                ? null
                                : () => _run(() async {
                                      await confirmAndPublishCurrentSession(
                                          context);
                                    }),
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: Text(l.socialPublish)),
                      if (data.sessions.isEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: AppSpace.sm),
                            child: Text(l.socialNoSessions)),
                      for (final session in data.sessions)
                        Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.md),
                            child: SettingsSectionCard(
                                icon: Icons.groups_outlined,
                                title: session.title,
                                description: session.ownerUsername,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (session.ownerId ==
                                          provider.accountId) ...[
                                        SessionJoinPolicyControl(
                                            session: session,
                                            disabled: disabled,
                                            supportsDirectJoin:
                                                provider.supportsDirectJoin,
                                            onChanged: (body) async {
                                              await _run(() =>
                                                  provider.mutateSocial(
                                                      'PUT',
                                                      '/sessions/${Uri.encodeComponent(session.sessionId)}',
                                                      body));
                                            }),
                                        const SizedBox(height: AppSpace.sm),
                                        Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              FilledButton.tonal(
                                                  onPressed: disabled
                                                      ? null
                                                      : () => _invite(session),
                                                  child: Text(l.socialInvite)),
                                              TextButton(
                                                  onPressed: disabled
                                                      ? null
                                                      : () => _open(
                                                          session.sessionId,
                                                          manage: true),
                                                  child: Text(l.socialManage)),
                                            ]),
                                      ] else ...[
                                        Wrap(
                                            spacing: AppSpace.xs,
                                            runSpacing: AppSpace.xs,
                                            children: [
                                              AppStatusPill(
                                                  label: session.joinPolicy ==
                                                              'direct' &&
                                                          provider
                                                              .supportsDirectJoin
                                                      ? l.socialJoinDirect
                                                      : l.socialJoinApproval,
                                                  icon:
                                                      Icons.group_add_outlined),
                                              if (session.joinPolicy ==
                                                      'direct' &&
                                                  provider.supportsDirectJoin)
                                                AppStatusPill(
                                                    label:
                                                        session.defaultRole ==
                                                                'editor'
                                                            ? l.socialEdit
                                                            : l.socialView),
                                            ]),
                                        const SizedBox(height: AppSpace.sm),
                                        Align(
                                            alignment: AlignmentDirectional
                                                .centerStart,
                                            child: FilledButton.tonal(
                                                onPressed: disabled ||
                                                        (session.joinPolicy !=
                                                                'direct' &&
                                                            data.sessionRequests.any((r) =>
                                                                r.sessionId ==
                                                                    session
                                                                        .sessionId &&
                                                                r.status ==
                                                                    'pending'))
                                                    ? null
                                                    : () => session.joinPolicy ==
                                                                'direct' &&
                                                            provider.supportsDirectJoin
                                                        ? _joinDirectly(session)
                                                        : _invite(session, apply: true),
                                                child: Text(session.joinPolicy == 'direct' && provider.supportsDirectJoin ? l.socialDirectJoin : l.socialApply))),
                                      ],
                                    ]))),
                    ]),
                  ])),
                ]),
        ));
  }

  Widget _list(String tab, List<Widget> children) => AppPageFrame(
      scrollKey: PageStorageKey('social-$tab'),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children));

  Widget _requestCard(
      SocialRequest r, AccountShareProvider provider, bool disabled) {
    final l = context.l10n;
    final incoming = r.recipientId == provider.accountId;
    final label = r.kind == null
        ? l.socialFriendRequest
        : r.kind == 'invitation'
            ? l.socialInvitation
            : l.socialApplication;
    final subject = r.kind == 'invitation' ? r.recipientId : r.senderId;
    return Padding(
        key: Key('social-request-${r.id}'),
        padding: const EdgeInsets.only(bottom: AppSpace.md),
        child: SettingsSectionCard(
            icon:
                r.kind == null ? Icons.person_add_outlined : Icons.mail_outline,
            title: incoming ? r.senderUsername : r.recipientUsername,
            description:
                '$label · ${incoming ? l.socialReceived : l.socialSent}',
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (r.sessionTitle != null)
                Text(
                    '${r.sessionTitle} · ${r.role == 'editor' ? l.socialEdit : l.socialView}'),
              const SizedBox(height: 8),
              if (r.status == 'pending')
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: incoming
                        ? [
                            FilledButton(
                                onPressed: disabled
                                    ? null
                                    : () => _respond(r, 'accept'),
                                child: Text(l.socialAccept)),
                            TextButton(
                                onPressed: disabled
                                    ? null
                                    : () => _respond(r, 'reject'),
                                child: Text(l.socialReject)),
                          ]
                        : [
                            AppStatusPill(
                                label: l.socialRequestSent,
                                icon: Icons.schedule),
                            TextButton(
                                onPressed: disabled
                                    ? null
                                    : () => _respond(r, 'cancel'),
                                child: Text(l.cancel))
                          ])
              else if (r.status == 'accepted' &&
                  r.sessionId != null &&
                  subject == provider.accountId)
                FilledButton.tonal(
                    onPressed: disabled ? null : () => _open(r.sessionId!),
                    child: Text(l.socialOpen))
              else
                AppStatusPill(
                    label: r.status == 'accepted'
                        ? l.socialAccepted
                        : l.socialRequestClosed),
            ])));
  }
}
