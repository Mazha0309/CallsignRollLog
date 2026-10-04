import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/account_share_dto.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/personal_cloud_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
import 'package:openlogtool/providers/collaboration_provider.dart';
import 'package:openlogtool/providers/log_provider.dart';
import 'package:openlogtool/services/server_api.dart';
import 'package:openlogtool/widgets/personal_cloud_panel.dart';
import 'package:openlogtool/widgets/personal_cloud_conflict_page.dart';
import 'package:openlogtool/widgets/share_invitations_panel.dart';

String sharingErrorText(BuildContext context, Object error) {
  final l = context.l10n;
  if (error is ServerApiException) {
    if (error.code == 'VERSION_CONFLICT') return l.shareConflict;
    if (error.code == 'ACCOUNT_SHARE_PENDING_EXISTS') return l.shareExisting;
    if (error.code == 'SHARE_PERMISSION_DENIED' || error.code == 'NOT_FOUND') {
      return l.shareAccessChanged;
    }
  }
  if ('$error'.contains('ACCOUNT_CHANGED') ||
      '$error'.contains('SHARE_ACCESS_CHANGED')) {
    return l.shareAccessChanged;
  }
  if ('$error'.contains('SHARING_UPGRADE_REQUIRED')) {
    return l.shareUpgradeRequired;
  }
  if ('$error'.contains('VERSION_CONFLICT')) return l.shareConflict;
  if ('$error'.contains('SHARE_SYNC_REQUIRED')) return l.shareSyncFirst;
  return l.shareOperationFailed;
}

Future<void> showSessionSharingDialog(BuildContext context) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const SessionSharingDialog());

class SessionSharingDialog extends StatefulWidget {
  const SessionSharingDialog({super.key});
  @override
  State<SessionSharingDialog> createState() => _SessionSharingDialogState();
}

class _SessionSharingDialogState extends State<SessionSharingDialog> {
  final _username = TextEditingController();
  final _search = TextEditingController();
  final _selected = <String>{};
  List<ShareSessionRef> _sessions = [];
  String _mode = 'selected';
  bool _edit = false, _delete = false, _loading = true, _working = false;
  String? _scope, _error;
  AccountShareGrantDto? _grant;
  int _loadEpoch = 0;

  @override
  void initState() {
    super.initState();
    _scope = context.read<AccountShareProvider>().accountScope;
    unawaited(_load());
  }

  @override
  void dispose() {
    _username.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final epoch = ++_loadEpoch;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final sharing = context.read<AccountShareProvider>();
    try {
      await sharing.refresh();
      if (!mounted || _scope != sharing.accountScope) return;
      final remote = await sharing.loadShareCandidates();
      if (!mounted || _scope != sharing.accountScope) return;
      final local =
          await context.read<SessionProvider>().listAvailableSessionEntries();
      if (!mounted || epoch != _loadEpoch || _scope != sharing.accountScope) {
        return;
      }
      final merged = {for (final row in remote) row.identity: row};
      for (final entry in local) {
        if (!entry.hasCollaborationBinding && !entry.isShared) {
          final row = ShareSessionRef(
              source: 'personal',
              sessionId: entry.session.sessionId,
              title: entry.session.title);
          merged.putIfAbsent(row.identity, () => row);
        }
      }
      setState(() {
        _sessions = merged.values.toList();
        _loading = false;
      });
    } catch (error) {
      if (mounted && epoch == _loadEpoch) {
        setState(() {
          _error = sharingErrorText(context, error);
          _loading = false;
        });
      }
    }
  }

  void _chooseGrant(AccountShareGrantDto grant) => setState(() {
        _grant = grant;
        _username.text = grant.granteeUsername;
        _mode = grant.scopeMode;
        _edit = grant.canEditLogs;
        _delete = grant.canDeleteLogs;
        _selected
          ..clear()
          ..addAll(grant.selectedSessions.map((s) => s.identity));
        _error = null;
      });

