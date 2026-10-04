import 'dart:async';
import 'package:openlogtool/utils/app_snack_bar.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/collaboration_conflict.dart';
import 'package:openlogtool/models/collaboration_dto.dart';
import 'package:openlogtool/models/live_draft.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/personal_cloud_provider.dart';
import 'package:openlogtool/widgets/session_friend_actions.dart';
import 'package:openlogtool/services/collaboration_sync.dart';
import 'package:openlogtool/theme/app_theme.dart';
import 'package:openlogtool/widgets/collaboration_conflict_center.dart';
import 'package:openlogtool/widgets/collaboration_local_session_action.dart';
import 'package:openlogtool/widgets/session_people_actions.dart';
import 'package:openlogtool/widgets/app_section_tabs.dart';
import 'package:openlogtool/widgets/share_invitation_badge.dart';
import 'package:openlogtool/widgets/settings/settings_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

typedef PublicShareUriOpener = Future<bool> Function(Uri uri);

enum _CloseCollaborationAction { close, discardAndClose, submitAndClose }

enum _CollaborationView { overview, synchronization, access }

enum _SynchronizationView { offlineRecords, conflicts }

enum _AccessView { members, invites, publicShare }

bool _liveDraftHasCloseBlockingContent(LiveDraftFieldsDto fields) {
  bool hasText(String field) => fields[field].trim().isNotEmpty;
  bool hasNonDefaultReport(String field) {
    final value = fields[field].trim();
    return value.isNotEmpty && value != '59';
  }

  return const [
        'callsign',
        'qth',
        'device',
        'power',
        'antenna',
        'height',
        'remarks',
      ].any(hasText) ||
      hasNonDefaultReport('rstSent') ||
      hasNonDefaultReport('rstRcvd');
}

bool _liveDraftIsComplete(LiveDraftFieldsDto fields) => const [
      'time',
      'controller',
      'callsign'
    ].every((field) => fields[field].trim().isNotEmpty);

class CollaborationScreen extends StatefulWidget {
  const CollaborationScreen({
    super.key,
    this.publicShareUriOpener,
    this.focusPublicShare = false,
    this.focusParticipants = false,
  });

  final PublicShareUriOpener? publicShareUriOpener;
  final bool focusPublicShare;
  final bool focusParticipants;

  @override
  State<CollaborationScreen> createState() => _CollaborationScreenState();
}

class _CollaborationScreenState extends State<CollaborationScreen> {
  final _inviteCodeController = TextEditingController();
  final _publicShareAnchorKey = GlobalKey();
  InviteRole _inviteRole = InviteRole.editor;
  late _CollaborationView _selectedView;
  _SynchronizationView _selectedSynchronizationView =
      _SynchronizationView.offlineRecords;
  late _AccessView _selectedAccessView;

