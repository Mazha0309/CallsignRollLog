import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/controller_display.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/providers/settings_provider.dart';
import 'package:openlogtool/screens/data_workspace_page.dart';
import 'package:openlogtool/screens/session_hub_page.dart';
import 'package:openlogtool/services/controller_window_service.dart';
import 'package:openlogtool/services/collaboration_sync.dart';
import 'package:openlogtool/services/url_sync.dart';
import 'package:openlogtool/theme/app_theme.dart';
import 'package:openlogtool/widgets/log_form.dart';
import 'package:openlogtool/widgets/log_table.dart';
import 'package:openlogtool/widgets/settings_panel.dart';
import 'package:openlogtool/widgets/primary_navigation_rail.dart';
import 'package:openlogtool/utils/app_snack_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  ServerProvider? _serverProvider;
  int _observedAuthenticationNoticeRevision = 0;

  /// 启动时 URL 已指定页面：优先恢复 URL，而不是跳转 sessions。
  bool _restoredFromUrl = false;

  /// 首帧完成前路由回调只改字段，不调用 setState。
  bool _syncReady = false;

  static const _destinations = <_AppDestination>[
    _AppDestination(_AppSection.workbench, Icons.radio_outlined, Icons.radio),
    _AppDestination(_AppSection.sessions, Icons.groups_outlined, Icons.groups),
    _AppDestination(_AppSection.data, Icons.storage_outlined, Icons.storage),
    _AppDestination(
        _AppSection.settings, Icons.settings_outlined, Icons.settings),
  ];

  @override
  void initState() {
    super.initState();
    UrlSync.init(onRouteChanged: _onRouteChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncReady = true;
      _initSession();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final server = context.read<ServerProvider>();
    if (identical(server, _serverProvider)) return;
    _serverProvider?.removeListener(_handleServerStateChanged);
    _serverProvider = server..addListener(_handleServerStateChanged);
    _handleServerStateChanged();
  }

  void _handleServerStateChanged() {
    final server = _serverProvider;
    if (server == null) return;
    final revision = server.authenticationNoticeRevision;
    final code = server.authenticationNoticeCode;
    if (revision <= _observedAuthenticationNoticeRevision || code == null) {
      return;
    }
    _observedAuthenticationNoticeRevision = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _serverProvider?.authenticationNoticeRevision != revision ||
          _serverProvider?.authenticationNoticeCode != code) {
        return;
      }
      final message = code == 'TOKEN_STORAGE_UNAVAILABLE'
          ? context.l10n.authStorageUnavailableNotice
          : context.l10n.authSessionExpiredNotice;
      context.showLoggedSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: context.l10n.navSettings,
            onPressed: () => _onItemTapped(3),
          ),
        ),
        source: 'Authentication',
        type: 'error',
      );
    });
  }

  void _onRouteChanged(SyncRoute route) {
    if (!mounted) return;
    if (route.page != null) _restoredFromUrl = true;
    final index = homeIndexForPage(route.page);
    final currentSessionId = context.read<SessionProvider>().currentSessionId;
    if (route.session != null && route.session != currentSessionId) {
      _restoreSessionFromUrl(route.session!);
    }
    if (index == _selectedIndex && route.session == null) return;
    if (_syncReady) {
      setState(() => _selectedIndex = index);
    } else {
      _selectedIndex = index;
    }
  }

  /// 浏览器后退/分享链接带 session 参数时，切换回对应会话。
  Future<void> _restoreSessionFromUrl(String sessionId) async {
    final sessions = context.read<SessionProvider>();
    final logs = context.read<LogProvider>();
    try {
      await logs.reloadForSession(sessionId, propagateErrors: true);
      await sessions.switchToSession(sessionId);
    } catch (e) {
      debugPrint('[HomeScreen] URL session restore failed: $e');
    }
  }

  @override
  void dispose() {
    _serverProvider?.removeListener(_handleServerStateChanged);
    ControllerWindowService.closeAll().catchError((Object error) {
      debugPrint('[ControllerWindow] close failed: $error');
    });
    super.dispose();
  }

  Future<void> _initSession() async {
    final sp = context.read<SessionProvider>();
    final lp = context.read<LogProvider>();
    await sp.ready;
    if (!mounted) return;
    if (!_restoredFromUrl && sp.currentSessionId == null) {
      setState(() => _selectedIndex = 1);
      return;
    }
    await lp.reloadForSession(sp.currentSessionId);
  }

  void _onItemTapped(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    final sessionProvider = context.read<SessionProvider>();
    final blockedWorkbench =
        index == 0 && sessionProvider.currentSessionId == null;
    final destination = blockedWorkbench ? 1 : index;
    if (blockedWorkbench) {
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.createOrJoinSessionFirst)),
      );
    }
    if (destination == _selectedIndex) return;
    setState(() => _selectedIndex = destination);
    UrlSync.push(
      pageForHomeIndex(destination),
      destination == 0 ? sessionProvider.currentSessionId : null,
    );
  }

  Future<bool> _handleSystemBack() async {
    if (FocusManager.instance.primaryFocus?.hasFocus ?? false) {
      FocusManager.instance.primaryFocus?.unfocus();
      return true;
    }
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final primarySidebarExpanded = context.select<SettingsProvider, bool>(
      (settings) => settings.primarySidebarExpanded,
    );
    final pages = <Widget>[
      _WorkbenchPage(
        onOpenSessions: () => _onItemTapped(1),
        saveShortcutEnabled: _selectedIndex == 0,
      ),
      SessionHubPage(
        onSessionOpened: () {
          if (mounted) setState(() => _selectedIndex = 0);
          UrlSync.push(
            pageForHomeIndex(0),
            context.read<SessionProvider>().currentSessionId,
          );
        },
      ),
      const DataWorkspacePage(),
      const SettingsPage(),
    ];
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleSystemBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _destinations[_selectedIndex].selectedIcon,
                size: 21,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Text(_destinations[_selectedIndex].label(context.l10n)),
            ],
          ),
          centerTitle: false,
          actions: [
            _AppBarSyncStatus(
              onPressed: () => _onItemTapped(1),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final content = IndexedStack(
              index: _selectedIndex,
              children: pages,
            );
            final showSidebar = constraints.maxWidth >= 720;
            final isDesktop = constraints.maxWidth >= 1200;
            // Keep the page stack at a stable element position when crossing the
            // mobile/sidebar breakpoint. Reparenting the focused TextField while
            // Windows is dispatching WM_SIZE can tear down its native IME
            // connection in the middle of that callback.
            return Row(
              children: [
                if (showSidebar)
                  PrimaryNavigationRail(
                    isDesktop: isDesktop,
                    expanded: primarySidebarExpanded,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onItemTapped,
                    onExpandedChanged: context
                        .read<SettingsProvider>()
                        .setPrimarySidebarExpanded,
                    destinations: [
                      for (final destination in _destinations)
                        NavigationRailDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: Text(destination.label(context.l10n)),
                        ),
                    ],
                  )
                else
                  const SizedBox.shrink(),
                Expanded(
                  key: const ValueKey('home-page-stack'),
                  child: content,
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: MediaQuery.sizeOf(context).width < 720
            ? NavigationBar(
                key: const Key('mobile-navigation'),
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onItemTapped,
                destinations: [
                  for (final destination in _destinations)
                    NavigationDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: destination.label(context.l10n),
                    ),
                ],
              )
            : null,
      ),
    );
  }
}

