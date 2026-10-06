import 'dart:math' as math;
import 'package:openlogtool/utils/app_snack_bar.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/services/github_release_service.dart';
import 'package:url_launcher/url_launcher.dart';

typedef AboutLinkLauncher = Future<bool> Function(Uri uri);
typedef AboutUpdateChecker = Future<ReleaseUpdateCheck> Function(
  String currentVersion,
);

class AboutAppDialog extends StatelessWidget {
  const AboutAppDialog({
    super.key,
    required this.appName,
    required this.fullVersion,
    required this.buildNumber,
    required this.commitHash,
    this.linkLauncher,
    this.updateChecker,
  });

  static final Uri repositoryUri =
      Uri.parse('https://github.com/Mazha0309/CallsignRollLog');
  static final Uri issueTrackerUri =
      Uri.parse('https://github.com/Mazha0309/CallsignRollLog/issues');
  static final GitHubReleaseService _githubReleaseService =
      GitHubReleaseService();

  final String appName;
  final String fullVersion;
  final String buildNumber;
  final String commitHash;
  final AboutLinkLauncher? linkLauncher;
  final AboutUpdateChecker? updateChecker;

  bool get _hasBuildNumber =>
      buildNumber.trim().isNotEmpty && buildNumber.trim() != '0';
  bool get _hasCommitHash =>
      commitHash.trim().isNotEmpty && commitHash.trim() != 'local';

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final double maxHeight = math.min(
      math.max(mediaSize.height - 32.0, 240.0),
      720.0,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      key: const Key('about-app-dialog'),
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                key: const Key('about-app-scroll'),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AboutHeader(
                      appName: appName,
                      fullVersion: fullVersion,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.l10n.aboutAppDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(context.l10n.aboutVersionSection),
                    const SizedBox(height: 10),
                    _VersionCard(
                      fullVersion: fullVersion,
                      buildNumber: buildNumber,
                      commitHash: commitHash,
                      onCopy: () => _copyVersionInformation(context),
                      checkForUpdate:
                          updateChecker ?? _githubReleaseService.checkForUpdate,
                      onOpenRelease: (uri) => _openExternal(context, uri),
                    ),
                    const SizedBox(height: 24),
                    _SectionTitle(context.l10n.aboutProjectSection),
                    const SizedBox(height: 10),
                    _ProjectLinks(
                      onOpenRepository: () =>
                          _openExternal(context, repositoryUri),
                      onOpenIssues: () =>
                          _openExternal(context, issueTrackerUri),
                      onOpenLicenses: () => _openLicenses(context),
                    ),
                    const SizedBox(height: 16),
                    _LicenseSummary(),
                    const SizedBox(height: 20),
                    Text(
                      context.l10n.aboutCopyright,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('about-close'),
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n.close),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyVersionInformation(BuildContext context) async {
    final information = <String>[
      '$appName $fullVersion',
      if (_hasBuildNumber) '${context.l10n.aboutBuildLabel}: $buildNumber',
      if (_hasCommitHash) '${context.l10n.aboutCommitLabel}: $commitHash',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: information));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showLoggedSnackBar(
      SnackBar(content: Text(context.l10n.aboutVersionInfoCopied)),
    );
  }

  Future<void> _openExternal(BuildContext context, Uri uri) async {
    try {
      final opened = await (linkLauncher ?? _launchLink)(uri);
      if (opened || !context.mounted) return;
      _showLinkError(context, uri.toString());
    } catch (error) {
      if (context.mounted) _showLinkError(context, error.toString());
    }
  }

  Future<bool> _launchLink(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  void _showLinkError(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showLoggedSnackBar(
      SnackBar(content: Text(context.l10n.aboutLinkOpenFailed(error))),
    );
  }

  void _openLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: appName,
      applicationVersion: fullVersion,
      applicationLegalese: context.l10n.aboutCopyright,
      applicationIcon: Padding(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          'assets/images/app_icon_512.png',
          width: 56,
          height: 56,
          cacheWidth: 224,
          cacheHeight: 224,
        ),
      ),
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader({required this.appName, required this.fullVersion});

  final String appName;
  final String fullVersion;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final details = Column(
            crossAxisAlignment:
                compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(
                appName,
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.aboutAppTagline,
                textAlign: compact ? TextAlign.center : TextAlign.start,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  context.l10n.aboutVersionChip(fullVersion),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          );
          final logo = Container(
            width: 76,
            height: 76,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/images/app_icon_512.png',
                fit: BoxFit.cover,
                cacheWidth: 256,
                cacheHeight: 256,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.radio_outlined,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
          if (compact) {
            return Column(
              children: [logo, const SizedBox(height: 14), details],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              logo,
              const SizedBox(width: 18),
              Expanded(child: details),
            ],
          );
        },
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      );
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({
    required this.fullVersion,
    required this.buildNumber,
    required this.commitHash,
    required this.onCopy,
    required this.checkForUpdate,
    required this.onOpenRelease,
  });

  final String fullVersion;
  final String buildNumber;
  final String commitHash;
  final VoidCallback onCopy;
  final AboutUpdateChecker checkForUpdate;
  final Future<void> Function(Uri uri) onOpenRelease;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            _VersionRow(
              label: context.l10n.aboutVersionLabel,
              value: fullVersion,
            ),
            if (buildNumber.trim().isNotEmpty && buildNumber.trim() != '0') ...[
              const SizedBox(height: 10),
              _VersionRow(
                label: context.l10n.aboutBuildLabel,
                value: buildNumber,
              ),
            ],
            if (commitHash.trim().isNotEmpty &&
                commitHash.trim() != 'local') ...[
              const SizedBox(height: 10),
              _VersionRow(
                label: context.l10n.aboutCommitLabel,
                value: commitHash,
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    key: const Key('about-copy-version'),
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: Text(context.l10n.aboutCopyVersionInfo),
                  ),
                  _UpdateCheckButton(
                    currentVersion: fullVersion,
                    checkForUpdate: checkForUpdate,
                    onOpenRelease: onOpenRelease,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _UpdateCheckButton extends StatefulWidget {
  const _UpdateCheckButton({
    required this.currentVersion,
    required this.checkForUpdate,
    required this.onOpenRelease,
  });

  final String currentVersion;
  final AboutUpdateChecker checkForUpdate;
  final Future<void> Function(Uri uri) onOpenRelease;

  @override
  State<_UpdateCheckButton> createState() => _UpdateCheckButtonState();
}

class _UpdateCheckButtonState extends State<_UpdateCheckButton> {
  bool _checking = false;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        key: const Key('about-check-updates'),
        onPressed: _checking ? null : _checkForUpdate,
        icon: _checking
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.system_update_alt_outlined, size: 18),
        label: Text(
          _checking
              ? context.l10n.aboutCheckingUpdates
              : context.l10n.aboutCheckUpdates,
        ),
      );

  Future<void> _checkForUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);

    try {
      final result = await widget.checkForUpdate(widget.currentVersion);
      if (!mounted) return;
      setState(() => _checking = false);

      if (!result.updateAvailable) {
        ScaffoldMessenger.of(context).showLoggedSnackBar(
          SnackBar(
            content: Text(context.l10n.aboutUpToDate(result.latestVersion)),
          ),
        );
        return;
      }

      await _showUpdateAvailable(result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
      ScaffoldMessenger.of(context).showLoggedSnackBar(
        SnackBar(content: Text(context.l10n.aboutUpdateCheckFailed)),
      );
    }
  }

  Future<void> _showUpdateAvailable(ReleaseUpdateCheck result) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('about-update-available-dialog'),
        title: Text(context.l10n.aboutUpdateAvailableTitle),
        content: Text(
          context.l10n.aboutUpdateAvailableMessage(
            result.currentVersion,
            result.latestVersion,
          ),
        ),
        actions: [
          TextButton(
            key: const Key('about-update-later'),
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.aboutUpdateLater),
          ),
          FilledButton(
            key: const Key('about-open-release'),
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.onOpenRelease(result.releaseUri);
            },
            child: Text(context.l10n.aboutOpenRelease),
          ),
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final labelWidget = Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          );
          final valueWidget = SelectableText(
            value,
            textAlign:
                constraints.maxWidth < 280 ? TextAlign.start : TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          );
          if (constraints.maxWidth < 280) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 2),
                valueWidget,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: labelWidget),
              const SizedBox(width: 16),
              Flexible(child: valueWidget),
            ],
          );
        },
      );
}

