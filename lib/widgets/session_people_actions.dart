import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/social_dto.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/screens/social_screen.dart';
import 'package:openlogtool/widgets/session_friend_actions.dart';

/// Owner actions scoped to one session, backed by the account-level WS snapshot.
class SessionPeopleActions extends StatefulWidget {
  const SessionPeopleActions({super.key, required this.sessionId});
  final String sessionId;
  @override
  State<SessionPeopleActions> createState() => _SessionPeopleActionsState();
}

class _SessionPeopleActionsState extends State<SessionPeopleActions> {
  bool _working = false;
  String? _error;
  String? _acceptedRequests;
  bool _needsMemberRefresh = false;
  bool _refreshScheduled = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _error = context.l10n.operationFailed('$error'));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _invite() async {
    final session = context.read<SessionProvider>().currentSession;
    if (session?.sessionId != widget.sessionId) return;
    final result = await showSessionInvitationDialog(context,
        sessionId: widget.sessionId, sessionTitle: session!.title);
    if (mounted && result == SessionInvitationResult.friends) {
      await Navigator.push(context,
          MaterialPageRoute<void>(builder: (_) => const SocialScreen()));
    }
  }

  Future<void> _respond(SocialRequest request, String action) async {
    final social = context.read<AccountShareProvider>();
    final collaboration = context.read<CollaborationProvider>();
    if (collaboration.binding?.sessionId != widget.sessionId ||
        !collaboration.isOwner) {
      return;
    }
    await social.mutateSocial(
        'POST', '/session-requests/${Uri.encodeComponent(request.id)}/$action');
    if (!mounted ||
        collaboration.binding?.sessionId != widget.sessionId ||
        !collaboration.isOwner) {
      return;
    }
    if (action == 'accept') {
      await collaboration.refreshManagement();
      _needsMemberRefresh = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<AccountShareProvider>();
    final collaboration = context.watch<CollaborationProvider>();
    final session = context.watch<SessionProvider>().currentSession;
    final l = context.l10n;
    final current = session?.sessionId == widget.sessionId &&
        collaboration.binding?.sessionId == widget.sessionId;
    final disabled = _working ||
        social.busy ||
        social.loading ||
        collaboration.isBusy ||
        !current ||
        !collaboration.isOwner;
    final closed =
        session?.status != 'active' || collaboration.canonicalSessionClosed;
    final visible = social.social.sessions
        .where((s) => s.sessionId == widget.sessionId)
        .firstOrNull;
    final requests = social.social.sessionRequests
        .where((r) => r.sessionId == widget.sessionId && r.status == 'pending')
        .toList();
    final accepted = social.social.sessionRequests
        .where((r) => r.sessionId == widget.sessionId && r.status == 'accepted')
        .map((r) => r.id)
        .toList()
      ..sort();
    final fingerprint = accepted.join('|');
    if (_acceptedRequests != null && _acceptedRequests != fingerprint) {
      _needsMemberRefresh = true;
    }
    _acceptedRequests = fingerprint;
    // Account WS invalidations refresh the social snapshot. If a friend accepts
    // elsewhere, update the visible member list as well, without a polling loop.
    if (_needsMemberRefresh &&
        !_refreshScheduled &&
        !disabled &&
        collaboration.state == CollaborationState.ready) {
      _refreshScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshScheduled = false;
        if (!mounted ||
            _working ||
            collaboration.isBusy ||
            collaboration.binding?.sessionId != widget.sessionId ||
            !collaboration.isOwner) {
          return;
        }
        _needsMemberRefresh = false;
        _run(collaboration.refreshManagement);
      });
    }
    return Card(
        key: const Key('session-people-actions'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.sessionPeopleTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l.sessionPeopleHint),
            if (social.lastError != null || _error != null) ...[
              const SizedBox(height: 8),
              Text(_error ?? l.operationFailed('${social.lastError}'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                  key: const Key('people-invite-friend'),
                  onPressed: disabled || closed ? null : () => _run(_invite),
                  icon: const Icon(Icons.person_add_outlined),
                  label: Text(l.socialInvite)),
              OutlinedButton.icon(
                  onPressed: disabled
                      ? null
                      : () => _run(() async {
                            await social.refresh();
                            if (mounted &&
                                collaboration.binding?.sessionId ==
                                    widget.sessionId &&
                                collaboration.isOwner) {
                              await collaboration.refreshManagement();
                            }
                          }),
                  icon: const Icon(Icons.refresh),
                  label: Text(l.refresh)),
            ]),
            if (visible != null)
              SwitchListTile(
                key: const Key('people-friend-visibility'),
                contentPadding: EdgeInsets.zero,
                title: Text(l.socialDiscoverable),
                subtitle: Text(l.socialVisibilityHint),
                value: visible.visibility == 'friends',
                onChanged: disabled || closed
                    ? null
                    : (value) => _run(() => social.mutateSocial(
                        'PUT',
                        '/sessions/${Uri.encodeComponent(widget.sessionId)}',
                        {'visibility': value ? 'friends' : 'private'})),
              ),
            const Divider(height: 24),
            Text(l.sessionPendingRequests,
                style: Theme.of(context).textTheme.titleSmall),
            if (requests.isEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l.socialNoMessages)),
            for (final request in requests)
              Padding(
                key: Key('session-request-${request.id}'),
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${request.kind == 'application' ? l.socialApplication : l.socialInvitation} · '
                          '${request.senderId == social.accountId ? request.recipientUsername : request.senderUsername}'),
                      Text(request.role == 'editor'
                          ? l.socialEdit
                          : l.socialView),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        if (request.recipientId == social.accountId) ...[
                          TextButton(
                              onPressed: disabled || closed
                                  ? null
                                  : () =>
                                      _run(() => _respond(request, 'accept')),
                              child: Text(l.socialAccept)),
                          TextButton(
                              onPressed: disabled
                                  ? null
                                  : () =>
                                      _run(() => _respond(request, 'reject')),
                              child: Text(l.socialReject)),
                        ] else ...[
                          Text(l.socialPending),
                          TextButton(
                              onPressed: disabled
                                  ? null
                                  : () =>
                                      _run(() => _respond(request, 'cancel')),
                              child: Text(l.cancel)),
                        ],
                      ]),
                    ]),
              ),
          ]),
        ));
  }
}
