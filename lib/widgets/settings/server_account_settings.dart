import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/account_dto.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/services/secure_token_store.dart';
import 'package:openlogtool/services/server_api.dart';
import 'package:openlogtool/utils/app_snack_bar.dart';
import 'package:openlogtool/utils/server_connection_error.dart';
import 'package:openlogtool/utils/server_url.dart';
import 'package:openlogtool/widgets/settings/settings_ui.dart';
import 'package:provider/provider.dart';

class ServerAccountSettings extends StatefulWidget {
  const ServerAccountSettings({
    required this.cardPadding,
    super.key,
  });

  final double cardPadding;

  @override
  State<ServerAccountSettings> createState() => _ServerAccountSettingsState();
}

class _ServerAccountSettingsState extends State<ServerAccountSettings> {
  final _serverUrlController = TextEditingController();
  bool _initializedUrl = false;
  bool _urlEdited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen here so an asynchronously restored server URL reaches the field
    // even though the settings page is already mounted in Home's IndexedStack.
    // Keep a user's in-progress edit untouched.
    final provider = Provider.of<ServerProvider>(context);
    if (!_initializedUrl) {
      _serverUrlController.text = provider.serverUrl;
      _initializedUrl = true;
    } else if (!_urlEdited && _serverUrlController.text != provider.serverUrl) {
      _serverUrlController.text = provider.serverUrl;
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerProvider>(
      builder: (context, server, _) {
        final l10n = context.l10n;
        return SettingsSectionCard(
          key: const Key('server-account-settings'),
          icon: Icons.cloud_outlined,
          title: l10n.serverSettingsTitle,
          description: l10n.socialServerLinkHint,
          padding: widget.cardPadding,
          headerTrailing: _ConnectionBadge(server: server),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('server-url-field'),
                controller: _serverUrlController,
                enabled: !server.isBusy,
                keyboardType: TextInputType.url,
                autofillHints: const [AutofillHints.url],
                decoration: InputDecoration(
                  labelText: l10n.serverAddressLabel,
                  hintText: l10n.serverAddressHint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: const Icon(Icons.link, size: 18),
                ),
                onChanged: (_) => _urlEdited = true,
                onSubmitted: server.isBusy
                    ? null
                    : (_) => unawaited(_saveAndCheck(server)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('server-check-button'),
                  icon: server.isBusy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering, size: 16),
                  label: Text(l10n.serverSaveAndCheck),
                  onPressed: server.isBusy ? null : () => _saveAndCheck(server),
                ),
              ),
              if (server.serverInfo != null) ...[
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.copy_outlined),
                      label: Text(l10n.socialServerLink),
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: '${server.serverUrl}/connect'));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.socialDone)));
                        }
                      },
                    )),
                const SizedBox(height: 8),
                SelectableText(
                  l10n.serverInstanceDetails(
                    server.serverInfo!.serverInstanceId,
                    server.serverInfo!.features.join(', '),
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (server.tokenStorageStatus.isDegraded) ...[
                const SizedBox(height: 12),
                _tokenStorageWarning(server.tokenStorageStatus),
              ],
              const Divider(height: 28),
              if (!server.isLoggedIn)
                _signedOutActions(server)
              else
                _signedInAccount(server),
            ],
          ),
        );
      },
    );
  }

  Widget _tokenStorageWarning(TokenStorageStatus status) {
    final memoryOnly = status.backend == TokenStorageBackend.memoryOnly;
    return AppNotice(
      key: Key('token-storage-warning-${status.backend.name}'),
      icon: memoryOnly ? Icons.error_outline : Icons.key_off_outlined,
      tone: memoryOnly ? AppTone.danger : AppTone.warning,
      message: memoryOnly
          ? context.l10n.tokenStorageMemoryOnlyWarning
          : context.l10n.tokenStoragePrivateFileWarning,
    );
  }

  Widget _signedOutActions(ServerProvider server) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.serverSignedOutHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('server-login-button'),
                icon: const Icon(Icons.login, size: 16),
                label: Text(l10n.serverLogin),
                onPressed:
                    server.isBusy ? null : () => _showLoginDialog(server),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('server-register-button'),
                icon: const Icon(Icons.person_add_outlined, size: 16),
                label: Text(l10n.serverRegister),
                onPressed:
                    server.isBusy ? null : () => _showRegisterDialog(server),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _signedInAccount(ServerProvider server) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              child: Text(
                (server.username?.isNotEmpty ?? false)
                    ? server.username![0].toUpperCase()
                    : '?',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.username ?? '',
                    key: const Key('account-username'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    l10n.serverAccountId(server.accountId ?? ''),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              key: const Key('server-logout-button'),
              icon: const Icon(Icons.logout, size: 16),
              label: Text(l10n.serverLogout),
              onPressed: server.isBusy ? null : () => _logout(server),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('account-change-username-button'),
              icon: const Icon(Icons.badge_outlined, size: 18),
              label: Text(l10n.accountChangeUsername),
              onPressed:
                  server.isBusy ? null : () => _showUsernameDialog(server),
            ),
            OutlinedButton.icon(
              key: const Key('account-change-password-button'),
              icon: const Icon(Icons.password_outlined, size: 18),
              label: Text(l10n.accountChangePassword),
              onPressed:
                  server.isBusy ? null : () => _showPasswordDialog(server),
            ),
            OutlinedButton.icon(
              key: const Key('account-device-sessions-button'),
              icon: const Icon(Icons.devices_outlined, size: 18),
              label: Text(l10n.accountDeviceSessions),
              onPressed: server.isBusy
                  ? null
                  : () => showDialog<void>(
                        context: context,
                        builder: (_) => DeviceSessionsDialog(provider: server),
                      ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveAndCheck(ServerProvider server) async {
    final candidateUrl =
        serverUrlFromConnectionInput(_serverUrlController.text);
    try {
      final info = await server.saveAndCheckServerUrl(candidateUrl);
      if (!mounted) return;
      _urlEdited = false;
      if (_serverUrlController.text != server.serverUrl) {
        _serverUrlController.text = server.serverUrl;
      }
      context.showLoggedSnackBar(
        SnackBar(
          content: Text(
            context.l10n.serverCheckSucceeded(
              info.protocolMin,
              info.protocolMax,
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      context.showLoggedSnackBar(
        SnackBar(
          content: Text(
            localizedServerConnectionError(
              l10n: context.l10n,
              serverUrl: candidateUrl,
              error: error,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _showLoginDialog(ServerProvider server) async {
    if (server.isBusy) return;
    final serverUrl = server.serverUrl;
    final accountId = server.accountId;
    var contextRevision = server.contextRevision;
    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CredentialsDialog(
        registration: false,
        isCurrentContext: () =>
            server.serverUrl == serverUrl &&
            server.accountId == accountId &&
            server.contextRevision == contextRevision,
        onSubmit: (username, password) async {
          final attempt = server.login(username, password);
          // login advances its context synchronously before the first await.
          // Allow this attempt's own revision on failure/retry, not a later
          // server/account switch while the request is running.
          contextRevision = server.contextRevision;
          try {
            await attempt;
          } on ServerApiException catch (error) {
            if (error.code != 'PASSWORD_CHANGE_REQUIRED' ||
                !server.passwordChangeRequired) {
              rethrow;
            }
          }
        },
      ),
    );
    if (submitted != true || !mounted) return;
    if (server.passwordChangeRequired) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => RequiredPasswordChangeDialog(provider: server),
      );
      return;
    }
    context.showLoggedSnackBar(
      SnackBar(content: Text(context.l10n.serverLoginSucceeded)),
    );
  }

  Future<void> _showRegisterDialog(ServerProvider server) async {
    if (server.isBusy) return;
    final serverUrl = server.serverUrl;
    final accountId = server.accountId;
    var contextRevision = server.contextRevision;
    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CredentialsDialog(
        registration: true,
        isCurrentContext: () =>
            server.serverUrl == serverUrl &&
            server.accountId == accountId &&
            server.contextRevision == contextRevision,
        onSubmit: (username, password) async {
          final attempt = server.register(username, password);
          contextRevision = server.contextRevision;
          await attempt;
        },
      ),
    );
    if (submitted != true || !mounted) return;
    context.showLoggedSnackBar(
      SnackBar(content: Text(context.l10n.serverRegistrationSucceeded)),
    );
  }

  Future<void> _showUsernameDialog(ServerProvider server) async {
    final values = await showDialog<_UsernameChange>(
      context: context,
      builder: (_) => _UsernameDialog(initialUsername: server.username ?? ''),
    );
    if (values == null || !mounted) return;
    try {
      await server.changeUsername(
        username: values.username,
        currentPassword: values.currentPassword,
      );
      if (!mounted) return;
      context.showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.accountUsernameUpdated)),
      );
    } catch (error) {
      if (mounted) {
        _showError(context.l10n.accountUpdateFailed(_errorDetail(error)));
      }
    }
  }

  Future<void> _showPasswordDialog(ServerProvider server) async {
    final values = await showDialog<_PasswordChange>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (values == null || !mounted) return;
    try {
      final result = await server.changePassword(
        currentPassword: values.currentPassword,
        newPassword: values.newPassword,
      );
      if (!mounted) return;
      context.showLoggedSnackBar(
        SnackBar(
          content: Text(
            context.l10n.accountPasswordUpdated(
              result.revokedDeviceSessionCount,
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showError(context.l10n.accountUpdateFailed(_errorDetail(error)));
      }
    }
  }

  Future<void> _logout(ServerProvider server) async {
    try {
      await server.logout();
    } catch (error) {
      if (mounted) {
        _showError(context.l10n.serverLogoutFailed(_errorDetail(error)));
      }
    }
  }

  void _showError(String message) {
    context.showLoggedSnackBar(SnackBar(content: Text(message)));
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.server});

  final ServerProvider server;

  @override
  Widget build(BuildContext context) {
    final connected = server.isServerReachable;
    return AppStatusPill(
      icon: connected ? Icons.check_circle_outline : Icons.cloud_off_outlined,
      tone: connected ? AppTone.success : AppTone.neutral,
      label: connected
          ? context.l10n.serverConnected
          : context.l10n.serverNotConnected,
    );
  }
}

class RequiredPasswordChangeDialog extends StatefulWidget {
  const RequiredPasswordChangeDialog({
    required this.provider,
    super.key,
  });

  final ServerProvider provider;

  @override
  State<RequiredPasswordChangeDialog> createState() =>
      _RequiredPasswordChangeDialogState();
}

class _RequiredPasswordChangeDialogState
    extends State<RequiredPasswordChangeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.provider.passwordChangeChallenge;
    final seconds = challenge?.passwordChangeTokenExpiresIn ?? 0;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const Key('required-password-change-dialog'),
        title: Text(context.l10n.passwordChangeRequiredTitle),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.passwordChangeRequiredHint(
                    challenge?.user.username ?? '',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.passwordChangeCredentialExpires(seconds),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('required-new-password-field'),
                  controller: _passwordController,
                  obscureText: true,
                  autofocus: true,
                  enabled: !_submitting,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: context.l10n.newPasswordLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => _passwordValidator(context, value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('required-confirm-password-field'),
                  controller: _confirmController,
                  obscureText: true,
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    labelText: context.l10n.confirmNewPasswordLabel,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => value != _passwordController.text
                      ? context.l10n.passwordMismatch
                      : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    key: const Key('required-password-change-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting
                ? null
                : () {
                    widget.provider.cancelRequiredPasswordChange();
                    Navigator.pop(context);
                  },
            child: Text(context.l10n.cancelLogin),
          ),
          FilledButton(
            key: const Key('complete-password-change-button'),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.completePasswordChange),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.provider.completeRequiredPasswordChange(
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      context.showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.passwordChangeCompleted)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = context.l10n.accountUpdateFailed(_errorDetail(error));
      });
    }
  }
}

class DeviceSessionsDialog extends StatefulWidget {
  const DeviceSessionsDialog({
    required this.provider,
    super.key,
  });

  final ServerProvider provider;

  @override
  State<DeviceSessionsDialog> createState() => _DeviceSessionsDialogState();
}

class _DeviceSessionsDialogState extends State<DeviceSessionsDialog> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) => AlertDialog(
        key: const Key('device-sessions-dialog'),
        title: Row(
          children: [
            Expanded(child: Text(context.l10n.deviceSessionsTitle)),
            IconButton(
              tooltip: context.l10n.refresh,
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        content: SizedBox(
          width: 620,
          height: 420,
          child: _body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && widget.provider.deviceSessions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && widget.provider.deviceSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _refresh,
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }
    final sessions = widget.provider.deviceSessions;
    if (sessions.isEmpty) {
      return Center(child: Text(context.l10n.deviceSessionsEmpty));
    }
    return ListView.separated(
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final session = sessions[index];
        final deviceName = session.deviceId?.trim();
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            session.current ? Icons.devices : Icons.devices_outlined,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  deviceName == null || deviceName.isEmpty
                      ? context.l10n.deviceUnknown
                      : deviceName,
                ),
              ),
              if (session.current)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(context.l10n.deviceCurrent),
                ),
            ],
          ),
          subtitle: Text(
            [
              if (session.userAgent?.isNotEmpty ?? false) session.userAgent!,
              if (session.ipAddress?.isNotEmpty ?? false)
                context.l10n.deviceIp(session.ipAddress!),
              context.l10n.deviceLastUsed(
                (session.lastUsedAt ?? session.createdAt).toLocal().toString(),
              ),
              context.l10n.deviceExpires(
                session.expiresAt.toLocal().toString(),
              ),
            ].join('\n'),
          ),
          isThreeLine: true,
          trailing: IconButton(
            tooltip: session.current
                ? context.l10n.revokeCurrentDevice
                : context.l10n.revokeDevice,
            onPressed:
                widget.provider.isBusy ? null : () => _confirmRevoke(session),
            icon: Icon(
              session.current ? Icons.logout : Icons.delete_outline,
            ),
          ),
        );
      },
    );
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      await widget.provider.refreshDeviceSessions();
    } catch (error) {
      if (mounted) {
        setState(() => _error = context.l10n.accountUpdateFailed(
              _errorDetail(error),
            ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmRevoke(DeviceSessionDto session) async {
    final accepted = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              session.current
                  ? context.l10n.revokeCurrentDevice
                  : context.l10n.revokeDevice,
            ),
            content: Text(
              session.current
                  ? context.l10n.revokeCurrentDeviceConfirmation
                  : context.l10n.revokeDeviceConfirmation,
            ),
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
    if (!accepted || !mounted) return;
    try {
      await widget.provider.revokeDeviceSession(session);
      if (!mounted) return;
      if (session.current) Navigator.pop(context);
      context.showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.deviceRevoked)),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = context.l10n.accountUpdateFailed(
              _errorDetail(error),
            ));
      }
    }
  }
}

