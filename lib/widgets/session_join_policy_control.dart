import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/social_dto.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/theme/app_theme.dart';
import 'package:openlogtool/widgets/settings/settings_ui.dart';

/// Session access is independent of friendship and existing memberships.
/// Policies only affect how new participants can join this particular session.
class SessionJoinPolicyControl extends StatefulWidget {
  const SessionJoinPolicyControl({
    super.key,
    required this.session,
    required this.disabled,
    required this.supportsDirectJoin,
    required this.onChanged,
  });

  final FriendSession session;
  final bool disabled;
  final bool supportsDirectJoin;
  final Future<void> Function(Map<String, Object?>) onChanged;

  @override
  State<SessionJoinPolicyControl> createState() =>
      _SessionJoinPolicyControlState();
}

class _SessionJoinPolicyControlState extends State<SessionJoinPolicyControl> {
  bool _working = false;

  String get _mode => widget.session.visibility != 'friends'
      ? 'private'
      : widget.supportsDirectJoin && widget.session.joinPolicy == 'direct'
          ? 'direct'
          : 'approval';

  String get _role =>
      widget.session.defaultRole == 'editor' ? 'editor' : 'viewer';

  (int, String, String?) _serverScope(ServerProvider server) =>
      (server.contextRevision, server.serverUrl, server.accountId);

  (String, String, String, String) get _sessionScope => (
        widget.session.sessionId,
        widget.session.visibility,
        widget.session.joinPolicy,
        widget.session.defaultRole,
      );

  Future<void> _change(String mode, String role) async {
    if (_working || widget.disabled || (mode == _mode && role == _role)) return;
    final server = context.read<ServerProvider>();
    final serverScope = _serverScope(server);
    final sessionScope = _sessionScope;
    final supportsDirectJoin = widget.supportsDirectJoin;
    bool isCurrent() =>
        mounted &&
        _serverScope(server) == serverScope &&
        _sessionScope == sessionScope &&
        widget.supportsDirectJoin == supportsDirectJoin;
    final needsConsent = mode == 'direct' &&
        (_mode != 'direct' || (_role != 'editor' && role == 'editor'));
    setState(() => _working = true);
    try {
      if (needsConsent) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            dialogContext.watch<ServerProvider>();
            final current = isCurrent();
            final l = dialogContext.l10n;
            return AlertDialog(
              key: const Key('session-direct-join-confirmation'),
              title: Text(l.socialJoinDirect),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!current)
                      Text(l.hubContextChanged)
                    else ...[
                      Text(widget.session.title,
                          style: Theme.of(dialogContext).textTheme.titleMedium),
                      const SizedBox(height: AppSpace.sm),
                      Text(l.socialDirectJoinWarning),
                      const SizedBox(height: AppSpace.sm),
                      Text('${l.socialDirectRole}: '
                          '${role == 'editor' ? l.socialEdit : l.socialView}'),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(l.cancel)),
                FilledButton(
                    key: const Key('confirm-session-direct-join'),
                    onPressed: current
                        ? () => Navigator.pop(dialogContext, true)
                        : null,
                    child: Text(l.socialDirectJoinConfirm)),
              ],
            );
          },
        );
        if (confirmed != true) return;
      }
      if (!isCurrent() || widget.disabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.hubContextChanged)));
        }
        return;
      }
      await widget.onChanged({
        'visibility': mode == 'private' ? 'private' : 'friends',
        if (supportsDirectJoin) ...{
          'joinPolicy': mode == 'direct' ? 'direct' : 'approval',
          'defaultRole': role,
        },
      });
    } catch (error) {
      if (mounted && isCurrent()) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.operationFailed('$error'))));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final disabled = widget.disabled || _working;
    final secondary = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: InputDecoration(labelText: l.socialJoinMode),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('session-join-mode'),
              value: _mode,
              isExpanded: true,
              isDense: true,
              items: [
                DropdownMenuItem(
                    value: 'private', child: Text(l.socialJoinInviteOnly)),
                DropdownMenuItem(
                    value: 'approval', child: Text(l.socialJoinApproval)),
                if (widget.supportsDirectJoin)
                  DropdownMenuItem(
                      value: 'direct', child: Text(l.socialJoinDirect)),
              ],
              onChanged: disabled
                  ? null
                  : (mode) {
                      if (mode != null) _change(mode, _role);
                    },
            ),
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        if (_mode == 'direct') ...[
          AppNotice(message: l.socialDirectJoinWarning, tone: AppTone.warning),
          const SizedBox(height: AppSpace.sm),
          InputDecorator(
            decoration: InputDecoration(labelText: l.socialDirectRole),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const Key('session-direct-join-role'),
                value: _role,
                isExpanded: true,
                isDense: true,
                items: [
                  DropdownMenuItem(value: 'viewer', child: Text(l.socialView)),
                  DropdownMenuItem(value: 'editor', child: Text(l.socialEdit)),
                ],
                onChanged: disabled
                    ? null
                    : (role) {
                        if (role != null) _change(_mode, role);
                      },
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xs),
        ],
        Text(l.socialDirectJoinExistingHint, style: secondary),
      ],
    );
  }
}
