import 'dart:async';
import 'package:openlogtool/utils/app_snack_bar.dart';

import 'package:flutter/material.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:provider/provider.dart';

String localCollaborationActionErrorText(
  AppLocalizations l10n,
  Object error,
) {
  final raw = error.toString();
  if (raw.contains('COLLABORATION_OPERATION_IN_PROGRESS')) {
    return l10n.localCollaborationOperationBusy;
  }
  if (raw.contains('LOCAL_COLLABORATION_REQUIRED')) {
    return l10n.localCollaborationRequired;
  }
  return l10n.operationFailed(raw.replaceFirst('Bad state: ', ''));
}

/// Independent copies and explicit data cleanup, not session lifecycle actions.
/// Ending a shared session and leaving its membership live in collaboration
/// management; neither operation is emulated by detaching a local replica.
class CollaborationLocalSessionAction extends StatelessWidget {
  const CollaborationLocalSessionAction({
    super.key,
    this.padding = EdgeInsets.zero,
    this.alignment,
  });

  final EdgeInsetsGeometry padding;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final collaboration = context.watch<CollaborationProvider>();
    final session = context.watch<SessionProvider>().currentSession;
    final binding = collaboration.binding;
    if (session == null ||
        binding == null ||
        binding.sessionId != session.sessionId) {
      return const SizedBox.shrink();
    }

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        MenuAnchor(
          menuChildren: [
            MenuItemButton(
              key: const Key('create-editable-local-copy'),
              leadingIcon: const Icon(Icons.copy_all_outlined),
              onPressed: () => unawaited(
                _confirmCreateCopy(
                  context,
                  collaboration: collaboration,
                  sourceTitle: session.title,
                ),
              ),
              child: Text(context.l10n.createEditableLocalCopy),
            ),
            MenuItemButton(
              key: const Key('delete-collaboration-locally'),
              leadingIcon: Icon(
                Icons.delete_forever,
                color: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => unawaited(
                _confirmDeleteLocally(
                  context,
                  collaboration: collaboration,
                  sourceTitle: session.title,
                ),
              ),
              child: Text(context.l10n.historySessionDeleteAction),
            ),
          ],
          builder: (context, controller, child) => OutlinedButton.icon(
            key: const Key('more-local-collaboration-actions'),
            onPressed: collaboration.isBusy
                ? null
                : () =>
                    controller.isOpen ? controller.close() : controller.open(),
            icon: const Icon(Icons.more_horiz),
            label: Text(context.l10n.moreLocalCollaborationActions),
          ),
        ),
      ],
    );

    return Padding(
      padding: padding,
      child: alignment == null
          ? actions
          : Align(alignment: alignment!, child: actions),
    );
  }

  Future<void> _confirmCreateCopy(
    BuildContext context, {
    required CollaborationProvider collaboration,
    required String sourceTitle,
  }) async {
    final sourceSessionId = context.read<SessionProvider>().currentSessionId;
    final sourceBinding = collaboration.binding;
    final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            key: const Key('create-editable-local-copy-dialog'),
            title: Text(context.l10n.createEditableLocalCopyTitle),
            content: Text(
              context.l10n.createEditableLocalCopyConfirmation(sourceTitle),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                key: const Key('confirm-create-editable-local-copy'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.createEditableLocalCopy),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted || !context.mounted) return;

    // A dialog must never copy another session selected while it was open.
    if (context.read<SessionProvider>().currentSessionId != sourceSessionId ||
        collaboration.binding?.sessionId != sourceBinding?.sessionId ||
        collaboration.binding?.accountId != sourceBinding?.accountId ||
        collaboration.binding?.serverInstanceId !=
            sourceBinding?.serverInstanceId) {
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.hubContextChanged)),
      );
      return;
    }
    await _runLocalAction(
      context,
      () => collaboration.createEditableLocalCopy(
        title: _editableLocalCopyTitle(context, sourceTitle),
      ),
      success: context.l10n.editableLocalCopySucceeded,
    );
  }

  Future<void> _confirmDeleteLocally(
    BuildContext context, {
    required CollaborationProvider collaboration,
    required String sourceTitle,
  }) async {
    final accepted = await showDialog<bool>(
          context: context,
          builder: (_) => _DeleteCurrentCollaborationConfirmationDialog(
            sessionTitle: sourceTitle,
          ),
        ) ??
        false;
    if (!accepted || !context.mounted) return;

    await _runLocalAction(
      context,
      collaboration.deleteCurrentSessionLocally,
      success: context.l10n.historySessionDeleted,
    );
  }

  Future<void> _runLocalAction(
    BuildContext context,
    Future<void> Function() action, {
    required String success,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await action();
      if (!messenger.mounted) return;
      messenger.showLoggedSnackBar(SnackBar(content: Text(success)));
    } catch (error) {
      if (!messenger.mounted) return;
      messenger.showLoggedSnackBar(
        SnackBar(content: Text(localCollaborationActionErrorText(l10n, error))),
      );
    }
  }

  String _editableLocalCopyTitle(BuildContext context, String sourceTitle) {
    final sourceRunes = sourceTitle.trim().runes.toList(growable: true);
    var localTitle = context.l10n.editableLocalCopySessionTitle(
      String.fromCharCodes(sourceRunes),
    );
    while (localTitle.runes.length > 200 && sourceRunes.isNotEmpty) {
      sourceRunes.removeLast();
      localTitle = context.l10n.editableLocalCopySessionTitle(
        String.fromCharCodes(sourceRunes),
      );
    }
    return localTitle.runes.length > 200
        ? String.fromCharCodes(localTitle.runes.take(200))
        : localTitle;
  }
}

class _DeleteCurrentCollaborationConfirmationDialog extends StatefulWidget {
  const _DeleteCurrentCollaborationConfirmationDialog({
    required this.sessionTitle,
  });

  final String sessionTitle;

  @override
  State<_DeleteCurrentCollaborationConfirmationDialog> createState() =>
      _DeleteCurrentCollaborationConfirmationDialogState();
}

class _DeleteCurrentCollaborationConfirmationDialogState
    extends State<_DeleteCurrentCollaborationConfirmationDialog> {
  final _nameController = TextEditingController();
  bool _nameMatches = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const Key('delete-current-collaboration-locally-dialog'),
        title: Text(context.l10n.historySessionDeleteTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.historySessionDeleteWarning(widget.sessionTitle),
              ),
              const SizedBox(height: 12),
              SelectableText(
                context.l10n
                    .historySessionDeleteExpectedName(widget.sessionTitle),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('delete-current-collaboration-name'),
                controller: _nameController,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: context.l10n.historySessionDeleteNameLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final matches = value.trim() == widget.sessionTitle;
                  if (matches != _nameMatches) {
                    setState(() => _nameMatches = matches);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const Key(
              'confirm-delete-current-collaboration-locally',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: _nameMatches ? () => Navigator.pop(context, true) : null,
            child: Text(context.l10n.historySessionDeleteAction),
          ),
        ],
      );
}