enum _AppSection { workbench, sessions, data, settings }

class _AppDestination {
  const _AppDestination(this.section, this.icon, this.selectedIcon);

  final _AppSection section;
  final IconData icon;
  final IconData selectedIcon;

  String label(AppLocalizations l10n) => switch (section) {
        _AppSection.workbench => l10n.navWorkbench,
        _AppSection.sessions => l10n.navSessions,
        _AppSection.data => l10n.navData,
        _AppSection.settings => l10n.navSettings,
      };
}

class _WorkbenchPage extends StatelessWidget {
  const _WorkbenchPage({
    required this.onOpenSessions,
    required this.saveShortcutEnabled,
  });

  final VoidCallback onOpenSessions;
  final bool saveShortcutEnabled;

  @override
  Widget build(BuildContext context) => AddRecordPage(
        onOpenSessions: onOpenSessions,
        saveShortcutEnabled: saveShortcutEnabled,
      );
}

class _WorkbenchStatusBar extends StatelessWidget {
  const _WorkbenchStatusBar();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>().currentSession;
    if (session == null) return const SizedBox.shrink();
    final collaboration = context.watch<CollaborationProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      key: const Key('workbench-status-bar'),
      width: double.infinity,
      child: Container(
        key: const Key('workbench-session-header'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final introduction = Row(
              key: const Key('workbench-session-summary'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.radio_outlined,
                    size: 18,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        session.status == 'active'
                            ? context.l10n.sessionActive
                            : context.l10n.sessionClosed,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final statusWidgets = <Widget>[
              _StatusLabel(
                icon: collaboration.binding == null
                    ? Icons.person_outline
                    : Icons.groups_outlined,
                text: collaboration.binding == null
                    ? context.l10n.collaborationLocalOnly
                    : collaborationStateLabel(
                        context.l10n,
                        collaboration.state.name,
                      ),
              ),
              if (collaboration.binding != null) ...[
                _StatusLabel(
                  icon: Icons.sync,
                  text:
                      context.l10n.pendingSyncCount(collaboration.pendingCount),
                ),
                _StatusLabel(
                  icon: Icons.warning_amber,
                  text: context.l10n.conflictCount(collaboration.conflictCount),
                  danger: collaboration.conflictCount > 0,
                ),
              ],
            ];
            final statuses = Wrap(
              key: const Key('workbench-session-statuses'),
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: statusWidgets,
            );
            final stackStatuses =
                constraints.maxWidth < 640 && collaboration.binding != null;
            if (stackStatuses) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  introduction,
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: statuses,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: introduction),
                const SizedBox(width: 12),
                statuses,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AppBarSyncStatus extends StatelessWidget {
  const _AppBarSyncStatus({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final hasSession = context.select<SessionProvider, bool>(
      (sessions) => sessions.currentSession != null,
    );
    final collaboration = context.watch<CollaborationProvider>();
    final local = collaboration.binding == null;
    if (!hasSession || local) return const SizedBox.shrink();
    final online =
        collaboration.transportPhase == CollaborationTransportPhase.online;
    final reconnecting = collaboration.transportPhase ==
            CollaborationTransportPhase.connecting ||
        collaboration.transportPhase == CollaborationTransportPhase.backingOff;
    final statusLabel = collaboration.state == CollaborationState.ready
        ? online
            ? context.l10n.connectionConnected
            : reconnecting
                ? context.l10n.connectionReconnecting
                : context.l10n.connectionOffline
        : collaborationStateLabel(
            context.l10n,
            collaboration.state.name,
          );
    return IconButton(
      key: const Key('open-sync-status'),
      tooltip: context.l10n.collaborationStatusTooltip(
        statusLabel,
        collaboration.pendingCount,
      ),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: Icon(
        online
            ? Icons.cloud_done_outlined
            : reconnecting
                ? Icons.sync
                : Icons.cloud_off,
        color: online
            ? Colors.green
            : reconnecting
                ? Colors.orange
                : Theme.of(context).colorScheme.error,
        size: 20,
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({
    required this.icon,
    required this.text,
    this.danger = false,
  });

  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = danger ? colors.error : colors.onSurfaceVariant;
    final background = danger
        ? colors.errorContainer.withValues(alpha: 0.6)
        : colors.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 5),
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _WorkbenchSectionCard extends StatelessWidget {
  const _WorkbenchSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.keepTrailingInlineOnCompact = false,
  });

  final IconData icon;
  final Widget title;
  final Widget child;
  final Widget? trailing;
  final bool keepTrailingInlineOnCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final heading = Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: title),
      ],
    );
    return LayoutBuilder(
      builder: (context, cardConstraints) {
        final compact = cardConstraints.maxWidth < 600;
        return Card(
          margin: EdgeInsets.zero,
          color: colors.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 14 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final action = trailing;
                    if (action == null) return heading;
                    if (constraints.maxWidth < 720 &&
                        !keepTrailingInlineOnCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          heading,
                          const SizedBox(height: 12),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: action,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: heading),
                        const SizedBox(width: 16),
                        action,
                      ],
                    );
                  },
                ),
                SizedBox(height: compact ? 12 : 16),
                child,
              ],
            ),
          ),
        );
      },
    );
  }
}