  Future<void> _submit() async {
    final sharing = context.read<AccountShareProvider>();
    var selected =
        _sessions.where((row) => _selected.contains(row.identity)).toList();
    if (_username.text.trim().isEmpty ||
        (_mode == 'selected' && selected.isEmpty)) {
      setState(() => _error = context.l10n.shareNeedsSelection);
      return;
    }
    if (_scope != sharing.accountScope || _working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      if (_mode == 'all' || selected.any((s) => s.source == 'personal')) {
        final cloud = context.read<PersonalCloudProvider?>();
        if (cloud == null) throw StateError('SHARE_SYNC_REQUIRED');
        await cloud.syncNow();
        if (!mounted || _scope != sharing.accountScope) return;
        if (cloud.state != PersonalCloudSyncState.upToDate) {
          throw StateError('SHARE_SYNC_REQUIRED');
        }
      }
      if (!mounted || _scope != sharing.accountScope) return;
      if (_edit &&
          (_mode == 'all' || selected.any((s) => s.source == 'personal'))) {
        if (!sharing.supportsPersonalPromotion) {
          throw StateError('SHARING_UPGRADE_REQUIRED');
        }
        final promoted = await _promotePersonalSessions(selected);
        if (promoted == null || !mounted || _scope != sharing.accountScope) {
          return;
        }
        selected = [
          for (final row in selected)
            promoted.contains(row.sessionId) && row.source == 'personal'
                ? ShareSessionRef(
                    source: 'collaboration',
                    sessionId: row.sessionId,
                    title: row.title)
                : row
        ];
      }
      await sharing.saveShare(
          username: _username.text.trim(),
          scopeMode: _mode,
          sessions: selected,
          canEditLogs: _edit,
          canDeleteLogs: _delete,
          expectedScope: _scope,
          grantId: _grant?.id);
      if (!mounted) return;
      setState(() {
        _grant = null;
        _username.clear();
        _selected.clear();
        _mode = 'selected';
        _edit = _delete = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.shareSaved)));
    } catch (error) {
      if (mounted) setState(() => _error = sharingErrorText(context, error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<Set<String>?> _promotePersonalSessions(
      List<ShareSessionRef> selected) async {
    final sessions = context.read<SessionProvider>();
    final sharing = context.read<AccountShareProvider>();
    final entries = await sessions.listAvailableSessionEntries();
    if (!mounted || _scope != sharing.accountScope) return null;
    final candidates = entries
        .where((entry) =>
            !entry.isShared &&
            !entry.hasCollaborationBinding &&
            entry.session.status == 'active' &&
            (_mode == 'all' ||
                selected.any((row) =>
                    row.source == 'personal' &&
                    row.sessionId == entry.session.sessionId)))
        .toList();
    if (candidates.isEmpty) return <String>{};
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              key: const Key('confirm-share-promotion'),
              title: Text(zh
                  ? '开启共同编辑并升级协作'
                  : 'Enable editing and upgrade to collaboration'),
              content: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(zh
                        ? '以下正在进行的个人会话将升级为协作，保留会话和记录，不创建副本。之后通过服务器同步；撤销共享不会撤销已保存的修改。'
                        : 'These active personal sessions will become collaborative, keeping their identity and records. Changes will sync through the server. Revoking access does not undo saved edits.'),
                    const SizedBox(height: 12),
                    for (final entry in candidates)
                      Text('• ${entry.session.title}'),
                    const SizedBox(height: 12),
                    Text(zh
                        ? '已关闭的会话保持只读。新增、修改与删除权限分开；不会授予管理会话或继续转授权的权限。'
                        : 'Closed sessions remain read-only. Delete permission is separate; no session-management or resharing permission is granted.'),
                    if (_mode == 'all')
                      Text(zh
                          ? '以后新建的个人会话会持续共享，但先保持只读，需由你开启协作后才能共同编辑。'
                          : 'Future personal sessions remain shared read-only until you enable collaboration.'),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: Text(c.l10n.cancel)),
                FilledButton(
                    key: const Key('confirm-share-promotion-accept'),
                    onPressed: () => Navigator.pop(c, true),
                    child: Text(c.l10n.hubEnableCollaboration)),
              ],
            ));
    if (confirmed != true || !mounted || _scope != sharing.accountScope) {
      return null;
    }
    final previous = sessions.currentSessionId;
    final logs = context.read<LogProvider>();
    final collaboration = context.read<CollaborationProvider>();
    final cloud = context.read<PersonalCloudProvider>();
    final promoted = <String>{};
    String? last;
    try {
      for (final entry in candidates) {
        if (!mounted || _scope != sharing.accountScope) {
          throw StateError('ACCOUNT_CHANGED');
        }
        final id = entry.session.sessionId;
        await logs.reloadForSession(id, propagateErrors: true);
        if (!mounted || _scope != sharing.accountScope) {
          throw StateError('ACCOUNT_CHANGED');
        }
        await sessions.switchToSession(id);
        last = id;
        await cloud.runWithPersonalSyncPaused(() =>
            collaboration.publishCurrentSession(promotePersonalShare: true));
        if (!mounted ||
            _scope != sharing.accountScope ||
            sessions.currentSessionId != id) {
          throw StateError('ACCOUNT_CHANGED');
        }
        promoted.add(id);
        // Retain completed progress if a later publication or share send fails.
        setState(() {
          _sessions = [
            for (final row in _sessions)
              row.source == 'personal' && row.sessionId == id
                  ? ShareSessionRef(
                      source: 'collaboration', sessionId: id, title: row.title)
                  : row
          ];
          if (_selected.remove('personal:$id')) {
            _selected.add('collaboration:$id');
          }
        });
      }
      return promoted;
    } finally {
      if (mounted &&
          _scope == sharing.accountScope &&
          previous != null &&
          sessions.currentSessionId == last &&
          previous != last) {
        await logs.reloadForSession(previous, propagateErrors: true);
        await sessions.switchToSession(previous);
      }
      if (_scope == sharing.accountScope) await sharing.refresh();
    }
  }

  Future<void> _revoke(AccountShareGrantDto grant) async {
    final sharing = context.read<AccountShareProvider>();
    final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(context.l10n.shareRevoke),
                content: Text(context.l10n.shareRevokeHint),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.l10n.cancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.l10n.shareRevoke))
                ]));
    if (yes != true || !mounted) return;
    try {
      await sharing.respondShare(
          grant.id, grant.status == 'pending' ? 'cancel' : 'revoke',
          expectedScope: _scope);
      if (mounted && _grant?.id == grant.id) {
        setState(() {
          _grant = null;
          _username.clear();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = sharingErrorText(context, error));
    }
  }

  Future<void> _sync() async {
    final cloud = context.read<PersonalCloudProvider?>();
    if (cloud == null) return;
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(context.l10n.personalCloudTitle),
              content: SizedBox(
                  width: 600,
                  child: SingleChildScrollView(
                      child: PersonalCloudPanel(
                    onOpenConflicts: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (pageContext) => PersonalCloudConflictPage(
                                  onOpenDatabase: () =>
                                      Navigator.pop(pageContext),
                                ))),
                  ))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.close))
              ],
            ));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sharing = context.watch<AccountShareProvider>();
    final changed = _scope != sharing.accountScope;
    final disabled = _loading || _working || sharing.busy || changed;
    final needle = _search.text.trim().toLowerCase();
    final visible = _sessions
        .where((s) =>
            s.title.toLowerCase().contains(needle) ||
            s.sessionId.toLowerCase().contains(needle))
        .toList();
    return PopScope(
        canPop: !_working,
        child: AlertDialog(
          title: Text(l.shareSessionsTitle),
          content: SizedBox(
              width: 620,
              child: changed
                  ? Text(l.shareAccessChanged)
                  : !sharing.supportsBatchSharing
                      ? Text(l.shareUpgradeRequired)
                      : SingleChildScrollView(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                              const ShareInvitationsPanel(),
                              const Divider(height: 24),
                              if (_loading || _working)
                                const LinearProgressIndicator(),
                              if (_error != null) ...[
                                Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)),
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                        onPressed: disabled ? null : _load,
                                        child: Text(l.retry)))
                              ],
                              TextField(
                                  key: const Key('share-recipient'),
                                  controller: _username,
                                  enabled: !disabled && _grant == null,
                                  decoration: InputDecoration(
                                      labelText: l.usernameLabel,
                                      helperText: l.shareRecipientHint,
                                      helperMaxLines: 2)),
                              if (_grant == null &&
                                  sharing.social.friends.isNotEmpty)
                                Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          for (final friend
                                              in sharing.social.friends)
                                            ActionChip(
                                                label: Text(friend.username),
                                                onPressed: disabled
                                                    ? null
                                                    : () {
                                                        final matches = sharing
                                                            .outgoing
                                                            .where((g) =>
                                                                g.granteeUserId ==
                                                                friend.userId);
                                                        if (matches
                                                            .isNotEmpty) {
                                                          _chooseGrant(
                                                              matches.first);
                                                        } else {
                                                          setState(() =>
                                                              _username.text =
                                                                  friend
                                                                      .username);
                                                        }
                                                      }),
                                        ])),
                              const SizedBox(height: 16),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                ChoiceChip(
                                    key: const Key('share-scope-selected'),
                                    label: Text(l.shareSelected),
                                    selected: _mode == 'selected',
                                    onSelected: disabled
                                        ? null
                                        : (_) =>
                                            setState(() => _mode = 'selected')),
                                ChoiceChip(
                                    key: const Key('share-scope-all'),
                                    label: Text(l.shareAll),
                                    selected: _mode == 'all',
                                    onSelected: disabled
                                        ? null
                                        : (_) => setState(() => _mode = 'all')),
                              ]),
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(_mode == 'all'
                                      ? l.shareAllHint
                                      : l.shareSelectedHint)),
                              if (_mode == 'selected') ...[
                                TextField(
                                    key: const Key('share-session-search'),
                                    controller: _search,
                                    onChanged: (_) => setState(() {}),
                                    decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.search),
                                        hintText: l.searchSessions)),
                                Wrap(spacing: 8, children: [
                                  TextButton(
                                      onPressed: disabled
                                          ? null
                                          : () => setState(() =>
                                              _selected.addAll(visible
                                                  .map((s) => s.identity))),
                                      child: Text(l.shareSelectVisible)),
                                  TextButton(
                                      onPressed: disabled
                                          ? null
                                          : () => setState(_selected.clear),
                                      child: Text(
                                          '${l.shareClearSelection} (${_selected.length})')),
                                ]),
                                SizedBox(
                                    height: 210,
                                    child: visible.isEmpty
                                        ? Center(
                                            child: Text(l.historySessionsEmpty))
                                        : ListView.builder(
                                            itemCount: visible.length,
                                            itemBuilder: (context, index) {
                                              final s = visible[index];
                                              return CheckboxListTile(
                                                  key: Key(
                                                      'share-select-${s.identity}'),
                                                  dense: true,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: Text(s.title),
                                                  subtitle: Text(s.source ==
                                                          'personal'
                                                      ? l.hubMyRecords
                                                      : l.hubTogetherRecords),
                                                  value: _selected
                                                      .contains(s.identity),
                                                  onChanged: disabled
                                                      ? null
                                                      : (yes) => setState(() {
                                                            if (yes == true) {
                                                              _selected.add(
                                                                  s.identity);
                                                            } else {
                                                              _selected.remove(
                                                                  s.identity);
                                                            }
                                                          }));
                                            })),
                              ],
                              const Divider(),
                              SwitchListTile(
                                  key: const Key('share-edit-permission'),
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(l.shareEditLogs),
                                  subtitle: Text(_edit
                                      ? l.shareEditLogs
                                      : l.shareViewOnly),
                                  value: _edit,
                                  onChanged: disabled
                                      ? null
                                      : (value) => setState(() {
                                            _edit = value;
                                            if (!value) _delete = false;
                                          })),
                              SwitchListTile(
                                  key: const Key('share-delete-permission'),
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(l.shareDeleteLogs),
                                  value: _delete,
                                  onChanged: disabled || !_edit
                                      ? null
                                      : (value) =>
                                          setState(() => _delete = value)),
                              Text(l.sharePermissionHint,
                                  style: Theme.of(context).textTheme.bodySmall),
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                      onPressed: disabled ? null : _sync,
                                      icon:
                                          const Icon(Icons.cloud_sync_outlined),
                                      label: Text(l.shareSyncLocal))),
                              if (sharing.outgoing.isNotEmpty) ...[
                                const Divider(),
                                Text(l.shareManage,
                                    style:
                                        Theme.of(context).textTheme.titleSmall),
                                for (final grant in sharing.outgoing)
                                  ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(grant.granteeUsername.isEmpty
                                          ? grant.granteeUserId
                                          : grant.granteeUsername),
                                      subtitle: Text(
                                          '${grant.scopeMode == 'all' ? l.shareAll : '${l.shareSelected} (${grant.selectedSessions.length})'} · ${grant.canEditLogs ? l.shareEditLogs : l.shareViewOnly}${grant.canDeleteLogs ? ' · ${l.shareDeleteLogs}' : ''}${grant.status == 'pending' ? ' · ${l.socialRequestSent}' : ''}'),
                                      trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                                tooltip: l.save,
                                                onPressed: disabled
                                                    ? null
                                                    : () => _chooseGrant(grant),
                                                icon: const Icon(
                                                    Icons.edit_outlined)),
                                            IconButton(
                                                tooltip: l.shareRevoke,
                                                onPressed: disabled
                                                    ? null
                                                    : () => _revoke(grant),
                                                icon:
                                                    const Icon(Icons.link_off))
                                          ])),
                              ],
                            ]))),
          actions: [
            TextButton(
                onPressed: _working ? null : () => Navigator.pop(context),
                child: Text(l.close)),
            if (_grant != null)
              TextButton(
                  onPressed: disabled
                      ? null
                      : () => setState(() {
                            _grant = null;
                            _username.clear();
                            _selected.clear();
                            _mode = 'selected';
                            _edit = _delete = false;
                          }),
                  child: Text(l.cancel)),
            FilledButton(
                key: const Key('share-save'),
                onPressed:
                    disabled || !sharing.supportsBatchSharing ? null : _submit,
                child: Text(_grant == null ? l.shareSend : l.save)),
          ],
        ));
  }
}
