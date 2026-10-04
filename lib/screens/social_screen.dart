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
import 'package:openlogtool/widgets/session_friend_actions.dart';

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
    var draftName = '';
    final name = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
              title: Text(c.l10n.socialAddFriend),
              content: TextField(
                  key: const Key('friend-username'),
                  onChanged: (value) => draftName = value,
                  autofocus: true,
                  maxLength: 64,
                  decoration: InputDecoration(labelText: c.l10n.socialUsername),
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) Navigator.pop(c, value.trim());
                  }),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: Text(c.l10n.cancel)),
                FilledButton(
                    onPressed: () {
                      if (draftName.trim().isNotEmpty) {
                        Navigator.pop(c, draftName.trim());
                      }
                    },
                    child: Text(c.l10n.socialSend))
              ],
            ));
    if (!mounted || name == null) return;
    final provider = context.read<AccountShareProvider>();
    final ok = await _run(() =>
        provider.mutateSocial('POST', '/friend-requests', {'username': name}));
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.socialPending)));
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
    final shouldOpen = action == 'accept' && request.kind == 'invitation';
    final success = await _run(() async {
      await provider.mutateSocial('POST',
          '/${request.sessionId == null ? 'friend-requests' : 'session-requests'}/${Uri.encodeComponent(request.id)}/$action');
      if (shouldOpen && mounted) {
        await collaboration.openJoinedSession(request.sessionId!);
      }
    });
    if (success && shouldOpen && mounted) {
      Navigator.pop(context);
      widget.onSessionOpened?.call();
    }
  }

  Future<void> _open(String id, {bool manage = false}) async {
    final collaboration = context.read<CollaborationProvider>();
    final ok = await _run(() => collaboration.openJoinedSession(id));
    if (!ok || !mounted) return;
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
    final provider = context.read<AccountShareProvider>();
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
                    _list([
                      Text(l.socialIntro),
                      const SizedBox(height: 16),
                      Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                              key: const Key('social-add-friend'),
                              onPressed: disabled ? null : _addFriend,
                              icon: const Icon(Icons.person_add_outlined),
                              label: Text(l.socialAddFriend))),
                      const SizedBox(height: 16),
                      if (data.friends.isEmpty) Text(l.socialNoFriends),
                      for (final friend in data.friends)
                        Card(
                            child: ListTile(
                                leading: const CircleAvatar(
                                    child: Icon(Icons.person_outline)),
                                title: Text(friend.username),
                                trailing: PopupMenuButton<String>(
                                    enabled: !disabled,
                                    onSelected: (v) =>
                                        _remove(friend, v == 'block'),
                                    itemBuilder: (_) => [
                                          PopupMenuItem(
                                              value: 'remove',
                                              child: Text(l.socialRemove)),
                                          PopupMenuItem(
                                              value: 'block',
                                              child: Text(l.socialBlock)),
                                        ]))),
                      if (data.blocks.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(l.socialBlocked),
                        for (final person in data.blocks)
                          ListTile(
                              title: Text(person.username),
                              trailing: TextButton(
                                  onPressed: disabled
                                      ? null
                                      : () => _run(() => provider.mutateSocial(
                                          'DELETE',
                                          '/blocks/${Uri.encodeComponent(person.username)}')),
                                  child: Text(l.socialUnblock)))
                      ],
                    ]),
                    _list([
                      if (data.friendRequests.isEmpty &&
                          data.sessionRequests.isEmpty)
                        Text(l.socialNoMessages),
                      for (final request in [
                        ...data.friendRequests,
                        ...data.sessionRequests
                      ])
                        _requestCard(request, provider, disabled),
                    ]),
                    _list([
                      Text(l.socialVisibilityHint),
                      const SizedBox(height: 16),
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
                      if (data.sessions.isEmpty) Text(l.socialNoSessions),
                      for (final session in data.sessions)
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(session.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      Text(session.ownerUsername),
                                      const SizedBox(height: 8),
                                      if (session.ownerId ==
                                          provider.accountId) ...[
                                        SwitchListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(l.socialDiscoverable),
                                            value:
                                                session.visibility == 'friends',
                                            onChanged: disabled
                                                ? null
                                                : (value) => _run(() =>
                                                    provider.mutateSocial('PUT',
                                                        '/sessions/${Uri.encodeComponent(session.sessionId)}', {
                                                      'visibility': value
                                                          ? 'friends'
                                                          : 'private'
                                                    }))),
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
                                      ] else
                                        FilledButton.tonal(
                                            onPressed: disabled ||
                                                    data.sessionRequests.any(
                                                        (r) =>
                                                            r.sessionId ==
                                                                session
                                                                    .sessionId &&
                                                            r.status ==
                                                                'pending')
                                                ? null
                                                : () => _invite(session,
                                                    apply: true),
                                            child: Text(l.socialApply)),
                                    ]))),
                    ]),
                  ])),
                ]),
        ));
  }

  Widget _list(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children))),
      ]);

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
    return Card(
        key: Key('social-request-${r.id}'),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '$label · ${incoming ? r.senderUsername : r.recipientUsername}',
                  style: Theme.of(context).textTheme.titleMedium),
              Text(incoming ? l.socialReceived : l.socialSent),
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
                            Text(l.socialPending),
                            TextButton(
                                onPressed: disabled
                                    ? null
                                    : () => _respond(r, 'cancel'),
                                child: Text(l.cancel))
                          ])
              else if (r.sessionId != null && subject == provider.accountId)
                FilledButton.tonal(
                    onPressed: disabled ? null : () => _open(r.sessionId!),
                    child: Text(l.socialOpen))
              else
                Text(l.socialAccepted),
            ])));
  }
}