class AddRecordPage extends StatelessWidget {
  const AddRecordPage({
    super.key,
    this.onOpenSessions,
    this.saveShortcutEnabled = true,
  });

  final VoidCallback? onOpenSessions;
  final bool saveShortcutEnabled;

  @override
  Widget build(BuildContext context) {
    final logProvider = context.read<LogProvider>();
    return ListenableBuilder(
      listenable: logProvider,
      builder: (context, _) => _buildWorkbench(context, logProvider),
    );
  }

  Widget _buildWorkbench(
    BuildContext context,
    LogProvider logProvider,
  ) {
    final currentSession = context.watch<SessionProvider>().currentSession;
    if (currentSession == null) return _buildNoSessionState(context);

    final sessionClosed = currentSession.status != 'active';
    final readOnly = logProvider.currentSessionReadOnly || sessionClosed;
    final conflictedLogIds =
        context.watch<CollaborationProvider>().conflictedLogIds;
    final content = _buildStackedLayout(
      context,
      logProvider,
      conflictedLogIds,
      readOnly,
      currentSession.sessionId,
    );
    return content;
  }

  Widget _buildNoSessionState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            margin: EdgeInsets.zero,
            color: colors.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.event_note_outlined,
                      size: 32,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.l10n.noCurrentSession,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.workbenchNoSessionHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                  ),
                  if (onOpenSessions != null) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('open-sessions-from-empty-workbench'),
                      onPressed: onOpenSessions,
                      icon: const Icon(Icons.groups_outlined),
                      label: Text(context.l10n.goCreateSession),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStackedLayout(
    BuildContext context,
    LogProvider logProvider,
    Set<String> conflictedLogIds,
    bool readOnly,
    String currentSessionId,
  ) {
    final stackedContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _WorkbenchStatusBar(),
        if (readOnly) ...[
          const SizedBox(height: 8),
          Container(
            key: const Key('workbench-read-only-banner'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.watch<SessionProvider>().currentSession?.status !=
                            'active'
                        ? context.l10n.historySessionReadOnly
                        : context.l10n.sharedDraftReadOnly,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _WorkbenchSectionCard(
          key: const Key('current-record-section'),
          icon: Icons.edit_note_outlined,
          title: Text(
            context.l10n.currentRecord,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          trailing: _currentOrdinalBadge(context, logProvider.logCount),
          keepTrailingInlineOnCompact: true,
          child: LogForm(
            key: ValueKey('log-form-$currentSessionId'),
            readOnly: readOnly,
            saveShortcutEnabled: saveShortcutEnabled,
          ),
        ),
        const SizedBox(height: 16),
        _WorkbenchSectionCard(
          key: const Key('saved-records-section'),
          icon: Icons.format_list_numbered_outlined,
          title: Consumer<LogProvider>(
            builder: (_, lp, __) => Row(
              children: [
                Flexible(
                  child: Text(
                    context.l10n.savedRecords,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    context.l10n.recordCount(lp.logCount),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
          trailing: _buildLogActions(context, readOnly),
          child: LogTable(
            readOnly: readOnly,
            conflictedLogIds: conflictedLogIds,
          ),
        ),
      ],
    );
    final limitWidth = context.select<SettingsProvider, bool>(
      (settings) => settings.limitWorkbenchWidth,
    );
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          constraints.maxWidth < 600 ? 12 : 20,
          12,
          constraints.maxWidth < 600 ? 12 : 20,
          24,
        ),
        child: limitWidth
            ? Center(
                child: ConstrainedBox(
                  key: const Key('workbench-width-limit'),
                  constraints: const BoxConstraints(
                    maxWidth: AppDimensions.wideContentWidth,
                  ),
                  child: stackedContent,
                ),
              )
            : stackedContent,
      ),
    );
  }

  Widget _currentOrdinalBadge(BuildContext context, int savedCount) {
    final colors = Theme.of(context).colorScheme;
    final ordinal = resolveVisibleRecordOrdinal(
      snapshotOrdinal: context
          .watch<CollaborationProvider>()
          .liveDraftSnapshot
          ?.currentOrdinal,
      savedCount: savedCount,
    );
    return Container(
      key: const Key('current-ordinal-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.l10n.currentOrdinal(ordinal),
        style: TextStyle(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildLogActions(
    BuildContext context,
    bool readOnly,
  ) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Consumer<LogProvider>(
          builder: (_, lp, __) => OutlinedButton.icon(
            onPressed: !readOnly && lp.canUndo
                ? () => _showUndoConfirmation(context)
                : null,
            icon: const Icon(Icons.restore),
            label: Text(context.l10n.restoreLastDeletedRecord),
          ),
        ),
      ],
    );
  }

  Future<void> _showUndoConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.restoreLastDeletedRecordTitle),
        content: Text(dialogContext.l10n.restoreLastDeletedRecordConfirmation),
        actions: [
          TextButton(
            child: Text(dialogContext.l10n.cancel),
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          FilledButton(
            child: Text(dialogContext.l10n.restoreLastDeletedRecord),
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<LogProvider>().undoLastLog();
      if (!context.mounted) return;
      context.showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.recordRestored)),
      );
    } catch (error) {
      if (!context.mounted) return;
      context.showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.operationFailed('$error'))),
      );
    }
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 8 : 24,
            vertical: isNarrow ? 12 : 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: const SettingsPanel(),
            ),
          ),
        );
      },
    );
  }
}
