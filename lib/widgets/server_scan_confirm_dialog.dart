import 'package:flutter/material.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/utils/server_scan_rules.dart';

Future<bool> confirmScannedServerAddress(
  BuildContext context, {
  required bool loggedIn,
  required String currentServerUrl,
  required String candidateUrl,
}) async {
  final l10n = context.l10n;
  final switching = serverScanSwitchesAccount(
    loggedIn: loggedIn,
    currentServerUrl: currentServerUrl,
    candidateUrl: candidateUrl,
  );
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.serverScanConfirmTitle),
      content: Text(
        switching
            ? l10n.serverScanConfirmSwitch(candidateUrl)
            : l10n.serverScanConfirmCheck(candidateUrl),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('server-scan-confirm-button'),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.confirm),
        ),
      ],
    ),
  );
  return confirmed == true;
}