class _ProjectLinks extends StatelessWidget {
  const _ProjectLinks({
    required this.onOpenRepository,
    required this.onOpenIssues,
    required this.onOpenLicenses,
  });

  final VoidCallback onOpenRepository;
  final VoidCallback onOpenIssues;
  final VoidCallback onOpenLicenses;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _AboutLinkTile(
              key: const Key('about-repository'),
              icon: Icons.code_outlined,
              title: context.l10n.aboutRepository,
              subtitle: context.l10n.aboutRepositoryHint,
              onTap: onOpenRepository,
            ),
            const Divider(height: 1),
            _AboutLinkTile(
              key: const Key('about-issues'),
              icon: Icons.bug_report_outlined,
              title: context.l10n.aboutIssueTracker,
              subtitle: context.l10n.aboutIssueTrackerHint,
              onTap: onOpenIssues,
            ),
            const Divider(height: 1),
            _AboutLinkTile(
              key: const Key('about-licenses'),
              icon: Icons.article_outlined,
              title: context.l10n.aboutOpenSourceLicenses,
              subtitle: context.l10n.aboutOpenSourceLicensesHint,
              trailing: Icons.chevron_right,
              onTap: onOpenLicenses,
            ),
          ],
        ),
      );
}

class _AboutLinkTile extends StatelessWidget {
  const _AboutLinkTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing = Icons.open_in_new,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final IconData trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Icon(trailing, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        onTap: onTap,
      );
}

class _LicenseSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.balance_outlined,
              color: Theme.of(context).colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.aboutLicenseName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.aboutLicenseHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