  @override
  void initState() {
    super.initState();
    _selectedView = widget.focusPublicShare || widget.focusParticipants
        ? _CollaborationView.access
        : _CollaborationView.overview;
    _selectedAccessView =
        widget.focusPublicShare ? _AccessView.publicShare : _AccessView.members;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final collaboration = context.read<CollaborationProvider>();
        unawaited(_initialize(collaboration));
      }
    });
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.collaborationScreenTitle)),
      body: Consumer3<CollaborationProvider, ServerProvider, SessionProvider>(
        builder: (context, collaboration, server, sessions, _) {
          final showOwnerAccess = server.isLoggedIn &&
              collaboration.state == CollaborationState.ready &&
              collaboration.isOwner;
          final hasKnownOwnerAccess = server.isLoggedIn &&
              collaboration.binding != null &&
              collaboration.effectiveRole == SessionRole.owner;
          final availableViews = <_CollaborationView>[
            _CollaborationView.overview,
            if (collaboration.binding != null)
              _CollaborationView.synchronization,
            if (showOwnerAccess ||
                hasKnownOwnerAccess ||
                widget.focusPublicShare)
              _CollaborationView.access,
          ];
          final selectedView = availableViews.contains(_selectedView)
              ? _selectedView
              : _CollaborationView.overview;
          return AppPageFrame(
            scrollKey: const PageStorageKey('collaboration-management-page'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildViewSelector(
                  collaboration,
                  availableViews,
                  selectedView,
                ),
                const SizedBox(height: AppSpace.md),
                switch (selectedView) {
                  _CollaborationView.overview => _buildOverviewView(
                      collaboration,
                      server,
                      sessions,
                    ),
                  _CollaborationView.synchronization =>
                    _buildSynchronizationView(collaboration),
                  _CollaborationView.access => _buildAccessView(
                      collaboration,
                      server,
                      showOwnerAccess: showOwnerAccess,
                      preparingOwnerAccess: hasKnownOwnerAccess,
                    ),
                },
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildViewSelector(
    CollaborationProvider collaboration,
    List<_CollaborationView> availableViews,
    _CollaborationView selectedView,
  ) {
    final conflictCount = collaboration.conflictCount;
    final problemCount = collaboration.offlineRecords.length + conflictCount;
    return AppSectionTabs<_CollaborationView>(
      key: const Key('collaboration-view-selector'),
      segments: [
        if (availableViews.contains(_CollaborationView.overview))
          ButtonSegment(
            value: _CollaborationView.overview,
            icon: const Icon(Icons.dashboard_outlined),
            label: Text(context.l10n.collaborationOverviewTab),
          ),
        if (availableViews.contains(_CollaborationView.synchronization))
          ButtonSegment(
            value: _CollaborationView.synchronization,
            icon: const Icon(Icons.sync_outlined),
            label: Text(
              problemCount == 0
                  ? context.l10n.collaborationSyncConflictsTab
                  : '${context.l10n.collaborationSyncConflictsTab} '
                      '($problemCount)',
            ),
          ),
        if (availableViews.contains(_CollaborationView.access))
          ButtonSegment(
            value: _CollaborationView.access,
            icon: RequestBadge(
                count: context
                        .watch<AccountShareProvider?>()
                        ?.pendingSessionApplications(
                            collaboration.binding?.sessionId) ??
                    0,
                child: const Icon(Icons.group_outlined)),
            label: Text(context.l10n.sessionPeopleTitle),
          ),
      ],
      selected: {selectedView},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) return;
        setState(() => _selectedView = selection.first);
      },
    );
  }

  Widget _buildOverviewView(
    CollaborationProvider collaboration,
    ServerProvider server,
    SessionProvider sessions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _serverCard(server),
        if (collaboration.progressLabel.isNotEmpty ||
            collaboration.errorMessage != null ||
            collaboration.syncErrorMessage != null) ...[
          const SizedBox(height: 12),
          _statusCard(collaboration),
        ],
        if (sessions.currentSession != null) ...[
          const SizedBox(height: 12),
          _sessionCard(collaboration, sessions),
        ],
        if (server.isLoggedIn && collaboration.canJoinWithInvite) ...[
          const SizedBox(height: 12),
          _joinCard(collaboration),
        ],
      ],
    );
  }

  Widget _buildSynchronizationView(CollaborationProvider collaboration) {
    final selected = _selectedSynchronizationView;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (collaboration.progressLabel.isNotEmpty ||
            collaboration.errorMessage != null ||
            collaboration.syncErrorMessage != null) ...[
          _statusCard(collaboration),
          const SizedBox(height: 12),
        ],
        AppSectionTabs<_SynchronizationView>(
          key: const Key('collaboration-sync-view-selector'),
          secondary: true,
          segments: [
            ButtonSegment(
              value: _SynchronizationView.offlineRecords,
              icon: const Icon(Icons.cloud_off_outlined),
              label: Text(
                '${context.l10n.offlineReviewTitle} '
                '(${collaboration.offlineRecords.length})',
              ),
            ),
            ButtonSegment(
              value: _SynchronizationView.conflicts,
              icon: const Icon(Icons.rule_folder_outlined),
              label: Text(
                '${context.l10n.conflictCenterTitle} '
                '(${collaboration.conflictCount})',
              ),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            setState(() => _selectedSynchronizationView = selection.first);
          },
        ),
        const SizedBox(height: 12),
        if (selected == _SynchronizationView.offlineRecords)
          collaboration.offlineRecords.isEmpty
              ? _emptyState(
                  Icons.cloud_done_outlined,
                  context.l10n.offlineReviewTitle,
                  context.l10n.collaborationSyncSectionHint,
                )
              : _offlineReviewCard(collaboration)
        else
          CollaborationConflictCenter(
            conflicts: collaboration.openConflicts,
            loading: collaboration.conflictsLoading,
            resolvingConflictId: collaboration.resolvingConflictId,
            enabled: !collaboration.isBusy && collaboration.canResolveConflicts,
            onRefresh:
                collaboration.isBusy || !collaboration.canResolveConflicts
                    ? null
                    : () => unawaited(
                          _run(collaboration.refreshOpenConflicts),
                        ),
            onAcceptRemote: (conflictId) => unawaited(
              _confirmConflictResolution(
                collaboration,
                conflictId,
                CollaborationConflictResolution.useRemote,
              ),
            ),
            onKeepLocal: (conflictId) => unawaited(
              _confirmConflictResolution(
                collaboration,
                conflictId,
                CollaborationConflictResolution.keepLocal,
              ),
            ),
            onCopyLocalAsNew: (conflictId) => unawaited(
              _confirmConflictResolution(
                collaboration,
                conflictId,
                CollaborationConflictResolution.copyLocalAsNew,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAccessView(
    CollaborationProvider collaboration,
    ServerProvider server, {
    required bool showOwnerAccess,
    required bool preparingOwnerAccess,
  }) {
    if (!showOwnerAccess) {
      return KeyedSubtree(
        key: _publicShareAnchorKey,
        child: _publicShareAccessRequiredCard(
          preparingOwnerAccess: preparingOwnerAccess,
        ),
      );
    }

    final availableViews = <_AccessView>[
      _AccessView.members,
      if (collaboration.supportsInvites) _AccessView.invites,
      _AccessView.publicShare,
    ];
    final selected = availableViews.contains(_selectedAccessView)
        ? _selectedAccessView
        : _AccessView.members;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionTabs<_AccessView>(
          key: const Key('collaboration-access-view-selector'),
          secondary: true,
          segments: [
            ButtonSegment(
              value: _AccessView.members,
              icon: RequestBadge(
                  count: context
                          .watch<AccountShareProvider?>()
                          ?.pendingSessionApplications(
                              collaboration.binding?.sessionId) ??
                      0,
                  child: const Icon(Icons.people_outline)),
              label: Text(
                '${context.l10n.membersTitle} '
                '(${collaboration.members.length})',
              ),
            ),
            if (collaboration.supportsInvites)
              ButtonSegment(
                value: _AccessView.invites,
                icon: const Icon(Icons.mark_email_unread_outlined),
                label: Text(
                  '${context.l10n.legacyInviteCodes} '
                  '(${collaboration.invites.length})',
                ),
              ),
            ButtonSegment(
              value: _AccessView.publicShare,
              icon: const Icon(Icons.public_outlined),
              label: Text(
                '${context.l10n.publicShareManagement} '
                '(${collaboration.publicShares.length})',
              ),
            ),
          ],
          selected: {selected},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            setState(() => _selectedAccessView = selection.first);
          },
        ),
        const SizedBox(height: 12),
        switch (selected) {
          _AccessView.members => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if ((context.watch<AccountShareProvider?>()?.supportsFriends ??
                        false) &&
                    collaboration.binding != null) ...[
                  SessionPeopleActions(
                      key: ValueKey(collaboration.binding!.sessionId),
                      sessionId: collaboration.binding!.sessionId),
                  const SizedBox(height: AppSpace.md),
                ],
                _memberManagementCard(collaboration, server),
              ],
            ),
          _AccessView.invites => _inviteManagementCard(collaboration),
          _AccessView.publicShare => KeyedSubtree(
              key: _publicShareAnchorKey,
              child: _publicShareCard(collaboration),
            ),
        },
      ],
    );
  }

  Widget _emptyState(IconData icon, String title, String description) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: colors.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _initialize(CollaborationProvider collaboration) async {
    final social = context.read<AccountShareProvider?>();
    if (social?.supportsFriends == true) unawaited(social!.refresh());
    await _run(collaboration.refreshCurrentSession);
    if (mounted && collaboration.supportsPublicShareManagement) {
      await _run(collaboration.refreshPublicShares);
    }
  }

  Widget _publicShareAccessRequiredCard({
    required bool preparingOwnerAccess,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('public-share-access-required'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              preparingOwnerAccess ? Icons.sync : Icons.public_off_outlined,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.publicShareManagement,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preparingOwnerAccess
                        ? context.l10n.publicShareManagementHint
                        : context.l10n.publicShareAccessRequired,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _publicShareCard(CollaborationProvider collaboration) {
    final created = collaboration.lastCreatedPublicShare;
    final createdUri = created != null &&
            created.active &&
            (created.secret?.isNotEmpty ?? false)
        ? collaboration.publicSharePageUri(created)
        : null;
    final activeShares = collaboration.publicShares
        .where((share) => share.active)
        .toList(growable: false);
    final supported = collaboration.supportsPublicShareManagement;
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('public-share-management'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.publicShareManagement,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(context.l10n.publicShareManagementHint),
            const SizedBox(height: 12),
            if (!supported)
              Container(
                key: const Key('public-share-unsupported'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: colors.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(child: Text(context.l10n.publicShareUnsupported)),
                  ],
                ),
              )
            else ...[
              if (createdUri != null)
                Container(
                  key: const Key('public-share-ready'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.public, color: colors.onPrimaryContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.l10n.publicShareCreatedTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: colors.onPrimaryContainer),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.l10n.publicShareCreatedHint,
                        style: TextStyle(color: colors.onPrimaryContainer),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        createdUri.toString(),
                        key: const Key('public-share-uri'),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            key: const Key('copy-public-share-link'),
                            onPressed: () => unawaited(
                              _run(
                                () => _copyPublicShare(
                                  collaboration,
                                  created!,
                                ),
                                success: context.l10n.publicShareLinkCopied,
                              ),
                            ),
                            icon: const Icon(Icons.copy),
                            label: Text(context.l10n.copyPublicShareLink),
                          ),
                          OutlinedButton.icon(
                            key: const Key('open-public-share-link'),
                            onPressed: () => unawaited(
                              _openPublicShare(collaboration, created!),
                            ),
                            icon: const Icon(Icons.open_in_new),
                            label: Text(context.l10n.openPublicShare),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else if (activeShares.isEmpty)
                Container(
                  key: const Key('public-share-empty'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Text(context.l10n.publicShareNoActiveLinks),
                )
              else
                Container(
                  key: const Key('public-share-secret-unavailable'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    context.l10n.publicShareSecretUnavailable,
                    style: TextStyle(color: colors.onTertiaryContainer),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('create-public-share-link'),
                    onPressed: collaboration.isBusy
                        ? null
                        : () => unawaited(
                              _createPublicShare(collaboration),
                            ),
                    icon: const Icon(Icons.add_link),
                    label: Text(context.l10n.createPublicShare),
                  ),
                  OutlinedButton.icon(
                    key: const Key('refresh-public-share-links'),
                    onPressed: collaboration.isBusy
                        ? null
                        : () => unawaited(
                              _run(collaboration.refreshPublicShares),
                            ),
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.refresh),
                  ),
                ],
              ),
              if (collaboration.publicShares.isNotEmpty) ...[
                const Divider(height: 28),
                Text(
                  context.l10n.publicShareLinksTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final share in collaboration.publicShares)
                  ListTile(
                    key: Key('public-share-${share.publicShareId}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      share.active ? Icons.public : Icons.link_off,
                    ),
                    title: SelectableText(share.publicShareId),
                    subtitle: Text(
                      share.active
                          ? context.l10n.publicShareExpiresAt(
                              share.expiresAt.toLocal().toString(),
                            )
                          : context.l10n.publicShareUnavailable,
                    ),
                    trailing: share.active
                        ? TextButton(
                            onPressed: collaboration.isBusy
                                ? null
                                : () => unawaited(
                                      _run(
                                        () => collaboration.revokePublicShare(
                                          share.publicShareId,
                                        ),
                                      ),
                                    ),
                            child: Text(context.l10n.revokePublicShare),
                          )
                        : null,
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _createPublicShare(
    CollaborationProvider collaboration,
  ) async {
    final expiresInHours = await showDialog<int>(
      context: context,
      builder: (_) => const _PublicShareExpiryDialog(),
    );
    if (!mounted || expiresInHours == null) return;

    await _run(
      () async {
        final share = await collaboration.createPublicShare(
          expiresInHours: expiresInHours,
        );
        await _copyPublicShare(collaboration, share);
        return share;
      },
      success: context.l10n.publicShareLinkCopied,
    );
  }

  Future<void> _copyPublicShare(
    CollaborationProvider collaboration,
    PublicShareDto share,
  ) =>
      Clipboard.setData(
        ClipboardData(text: collaboration.publicSharePageUri(share).toString()),
      );

  Future<void> _openPublicShare(
    CollaborationProvider collaboration,
    PublicShareDto share,
  ) async {
    final uri = collaboration.publicSharePageUri(share);
    final opener = widget.publicShareUriOpener ??
        (value) => launchUrl(value, mode: LaunchMode.externalApplication);
    try {
      final opened = await opener(uri);
      if (!opened) throw StateError('URL_LAUNCH_REJECTED');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.publicShareOpenFailed)),
      );
    }
  }

  Widget _offlineReviewCard(CollaborationProvider collaboration) {
    return Card(
      key: const Key('offline-live-draft-review'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.offlineReviewTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final record in collaboration.offlineRecords)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          child: Text('${record.provisionalOrdinal}'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.record['callsign'].isEmpty
                                    ? '—'
                                    : record.record['callsign'],
                              ),
                              Text(
                                [
                                  record.record['controller'],
                                  if (record.lastErrorCode != null)
                                    record.lastErrorCode!,
                                ]
                                    .where((value) => value.isNotEmpty)
                                    .join(' · '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        TextButton(
                          onPressed: collaboration.isBusy
                              ? null
                              : () => unawaited(
                                    _run(
                                      () => collaboration.resolveOfflineRecord(
                                        record.mutationId,
                                        OfflineRecordResolution.discard,
                                      ),
                                    ),
                                  ),
                          child: Text(context.l10n.resolutionDiscard),
                        ),
                        TextButton(
                          onPressed: collaboration.canEditLiveDraft &&
                                  !collaboration.isBusy
                              ? () => unawaited(
                                    _run(
                                      () => collaboration.resolveOfflineRecord(
                                        record.mutationId,
                                        OfflineRecordResolution
                                            .copyToCurrentDraft,
                                      ),
                                    ),
                                  )
                              : null,
                          child: Text(context.l10n.resolutionCopyCurrent),
                        ),
                        FilledButton.tonal(
                          onPressed: collaboration.canEditLiveDraft &&
                                  !collaboration.isBusy
                              ? () => unawaited(
                                    _run(
                                      () => collaboration.resolveOfflineRecord(
                                        record.mutationId,
                                        OfflineRecordResolution
                                            .submitAsDuplicate,
                                      ),
                                    ),
                                  )
                              : null,
                          child: Text(context.l10n.resolutionSubmitDuplicate),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _serverCard(ServerProvider server) {
    return Card(
      child: ListTile(
        leading: Icon(
          server.isLoggedIn ? Icons.cloud_done : Icons.cloud_off,
        ),
        title: Text(
          server.isLoggedIn
              ? server.username ?? context.l10n.serverLoggedIn
              : context.l10n.serverNotLoggedIn,
        ),
        subtitle: Text(
          server.isLoggedIn
              ? context.l10n.collaborationServerAccount(
                  server.serverUrl,
                  server.accountId ?? '',
                )
              : context.l10n.collaborationServerLoginHint,
        ),
        isThreeLine: server.isLoggedIn,
      ),
    );
  }

  Widget _statusCard(CollaborationProvider collaboration) {
    final error = collaboration.errorMessage ?? collaboration.syncErrorMessage;
    final errorCode = collaboration.errorMessage != null
        ? collaboration.errorCode
        : collaboration.syncErrorCode;
    return Card(
      color: error == null
          ? Theme.of(context).colorScheme.secondaryContainer
          : Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (collaboration.progressLabel.isNotEmpty)
              Text(collaboration.progressLabel),
            if (collaboration.progress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: collaboration.progress),
            ],
            if (error != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                '${errorCode ?? 'COLLABORATION_FAILED'}\n$error',
              ),
              if (collaboration.remoteCommitPendingLocalApply) ...[
                const SizedBox(height: 8),
                Text(context.l10n.remoteCommitPendingLocalApplyHint),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _joinCard(CollaborationProvider collaboration) {
    return Card(
      key: const Key('join-collaboration-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.joinCollaborationTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(context.l10n.joinCollaborationHint),
            const SizedBox(height: 12),
            TextField(
              key: const Key('collaboration-invite-code'),
              controller: _inviteCodeController,
              enabled: !collaboration.isBusy,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: context.l10n.inviteCodeLabel,
                hintText: 'ABCDE-12345',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('join-collaboration-button'),
              onPressed: collaboration.isBusy
                  ? null
                  : () => _run(
                        () => collaboration.joinWithCode(
                          _inviteCodeController.text,
                        ),
                        success: context.l10n.joinCollaborationSucceeded,
                      ),
              icon: const Icon(Icons.group_add),
              label: Text(context.l10n.join),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionCard(
    CollaborationProvider collaboration,
    SessionProvider sessions,
  ) {
    final session = sessions.currentSession!;
    final binding = collaboration.binding;
    final failedPublish = collaboration.state == CollaborationState.failed &&
        collaboration.failedOperation == 'publish';
    final isLocal = binding == null &&
        collaboration.state != CollaborationState.publishing &&
        !failedPublish;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const SizedBox(height: 8),
            if (isLocal)
              Text(context.l10n.localCollaborationSessionHint)
            else ...[
              Text(_roleLabel(collaboration.effectiveRole ?? binding?.role)),
              const SizedBox(height: 8),
              Text(_overviewSyncLabel(collaboration)),
              if (!collaboration.canEditCurrentSession) ...[
                const SizedBox(height: 4),
                Text(_readOnlyReason(collaboration, sessions)),
              ],
              ExpansionTile(
                key: const PageStorageKey<String>(
                    'collaboration-technical-details'),
                tilePadding: EdgeInsets.zero,
                title: Text(context.l10n.collaborationTechnicalDetails),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          session.sessionId,
                          // Keep its scroll offset separate from the tile's
                          // boolean expansion state in PageStorage.
                          key: PageStorageKey<String>(
                              'collaboration-session-id-${session.sessionId}'),
                        ),
                        Text(context.l10n.collaborationSessionSummary(
                          collaborationStateLabel(
                              context.l10n, collaboration.state.name),
                          _roleLabel(
                              collaboration.effectiveRole ?? binding?.role),
                        )),
                        Text(context.l10n.collaborationSyncSummary(
                          _transportLabel(collaboration.transportPhase),
                          collaboration.lastAppliedSeq,
                          collaboration.serverHeadSeq,
                        )),
                        Text(context.l10n.collaborationQueueSummary(
                          collaboration.pendingCount,
                          collaboration.conflictCount,
                          collaboration.rejectedCount,
                        )),
                        if (collaboration.lastSuccessfulSyncAt != null)
                          Text(context.l10n.collaborationLastSync(
                            collaboration.lastSuccessfulSyncAt!
                                .toLocal()
                                .toString(),
                          )),
                      ],
                    ),
                  ),
                ],
              ),
              if (collaboration.hasOpenSessionConflict) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.collaborationSessionConflictHint,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            if (!isLocal) ...[
              Text(context.l10n.collaborationLifecycleHint),
              const SizedBox(height: 12),
            ],
            if (isLocal ||
                collaboration.state == CollaborationState.publishing ||
                failedPublish)
              FilledButton.icon(
                onPressed: collaboration.isBusy
                    ? null
                    : () => _run(
                          () async {
                            if (isLocal) {
                              await confirmAndPublishCurrentSession(context);
                            } else {
                              final cloud =
                                  context.read<PersonalCloudProvider?>();
                              if (cloud == null) {
                                await collaboration.publishCurrentSession();
                              } else {
                                await cloud.runWithPersonalSyncPaused(
                                    collaboration.publishCurrentSession);
                              }
                            }
                            return null;
                          },
                          success: context.l10n.publishSessionSucceeded,
                        ),
                icon: const Icon(Icons.cloud_upload),
                label: Text(
                  isLocal
                      ? context.l10n.publishCollaborationSession
                      : context.l10n.retryPublishSession,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: collaboration.isBusy
                        ? null
                        : () {
                            unawaited(
                              _run(collaboration.refreshCurrentSession),
                            );
                          },
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.syncNowAndRefreshAccess),
                  ),
                  if (collaboration.isOwner) ...[
                    if (session.status == 'active' &&
                        !collaboration.canonicalSessionClosed) ...[
                      OutlinedButton.icon(
                        onPressed: collaboration.isBusy ||
                                collaboration.hasOpenSessionConflict
                            ? null
                            : () =>
                                _renameSession(collaboration, session.title),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(context.l10n.renameSession),
                      ),
                      OutlinedButton.icon(
                        key: const Key('close-collaboration-session'),
                        onPressed: collaboration.isBusy ||
                                collaboration.hasOpenSessionConflict
                            ? null
                            : () => _closeSession(collaboration),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: Text(context.l10n.closeSharedSession),
                      ),
                    ] else if (session.status == 'closed' &&
                        collaboration.canonicalSessionClosed)
                      FilledButton.tonalIcon(
                        onPressed: collaboration.isBusy ||
                                collaboration.hasOpenSessionConflict
                            ? null
                            : () => _reopenSession(collaboration),
                        icon: const Icon(Icons.play_circle_outline),
                        label: Text(context.l10n.reopenSession),
                      ),
                  ],
                  if (collaboration.effectiveRole != null &&
                      collaboration.effectiveRole != SessionRole.owner)
                    OutlinedButton.icon(
                      onPressed: collaboration.isBusy
                          ? null
                          : () => _leaveSession(collaboration),
                      icon: const Icon(Icons.logout),
                      label: Text(context.l10n.leaveSession),
                    ),
                ],
              ),
            const CollaborationLocalSessionAction(
              padding: EdgeInsets.only(top: 8),
              alignment: AlignmentDirectional.centerStart,
            ),
          ],
        ),
      ),
    );
  }

  String _overviewSyncLabel(CollaborationProvider collaboration) {
    if (collaboration.conflictCount > 0 ||
        collaboration.rejectedCount > 0 ||
        collaboration.offlineRecords.isNotEmpty) {
      return context.l10n.collaborationOverviewAttention;
    }
    if (collaboration.pendingCount > 0) {
      return context.l10n
          .collaborationOverviewPending(collaboration.pendingCount);
    }
    return collaboration.transportPhase == CollaborationTransportPhase.online
        ? context.l10n.collaborationOverviewOnline
        : context.l10n.collaborationOverviewOffline;
  }

  String _transportLabel(CollaborationTransportPhase phase) => switch (phase) {
        CollaborationTransportPhase.stopped => context.l10n.transportStopped,
        CollaborationTransportPhase.connecting =>
          context.l10n.transportConnecting,
        CollaborationTransportPhase.online => context.l10n.transportOnline,
        CollaborationTransportPhase.backingOff =>
          context.l10n.transportBackingOff,
        CollaborationTransportPhase.authRequired =>
          context.l10n.transportAuthRequired,
        CollaborationTransportPhase.incompatible =>
          context.l10n.transportIncompatible,
      };

  String _readOnlyReason(
    CollaborationProvider collaboration,
    SessionProvider sessions,
  ) {
    if (collaboration.state == CollaborationState.revoked) {
      return context.l10n.readOnlyRevoked;
    }
    if (sessions.currentSession?.status == 'closed' &&
        !collaboration.canonicalSessionClosed) {
      return context.l10n.readOnlyClosePending;
    }
    if (sessions.currentSession?.status == 'active' &&
        collaboration.canonicalSessionClosed) {
      return context.l10n.readOnlyReopenPending;
    }
    if (sessions.currentSession?.status != 'active') {
      return context.l10n.readOnlySessionClosed;
    }
    if (collaboration.effectiveRole == SessionRole.viewer) {
      return context.l10n.readOnlyViewer;
    }
    if (collaboration.state == CollaborationState.resyncing) {
      return context.l10n.readOnlyResyncing;
    }
    return context.l10n.readOnlyCheckingAccess;
  }

  Future<void> _renameSession(
    CollaborationProvider collaboration,
    String currentTitle,
  ) async {
    final controller = TextEditingController(text: currentTitle);
    final successMessage = context.l10n.sessionTitleQueued;
    try {
      final title = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.l10n.renameCollaborationSession),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: context.l10n.sessionTitleLabel,
            ),
            onSubmitted: (value) =>
                Navigator.of(dialogContext).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(context.l10n.saveLocally),
            ),
          ],
        ),
      );
      if (title == null || title == currentTitle) return;
      await _run(
        () => collaboration.renameCurrentSession(title),
        success: successMessage,
      );
    } finally {
      controller.dispose();
    }
  }

  Object _sessionActionIdentity(CollaborationProvider collaboration) {
    final binding = collaboration.binding;
    return (
      context.read<SessionProvider>().currentSessionId,
      binding?.sessionId,
      binding?.serverInstanceId,
      binding?.accountId,
      context.read<ServerProvider>().contextRevision,
    );
  }

  bool _sessionActionStillCurrent(
    CollaborationProvider collaboration,
    Object identity,
  ) {
    if (!mounted) return false;
    if (_sessionActionIdentity(collaboration) == identity) return true;
    ScaffoldMessenger.of(context).showLoggedSnackBar(
      SnackBar(content: Text(context.l10n.hubContextChanged)),
    );
    return false;
  }

  Future<void> _leaveSession(CollaborationProvider collaboration) async {
    final identity = _sessionActionIdentity(collaboration);
    final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.l10n.leaveSession),
            content: Text(context.l10n.leaveSessionConfirmation),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.confirm),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted || !_sessionActionStillCurrent(collaboration, identity)) {
      return;
    }
    await _run(collaboration.leaveCurrentSession);
  }

  Future<void> _closeSession(CollaborationProvider collaboration) async {
    final identity = _sessionActionIdentity(collaboration);
    try {
      if (collaboration.supportsLiveDraft) {
        await collaboration.refreshLiveDraft();
        if (!mounted) return;
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showLoggedSnackBar(
          SnackBar(content: Text(context.l10n.operationFailed('$error'))),
        );
      }
      return;
    }
    if (!_sessionActionStillCurrent(collaboration, identity)) return;
    final fields = collaboration.liveDraftFields;
    final hasDraft =
        fields != null && _liveDraftHasCloseBlockingContent(fields);
    final draftComplete = fields != null && _liveDraftIsComplete(fields);
    final foreignLocks = collaboration.liveDraftLocks
        .where(
          (lock) =>
              lock.expiresAt.isAfter(DateTime.now()) &&
              collaboration.fieldLockedByAnotherUser(lock.field),
        )
        .toList(growable: false);
    final draftLocked = foreignLocks.isNotEmpty;
    final canResolveDraft = collaboration.canEditLiveDraft && !draftLocked;
    final action = await showDialog<_CloseCollaborationAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('close-collaboration-session-dialog'),
        title: Text(context.l10n.closeCollaborationSessionTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.closeCollaborationSessionMessage),
            if (draftLocked) ...[
              const SizedBox(height: 12),
              Text(
                context.l10n.closeCollaborationDraftLocked(foreignLocks.length),
                key: const Key('close-collaboration-draft-locked'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ] else if (hasDraft) ...[
              const SizedBox(height: 12),
              Text(
                context.l10n.closeCollaborationDraftNotEmpty,
                key: const Key('close-collaboration-draft-not-empty'),
              ),
              if (!draftComplete) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.closeCollaborationDraftIncomplete,
                  key: const Key('close-collaboration-draft-incomplete'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          if (!hasDraft && !draftLocked)
            FilledButton(
              key: const Key('confirm-close-collaboration-session'),
              onPressed: () => Navigator.pop(
                dialogContext,
                _CloseCollaborationAction.close,
              ),
              child: Text(context.l10n.closeSharedSession),
            ),
          if (hasDraft && canResolveDraft)
            OutlinedButton(
              key: const Key('discard-live-draft-and-close'),
              onPressed: () => Navigator.pop(
                dialogContext,
                _CloseCollaborationAction.discardAndClose,
              ),
              child: Text(context.l10n.closeCollaborationDiscardAndClose),
            ),
          if (hasDraft && draftComplete && canResolveDraft)
            FilledButton(
              key: const Key('submit-live-draft-and-close'),
              onPressed: () => Navigator.pop(
                dialogContext,
                _CloseCollaborationAction.submitAndClose,
              ),
              child: Text(context.l10n.closeCollaborationSubmitAndClose),
            ),
        ],
      ),
    );
    if (!mounted ||
        action == null ||
        !_sessionActionStillCurrent(collaboration, identity)) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (action) {
        case _CloseCollaborationAction.close:
          break;
        case _CloseCollaborationAction.discardAndClose:
          await collaboration.discardCurrentLiveDraft();
          break;
        case _CloseCollaborationAction.submitAndClose:
          final disposition = await collaboration.commitCurrentLiveDraft();
          if (disposition == LiveDraftCommitDisposition.queuedOffline) {
            if (mounted) {
              messenger.showLoggedSnackBar(
                SnackBar(
                  content: Text(
                    context.l10n.closeCollaborationQueuedOffline,
                  ),
                ),
              );
            }
            return;
          }
          break;
      }
      if (!_sessionActionStillCurrent(collaboration, identity)) return;
      await collaboration.closeCurrentSession();
      if (mounted) {
        messenger.showLoggedSnackBar(
          SnackBar(content: Text(context.l10n.closeSessionQueued)),
        );
      }
    } catch (error) {
      if (mounted) {
        messenger.showLoggedSnackBar(
          SnackBar(content: Text(context.l10n.operationFailed('$error'))),
        );
      }
    }
  }

  Future<void> _reopenSession(CollaborationProvider collaboration) async {
    final identity = _sessionActionIdentity(collaboration);
    final successMessage = context.l10n.reopenSessionQueued;
    final accepted = await _confirm(
      context.l10n.reopenCollaborationSessionTitle,
      context.l10n.reopenCollaborationSessionMessage,
    );
    if (!accepted || !_sessionActionStillCurrent(collaboration, identity)) {
      return;
    }
    await _run(
      collaboration.reopenCurrentSession,
      success: successMessage,
    );
  }

  Future<void> _confirmConflictResolution(
    CollaborationProvider collaboration,
    String conflictId,
    CollaborationConflictResolution resolution,
  ) async {
    final title = switch (resolution) {
      CollaborationConflictResolution.useRemote =>
        context.l10n.conflictUseRemoteTitle,
      CollaborationConflictResolution.keepLocal =>
        context.l10n.conflictKeepLocalTitle,
      CollaborationConflictResolution.copyLocalAsNew =>
        context.l10n.conflictCopyLocalTitle,
    };
    final message = switch (resolution) {
      CollaborationConflictResolution.useRemote =>
        context.l10n.conflictUseRemoteMessage,
      CollaborationConflictResolution.keepLocal =>
        context.l10n.conflictKeepLocalMessage,
      CollaborationConflictResolution.copyLocalAsNew =>
        context.l10n.conflictCopyLocalMessage,
    };
    final accepted = await _confirm(
      title,
      message,
    );
    if (!accepted || !mounted) return;
    final action = switch (resolution) {
      CollaborationConflictResolution.useRemote => () =>
          collaboration.useRemoteForConflict(conflictId),
      CollaborationConflictResolution.keepLocal => () =>
          collaboration.keepLocalForConflict(conflictId),
      CollaborationConflictResolution.copyLocalAsNew => () =>
          collaboration.copyLocalAsNewForConflict(conflictId),
    };
    final success = switch (resolution) {
      CollaborationConflictResolution.useRemote =>
        context.l10n.conflictUseRemoteSucceeded,
      CollaborationConflictResolution.keepLocal =>
        context.l10n.conflictKeepLocalSucceeded,
      CollaborationConflictResolution.copyLocalAsNew =>
        context.l10n.conflictCopyLocalSucceeded,
    };
    await _run(
      action,
      success: success,
    );
  }

  Widget _inviteManagementCard(CollaborationProvider collaboration) {
    final secret = collaboration.lastCreatedInvite;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.memberInvitesTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                DropdownButton<InviteRole>(
                  value: _inviteRole,
                  items: [
                    DropdownMenuItem(
                      value: InviteRole.editor,
                      child: Text(context.l10n.roleEditor),
                    ),
                    DropdownMenuItem(
                      value: InviteRole.viewer,
                      child: Text(context.l10n.roleViewer),
                    ),
                  ],
                  onChanged: collaboration.isBusy
                      ? null
                      : (value) => setState(() => _inviteRole = value!),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: collaboration.isBusy
                      ? null
                      : () => _run(
                            () => collaboration.createInvite(role: _inviteRole),
                            success: context.l10n.inviteCreated,
                          ),
                  child: Text(context.l10n.generate),
                ),
              ],
            ),
            if (secret?.code != null) ...[
              const SizedBox(height: 12),
              Text(context.l10n.inviteCodeOneTimeHint,
                  style: Theme.of(context).textTheme.bodySmall),
              SelectableText(
                secret!.code!,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
            const Divider(height: 24),
            if (collaboration.invites.isEmpty)
              Text(context.l10n.noInvites)
            else
              ...collaboration.invites.map(
                (invite) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${invite.role == InviteRole.editor ? context.l10n.roleEditor : context.l10n.roleViewer} '
                    '••${invite.codeHint}',
                  ),
                  subtitle: Text(
                    context.l10n.inviteSummary(
                      invite.usedCount,
                      invite.maxUses,
                      invite.revokedAt == null
                          ? context.l10n.inviteExpiresAt(
                              invite.expiresAt.toLocal().toString(),
                            )
                          : context.l10n.inviteRevoked,
                    ),
                  ),
                  trailing: invite.revokedAt == null
                      ? IconButton(
                          tooltip: context.l10n.revokePublicShare,
                          onPressed: collaboration.isBusy
                              ? null
                              : () => _run(
                                    () => collaboration.revokeInvite(
                                      invite.inviteId,
                                    ),
                                  ),
                          icon: const Icon(Icons.block),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _memberManagementCard(
    CollaborationProvider collaboration,
    ServerProvider server,
  ) {
    return SettingsSectionCard(
      key: const Key('session-members-card'),
      icon: Icons.groups_outlined,
      title: context.l10n.membersTitle,
      child: AppTileGroup(
        children: [
          ...collaboration.members.map(
            (member) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: AppIconBadge(
                icon: member.role == SessionRole.owner
                    ? Icons.workspace_premium_outlined
                    : Icons.person_outline,
                size: AppIconBadgeSize.action,
                tone: member.role == SessionRole.owner
                    ? AppTone.primary
                    : AppTone.neutral,
              ),
              title: Text(member.username ?? member.userId),
              subtitle: Text(_roleLabel(member.role)),
              trailing: member.userId == server.accountId
                  ? Text(context.l10n.currentAccount)
                  : PopupMenuButton<String>(
                      enabled: !collaboration.isBusy,
                      onSelected: (action) {
                        if (action == 'owner') {
                          _confirmTransfer(collaboration, member);
                        } else if (action == 'remove') {
                          _confirmRemove(collaboration, member);
                        } else if (action == 'editor') {
                          _run(
                            () => collaboration.updateMemberRole(
                              member.userId,
                              InviteRole.editor,
                            ),
                            success: context.l10n.memberSetEditor,
                          );
                        } else if (action == 'viewer') {
                          _run(
                            () => collaboration.updateMemberRole(
                              member.userId,
                              InviteRole.viewer,
                            ),
                            success: context.l10n.memberSetViewer,
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'editor',
                          child: Text(context.l10n.setAsEditor),
                        ),
                        PopupMenuItem(
                          value: 'viewer',
                          child: Text(context.l10n.setAsViewer),
                        ),
                        PopupMenuItem(
                          value: 'owner',
                          child: Text(context.l10n.transferOwnership),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Text(context.l10n.removeMember),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmTransfer(
    CollaborationProvider collaboration,
    MembershipDto member,
  ) async {
    final successMessage = context.l10n.ownershipTransferred;
    final accepted = await _confirm(
      context.l10n.transferOwnership,
      context.l10n.transferOwnershipConfirmation(
        member.username ?? member.userId,
      ),
    );
    if (accepted) {
      await _run(
        () => collaboration.transferOwnership(member.userId),
        success: successMessage,
      );
    }
  }

  Future<void> _confirmRemove(
    CollaborationProvider collaboration,
    MembershipDto member,
  ) async {
    final successMessage = context.l10n.memberRemoved;
    final accepted = await _confirm(
      context.l10n.removeMember,
      context.l10n.removeMemberConfirmation(
        member.username ?? member.userId,
      ),
    );
    if (accepted) {
      await _run(
        () => collaboration.removeMember(member.userId),
        success: successMessage,
      );
    }
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.confirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _run(
    Future<Object?> Function() operation, {
    String? success,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await operation();
      if (mounted && success != null) {
        messenger.showLoggedSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        messenger.showLoggedSnackBar(
          SnackBar(content: Text(context.l10n.operationFailed('$error'))),
        );
      }
    }
  }

  String _roleLabel(SessionRole? role) => switch (role) {
        SessionRole.owner => context.l10n.roleOwner,
        SessionRole.editor => context.l10n.roleEditor,
        SessionRole.viewer => context.l10n.roleViewer,
        null => context.l10n.unknown,
      };
}

class _PublicShareExpiryDialog extends StatefulWidget {
  const _PublicShareExpiryDialog();

  @override
  State<_PublicShareExpiryDialog> createState() =>
      _PublicShareExpiryDialogState();
}

class _PublicShareExpiryDialogState extends State<_PublicShareExpiryDialog> {
  static const _presetHours = [1, 6, 12, 24, 72, 168, 720];

  final _customHoursController = TextEditingController();
  late final DateTime _createdAt;
  int _selectedHours = 24;
  bool _usesCustomHours = false;

  @override
  void initState() {
    super.initState();
    _createdAt = DateTime.now();
  }

  @override
  void dispose() {
    _customHoursController.dispose();
    super.dispose();
  }

  int? get _effectiveHours {
    if (!_usesCustomHours) return _selectedHours;
    final value = int.tryParse(_customHoursController.text);
    return value != null && value >= 1 && value <= 720 ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveHours = _effectiveHours;
    final customValue = int.tryParse(_customHoursController.text);
    final customValueOutOfRange = _usesCustomHours &&
        _customHoursController.text.isNotEmpty &&
        (customValue == null || customValue < 1 || customValue > 720);

    return AlertDialog(
      key: const Key('public-share-expiry-dialog'),
      title: Text(context.l10n.publicShareExpiryDialogTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.publicShareExpiryDialogHint),
              const SizedBox(height: 16),
              Text(
                context.l10n.publicShareExpiryPresets,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final hours in _presetHours)
                    ChoiceChip(
                      key: Key('public-share-expiry-$hours'),
                      label: Text(_presetLabel(context, hours)),
                      selected: !_usesCustomHours && _selectedHours == hours,
                      onSelected: (_) {
                        setState(() {
                          _usesCustomHours = false;
                          _selectedHours = hours;
                        });
                      },
                    ),
                  ChoiceChip(
                    key: const Key('public-share-expiry-custom'),
                    label: Text(context.l10n.publicShareExpiryCustom),
                    selected: _usesCustomHours,
                    onSelected: (_) {
                      setState(() => _usesCustomHours = true);
                    },
                  ),
                ],
              ),
              if (_usesCustomHours) ...[
                const SizedBox(height: 16),
                TextField(
                  key: const Key('public-share-custom-hours'),
                  controller: _customHoursController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    labelText: context.l10n.publicShareExpiryCustomHours,
                    hintText: '1–720',
                    errorText: customValueOutOfRange
                        ? context.l10n.publicShareExpiryRangeError
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    final hours = _effectiveHours;
                    if (hours != null) Navigator.pop(context, hours);
                  },
                ),
              ],
              if (effectiveHours != null) ...[
                const SizedBox(height: 16),
                Container(
                  key: const Key('public-share-estimated-expiry'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.schedule, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.publicShareEstimatedExpiry(
                            _formatLocalExpiry(
                              context,
                              _createdAt.add(Duration(hours: effectiveHours)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-public-share-expiry'),
          onPressed: effectiveHours == null
              ? null
              : () => Navigator.pop(context, effectiveHours),
          child: Text(context.l10n.confirm),
        ),
      ],
    );
  }

  String _presetLabel(BuildContext context, int hours) => switch (hours) {
        1 => context.l10n.publicShareExpiryOneHour,
        6 => context.l10n.publicShareExpirySixHours,
        12 => context.l10n.publicShareExpiryTwelveHours,
        24 => context.l10n.publicShareExpiryOneDay,
        72 => context.l10n.publicShareExpiryThreeDays,
        168 => context.l10n.publicShareExpirySevenDays,
        720 => context.l10n.publicShareExpiryThirtyDays,
        _ => '$hours h',
      };

  String _formatLocalExpiry(BuildContext context, DateTime expiry) {
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(expiry);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(expiry),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return '$date $time';
  }
}
