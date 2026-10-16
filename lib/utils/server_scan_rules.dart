import 'package:openlogtool/utils/server_url.dart';

bool serverScanSwitchesAccount({
  required bool loggedIn,
  required String currentServerUrl,
  required String candidateUrl,
}) {
  if (!loggedIn) return false;
  // normalizeServerUrl keeps /connect. Connection pages have to be stripped
  // first, or the same server looks like a switch.
  return serverUrlFromConnectionInput(candidateUrl) !=
      serverUrlFromConnectionInput(currentServerUrl);
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
