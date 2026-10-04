import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/account_share_provider.dart';

/// Sharing owns its pending indicator; users need not open social messages.
class ShareInvitationBadge extends StatelessWidget {
  const ShareInvitationBadge({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final count = context.select<AccountShareProvider, int>(
        (provider) => provider.pendingShareCount);
    return Semantics(
      label: count > 0 ? '${context.l10n.shareInboxTitle} ($count)' : null,
      child: Badge.count(
        count: count,
        isLabelVisible: count > 0,
        backgroundColor: Colors.red.shade700,
        textColor: Colors.white,
        child: child,
      ),
    );
  }
}

class RequestBadge extends StatelessWidget {
  const RequestBadge({super.key, required this.count, required this.child});
  final int count;
  final Widget child;
  @override
  Widget build(BuildContext context) => Badge.count(
      count: count,
      isLabelVisible: count > 0,
      backgroundColor: Colors.red.shade700,
      textColor: Colors.white,
      child: child);
}
