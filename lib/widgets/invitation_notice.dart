import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/account_share_provider.dart';

/// A persistent, dismissible reminder plus one non-focus-stealing toast for
/// newly received requests. WebSocket refreshes do not repeat the same toast.
class InvitationNotice extends StatefulWidget {
  const InvitationNotice(
      {super.key,
      required this.onOpen,
      this.onOpenRequests,
      this.keyboardVisible = false});
  final VoidCallback onOpen;
  final VoidCallback? onOpenRequests;
  // Read above Scaffold: its resized body removes the keyboard view insets.
  final bool keyboardVisible;
  @override
  State<InvitationNotice> createState() => _InvitationNoticeState();
}

// A controller may refer to a queued or already-finished SnackBar. Flutter's
// close() assumes it is the active one; never close another message's slot.
class _InvitationToast {
  _InvitationToast(this.messenger);
  final ScaffoldMessengerState messenger;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? controller;
  bool visible = false, finished = false, cancelled = false;
  void cancel() {
    cancelled = true;
    if (visible && !finished && messenger.mounted) controller?.close();
  }
}

class _InvitationNoticeState extends State<InvitationNotice> {
  String? _scope;
  final _seen = <String>{};
  final _dismissed = <String>{};
  _InvitationToast? _toast;

  void _closeToastLater() {
    final toast = _toast;
    _toast = null;
    if (toast == null) return;
    toast.cancelled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => toast.cancel());
  }

  @override
  void dispose() {
    _closeToastLater();
    super.dispose();
  }

  void _open() {
    _toast?.cancel();
    widget.onOpen();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountShareProvider>();
    final keys = provider.pendingInboundKeys;
    final scope = provider.accountScope;
    if (_scope != scope) {
      _scope = scope;
      _seen.clear();
      _dismissed.clear();
      _closeToastLater();
    }
    final fresh = keys.difference(_seen);
    _seen.addAll(keys);
    if (fresh.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            scope != provider.accountScope ||
            !provider.pendingInboundKeys.any(fresh.contains) ||
            ModalRoute.of(context)?.isCurrent != true) {
          return;
        }
        _toast?.cancel();
        final toast = _InvitationToast(ScaffoldMessenger.of(context));
        _toast = toast;
        toast.controller = toast.messenger.showSnackBar(SnackBar(
          content: Text(context.l10n.newInvitationNotice),
          duration: const Duration(seconds: 6),
          persist: false,
          onVisible: () {
            toast.visible = true;
            if (toast.cancelled || !mounted || scope != provider.accountScope) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => toast.cancel());
            }
          },
          action: SnackBarAction(
              label: context.l10n.viewInvitations,
              onPressed: () {
                if (mounted && scope == provider.accountScope) _open();
              }),
        ));
        toast.controller!.closed.then((_) {
          toast.finished = true;
          if (identical(_toast, toast)) _toast = null;
        });
      });
    }
    if (keys.isEmpty) _closeToastLater();
    if (keys.isEmpty || keys.difference(_dismissed).isEmpty) {
      return const SizedBox.shrink();
    }
    // Do not squeeze the editor out of a small phone viewport while typing.
    // The toast and bell still notify; the banner returns after the keyboard.
    if (widget.keyboardVisible) {
      return const SizedBox.shrink();
    }
    final l = context.l10n;
    final name = provider.inbox
        .where((g) => g.status == 'pending')
        .firstOrNull
        ?.grantorUsername;
    final request = provider.pendingSocialRequests.firstOrNull;
    final summary = name != null && name.isNotEmpty
        ? l.shareInvitationFrom(name)
        : request == null
            ? l.newInvitationNotice
            : '${request.senderUsername} · ${request.sessionId == null ? l.socialFriendRequest : request.kind == 'application' ? l.socialApplication : l.socialInvitation}';
    return Material(
      key: const Key('incoming-invitations-notice'),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              const Icon(Icons.mark_email_unread_outlined),
              const SizedBox(width: 10),
              Expanded(
                  child: Semantics(
                      liveRegion: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall),
                          Text(l.pendingInvitations(keys.length),
                              style: Theme.of(context).textTheme.bodySmall),
                          TextButton(
                              key: const Key('view-incoming-invitations'),
                              onPressed: _open,
                              child: Text(l.viewInvitations)),
                          if (provider.pendingShareCount > 0 &&
                              request != null &&
                              widget.onOpenRequests != null)
                            TextButton.icon(
                                key: const Key('view-incoming-requests'),
                                onPressed: widget.onOpenRequests,
                                icon: Icon(
                                    Icons.notification_important_outlined,
                                    color: Colors.red.shade700),
                                label: Text(
                                    '${l.socialMessages} (${provider.pendingSocialRequests.length})')),
                        ],
                      ))),
              IconButton(
                  key: const Key('dismiss-invitation-notice'),
                  tooltip: l.dismissInvitationNotice,
                  onPressed: () {
                    _toast?.cancel();
                    setState(() {
                      _dismissed.clear();
                      _dismissed.addAll(keys);
                    });
                  },
                  icon: const Icon(Icons.close)),
            ]),
          )),
    );
  }
}
