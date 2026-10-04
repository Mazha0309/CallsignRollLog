import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/social_dto.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/screens/social_screen.dart';
import 'package:openlogtool/theme/app_theme.dart';
import 'package:openlogtool/widgets/session_friend_actions.dart';
import 'package:openlogtool/widgets/session_join_policy_control.dart';
import 'package:openlogtool/widgets/settings/settings_ui.dart';
import 'package:openlogtool/widgets/share_invitation_badge.dart';

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
  int? _socialRevision;
  (int, String, String?, String)? _memberScope;
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
      final revision = social.revision;
      await collaboration.refreshManagement();
      _needsMemberRefresh = social.revision != revision;
    }
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<AccountShareProvider>();
    final server = context.watch<ServerProvider>();
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
    final scope = (
      server.contextRevision,
      server.serverUrl,
      server.accountId,
      widget.sessionId
    );
    if (_memberScope != scope) {
      _memberScope = scope;
      _socialRevision = social.revision;
      _needsMemberRefresh = false;
    } else if (_socialRevision != social.revision) {
      _needsMemberRefresh = true;
    }
    _socialRevision = social.revision;
    // Account WS invalidations include direct joins, which create no accepted
    // request. Refresh membership after every new account snapshot instead of
    // inferring membership changes from invitation IDs or adding a poll.
    if (_needsMemberRefresh &&
        !_refreshScheduled &&
        !disabled &&
        collaboration.state == CollaborationState.ready) {
      _refreshScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshScheduled = false;
        if (!mounted ||
            _memberScope != scope ||
            (
                  server.contextRevision,
                  server.serverUrl,
                  server.accountId,
                  widget.sessionId
                ) !=
                scope ||
            _working ||
            social.busy ||
            social.loading ||
            collaboration.isBusy ||
            collaboration.binding?.sessionId != widget.sessionId ||
            !collaboration.isOwner) {
          return;
        }
        _needsMemberRefresh = false;
        _run(collaboration.refreshManagement);
      });
    }
    return SettingsSectionCard(
        key: const Key('session-people-actions'),
        icon: Icons.person_add_outlined,
        title: l.sessionPeopleTitle,
        description: l.sessionPeopleHint,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (social.lastError != null || _error != null) ...[
            AppNotice(
                message: _error ?? l.operationFailed('${social.lastError}'),
                tone: AppTone.danger),
            const SizedBox(height: AppSpace.sm),
          ],
          Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
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
          if (visible != null) ...[
            const SizedBox(height: AppSpace.md),
            SessionJoinPolicyControl(
              key: const Key('people-friend-visibility'),
              session: visible,
              disabled: disabled || closed,
              supportsDirectJoin: social.supportsDirectJoin,
              onChanged: (policy) => _run(() => social.mutateSocial(
                  'PUT',
                  '/sessions/${Uri.encodeComponent(widget.sessionId)}',
                  policy)),
            ),
          ],
          const Divider(height: AppSpace.lg),
          Align(
              alignment: AlignmentDirectional.centerStart,
              child: RequestBadge(
                  key: const Key('session-applications-badge'),
                  count: social.pendingSessionApplications(widget.sessionId),
                  child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 12),
                      child: AppSectionLabel(l.sessionPendingRequests)))),
          if (requests.isEmpty)
            Padding(
                padding: const EdgeInsets.only(top: AppSpace.xxs),
                child: Text(l.socialNoMessages,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant))),
          for (final request in requests)
            Padding(
              key: Key('session-request-${request.id}'),
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${request.kind == 'application' ? l.socialApplication : l.socialInvitation} · '
                        '${request.senderId == social.accountId ? request.recipientUsername : request.senderUsername}'),
                    Text(request.role == 'editor' ? l.socialEdit : l.socialView,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: AppSpace.xs),
                    Wrap(
                        spacing: AppSpace.xs,
                        runSpacing: AppSpace.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (request.recipientId == social.accountId) ...[
                            FilledButton.tonal(
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
                            AppStatusPill(label: l.socialPending),
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
        ]));
  }
}
