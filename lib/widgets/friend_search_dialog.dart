import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/social_dto.dart';
import 'package:openlogtool/providers/account_share_provider.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/services/server_api.dart';
import 'package:openlogtool/theme/app_theme.dart';
import 'package:openlogtool/widgets/settings/settings_ui.dart';

Future<void> showFriendSearchDialog(BuildContext context) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const FriendSearchDialog());

class FriendSearchDialog extends StatefulWidget {
  const FriendSearchDialog({super.key});
  @override
  State<FriendSearchDialog> createState() => _FriendSearchDialogState();
}

class _FriendSearchDialogState extends State<FriendSearchDialog> {
  final _query = TextEditingController();
  final _sent = <String, String>{};
  SocialUserSearchPage? _results;
  String? _initialScope;
  String? _error;
  int _generation = 0;
  int _snapshotRevision = 0;
  bool _searching = false;
  bool _sending = false;
  bool _changed = false;

  String _scope() {
    final social = context.read<AccountShareProvider>();
    final server = context.read<ServerProvider>();
    return '${identityHashCode(social)}|${social.accountScope}|${social.accountId}|'
        '${server.contextRevision}|${server.serverUrl}|${server.accountId}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.watch<AccountShareProvider>();
    context.watch<ServerProvider>();
    _initialScope ??= _scope();
    if (_initialScope != _scope() && !_changed) {
      _changed = true;
      _generation++;
      _results = null;
      _error = null;
      _searching = false;
      _query.clear();
    }
  }

  bool get _current => mounted && !_changed && _initialScope == _scope();

  void _editQuery(String _) => setState(() {
        _generation++;
        _results = null;
        _error = null;
        _searching = false;
        _sent.clear();
      });

  Future<void> _search() async {
    if (!_current || _sending || _searching) return;
    final query = _query.text.trim();
    if (query.runes.length < 2 || query.runes.length > 64) return;
    final social = context.read<AccountShareProvider>();
    final generation = ++_generation;
    final snapshotRevision = social.revision;
    setState(() {
      _searching = true;
      _results = null;
      _error = null;
      _sent.clear();
    });
    try {
      final results = await social.searchUsers(query);
      if (!_current || generation != _generation) return;
      setState(() {
        _results = results;
        _snapshotRevision = snapshotRevision;
      });
    } catch (error) {
      if (!_current || generation != _generation) return;
      setState(() => _error = error is ServerApiException
          ? switch (error.statusCode) {
              404 => context.l10n.socialSearchUpgrade,
              429 => context.l10n.socialSearchRateLimited,
              _ => context.l10n.socialSearchFailed,
            }
          : context.l10n.socialSearchFailed);
    } finally {
      if (_current && generation == _generation) {
        setState(() => _searching = false);
      }
    }
  }

  (String, String?) _relationship(SocialUserSearchResult person) {
    final social = context.read<AccountShareProvider>();
    if (social.revision > _snapshotRevision && social.lastError == null) {
      if (social.social.friends.any((f) => f.userId == person.userId)) {
        return ('friend', null);
      }
      final pending = social.social.friendRequests.where((r) =>
          r.status == 'pending' &&
          (r.senderId == person.userId || r.recipientId == person.userId));
      if (pending.isNotEmpty) {
        final r = pending.first;
        return (r.senderId == person.userId ? 'incoming' : 'outgoing', r.id);
      }
      return ('none', null);
    }
    return (_sent[person.userId] ?? person.relationship, person.requestId);
  }

