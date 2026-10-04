import 'dart:async';
import 'package:openlogtool/utils/app_snack_bar.dart';

import 'package:flutter/material.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/src/bridge/rust_api.dart';
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/widgets/session_sharing_dialog.dart';
import 'package:openlogtool/widgets/share_invitation_badge.dart';
import 'package:openlogtool/widgets/share_invitations_panel.dart';
import 'package:openlogtool/widgets/shared_session_records_dialog.dart';

typedef SessionHistoryLoader = Future<List<Session>> Function();
typedef SessionHistoryAction = Future<void> Function(Session session);
typedef SessionHistoryCurrentIdGetter = String? Function();
typedef SessionCollaborationBindingChecker = Future<bool> Function(
  String sessionId,
);

enum _SessionCollection { all, personal, collaboration, shared, closed }

enum _SessionRowAction { closeLocally, manageCollaboration, deleteLocally }

String historySessionCloseErrorText(BuildContext context, Object error) {
  final raw = error.toString();
  if (raw.contains('LOCAL_CLOSE_COLLABORATION_FORBIDDEN')) {
    return context.l10n.historySessionCollaborationCloseRequired;
  }
  if (raw.contains('COLLABORATION_OPERATION_IN_PROGRESS')) {
    return context.l10n.localCollaborationOperationBusy;
  }
  if (raw.contains('LOCAL_COLLABORATION_REQUIRED')) {
    return context.l10n.localCollaborationRequired;
  }
  return context.l10n.historySessionCloseFailed(
    raw.replaceFirst('Bad state: ', ''),
  );
}

Future<void> closeSessionFromHistory({
  required Session session,
  required SessionCollaborationBindingChecker hasCollaborationBinding,
  required SessionHistoryAction closeLocalSession,
}) async {
  final collaboration = await hasCollaborationBinding(session.sessionId);
  if (collaboration) {
    throw StateError('LOCAL_CLOSE_COLLABORATION_FORBIDDEN');
  }
  await closeLocalSession(session);
}

String localSessionReopenErrorText(BuildContext context, Object error) {
  final raw = error.toString();
  if (raw.contains('LOCAL_REOPEN_COLLABORATION_FORBIDDEN')) {
    return context.l10n.historySessionCollaborationReopenRequired;
  }
  return context.l10n.historySessionReopenFailed(raw);
}

Future<bool> confirmReopenLocalSession(
  BuildContext context, {
  required String sessionTitle,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.l10n.historySessionReopenTitle),
      content: Text(
        dialogContext.l10n.historySessionReopenConfirmation(sessionTitle),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(dialogContext.l10n.cancel),
        ),
        FilledButton.icon(
          key: const Key('confirm-reopen-local-session'),
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.play_arrow),
          label: Text(dialogContext.l10n.historySessionReopenAction),
        ),
      ],
    ),
  );
  return confirmed == true;
}

void showReopenedSessionLogsUnavailable(
  BuildContext context, {
  required LogProvider logs,
  required String sessionId,
  required String sessionTitle,
}) {
  if (!context.mounted) return;
  final l10n = context.l10n;
  ScaffoldMessenger.of(context).showLoggedSnackBar(
    SnackBar(
      content: Text(
        l10n.historySessionReopenedLogsUnavailable(sessionTitle),
      ),
      action: SnackBarAction(
        label: l10n.retry,
        onPressed: () {
          unawaited(
            _retryReopenedSessionLogs(
              context,
              logs: logs,
              sessionId: sessionId,
              sessionTitle: sessionTitle,
            ),
          );
        },
      ),
    ),
  );
}

