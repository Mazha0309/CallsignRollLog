import 'package:openlogtool/utils/server_url.dart';

bool serverScanSwitchesAccount({
  required bool loggedIn,
  required String currentServerUrl,
  required String candidateUrl,
}) {
  if (!loggedIn) return false;
  // Only the scanned page is a portal URL. The stored identity keeps paths
  // such as /app; stripping it would hide a real sign-out.
  return serverUrlFromConnectionInput(candidateUrl) !=
      normalizeServerUrl(currentServerUrl);
}

bool serverScanTorchVisible({
  required bool failed,
  required bool torchAvailable,
}) =>
    !failed && torchAvailable;

bool serverScanSwitchVisible({
  required bool failed,
  required int? cameras,
}) =>
    !failed && cameras != null && cameras >= 2;
