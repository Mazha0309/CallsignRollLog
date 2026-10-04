import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/utils/server_url.dart';

void main() {
  test('connection links and pasted portal pages resolve to the same server',
      () {
    expect(serverUrlFromConnectionInput('https://example.com/connect'),
        'https://example.com');
    expect(
        serverUrlFromConnectionInput('https://example.com/app/friends?x=1#tab'),
        'https://example.com');
    expect(serverUrlFromConnectionInput('https://example.com/client/'),
        'https://example.com');
    expect(serverUrlFromConnectionInput('https://example.com/prefix/connect'),
        'https://example.com/prefix');
    expect(serverUrlFromConnectionInput('http://192.168.1.2:3000/api/v1'),
        'http://192.168.1.2:3000');
  });
  test('existing server identities with custom deployment paths do not change',
      () {
    expect(normalizeServerUrl('https://example.com/app'),
        'https://example.com/app');
    expect(normalizeServerUrl('https://example.com/prefix'),
        'https://example.com/prefix');
  });
}