class _CredentialsDialog extends StatefulWidget {
  const _CredentialsDialog(
      {required this.registration,
      required this.onSubmit,
      required this.isCurrentContext});

  final bool registration;
  final Future<void> Function(String username, String password) onSubmit;
  final bool Function() isCurrentContext;

  @override
  State<_CredentialsDialog> createState() => _CredentialsDialogState();
}

class _CredentialsDialogState extends State<_CredentialsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!widget.isCurrentContext()) {
      setState(() => _error = context.l10n.hubContextChanged);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = !widget.isCurrentContext()
            ? context.l10n.hubContextChanged
            : widget.registration
                ? context.l10n.serverRegistrationFailed(_errorDetail(error))
                : context.l10n.serverLoginFailed(_errorDetail(error));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: !_submitting,
        child: AlertDialog(
          key: const Key('server-auth-dialog'),
          scrollable: true,
          title: Text(
            widget.registration
                ? context.l10n.serverRegister
                : context.l10n.serverLogin,
          ),
          content: AutofillGroup(
              child: Form(
            key: _formKey,
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const Key('server-auth-username-field'),
                    controller: _usernameController,
                    focusNode: _usernameFocus,
                    autofocus: true,
                    readOnly: _submitting,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () {},
                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    autofillHints: const [AutofillHints.username],
                    decoration: InputDecoration(
                      labelText: context.l10n.usernameLabel,
                      border: const OutlineInputBorder(),
                    ),
                    validator: widget.registration
                        ? (value) => (value?.trim().length ?? 0) < 3
                            ? context.l10n.usernameLengthHint
                            : null
                        : (value) => _requiredValidator(context, value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('server-auth-password-field'),
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    readOnly: _submitting,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: widget.registration
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onEditingComplete: () {},
                    onFieldSubmitted: (_) {
                      if (widget.registration) {
                        _confirmFocus.requestFocus();
                      } else {
                        unawaited(_submit());
                      }
                    },
                    obscureText: true,
                    autofillHints: [
                      widget.registration
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: InputDecoration(
                      labelText: context.l10n.passwordLabel,
                      border: const OutlineInputBorder(),
                    ),
                    validator: widget.registration
                        ? (value) => _passwordValidator(context, value)
                        : (value) => _requiredValidator(context, value),
                  ),
                  if (widget.registration) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('server-auth-confirm-password-field'),
                      controller: _confirmController,
                      focusNode: _confirmFocus,
                      readOnly: _submitting,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onEditingComplete: () {},
                      onFieldSubmitted: (_) => unawaited(_submit()),
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.confirmNewPasswordLabel,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) => value != _passwordController.text
                          ? context.l10n.passwordMismatch
                          : null,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      key: const Key('server-auth-error'),
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          )),
          actions: [
            TextButton(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: const Key('server-auth-submit-button'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.registration
                          ? context.l10n.serverRegister
                          : context.l10n.serverLogin,
                    ),
            ),
          ],
        ));
  }
}