  Future<void> _act(SocialUserSearchResult person) async {
    if (!_current || _sending || _searching) return;
    final social = context.read<AccountShareProvider>();
    if (social.busy) return;
    final (relationship, requestId) = _relationship(person);
    if (relationship != 'none' && relationship != 'incoming') return;
    if (relationship == 'incoming' && requestId == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await social.mutateSocial(
          'POST',
          relationship == 'incoming'
              ? '/friend-requests/${Uri.encodeComponent(requestId!)}/accept'
              : '/friend-requests',
          relationship == 'incoming'
              ? const {}
              : {'username': person.username});
      if (!_current) return;
      setState(() => _sent[person.userId] =
          relationship == 'incoming' ? 'friend' : 'outgoing');
    } catch (error) {
      if (!_current) return;
      setState(() => _error = error is ServerApiException
          ? switch (error.code) {
              'FRIEND_BLOCKED' => context.l10n.socialErrorBlocked,
              'USER_NOT_FOUND' => context.l10n.socialErrorUser,
              'REQUEST_CLOSED' => context.l10n.socialErrorClosed,
              _ => context.l10n.operationFailed(error.message),
            }
          : context.l10n.operationFailed('$error'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final social = context.watch<AccountShareProvider>();
    final server = context.watch<ServerProvider>();
    final disabled = _sending || social.busy || _changed;
    final valid = _query.text.trim().runes.length >= 2;
    final theme = Theme.of(context);
    final available = MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom -
        240;
    return PopScope(
      canPop: !_sending,
      child: AlertDialog(
        key: const Key('friend-search-dialog'),
        title: Text(l.socialAddFriend),
        content: SizedBox(
          width: AppDimensions.dialogWidth,
          height: available.clamp(160.0, 520.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_changed)
              AppNotice(message: l.hubContextChanged, tone: AppTone.warning)
            else ...[
              Text(l.socialSearchScope,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              if (server.serverUrl.isNotEmpty)
                Text(server.serverUrl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall),
              const SizedBox(height: AppSpace.md),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: TextField(
                  key: const Key('friend-username'),
                  controller: _query,
                  autofocus: true,
                  enabled: !disabled,
                  maxLength: 64,
                  textInputAction: TextInputAction.search,
                  onChanged: _editQuery,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                      labelText: l.socialSearchHint,
                      counterText: '',
                      prefixIcon: const Icon(Icons.person_search_outlined)),
                )),
                const SizedBox(width: AppSpace.xs),
                IconButton.filled(
                    key: const Key('friend-search-submit'),
                    tooltip: l.socialSearch,
                    onPressed:
                        disabled || _searching || !valid ? null : _search,
                    icon: const Icon(Icons.search)),
              ]),
              const SizedBox(height: AppSpace.md),
              if (_searching || _sending) const LinearProgressIndicator(),
              Expanded(
                  child: ListView(
                key: const PageStorageKey('friend-search-results'),
                padding: EdgeInsets.zero,
                children: [
                  if (_error != null) ...[
                    AppNotice(message: _error!, tone: AppTone.danger),
                    Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                            onPressed: disabled || _searching ? null : _search,
                            child: Text(l.retry))),
                  ] else if (!_searching && _results == null)
                    AppNotice(message: l.socialSearchStart, icon: Icons.search),
                  if (_results case final results?) ...[
                    if (results.items.isEmpty)
                      AppNotice(
                          message: l.socialSearchEmpty,
                          icon: Icons.person_search_outlined),
                    AppTileGroup(children: [
                      for (final person in results.items)
                        if (!social.social.blocks
                            .any((b) => b.userId == person.userId))
                          _personRow(person, disabled),
                    ]),
                    if (results.hasMore) ...[
                      const SizedBox(height: AppSpace.sm),
                      AppNotice(message: l.socialSearchMore),
                    ],
                  ],
                ],
              )),
            ],
          ]),
        ),
        actions: [
          TextButton(
              onPressed: _sending ? null : () => Navigator.pop(context),
              child: Text(l.close))
        ],
      ),
    );
  }

  Widget _personRow(SocialUserSearchResult person, bool disabled) {
    final l = context.l10n;
    final (relationship, _) = _relationship(person);
    final actionable = relationship == 'none' || relationship == 'incoming';
    final action = actionable
        ? OutlinedButton(
            key: Key('friend-search-action-${person.userId}'),
            onPressed: disabled ? null : () => _act(person),
            child: Text(
                relationship == 'incoming' ? l.socialAccept : l.socialSend))
        : null;
    final status = switch (relationship) {
      'friend' => l.socialAlreadyFriend,
      'incoming' => l.socialRequestIncoming,
      'outgoing' => l.socialRequestSent,
      _ => null,
    };
    return LayoutBuilder(
      key: Key('friend-search-result-${person.userId}'),
      builder: (context, constraints) {
        final stacked = actionable && constraints.maxWidth < 420;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(person.username),
              subtitle: status == null ? null : Text(status),
              trailing: actionable
                  ? (stacked ? null : action)
                  : Icon(
                      relationship == 'friend'
                          ? Icons.check_circle_outline
                          : Icons.schedule,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            if (stacked)
              Align(alignment: AlignmentDirectional.centerEnd, child: action),
          ]),
        );
      },
    );
  }
}
