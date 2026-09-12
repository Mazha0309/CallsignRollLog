import 'package:flutter/foundation.dart';
import 'package:openlogtool/utils/app_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/controller_display.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/screens/collaboration_screen.dart';
import 'package:openlogtool/screens/controller_display_screen.dart';
import 'package:openlogtool/services/controller_window_service.dart';
import 'package:openlogtool/services/collaboration_sync.dart';
import 'package:openlogtool/widgets/collaboration_local_session_action.dart';
import 'package:openlogtool/widgets/session_history_dialog.dart';
import 'package:openlogtool/widgets/session_title_editor.dart';
import 'package:openlogtool/widgets/settings/settings_ui.dart';
import 'package:provider/provider.dart';

/// “会话”区的统一入口。详细成员、邀请和冲突管理继续复用协作页面。
class SessionHubPage extends StatelessWidget {
  const SessionHubPage({super.key, this.onSessionOpened});

  final VoidCallback? onSessionOpened;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>().currentSession;
    final logs = context.watch<LogProvider>();
    final collaboration = context.watch<CollaborationProvider>();
    final settings = context.watch<SettingsProvider>();
    final renameAvailability = session == null
        ? null
        : sessionRenameAvailability(
            sessionStatus: session.status,
            collaborationState: collaboration.state,
            hasCollaborationBinding: collaboration.binding != null,
            isCollaborationOwner: collaboration.isOwner,
            isBusy: collaboration.isBusy,
            hasOpenSessionConflict: collaboration.hasOpenSessionConflict,
          );
    final isCompact = MediaQuery.sizeOf(context).width < 720;
    final displayData = session == null
        ? null
        : _displayData(session.title, logs, collaboration);
    final appearance = ControllerWindowAppearance(
      themeColor: settings.themeColor,
      isDarkMode: settings.isDarkMode,
      fontFamily: settings.fontFamily,
      locale: settings.locale,
    );
    if (displayData != null && (supportsControllerDesktopWindows || kIsWeb)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ControllerWindowService.updateOpenWindows(
          data: displayData,
          preferences: settings.controllerDisplayPreferences,
          appearance: appearance,
        ).catchError((Object error) {
          debugPrint('[ControllerWindow] update failed: $error');
        });
      });
    }

    final cardPadding = isCompact ? 14.0 : 18.0;
    return ListView(
      key: const PageStorageKey('session-hub'),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 24,
        vertical: isCompact ? 16 : 24,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsSectionCard(
                  key: const Key('current-session-section'),
                  icon: session == null
                      ? Icons.event_busy_outlined
                      : session.status == 'active'
                          ? Icons.radio_button_checked
                          : Icons.stop_circle_outlined,
                  title: session?.title ?? context.l10n.noCurrentSession,
                  description: session == null
                      ? null
                      : '${session.status == 'active' ? context.l10n.sessionActive : context.l10n.sessionClosed} · '
                          '${context.l10n.savedPositions(logs.logCount)}',
                  padding: cardPadding,
                  headerTrailing: _buildSessionHeaderActions(
                    context,
                    sessionTitle: session?.title,
                    collaboration: collaboration,
                    renameAvailability: renameAvailability,
                    onSessionOpened: onSessionOpened,
                  ),
                  child: session == null
                      ? Text(
                          context.l10n.noCurrentSessionHint,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.4,
                                  ),
                        )
                      : _buildCurrentSessionContent(
                          context,
                          sessionId: session.sessionId,
                          sessionTitle: session.title,
                          sessionStatus: session.status,
                          collaboration: collaboration,
                          settings: settings,
                        ),
                ),
                if (session != null &&
                    (supportsControllerDesktopWindows || kIsWeb)) ...[
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    key: const Key('local-controller-display-section'),
                    icon: Icons.screenshot_monitor_outlined,
                    title: context.l10n.localControllerDisplay,
                    description: context.l10n.localControllerDisplayHint,
                    padding: cardPadding,
                    tone: SettingsTone.tertiary,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (kIsWeb) ...[
                          OutlinedButton.icon(
                            key: const Key('open-controller-in-app'),
                            onPressed: () => _openInAppController(context),
                            icon: const Icon(Icons.fullscreen),
                            label: Text(context.l10n.openControllerInApp),
                          ),
                          OutlinedButton.icon(
                            key: const Key('open-controller-web-tab'),
                            onPressed: () => ControllerWindowService.openWebTab(
                              session.sessionId,
                            ),
                            icon: const Icon(Icons.tab_outlined),
                            label: Text(context.l10n.openControllerTab),
                          ),
                        ] else ...[
                          OutlinedButton.icon(
                            key: const Key('open-controller-floating-window'),
                            onPressed: () => _openDesktopWindow(
                              context,
                              ControllerWindowMode.floating,
                              displayData!,
                              settings,
                              appearance,
                            ),
                            icon: const Icon(Icons.picture_in_picture_alt),
                            label: Text(context.l10n.openFloatingWindow),
                          ),
                          OutlinedButton.icon(
                            key: const Key('open-controller-second-window'),
                            onPressed: () => _openDesktopWindow(
                              context,
                              ControllerWindowMode.secondDisplay,
                              displayData!,
                              settings,
                              appearance,
                            ),
                            icon: const Icon(Icons.monitor),
                            label: Text(context.l10n.openSecondDisplayWindow),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SettingsSectionCard(
                  key: const Key('session-history-section'),
                  icon: Icons.history_outlined,
                  title: context.l10n.historySessions,
                  description: context.l10n.historySessionsHint,
                  padding: cardPadding,
                  child: SessionHistoryPanel(
                    key: ValueKey(
                      'session-history-${session?.sessionId ?? 'none'}',
                    ),
                    onSessionOpened: onSessionOpened,
                    onCollaborationSessionManage: (_) => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const CollaborationScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSessionHeaderActions(
    BuildContext context, {
    required String? sessionTitle,
    required CollaborationProvider collaboration,
    required SessionRenameAvailability? renameAvailability,
    required VoidCallback? onSessionOpened,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (sessionTitle != null) ...[
          Chip(
            avatar: Icon(
              collaboration.binding == null ? Icons.person : Icons.groups,
              size: 16,
            ),
            label: Text(
              collaboration.binding == null
                  ? context.l10n.localSession
                  : context.l10n.collaborationState(
                      collaborationStateLabel(
                        context.l10n,
                        collaboration.state.name,
                      ),
                    ),
            ),
          ),
          Tooltip(
            message: sessionRenameAvailabilityLabel(
              context.l10n,
              renameAvailability!,
            ),
            child: IconButton(
              key: const Key('rename-session'),
              visualDensity: VisualDensity.compact,
              onPressed: renameAvailability == SessionRenameAvailability.allowed
                  ? () => _renameSession(
                        context,
                        sessionTitle,
                        collaboration,
                      )
                  : null,
              icon: const Icon(Icons.edit_outlined),
            ),
          ),
        ],
        OutlinedButton.icon(
          key: const Key('join-collaboration'),
          onPressed: collaboration.isBusy
              ? null
              : () => _joinCollaboration(
                    context,
                    onSessionOpened,
                  ),
          icon: const Icon(Icons.group_add),
          label: Text(context.l10n.joinCollaborationTitle),
        ),
        FilledButton.tonalIcon(
          key: const Key('create-session'),
          onPressed: () => _createSession(
            context,
            onSessionOpened,
          ),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.createSession),
        ),
      ],
    );
  }

  Widget _buildCurrentSessionContent(
    BuildContext context, {
    required String sessionId,
    required String sessionTitle,
    required String sessionStatus,
    required CollaborationProvider collaboration,
    required SettingsProvider settings,
  }) {
    final colors = Theme.of(context).colorScheme;
    final collaborationSession = collaboration.binding?.sessionId == sessionId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.tag_outlined,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SelectableText(
                  sessionId,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!collaborationSession && sessionStatus == 'active')
              FilledButton.icon(
                key: const Key('close-current-local-session'),
                onPressed: () => _closeCurrentLocalSession(
                  context,
                  sessionId,
                  sessionTitle,
                ),
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(context.l10n.historySessionCloseTitle),
              ),
            if (!collaborationSession && sessionStatus == 'closed')
              FilledButton.icon(
                key: const Key('reopen-current-local-session'),
                onPressed: () => _reopenCurrentLocalSession(
                  context,
                  sessionId,
                  sessionTitle,
                  onSessionOpened,
                ),
                icon: const Icon(Icons.play_arrow),
                label: Text(context.l10n.historySessionReopenAction),
              ),
            if (collaborationSession && sessionStatus == 'closed')
              FilledButton.icon(
                key: const Key('reopen-current-collaboration-session'),
                onPressed: collaboration.isOwner &&
                        !collaboration.isBusy &&
                        !collaboration.hasOpenSessionConflict
                    ? () => _reopenCurrentCollaborationSession(
                          context,
                          collaboration,
                          onSessionOpened,
                        )
                    : null,
                icon: const Icon(Icons.play_circle_outline),
                label: Text(context.l10n.reopenSession),
              ),
            FilledButton.icon(
              key: const Key('open-collaboration-management'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const CollaborationScreen(),
                ),
              ),
              icon: const Icon(Icons.group_outlined),
              label: Text(context.l10n.manageCollaboration),
            ),
            FilledButton.tonalIcon(
              key: const Key('open-live-share-management'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const CollaborationScreen(
                    focusPublicShare: true,
                  ),
                ),
              ),
              icon: const Icon(Icons.public),
              label: Text(context.l10n.openLiveShare),
            ),
            if (collaborationSession)
              const CollaborationLocalSessionAction()
            else
              OutlinedButton.icon(
                key: const Key('delete-current-local-session'),
                onPressed: () => _deleteCurrentLocalSession(
                  context,
                  sessionId,
                  sessionTitle,
                ),
                icon: Icon(Icons.delete_forever, color: colors.error),
                label: Text(
                  context.l10n.historySessionDeleteAction,
                  style: TextStyle(color: colors.error),
                ),
              ),
            if (settings.controllerDeviceModeEnabled)
              OutlinedButton.icon(
                key: const Key('enter-controller-device-mode'),
                onPressed: () => _openInAppController(context),
                icon: const Icon(Icons.fullscreen),
                label: Text(context.l10n.enterControllerScreen),
              ),
          ],
        ),
      ],
    );
  }

  static ControllerDisplayDto displayDataFor(
    String sessionTitle,
    LogProvider logs,
    CollaborationProvider collaboration,
  ) =>
      _displayData(sessionTitle, logs, collaboration);

  static ControllerDisplayDto _displayData(
    String sessionTitle,
    LogProvider logs,
    CollaborationProvider collaboration,
  ) {
    final snapshot = collaboration.liveDraftSnapshot;
    final draftFields = collaboration.liveDraftDisplayFields;
    final previous = logs.logs.isEmpty ? null : logs.logs.last;
    final connectionState = collaboration.binding == null
        ? ControllerConnectionState.connected
        : collaboration.state == CollaborationState.failed ||
                collaboration.state == CollaborationState.revoked ||
                collaboration.transportPhase ==
                    CollaborationTransportPhase.authRequired ||
                collaboration.transportPhase ==
                    CollaborationTransportPhase.incompatible ||
                collaboration.transportPhase ==
                    CollaborationTransportPhase.stopped
            ? ControllerConnectionState.offline
            : collaboration.transportPhase == CollaborationTransportPhase.online
                ? ControllerConnectionState.connected
                : ControllerConnectionState.reconnecting;
    if (snapshot != null) {
      final snapshotJson = Map<String, Object?>.from(snapshot.toJson());
      if (draftFields != null) {
        final draft = Map<String, Object?>.from(snapshotJson['draft']! as Map);
        draft['fields'] = draftFields.toJson();
        snapshotJson['draft'] = draft;
      }
      snapshotJson['currentOrdinal'] = resolveVisibleRecordOrdinal(
        snapshotOrdinal: snapshot.currentOrdinal,
        savedCount: logs.logCount,
      );
      snapshotJson['totalRecords'] = resolveVisibleRecordCount(
        snapshotTotalRecords: snapshot.totalRecords,
        savedCount: logs.logCount,
      );
      return ControllerDisplayDto.fromLiveDraftJson(
        snapshotJson,
        sessionTitle: sessionTitle,
        connectionState: connectionState,
      );
    }
    return ControllerDisplayDto(
      sessionTitle: sessionTitle,
      currentOrdinal: resolveVisibleRecordOrdinal(savedCount: logs.logCount),
      totalRecords: resolveVisibleRecordCount(savedCount: logs.logCount),
      current: ControllerRecordDisplay(
        controller: previous?.controller ?? '',
        rstSent: '59',
        rstRcvd: '59',
      ),
      previous:
          previous == null ? null : ControllerRecordDisplay.fromLog(previous),
      connectionState: connectionState,
      lastUpdatedAt:
          previous == null ? null : DateTime.tryParse(previous.updatedAt),
    );
  }

  static Future<void> _openInAppController(BuildContext context) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const _LiveControllerDisplayRoute(),
        ),
      );

  static Future<void> _joinCollaboration(
    BuildContext context,
    VoidCallback? onSessionOpened,
  ) async {
    final server = context.read<ServerProvider>();
    if (!server.isLoggedIn) {
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.collaborationServerLoginHint)),
      );
      return;
    }
    var draftCode = '';
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          key: const Key('join-collaboration-dialog'),
          title: Text(dialogContext.l10n.joinCollaborationTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(dialogContext.l10n.joinCollaborationHint),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('join-collaboration-code'),
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: dialogContext.l10n.inviteCodeLabel,
                  hintText: 'ABCDE-12345',
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onChanged: (value) => setDialogState(() => draftCode = value),
                onFieldSubmitted: (value) {
                  final normalized = value.trim();
                  if (normalized.isNotEmpty) {
                    Navigator.pop(dialogContext, normalized);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.l10n.cancel),
            ),
            FilledButton.icon(
              key: const Key('confirm-join-collaboration'),
              onPressed: draftCode.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        draftCode.trim(),
                      ),
              icon: const Icon(Icons.group_add),
              label: Text(dialogContext.l10n.join),
            ),
          ],
        ),
      ),
    );
    if (code == null || !context.mounted) return;
    final collaboration = context.read<CollaborationProvider>();
    try {
      await collaboration.joinWithCode(code);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.joinCollaborationSucceeded)),
      );
      onSessionOpened?.call();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(context.l10n.operationFailed('$error')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  static Future<void> _createSession(
    BuildContext context,
    VoidCallback? onSessionOpened,
  ) async {
    final now = DateTime.now();
    final materialLocalizations = MaterialLocalizations.of(context);
    final defaultTitle = '${materialLocalizations.formatShortDate(now)} '
        '${materialLocalizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(now),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    )}';
    var draftTitle = defaultTitle;
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          key: const Key('create-session-dialog'),
          title: Text(dialogContext.l10n.createSessionTitle),
          content: TextFormField(
            key: const Key('create-session-name'),
            initialValue: defaultTitle,
            autofocus: true,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: dialogContext.l10n.createSessionNameHint,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (value) => setDialogState(() => draftTitle = value),
            onFieldSubmitted: (value) {
              final normalized = value.trim();
              if (normalized.isNotEmpty) {
                Navigator.pop(dialogContext, normalized);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(dialogContext.l10n.cancel),
            ),
            FilledButton.icon(
              key: const Key('confirm-create-session'),
              onPressed: draftTitle.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        draftTitle.trim(),
                      ),
              icon: const Icon(Icons.add),
              label: Text(dialogContext.l10n.createSession),
            ),
          ],
        ),
      ),
    );
    if (title == null || !context.mounted) return;
    final sessions = context.read<SessionProvider>();
    final logs = context.read<LogProvider>();
    try {
      await sessions.startNewSession(title: title);
      await logs.reloadForSession(
        sessions.currentSessionId,
        propagateErrors: true,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.sessionCreated(title))),
      );
      onSessionOpened?.call();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(context.l10n.createSessionFailed('$error')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  static Future<void> _closeCurrentLocalSession(
    BuildContext context,
    String sessionId,
    String sessionTitle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.historySessionCloseTitle),
        content: Text(
          dialogContext.l10n.historySessionCloseConfirmation(sessionTitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirm-close-current-local-session'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.historySessionCloseTitle),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final sessions = context.read<SessionProvider>();
    final logs = context.read<LogProvider>();
    try {
      final closed = await sessions.closeSessionLocally(sessionId);
      await logs.reloadForSession(
        closed.sessionId,
        propagateErrors: true,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.historySessionClosed)),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(historySessionCloseErrorText(context, error)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  static Future<void> _deleteCurrentLocalSession(
    BuildContext context,
    String sessionId,
    String sessionTitle,
  ) async {
    final confirmed = await confirmDeleteLocalSession(
      context,
      sessionTitle: sessionTitle,
    );
    if (!confirmed || !context.mounted) return;
    final sessions = context.read<SessionProvider>();
    final logs = context.read<LogProvider>();
    try {
      await sessions.deleteSessionLocally(sessionId);
      await logs.forgetDeletedSession(sessionId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.historySessionDeleted)),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(context.l10n.historySessionDeleteFailed('$error')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  static Future<void> _reopenCurrentCollaborationSession(
    BuildContext context,
    CollaborationProvider collaboration,
    VoidCallback? onSessionOpened,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.reopenCollaborationSessionTitle),
        content: Text(dialogContext.l10n.reopenCollaborationSessionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.cancel),
          ),
          FilledButton(
            key: const Key('confirm-reopen-current-collaboration-session'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.reopenSession),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await collaboration.reopenCurrentSession();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.reopenSessionQueued)),
      );
      onSessionOpened?.call();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(context.l10n.operationFailed('$error')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  static Future<void> _renameSession(
    BuildContext context,
    String currentTitle,
    CollaborationProvider collaboration,
  ) async {
    final collaborationSession = collaboration.binding != null;
    final title = await showSessionRenameDialog(
      context,
      currentTitle: currentTitle,
      collaborationSession: collaborationSession,
    );
    if (title == null || !context.mounted) return;

    try {
      if (collaborationSession) {
        await collaboration.renameCurrentSession(title);
      } else {
        await context.read<SessionProvider>().renameCurrentSession(title);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(
            collaborationSession
                ? context.l10n.renameCollaborationSessionSaved
                : context.l10n.renameSessionSaved,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(context.l10n.renameSessionFailed(error.toString())),
        ),
      );
    }
  }

  static Future<void> _reopenCurrentLocalSession(
    BuildContext context,
    String sessionId,
    String sessionTitle,
    VoidCallback? onSessionOpened,
  ) async {
    final confirmed = await confirmReopenLocalSession(
      context,
      sessionTitle: sessionTitle,
    );
    if (!confirmed || !context.mounted) return;

    final sessions = context.read<SessionProvider>();
    final logs = context.read<LogProvider>();
    try {
      await sessions.reopenLocalSession(sessionId);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(localSessionReopenErrorText(context, error)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    try {
      await logs.reloadForSession(sessionId, propagateErrors: true);
    } catch (error, stackTrace) {
      try {
        await sessions.reloadCurrentSession();
      } catch (refreshError, refreshStackTrace) {
        debugPrint(
          '[SessionHub] reopened session refresh failed: '
          '$refreshError\n$refreshStackTrace',
        );
      }
      debugPrint(
        '[SessionHub] reopened session log load failed: '
        '$error\n$stackTrace',
      );
      if (!context.mounted) return;
      onSessionOpened?.call();
      showReopenedSessionLogsUnavailable(
        context,
        logs: logs,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
      );
      return;
    }

    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.historySessionReopened(sessionTitle);
    messenger.showLoggedSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
    onSessionOpened?.call();
  }

  static Future<void> _openDesktopWindow(
    BuildContext context,
    ControllerWindowMode mode,
    ControllerDisplayDto data,
    SettingsProvider settings,
    ControllerWindowAppearance appearance,
  ) async {
    try {
      await ControllerWindowService.open(
        mode: mode,
        data: data,
        preferences: settings.controllerDisplayPreferences,
        appearance: appearance,
        onPreferencesChanged: settings.setControllerDisplayPreferences,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(
          content: Text(
            context.l10n.controllerWindowOpenFailed(error.toString()),
          ),
        ),
      );
    }
  }
}

class _LiveControllerDisplayRoute extends StatelessWidget {
  const _LiveControllerDisplayRoute();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>().currentSession;
    final logs = context.watch<LogProvider>();
    final collaboration = context.watch<CollaborationProvider>();
    final settings = context.watch<SettingsProvider>();
    return ControllerDisplayScreen(
      data: SessionHubPage._displayData(
        session?.title ?? context.l10n.controllerScreenFallbackTitle,
        logs,
        collaboration,
      ),
      preferences: settings.controllerDisplayPreferences,
      onPreferencesChanged: settings.setControllerDisplayPreferences,
    );
  }
}
