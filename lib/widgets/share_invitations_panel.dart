import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/account_share_dto.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/widgets/settings/settings_ui.dart';

/// The same inbox is visible both in Sharing and in Messages.
class ShareInvitationsPanel extends StatefulWidget {
  const ShareInvitationsPanel({super.key, this.showEmpty = true});
  final bool showEmpty;
  @override
  State<ShareInvitationsPanel> createState() => _ShareInvitationsPanelState();
}

class _ShareInvitationsPanelState extends State<ShareInvitationsPanel> {
  bool _working = false;
  Object? _error;
  String? _scope;

  Future<void> _respond(AccountShareGrantDto grant, String action) async {
    final provider = context.read<AccountShareProvider>();
    if (_working || provider.busy) return;
    final scope = provider.accountScope;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await provider.respondShare(grant.id, action, expectedScope: scope);
      if (!mounted || scope != provider.accountScope) return;
      if (action == 'accept') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.shareAcceptedHint)),
        );
      }
    } catch (error) {
      if (mounted && scope == provider.accountScope) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && scope == provider.accountScope) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountShareProvider>();
    final l = context.l10n;
    if (_scope != provider.accountScope) {
      _scope = provider.accountScope;
      _error = null;
      _working = false;
    }
    final grants = provider.inbox.where((g) => g.status == 'pending').toList();
    if (!widget.showEmpty &&
        grants.isEmpty &&
        provider.inboxError == null &&
        _error == null) {
      return const SizedBox.shrink();
    }
    return Column(
      key: const Key('share-invitations-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
            '${l.shareInboxTitle}${grants.isEmpty ? '' : ' (${grants.length})'}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_error != null || provider.inboxError != null)
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(_error == null ? l.shareLoadFailed : l.shareOperationFailed),
            TextButton(
                onPressed: provider.loading ? null : provider.refresh,
                child: Text(l.retry)),
          ])
        else if (grants.isEmpty)
          if (provider.loading)
            const LinearProgressIndicator()
          else
            Text(l.shareInboxEmpty),
        for (final grant in grants)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SettingsSectionCard(
              key: Key('share-invitation-${grant.id}'),
              icon: Icons.mark_email_unread_outlined,
              title: l.shareInvitationFrom(grant.grantorUsername.isEmpty
                  ? grant.grantorUserId
                  : grant.grantorUsername),
              description:
                  '${grant.scopeMode == 'all' ? l.shareAll : '${l.shareSelected} (${grant.selectedSessions.length})'} · ${grant.canEditLogs ? l.shareEditLogs : l.shareViewOnly}${grant.canDeleteLogs ? ' · ${l.shareDeleteLogs}' : ''}',
              child: Wrap(spacing: 8, runSpacing: 4, children: [
                FilledButton.icon(
                    key: Key('accept-share-${grant.id}'),
                    onPressed: _working || provider.busy
                        ? null
                        : () => _respond(grant, 'accept'),
                    icon: const Icon(Icons.check),
                    label: Text(l.socialAccept)),
                TextButton(
                    key: Key('reject-share-${grant.id}'),
                    onPressed: _working || provider.busy
                        ? null
                        : () => _respond(grant, 'reject'),
                    child: Text(l.socialReject)),
              ]),
            ),
          ),
      ],
    );
  }
}
