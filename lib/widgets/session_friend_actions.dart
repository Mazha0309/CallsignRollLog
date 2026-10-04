import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/services/server_api.dart';

String _serverScope(ServerProvider server) =>
    '${server.contextRevision}|${server.serverUrl}|${server.accountId}';

/// Local recording remains local until the user explicitly confirms upload.
Future<bool> confirmAndPublishCurrentSession(BuildContext context) async {
  final sessions = context.read<SessionProvider>();
  final server = context.read<ServerProvider>();
  final collaboration = context.read<CollaborationProvider>();
  final session = sessions.currentSession;
  if (session == null || session.status != 'active' || !server.isLoggedIn) {
    return false;
  }
  final scope = _serverScope(server);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      key: const Key('confirm-session-upload-dialog'),
      title: Text(c.l10n.hubEnableCollaboration),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(session.title),
            const SizedBox(height: 12),
            Text(c.l10n.hubUploadExplanation),
            const SizedBox(height: 12),
            SelectableText(server.serverUrl),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(c.l10n.cancel)),
        FilledButton(
          key: const Key('confirm-session-upload'),
          onPressed: () => Navigator.pop(c, true),
          child: Text(c.l10n.hubConfirmUpload),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  if (_serverScope(server) != scope ||
      sessions.currentSessionId != session.sessionId) {
    throw StateError(context.l10n.hubContextChanged);
  }
  await collaboration.publishCurrentSession();
  if (!context.mounted) return false;
  if (_serverScope(server) != scope ||
      sessions.currentSessionId != session.sessionId) {
    throw StateError(context.l10n.hubContextChanged);
  }
  await context.read<AccountShareProvider>().refresh();
  if (!context.mounted) return false;
  if (_serverScope(server) != scope ||
      sessions.currentSessionId != session.sessionId) {
    throw StateError(context.l10n.hubContextChanged);
  }
  return true;
}

enum SessionInvitationResult { sent, friends }

Future<SessionInvitationResult?> showSessionInvitationDialog(
  BuildContext context, {
  required String sessionId,
  required String sessionTitle,
}) =>
    showDialog<SessionInvitationResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _SessionInvitationDialog(sessionId: sessionId, title: sessionTitle),
    );

class _SessionInvitationDialog extends StatefulWidget {
  const _SessionInvitationDialog(
      {required this.sessionId, required this.title});
  final String sessionId;
  final String title;

  @override
  State<_SessionInvitationDialog> createState() =>
      _SessionInvitationDialogState();
}

class _SessionInvitationDialogState extends State<_SessionInvitationDialog> {
  late final String _scope;
  String? _username;
  String _role = 'editor';
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scope = _serverScope(context.read<ServerProvider>());
    _username = context
        .read<AccountShareProvider>()
        .social
        .friends
        .firstOrNull
        ?.username;
  }

  Future<void> _send(String username) async {
    if (_sending) return;
    final server = context.read<ServerProvider>();
    if (_scope != _serverScope(server)) return;
    final social = context.read<AccountShareProvider>();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await social.mutateSocial(
          'POST',
          '/sessions/${Uri.encodeComponent(widget.sessionId)}/invitations',
          {'username': username, 'role': _role});
      if (!mounted) return;
      if (_scope != _serverScope(server)) {
        setState(() => _error = context.l10n.hubContextChanged);
        return;
      }
      Navigator.pop(context, SessionInvitationResult.sent);
    } catch (error) {
      if (!mounted) return;
      final l = context.l10n;
      if (_scope != _serverScope(server)) {
        setState(() => _error = l.hubContextChanged);
        return;
      }
      setState(() => _error = error is ServerApiException
          ? switch (error.code) {
              'FRIEND_REQUIRED' => l.socialErrorFriends,
              'ALREADY_MEMBER' => l.hubAlreadyMember,
              'REQUEST_CLOSED' => l.socialErrorClosed,
              _ => l.operationFailed(error.message),
            }
          : l.operationFailed('$error'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<AccountShareProvider>();
    final server = context.watch<ServerProvider>();
    final l = context.l10n;
    final changed = _scope != _serverScope(server);
    final friends = changed
        ? const <String>[]
        : social.social.friends.map((f) => f.username).toList();
    // A poll removing the selected friend must not silently invite somebody else.
    final selected = friends.contains(_username) ? _username : null;
    final disabled = _sending || social.busy || changed;
    return PopScope(
      canPop: !_sending,
      child: AlertDialog(
        key: const Key('session-friend-invite-dialog'),
        title: Text(l.socialInvite),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!changed) Text(widget.title),
                const SizedBox(height: 12),
                Text(changed
                    ? l.hubContextChanged
                    : friends.isEmpty
                        ? l.socialNoFriends
                        : l.hubInvitationHint),
                if (friends.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey('invite-friend-$selected'),
                    initialValue: selected,
                    isExpanded: true,
                    decoration:
                        InputDecoration(labelText: l.socialChooseFriend),
                    items: friends
                        .map((name) =>
                            DropdownMenuItem(value: name, child: Text(name)))
                        .toList(),
                    onChanged: disabled
                        ? null
                        : (value) => setState(() => _username = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const Key('session-invite-role'),
                    initialValue: _role,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                          value: 'editor', child: Text(l.socialEdit)),
                      DropdownMenuItem(
                          value: 'viewer', child: Text(l.socialView)),
                    ],
                    onChanged: disabled
                        ? null
                        : (value) => setState(() => _role = value!),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                if (_sending) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _sending ? null : () => Navigator.pop(context),
              child: Text(l.cancel)),
          if (friends.isEmpty && !changed)
            FilledButton(
                onPressed: disabled
                    ? null
                    : () =>
                        Navigator.pop(context, SessionInvitationResult.friends),
                child: Text(l.socialAddFriend))
          else
            FilledButton(
              key: const Key('send-session-friend-invite'),
              onPressed:
                  disabled || selected == null ? null : () => _send(selected),
              child: Text(l.socialInvite),
            ),
        ],
      ),
    );
  }
}
