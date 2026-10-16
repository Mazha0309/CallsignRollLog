import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/utils/server_scan_rules.dart';

void main() {
  test('only a signed-in user and a different server switches accounts', () {
    expect(
      serverScanSwitchesAccount(
        loggedIn: false,
        currentServerUrl: 'https://current.example',
        candidateUrl: 'https://other.example',
      ),
      isFalse,
    );
    expect(
      serverScanSwitchesAccount(
        loggedIn: true,
        currentServerUrl: 'https://server.example',
        candidateUrl: 'https://server.example/connect',
      ),
      isFalse,
    );
    expect(
      serverScanSwitchesAccount(
        loggedIn: true,
        currentServerUrl: 'https://current.example',
        candidateUrl: 'https://other.example/app/friends?x=1#tab',
      ),
      isTrue,
    );
  });

  test('torch and camera switch stay hidden unless the controller reports them',
      () {
    expect(
      serverScanTorchVisible(failed: false, torchAvailable: false),
      isFalse,
    );
    expect(
      serverScanTorchVisible(failed: true, torchAvailable: true),
      isFalse,
    );
    expect(
      serverScanTorchVisible(failed: false, torchAvailable: true),
      isTrue,
    );
    expect(serverScanSwitchVisible(failed: false, cameras: null), isFalse);
    expect(serverScanSwitchVisible(failed: false, cameras: 1), isFalse);
    expect(serverScanSwitchVisible(failed: true, cameras: 2), isFalse);
    expect(serverScanSwitchVisible(failed: false, cameras: 2), isTrue);
  });
}