final class _UsernameChange {
  const _UsernameChange(this.username, this.currentPassword);

  final String username;
  final String currentPassword;
}

class _UsernameDialog extends StatefulWidget {
  const _UsernameDialog({required this.initialUsername});

  final String initialUsername;

  @override
  State<_UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<_UsernameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initialUsername);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.accountChangeUsername),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _usernameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.usernameLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 3
                    ? context.l10n.usernameLengthHint
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.l10n.currentPasswordLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => _requiredValidator(context, value),
              ),
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
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              _UsernameChange(
                _usernameController.text.trim(),
                _passwordController.text,
              ),
            );
          },
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

final class _PasswordChange {
  const _PasswordChange(this.currentPassword, this.newPassword);

  final String currentPassword;
  final String newPassword;
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.accountChangePassword),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.currentPasswordLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => _requiredValidator(context, value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.l10n.newPasswordLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => _passwordValidator(context, value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: context.l10n.confirmNewPasswordLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => value != _newController.text
                    ? context.l10n.passwordMismatch
                    : null,
              ),
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
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              _PasswordChange(
                _currentController.text,
                _newController.text,
              ),
            );
          },
          child: Text(context.l10n.accountChangePassword),
        ),
      ],
    );
  }
}

String? _passwordValidator(BuildContext context, String? value) {
  if ((value?.length ?? 0) < 10) return context.l10n.passwordLengthHint;
  return null;
}

String? _requiredValidator(BuildContext context, String? value) {
  if (value == null || value.isEmpty) return context.l10n.fieldRequired;
  return null;
}

String _errorDetail(Object error) {
  if (error case ServerApiException(:final code, :final message)) {
    return '$code: $message';
  }
  return error.toString();
}
