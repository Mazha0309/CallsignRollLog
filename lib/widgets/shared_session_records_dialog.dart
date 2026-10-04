import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/account_share_dto.dart';
import 'package:openlogtool/models/log_entry.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/utils/log_time.dart';
import 'package:openlogtool/widgets/record_editor_dialog.dart';
import 'package:openlogtool/widgets/session_sharing_dialog.dart';

Future<void> showSharedSessionRecords(
        BuildContext context, SharedSessionDto session) =>
    showDialog<void>(
        context: context,
        builder: (_) => SharedSessionRecordsDialog(session: session));

/// Reads and edits the shared source directly; never changes the workbench or
/// creates a local collaboration binding.
class SharedSessionRecordsDialog extends StatefulWidget {
  const SharedSessionRecordsDialog({super.key, required this.session});
  final SharedSessionDto session;
  @override
  State<SharedSessionRecordsDialog> createState() =>
      _SharedSessionRecordsDialogState();
}

class _SharedSessionRecordsDialogState
    extends State<SharedSessionRecordsDialog> {
  final _search = TextEditingController();
  String? _scope, _error;
  int? _revision;
  int _page = 1, _request = 0;
  bool _loading = true, _working = false;
  SharedRecordsPage? _records;
  SharedSessionDto get _session => _records?.session ?? widget.session;

  @override
  void initState() {
    super.initState();
    _scope = context.read<AccountShareProvider>().accountScope;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sharing = context.watch<AccountShareProvider>();
    if (_scope != sharing.accountScope) {
      _request++;
      _records = null;
      _loading = false;
      _error = context.l10n.shareAccessChanged;
      return;
    }
    if (_revision != sharing.revision) {
      _revision = sharing.revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_working) unawaited(_load());
      });
    }
  }

  @override
  void dispose() {
    _request++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted ||
        _scope != context.read<AccountShareProvider>().accountScope) {
      return;
    }
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context
          .read<AccountShareProvider>()
          .loadSharedRecords(widget.session,
              page: _page, query: _search.text.trim(), expectedScope: _scope);
      if (!mounted || request != _request) return;
      if (_page > 1 && _page > result.totalPages) {
        _page = result.totalPages > 0 ? result.totalPages : 1;
        await _load();
        return;
      }
      setState(() {
        _records = result;
        _loading = false;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() {
          _records = null;
          _loading = false;
          _error = sharingErrorText(context, error);
        });
      }
    }
  }

  LogEntry _record(Map<String, Object?> row) =>
      LogEntry.fromJson({...row, 'id': row['syncId'] ?? row['sync_id']});
  Map<String, Object?> _value(LogEntry log) => {
        'time': log.time,
        'controller': log.controller,
        'callsign': log.callsign,
        'rstSent': log.report,
        'rstRcvd': log.rstRcvd,
        'qth': log.qth,
        'device': log.device,
        'power': log.power,
        'antenna': log.antenna,
        'height': log.height,
        'remarks': log.remarks,
      };

  Future<void> _openRecord([Map<String, Object?>? row]) async {
    if (_loading || _working) return;
    final sharing = context.read<AccountShareProvider>();
    final session = _session;
    final original = row == null
        ? LogEntry(
            time: DateTime.now().toUtc().toIso8601String(),
            controller: '',
            callsign: '',
            report: '59',
            rstRcvd: '59',
            qth: '',
            device: '',
            power: '',
            antenna: '',
            height: '',
            sessionId: session.sessionId)
        : _record(row);
    final readOnly = !session.canEditLogs;
    final edited = await showDialog<LogEntry>(
        context: context,
        builder: (context) {
          final current = context.watch<AccountShareProvider>();
          if (_scope != current.accountScope ||
              !current.sharedSessions
                  .any((s) => s.identity == session.identity)) {
            return AlertDialog(
                content: Text(context.l10n.shareAccessChanged),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.l10n.close))
                ]);
          }
          return RecordEditorDialog(
              log: original,
              readOnly: readOnly ||
                  !current.sharedSessions.any(
                      (s) => s.identity == session.identity && s.canEditLogs),
              title: row == null ? context.l10n.shareAddRecord : null);
        });
    if (edited == null ||
        !mounted ||
        readOnly ||
        _scope != sharing.accountScope) {
      return;
    }
    final value = _value(edited);
    // The editor displays HH:mm. Preserve the original instant if the user did
    // not change it; otherwise use the record's date, not today's date.
    value['time'] =
        edited.time == formatLogTimeForDisplay(original.time) && row != null
            ? original.time
            : normalizeLogTimeForStorage(edited.time,
                reference: DateTime.tryParse(original.time) ??
                    DateTime.tryParse(original.createdAt));
    if (row != null) {
      final before = _value(original);
      value.removeWhere((key, next) => before[key] == next);
      if (value.isEmpty) return;
    }
    await _mutate(session, {
      'operation': row == null ? 'create' : 'update',
      'syncId': original.id,
      if (session.source == 'personal')
        'expectedRevision': session.snapshotRevision
      else
        'baseVersion': row?['version'] ?? 0,
      row == null ? 'value' : 'patch': value,
    });
  }

  Future<void> _delete(Map<String, Object?> row) async {
    final session = _session;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(context.l10n.deleteRecord),
                content: Text(context.l10n.deleteRecordConfirmation),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.l10n.cancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.l10n.delete))
                ]));
    if (confirmed != true || !mounted) return;
    await _mutate(session, {
      'operation': 'delete',
      'syncId': row['syncId'] ?? row['sync_id'],
      if (session.source == 'personal')
        'expectedRevision': session.snapshotRevision
      else
        'baseVersion': row['version']
    });
  }

  Future<void> _mutate(
      SharedSessionDto session, Map<String, Object?> body) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await context
          .read<AccountShareProvider>()
          .mutateSharedRecord(session, body, expectedScope: _scope);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = sharingErrorText(context, error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sharing = context.watch<AccountShareProvider>();
    final changed = _scope != sharing.accountScope;
    final disabled = _loading || _working || changed || sharing.busy;
    return AlertDialog(
      title: Text(changed ? l.sharedSessionBadge : widget.session.title),
      content: SizedBox(
          width: 700,
          height: MediaQuery.sizeOf(context).height * .6,
          child: changed
              ? Text(l.shareAccessChanged)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      Text(l.sharedSessionFrom(widget.session.grantorUsername)),
                      Text(l.shareRecordsHint,
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      TextField(
                          key: const Key('shared-records-search'),
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: l.socialSearch,
                              suffixIcon: IconButton(
                                  tooltip: l.socialSearch,
                                  onPressed: disabled
                                      ? null
                                      : () {
                                          _page = 1;
                                          unawaited(_load());
                                        },
                                  icon: const Icon(Icons.arrow_forward))),
                          onSubmitted: disabled
                              ? null
                              : (_) {
                                  _page = 1;
                                  unawaited(_load());
                                }),
                      if (_loading || _working) const LinearProgressIndicator(),
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(_error!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))),
                      Expanded(
                          child: _records == null
                              ? const SizedBox.shrink()
                              : _records!.items.isEmpty
                                  ? Center(child: Text(l.historySessionsEmpty))
                                  : ListView.separated(
                                      itemCount: _records!.items.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final row = _records!.items[index];
                                        final record = _record(row);
                                        return ListTile(
                                          key:
                                              Key('shared-record-${record.id}'),
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(record.callsign),
                                          subtitle: Text(
                                              '${formatLogTimeForDisplay(record.time, includeDate: true)} · ${record.controller}\n${record.qth}'),
                                          onTap: disabled
                                              ? null
                                              : () => _openRecord(row),
                                          trailing: _session.canDeleteLogs
                                              ? IconButton(
                                                  tooltip: l.deleteRecord,
                                                  icon: const Icon(
                                                      Icons.delete_outline),
                                                  onPressed: disabled
                                                      ? null
                                                      : () => _delete(row))
                                              : const Icon(Icons.chevron_right),
                                        );
                                      })),
                      if (_records != null)
                        Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(l.sessionPage(
                                  _records!.page,
                                  _records!.totalPages > 0
                                      ? _records!.totalPages
                                      : 1)),
                              IconButton(
                                  key: const Key('shared-records-previous'),
                                  tooltip: MaterialLocalizations.of(context)
                                      .previousPageTooltip,
                                  onPressed: disabled || _page <= 1
                                      ? null
                                      : () {
                                          _page--;
                                          unawaited(_load());
                                        },
                                  icon: const Icon(Icons.chevron_left)),
                              IconButton(
                                  key: const Key('shared-records-next'),
                                  tooltip: MaterialLocalizations.of(context)
                                      .nextPageTooltip,
                                  onPressed:
                                      disabled || _page >= _records!.totalPages
                                          ? null
                                          : () {
                                              _page++;
                                              unawaited(_load());
                                            },
                                  icon: const Icon(Icons.chevron_right)),
                            ]),
                    ])),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l.close)),
        TextButton(onPressed: disabled ? null : _load, child: Text(l.refresh)),
        if (!changed && _records != null && _session.canEditLogs)
          FilledButton.icon(
              key: const Key('shared-record-add'),
              onPressed: disabled ? null : _openRecord,
              icon: const Icon(Icons.add),
              label: Text(l.shareAddRecord)),
      ],
    );
  }
}
