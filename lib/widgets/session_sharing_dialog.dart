import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/account_share_dto.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/personal_cloud_provider.dart';
import 'package:openlogtool/providers/session_provider.dart';
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
  if ('$error'.contains('ACCOUNT_CHANGED')) return l.shareAccessChanged;
  if ('$error'.contains('SHARE_SYNC_REQUIRED')) return l.shareSyncFirst;
  return l.shareOperationFailed;
}

Future<void> showSessionSharingDialog(BuildContext context) => showDialog<void>(
    context: context, builder: (_) => const SessionSharingDialog());

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
    final selected =
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
    return AlertDialog(
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
                                    color:
                                        Theme.of(context).colorScheme.error)),
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
                                child:
                                    Wrap(spacing: 6, runSpacing: 6, children: [
                                  for (final friend in sharing.social.friends)
                                    ActionChip(
                                        label: Text(friend.username),
                                        onPressed: disabled
                                            ? null
                                            : () {
                                                final matches = sharing.outgoing
                                                    .where((g) =>
                                                        g.granteeUserId ==
                                                        friend.userId);
                                                if (matches.isNotEmpty) {
                                                  _chooseGrant(matches.first);
                                                } else {
                                                  setState(() => _username
                                                      .text = friend.username);
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
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                                      : () => setState(() => _selected.addAll(
                                          visible.map((s) => s.identity))),
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
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(s.title),
                                              subtitle: Text(
                                                  s.source == 'personal'
                                                      ? l.hubMyRecords
                                                      : l.hubTogetherRecords),
                                              value: _selected
                                                  .contains(s.identity),
                                              onChanged: disabled
                                                  ? null
                                                  : (yes) => setState(() {
                                                        if (yes == true) {
                                                          _selected
                                                              .add(s.identity);
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
                              subtitle: Text(
                                  _edit ? l.shareEditLogs : l.shareViewOnly),
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
                                  : (value) => setState(() => _delete = value)),
                          Text(l.sharePermissionHint,
                              style: Theme.of(context).textTheme.bodySmall),
                          Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                  onPressed: disabled ? null : _sync,
                                  icon: const Icon(Icons.cloud_sync_outlined),
                                  label: Text(l.shareSyncLocal))),
                          if (sharing.outgoing.isNotEmpty) ...[
                            const Divider(),
                            Text(l.shareManage,
                                style: Theme.of(context).textTheme.titleSmall),
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
                                            icon: const Icon(Icons.link_off))
                                      ])),
                          ],
                        ]))),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l.close)),
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
    );
  }
}