Future<void> _retryReopenedSessionLogs(
  BuildContext context, {
  required LogProvider logs,
  required String sessionId,
  required String sessionTitle,
}) async {
  try {
    await logs.reloadForSession(sessionId, propagateErrors: true);
  } catch (_) {
    if (context.mounted) {
      showReopenedSessionLogsUnavailable(
        context,
        logs: logs,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
      );
    }
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showLoggedSnackBar(
    SnackBar(content: Text(context.l10n.historySessionSwitched(sessionTitle))),
  );
}

/// Searchable, paged history embedded directly in the Sessions destination.
class SessionHistoryPanel extends StatefulWidget {
  const SessionHistoryPanel({
    super.key,
    this.onSessionOpened,
    this.onCollaborationSessionManage,
  });

  final VoidCallback? onSessionOpened;
  final Future<void> Function(Session session)? onCollaborationSessionManage;

  @override
  State<SessionHistoryPanel> createState() => _SessionHistoryPanelState();
}

class _SessionHistoryPanelState extends State<SessionHistoryPanel> {
  final _searchController = TextEditingController();
  Future<List<SessionListEntry>>? _entries;
  _SessionCollection _collection = _SessionCollection.all;
  String _query = '';
  String? _busySessionId;
  int _page = 0;
  int? _databaseRevision;
  int? _dataRevision;
  int? _collaborationCatalogRevision;
  int? _sharingRevision;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sessions = context.watch<SessionProvider>();
    final sharing = context.watch<AccountShareProvider>();
    if (_entries == null ||
        _dataRevision != sessions.dataRevision ||
        _sharingRevision != sharing.revision ||
        _databaseRevision != sessions.databaseRevision ||
        _collaborationCatalogRevision !=
            sessions.collaborationCatalogRevision) {
      _databaseRevision = sessions.databaseRevision;
      _dataRevision = sessions.dataRevision;
      _sharingRevision = sharing.revision;
      _collaborationCatalogRevision = sessions.collaborationCatalogRevision;
      _entries = _loadEntries(sessions, sharing);
      _busySessionId = null;
      _page = 0;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<SessionListEntry>> _loadEntries(
    SessionProvider sessions,
    AccountShareProvider sharing,
  ) async {
    final local = await sessions.listAvailableSessionEntries();
    final sharedCollaborationIds = sharing.sharedSessions
        .where((s) => s.source == 'collaboration')
        .map((s) => s.sessionId)
        .toSet();
    final shared = <String, SessionListEntry>{};
    for (final entry in sharing.sharedHistoryEntries()) {
      final source = entry.sharedSession;
      final key = source?.source == 'collaboration'
          ? 'collaboration:${source!.sessionId}'
          : '${source?.grantorUserId}:${source?.source}:${entry.session.sessionId}';
      shared.putIfAbsent(key, () => entry);
    }
    return [
      ...local.where((entry) =>
          !entry.hasCollaborationBinding ||
          !sharedCollaborationIds.contains(entry.session.sessionId)),
      ...shared.values,
    ]..sort((a, b) => b.session.updatedAt.compareTo(a.session.updatedAt));
  }

  void _reload() {
    setState(() {
      _entries = _loadEntries(
        context.read<SessionProvider>(),
        context.read<AccountShareProvider>(),
      );
      _busySessionId = null;
      _page = 0;
    });
  }

  List<SessionListEntry> _filtered(
    List<SessionListEntry> entries,
    String? currentSessionId,
  ) {
    final query = _query.trim().toLowerCase();
    return entries.where((entry) {
      final session = entry.session;
      if (!entry.isShared && session.sessionId == currentSessionId) {
        return false;
      }
      final collaborative = entry.hasCollaborationBinding;
      if (!switch (_collection) {
        _SessionCollection.all => true,
        _SessionCollection.personal => !collaborative && !entry.isShared,
        _SessionCollection.collaboration => collaborative,
        _SessionCollection.shared => entry.isShared,
        _SessionCollection.closed => session.status == 'closed',
      }) {
        return false;
      }
      return query.isEmpty ||
          session.title.toLowerCase().contains(query) ||
          session.sessionId.toLowerCase().contains(query) ||
          (entry.sharedGrantorUsername?.toLowerCase().contains(query) ?? false);
    }).toList(growable: false);
  }

  Future<void> _browseShared(SessionListEntry entry) async {
    final sharing = context.read<AccountShareProvider>();
    final shared = entry.sharedSession ??
        sharing.sharedSessionById(entry.session.sessionId);
    if (shared != null) await showSharedSessionRecords(context, shared);
  }

  Future<void> _open(Session session) async {
    if (_busySessionId != null) return;
    final sessions = context.read<SessionProvider>();
    final logs = context.read<LogProvider>();
    final previousSessionId = sessions.currentSessionId;
    setState(() => _busySessionId = session.sessionId);
    try {
      await logs.reloadForSession(session.sessionId, propagateErrors: true);
      await sessions.switchToSession(session.sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(context.l10n.historySessionSwitched(session.title)),
        ),
      );
      widget.onSessionOpened?.call();
    } catch (error, stackTrace) {
      try {
        await logs.reloadForSession(previousSessionId, propagateErrors: true);
      } catch (rollbackError, rollbackStackTrace) {
        debugPrint(
          '[SessionHistory] log rollback failed: '
          '$rollbackError\n$rollbackStackTrace',
        );
      }
      debugPrint('[SessionHistory] open failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _busySessionId = null);
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(context.l10n.historySessionOpenFailed('$error')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _openCollaborationManagement(Session session) async {
    if (_busySessionId != null) return;
    final manage = widget.onCollaborationSessionManage;
    if (manage == null) {
      await _open(session);
      return;
    }
    final sessions = context.read<SessionProvider>();
    final logs = context.read<LogProvider>();
    final previousSessionId = sessions.currentSessionId;
    setState(() => _busySessionId = session.sessionId);
    try {
      await logs.reloadForSession(session.sessionId, propagateErrors: true);
      await sessions.switchToSession(session.sessionId);
      if (!mounted) return;
      await manage(session);
      if (mounted) setState(() => _busySessionId = null);
    } catch (error, stackTrace) {
      try {
        await logs.reloadForSession(previousSessionId, propagateErrors: true);
        if (previousSessionId != null) {
          await sessions.switchToSession(previousSessionId);
        }
      } catch (rollbackError, rollbackStackTrace) {
        debugPrint(
          '[SessionHistory] collaboration management rollback failed: '
          '$rollbackError\n$rollbackStackTrace',
        );
      }
      debugPrint(
        '[SessionHistory] open collaboration management failed: '
        '$error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() => _busySessionId = null);
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(context.l10n.historySessionOpenFailed('$error')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _reopen(Session session) async {
    if (_busySessionId != null) return;
    final confirmed = await confirmReopenLocalSession(
      context,
      sessionTitle: session.title,
    );
    if (!confirmed || !mounted) return;
    final sessions = context.read<SessionProvider>();
    final logs = context.read<LogProvider>();
    setState(() => _busySessionId = session.sessionId);
    try {
      await sessions.reopenLocalSession(session.sessionId);
      try {
        await logs.reloadForSession(session.sessionId, propagateErrors: true);
      } catch (error, stackTrace) {
        debugPrint(
          '[SessionHistory] reopened session log load failed: '
          '$error\n$stackTrace',
        );
        if (!mounted) return;
        setState(() => _busySessionId = null);
        widget.onSessionOpened?.call();
        showReopenedSessionLogsUnavailable(
          context,
          logs: logs,
          sessionId: session.sessionId,
          sessionTitle: session.title,
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(context.l10n.historySessionReopened(session.title)),
        ),
      );
      widget.onSessionOpened?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busySessionId = null);
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(localSessionReopenErrorText(context, error)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      _reload();
    }
  }

  Future<void> _close(Session session) async {
    if (_busySessionId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.historySessionCloseTitle),
        content: Text(
          dialogContext.l10n.historySessionCloseConfirmation(session.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.historySessionCloseTitle),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busySessionId = session.sessionId);
    try {
      await context
          .read<SessionProvider>()
          .closeSessionLocally(session.sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.historySessionClosed)),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busySessionId = null);
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(historySessionCloseErrorText(context, error)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _delete(Session session) async {
    if (_busySessionId != null) return;
    final confirmed = await confirmDeleteLocalSession(
      context,
      sessionTitle: session.title,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busySessionId = session.sessionId);
    final sessions = context.read<SessionProvider>();
    final logs = context.read<LogProvider>();
    try {
      await sessions.deleteSessionLocally(session.sessionId);
      await logs.forgetDeletedSession(session.sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.historySessionDeleted)),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() => _busySessionId = null);
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(context.l10n.historySessionDeleteFailed('$error')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  String _statusLabel(String status) => switch (status) {
        'active' => context.l10n.sessionActive,
        'closed' => context.l10n.sessionClosed,
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    final currentSessionId = context.watch<SessionProvider>().currentSessionId;
    final sharing = context.watch<AccountShareProvider>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final pageSize = compact ? 5 : 10;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FutureBuilder<List<SessionListEntry>>(
              future: _entries,
              builder: (context, snapshot) {
                final entries = (snapshot.data ?? const <SessionListEntry>[])
                    .where((entry) =>
                        entry.isShared ||
                        entry.session.sessionId != currentSessionId);
                final collections = {
                  _SessionCollection.all: context.l10n.hubAllRecords,
                  _SessionCollection.personal: context.l10n.hubMyRecords,
                  if (_collection == _SessionCollection.collaboration ||
                      entries.any((entry) => entry.hasCollaborationBinding))
                    _SessionCollection.collaboration:
                        context.l10n.hubTogetherRecords,
                  if (_collection == _SessionCollection.shared ||
                      sharing.supportsLegacySharing ||
                      sharing.pendingShareCount > 0 ||
                      entries.any((entry) => entry.isShared))
                    _SessionCollection.shared: context.l10n.sharedSessionBadge,
                  _SessionCollection.closed: context.l10n.hubEndedRecords,
                };
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final collection in collections.entries)
                      ChoiceChip(
                        key: Key('session-collection-${collection.key.name}'),
                        label: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(collection.value),
                          if (collection.key == _SessionCollection.shared &&
                              sharing.pendingShareCount > 0) ...[
                            const SizedBox(width: 6),
                            const ShareInvitationBadge(
                                key: Key('shared-collection-invitation-badge')),
                          ],
                        ]),
                        selected: _collection == collection.key,
                        onSelected: (_) {
                          setState(() {
                            _collection = collection.key;
                            _page = 0;
                          });
                          if (collection.key == _SessionCollection.shared) {
                            unawaited(sharing.refresh());
                          }
                        },
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (_collection == _SessionCollection.shared) ...[
              const ShareInvitationsPanel(),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: compact ? constraints.maxWidth : 360,
                  child: TextField(
                    key: const Key('session-history-search'),
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.l10n.searchSessions,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: MaterialLocalizations.of(context)
                                  .cancelButtonLabel,
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                  _page = 0;
                                });
                              },
                              icon: const Icon(Icons.clear),
                            ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() {
                      _query = value;
                      _page = 0;
                    }),
                  ),
                ),
                if (sharing.supportsBatchSharing)
                  OutlinedButton.icon(
                      key: const Key('history-share-sessions'),
                      onPressed: () => showSessionSharingDialog(context),
                      icon: const ShareInvitationBadge(
                          key: Key('history-sharing-invitation-badge'),
                          child: Icon(Icons.share_outlined)),
                      label: Text(context.l10n.shareSessionsTitle)),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<SessionListEntry>>(
              future: _entries,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.l10n.historySessionsLoadFailed(
                              '${snapshot.error}',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh),
                            label: Text(context.l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final filtered = _filtered(
                  snapshot.data ?? const <SessionListEntry>[],
                  currentSessionId,
                );
                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      context.l10n.historySessionsEmpty,
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final pageCount = (filtered.length / pageSize).ceil();
                final effectivePage = _page.clamp(0, pageCount - 1);
                if (effectivePage != _page) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _page = effectivePage);
                  });
                }
                final start = effectivePage * pageSize;
                final visible =
                    filtered.skip(start).take(pageSize).toList(growable: false);
                return Column(
                  children: [
                    for (var index = 0; index < visible.length; index++) ...[
                      _buildRow(visible[index], compact: compact),
                      if (index != visible.length - 1)
                        const SizedBox(height: 8),
                    ],
                    if (pageCount > 1) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            context.l10n.sessionPage(
                              effectivePage + 1,
                              pageCount,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            key: const Key('session-history-previous-page'),
                            tooltip: MaterialLocalizations.of(context)
                                .previousPageTooltip,
                            onPressed: effectivePage == 0
                                ? null
                                : () => setState(() => _page--),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            key: const Key('session-history-next-page'),
                            tooltip: MaterialLocalizations.of(context)
                                .nextPageTooltip,
                            onPressed: effectivePage >= pageCount - 1
                                ? null
                                : () => setState(() => _page++),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildRow(SessionListEntry entry, {required bool compact}) {
    final session = entry.session;
    final busy = _busySessionId == session.sessionId;
    final createdAt = DateTime.tryParse(session.createdAt)?.toLocal();
    final createdLabel = createdAt == null
        ? session.createdAt
        : '${MaterialLocalizations.of(context).formatMediumDate(createdAt)} '
            '${TimeOfDay.fromDateTime(createdAt).format(context)}';
    final canReopenLocally = session.status == 'closed' &&
        !entry.hasCollaborationBinding &&
        !entry.isShared;
    final opensCollaborationManagement = entry.hasCollaborationBinding &&
        session.status == 'closed' &&
        widget.onCollaborationSessionManage != null;
    final mainAction = entry.isShared
        ? OutlinedButton.icon(
            key: Key('browse-shared-session-${session.sessionId}'),
            onPressed: busy ? null : () => _browseShared(entry),
            icon: const Icon(Icons.visibility_outlined),
            label: Text(context.l10n.browseSharedSession),
          )
        : canReopenLocally
            ? FilledButton.tonalIcon(
                key: Key('reopen-history-session-${session.sessionId}'),
                onPressed: busy ? null : () => _reopen(session),
                icon: const Icon(Icons.play_circle_outline),
                label: Text(context.l10n.historySessionReopenAction),
              )
            : OutlinedButton.icon(
                key: Key('open-history-session-${session.sessionId}'),
                onPressed: busy
                    ? null
                    : () => opensCollaborationManagement
                        ? _openCollaborationManagement(session)
                        : _open(session),
                icon: const Icon(Icons.open_in_new),
                label: Text(
                  opensCollaborationManagement
                      ? context.l10n.openAndManageCollaboration
                      : context.l10n.historySessionOpen,
                ),
              );
    final menu = entry.isShared
        ? const SizedBox.shrink()
        : PopupMenuButton<_SessionRowAction>(
            key: Key('session-history-menu-${session.sessionId}'),
            tooltip: context.l10n.moreSessionActions,
            enabled: !busy,
            onSelected: (action) => switch (action) {
              _SessionRowAction.closeLocally => _close(session),
              _SessionRowAction.manageCollaboration =>
                _openCollaborationManagement(session),
              _SessionRowAction.deleteLocally => _delete(session),
            },
            itemBuilder: (context) => [
              if (entry.hasCollaborationBinding)
                PopupMenuItem(
                  value: _SessionRowAction.manageCollaboration,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(context.l10n.manageCollaboration),
                  ),
                ),
              if (session.status == 'active' && !entry.hasCollaborationBinding)
                PopupMenuItem(
                  value: _SessionRowAction.closeLocally,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(context.l10n.historySessionCloseTitle),
                  ),
                ),
              PopupMenuItem(
                value: _SessionRowAction.deleteLocally,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_forever,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    context.l10n.historySessionDeleteAction,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          );
    final copy = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          entry.isShared
              ? Icons.share_outlined
              : entry.hasCollaborationBinding
                  ? Icons.groups_outlined
                  : session.status == 'active'
                      ? Icons.radio_button_checked
                      : Icons.lock_clock_outlined,
          color: session.status == 'active'
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (entry.isShared)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Chip(
                        key: Key('session-share-badge-${session.sessionId}'),
                        label: Text(context.l10n.sharedSessionBadge),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '$createdLabel · ${_statusLabel(session.status)} · '
                '${entry.isShared ? context.l10n.sharedSessionFrom(entry.sharedGrantorUsername ?? '') : entry.hasCollaborationBinding ? context.l10n.manageCollaboration : context.l10n.localSession}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
    return Card(
      key: Key(
          'session-history-row-${entry.sharedSession?.identity ?? session.sessionId}'),
      margin: EdgeInsets.zero,
      elevation: 0,
      child: InkWell(
        onTap: busy
            ? null
            : () => entry.isShared ? _browseShared(entry) : _open(session),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copy,
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (busy)
                          const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          Flexible(child: mainAction),
                        menu,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 12),
                    if (busy)
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      mainAction,
                    menu,
                  ],
                ),
        ),
      ),
    );
  }
}

Future<bool> confirmDeleteLocalSession(
  BuildContext context, {
  required String sessionTitle,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteSessionConfirmationDialog(
        sessionTitle: sessionTitle,
      ),
    ) ??
    false;

Future<void> showSessionHistoryDialog(
  BuildContext context, {
  VoidCallback? onSessionOpened,
}) async {
  final sessionProvider = context.read<SessionProvider>();
  final logProvider = context.read<LogProvider>();
  final collaborationSessionIds = <String>{};
  String? reopenedWithoutLogsSessionId;
  Future<void> loadAndSwitch(Session session) async {
    final previousSessionId = sessionProvider.currentSessionId;
    try {
      // Load the target before persisting it as current. This keeps a failed
      // history open from leaving the two providers out of sync.
      await logProvider.reloadForSession(
        session.sessionId,
        propagateErrors: true,
      );
      await sessionProvider.switchToSession(session.sessionId);
    } catch (error, stackTrace) {
      try {
        await logProvider.reloadForSession(
          previousSessionId,
          propagateErrors: true,
        );
      } catch (rollbackError, rollbackStackTrace) {
        debugPrint(
          '[SessionHistory] log rollback failed: '
          '$rollbackError\n$rollbackStackTrace',
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  final selected = await showDialog<Session>(
    context: context,
    builder: (_) => SessionHistoryDialog(
      currentSessionId: sessionProvider.currentSessionId,
      currentSessionIdGetter: () => sessionProvider.currentSessionId,
      loadSessions: () async {
        final entries = await sessionProvider.listAvailableSessionEntries();
        collaborationSessionIds
          ..clear()
          ..addAll(entries
              .where((entry) => entry.hasCollaborationBinding)
              .map((entry) => entry.session.sessionId));
        return entries.map((entry) => entry.session).toList();
      },
      isCollaborationSession: (session) =>
          collaborationSessionIds.contains(session.sessionId),
      openSession: loadAndSwitch,
      reopenSession: (session) async {
        await sessionProvider.reopenLocalSession(session.sessionId);
        try {
          await logProvider.reloadForSession(
            session.sessionId,
            propagateErrors: true,
          );
        } catch (error, stackTrace) {
          try {
            await sessionProvider.reloadCurrentSession();
          } catch (refreshError, refreshStackTrace) {
            debugPrint(
              '[SessionHistory] reopened session refresh failed: '
              '$refreshError\n$refreshStackTrace',
            );
          }
          reopenedWithoutLogsSessionId = session.sessionId;
          debugPrint(
            '[SessionHistory] reopened session log load failed: '
            '$error\n$stackTrace',
          );
        }
      },
      closeSession: (session) => closeSessionFromHistory(
        session: session,
        hasCollaborationBinding: (sessionId) async =>
            await RustApi.getSessionCollaborationBinding(
              sessionId: sessionId,
            ) !=
            null,
        closeLocalSession: (target) async {
          final closed =
              await sessionProvider.closeSessionLocally(target.sessionId);
          if (sessionProvider.currentSessionId == closed.sessionId) {
            await logProvider.reloadForSession(
              closed.sessionId,
              propagateErrors: true,
            );
          }
        },
      ),
      canCloseCurrentSession: sessionProvider.currentSessionId != null,
      deleteSession: (session) async {
        await sessionProvider.deleteSessionLocally(session.sessionId);
        await logProvider.forgetDeletedSession(session.sessionId);
      },
    ),
  );
  if (selected == null || !context.mounted) return;
  onSessionOpened?.call();
  if (reopenedWithoutLogsSessionId == selected.sessionId) {
    showReopenedSessionLogsUnavailable(
      context,
      logs: logProvider,
      sessionId: selected.sessionId,
      sessionTitle: selected.title,
    );
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  final message = context.l10n.historySessionSwitched(selected.title);
  messenger.showLoggedSnackBar(
    SnackBar(
      content: Text(message),
    ),
  );
}

class SessionHistoryDialog extends StatefulWidget {
  const SessionHistoryDialog({
    super.key,
    required this.currentSessionId,
    required this.loadSessions,
    required this.openSession,
    required this.reopenSession,
    required this.closeSession,
    required this.deleteSession,
    this.canCloseCurrentSession = false,
    this.currentSessionIdGetter,
    this.isCollaborationSession,
  });

  final String? currentSessionId;
  final SessionHistoryCurrentIdGetter? currentSessionIdGetter;
  final SessionHistoryLoader loadSessions;
  final SessionHistoryAction openSession;
  final SessionHistoryAction reopenSession;
  final SessionHistoryAction closeSession;
  final SessionHistoryAction deleteSession;
  final bool canCloseCurrentSession;
  final bool Function(Session session)? isCollaborationSession;

  @override
  State<SessionHistoryDialog> createState() => _SessionHistoryDialogState();
}

class _SessionHistoryDialogState extends State<SessionHistoryDialog> {
  late Future<List<Session>> _sessions;
  String? _busySessionId;

  @override
  void initState() {
    super.initState();
    _sessions = widget.loadSessions();
  }

  void _reload() {
    setState(() => _sessions = widget.loadSessions());
  }

  Future<void> _open(Session session) async {
    if (_busySessionId != null) return;
    setState(() => _busySessionId = session.sessionId);
    try {
      await widget.openSession(session);
      if (!mounted) return;
      setState(() => _busySessionId = null);
      Navigator.of(context).pop(session);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busySessionId = null);
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content:
              Text(context.l10n.historySessionOpenFailed(error.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _close(Session session) async {
    if (_busySessionId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.historySessionCloseTitle),
        content: Text(
          context.l10n.historySessionCloseConfirmation(session.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.historySessionCloseTitle),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busySessionId = session.sessionId);
    try {
      await widget.closeSession(session);
      if (!mounted) return;
      setState(() {
        _busySessionId = null;
        _sessions = widget.loadSessions();
      });
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.historySessionClosed)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busySessionId = null);
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(historySessionCloseErrorText(context, error)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _reopen(Session session) async {
    if (_busySessionId != null) return;
    final confirmed = await confirmReopenLocalSession(
      context,
      sessionTitle: session.title,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busySessionId = session.sessionId);
    try {
      await widget.reopenSession(session);
      if (!mounted) return;
      setState(() => _busySessionId = null);
      Navigator.of(context).pop(session);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busySessionId = null;
        _sessions = widget.loadSessions();
      });
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(localSessionReopenErrorText(context, error)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _delete(Session session) async {
    if (_busySessionId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteSessionConfirmationDialog(
        sessionTitle: session.title,
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busySessionId = session.sessionId);
    try {
      await widget.deleteSession(session);
      if (!mounted) return;
      setState(() {
        _busySessionId = null;
        _sessions = widget.loadSessions();
      });
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.historySessionDeleted)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busySessionId = null);
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content:
              Text(context.l10n.historySessionDeleteFailed(error.toString())),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.62;
    return AlertDialog(
      key: const Key('session-history-dialog'),
      title: Text(context.l10n.historySessions),
      content: SizedBox(
        width: 620,
        height: height.clamp(280, 560),
        child: FutureBuilder<List<Session>>(
          future: _sessions,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n
                          .historySessionsLoadFailed(snapshot.error.toString()),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.retry),
                    ),
                  ],
                ),
              );
            }
            final sessions = snapshot.data ?? const <Session>[];
            if (sessions.isEmpty) {
              return Center(child: Text(context.l10n.historySessionsEmpty));
            }
            return ListView.separated(
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) => _sessionTile(sessions[index]),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
      ],
    );
  }

  Widget _sessionTile(Session session) {
    final currentSessionId =
        widget.currentSessionIdGetter?.call() ?? widget.currentSessionId;
    final isCurrent = currentSessionId == session.sessionId;
    final isActive = session.status == 'active';
    final isClosed = session.status == 'closed';
    final isCollaboration =
        widget.isCollaborationSession?.call(session) ?? false;
    final busy = _busySessionId == session.sessionId;
    final createdAt = DateTime.tryParse(session.createdAt)?.toLocal();
    final createdLabel = createdAt == null
        ? session.createdAt
        : '${MaterialLocalizations.of(context).formatMediumDate(createdAt)} '
            '${TimeOfDay.fromDateTime(createdAt).format(context)}';
    return ListTile(
      key: Key('session-history-tile-${session.sessionId}'),
      enabled: !isCurrent && _busySessionId == null,
      onTap: isCurrent || _busySessionId != null ? null : () => _open(session),
      leading: Icon(
        isActive ? Icons.radio_button_checked : Icons.lock_clock_outlined,
        color: isActive ? Colors.green : null,
      ),
      title: Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '$createdLabel · '
        '${isActive ? context.l10n.sessionActive : isClosed ? context.l10n.sessionClosed : session.status}',
      ),
      trailing: busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isCurrent
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(label: Text(context.l10n.historySessionCurrent)),
                    if (isActive &&
                        widget.canCloseCurrentSession &&
                        !isCollaboration)
                      IconButton(
                        key: Key('close-history-session-${session.sessionId}'),
                        tooltip: context.l10n.historySessionCloseTitle,
                        onPressed: _busySessionId == null
                            ? () => _close(session)
                            : null,
                        icon: Icon(
                          Icons.stop_circle_outlined,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (isClosed && !isCollaboration)
                      IconButton(
                        key: Key(
                          'reopen-history-session-${session.sessionId}',
                        ),
                        tooltip: context.l10n.historySessionReopenAction,
                        onPressed: _busySessionId == null
                            ? () => _reopen(session)
                            : null,
                        icon: Icon(
                          Icons.play_circle_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('open-history-session-${session.sessionId}'),
                      tooltip: context.l10n.historySessionOpen,
                      onPressed:
                          _busySessionId == null ? () => _open(session) : null,
                      icon: const Icon(Icons.open_in_new),
                    ),
                    if (isActive && !isCollaboration)
                      IconButton(
                        key: Key('close-history-session-${session.sessionId}'),
                        tooltip: context.l10n.historySessionCloseTitle,
                        onPressed: _busySessionId == null
                            ? () => _close(session)
                            : null,
                        icon: Icon(
                          Icons.stop_circle_outlined,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (isClosed && !isCollaboration)
                      IconButton(
                        key: Key(
                          'reopen-history-session-${session.sessionId}',
                        ),
                        tooltip: context.l10n.historySessionReopenAction,
                        onPressed: _busySessionId == null
                            ? () => _reopen(session)
                            : null,
                        icon: Icon(
                          Icons.play_circle_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    IconButton(
                      key: Key(
                        'delete-history-session-${session.sessionId}',
                      ),
                      tooltip: context.l10n.historySessionDeleteAction,
                      onPressed: _busySessionId == null
                          ? () => _delete(session)
                          : null,
                      icon: Icon(
                        Icons.delete_forever,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _DeleteSessionConfirmationDialog extends StatefulWidget {
  const _DeleteSessionConfirmationDialog({required this.sessionTitle});

  final String sessionTitle;

  @override
  State<_DeleteSessionConfirmationDialog> createState() =>
      _DeleteSessionConfirmationDialogState();
}

class _DeleteSessionConfirmationDialogState
    extends State<_DeleteSessionConfirmationDialog> {
  final _nameController = TextEditingController();
  bool _nameMatches = false;
  bool _nameChanged = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        key: const Key('delete-history-session-dialog'),
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
                key: const Key('delete-history-session-expected-name'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('delete-history-session-name'),
                controller: _nameController,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: context.l10n.historySessionDeleteNameLabel,
                  border: const OutlineInputBorder(),
                  errorText: _nameChanged && !_nameMatches
                      ? context.l10n.historySessionDeleteNameMismatch
                      : null,
                ),
                onChanged: (value) {
                  final matches = value.trim() == widget.sessionTitle;
                  if (matches != _nameMatches || !_nameChanged) {
                    setState(() {
                      _nameChanged = true;
                      _nameMatches = matches;
                    });
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
            key: const Key('confirm-delete-history-session'),
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
