import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openlogtool/services/github_release_service.dart';

void main() {
  group('GitHubReleaseService', () {
    test('uses the public latest-release API and reports a newer version',
        () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url, GitHubReleaseService.latestReleaseApiUri);
        expect(request.headers['accept'], 'application/vnd.github+json');
        expect(request.headers['x-github-api-version'], '2026-03-10');
        expect(request.headers['user-agent'], 'OpenLogTool-update-checker');
        expect(request.headers.containsKey('authorization'), isFalse);
        return _jsonResponse({'tag_name': 'v2.2.0-R'});
      });
      final service = GitHubReleaseService(httpClient: client);

      final result = await service.checkForUpdate('2.1.0-R+5-93884f8-237');

      expect(result.currentVersion, '2.1.0-R');
      expect(result.latestVersion, '2.2.0-R');
      expect(result.updateAvailable, isTrue);
      expect(
        result.releaseUri,
        Uri.parse(
          'https://github.com/Mazha0309/CallsignRollLog/releases/tag/v2.2.0-R',
        ),
      );
    });

    test('ignores local build metadata when versions are equal', () async {
      final service = GitHubReleaseService(
        httpClient: MockClient(
          (_) async => _jsonResponse({'tag_name': 'v2.1.0-R'}),
        ),
      );

      final result = await service.checkForUpdate('v2.1.0-R+5-93884f8-237');

      expect(result.currentVersion, result.latestVersion);
      expect(result.updateAvailable, isFalse);
    });

    test('returns a stable failure for non-success HTTP status', () async {
      final service = GitHubReleaseService(
        httpClient: MockClient((_) async => http.Response('', 503)),
      );

      await expectLater(
        service.checkForUpdate('2.1.0-R'),
        throwsA(
          isA<GitHubReleaseException>()
              .having(
                (error) => error.kind,
                'kind',
                GitHubReleaseFailureKind.httpStatus,
              )
              .having((error) => error.statusCode, 'statusCode', 503),
        ),
      );
    });

    test('identifies an exhausted GitHub API rate limit', () async {
      final service = GitHubReleaseService(
        httpClient: MockClient(
          (_) async => http.Response(
            '',
            403,
            headers: {'x-ratelimit-remaining': '0'},
          ),
        ),
      );

      await expectLater(
        service.checkForUpdate('2.1.0-R'),
        throwsA(
          isA<GitHubReleaseException>()
              .having(
                (error) => error.kind,
                'kind',
                GitHubReleaseFailureKind.rateLimited,
              )
              .having((error) => error.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('rejects malformed JSON as an invalid response', () async {
      final service = GitHubReleaseService(
        httpClient: MockClient(
          (_) async => http.Response('{not-json', 200),
        ),
      );

      await expectLater(
        service.checkForUpdate('2.1.0-R'),
        throwsA(
          isA<GitHubReleaseException>().having(
            (error) => error.kind,
            'kind',
            GitHubReleaseFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('rejects an invalid release tag instead of opening an arbitrary URL',
        () async {
      final service = GitHubReleaseService(
        httpClient: MockClient(
          (_) async => _jsonResponse({'tag_name': '../../untrusted'}),
        ),
      );

      await expectLater(
        service.checkForUpdate('2.1.0-R'),
        throwsA(
          isA<GitHubReleaseException>().having(
            (error) => error.kind,
            'kind',
            GitHubReleaseFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('returns a stable timeout failure', () async {
      final service = GitHubReleaseService(
        httpClient: MockClient(
          (_) => Completer<http.Response>().future,
        ),
        timeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        service.checkForUpdate('2.1.0-R'),
        throwsA(
          isA<GitHubReleaseException>().having(
            (error) => error.kind,
            'kind',
            GitHubReleaseFailureKind.timeout,
          ),
        ),
      );
    });

    test('wraps client exceptions as a stable network failure', () async {
      final service = GitHubReleaseService(
        httpClient: MockClient(
          (_) async => throw http.ClientException('offline'),
        ),
      );

      await expectLater(
        service.checkForUpdate('2.1.0-R'),
        throwsA(
          isA<GitHubReleaseException>().having(
            (error) => error.kind,
            'kind',
            GitHubReleaseFailureKind.network,
          ),
        ),
      );
    });

    test('rejects an invalid installed version before making a request',
        () async {
      var requested = false;
      final service = GitHubReleaseService(
        httpClient: MockClient((_) async {
          requested = true;
          return _jsonResponse({'tag_name': 'v2.1.0-R'});
        }),
      );

      await expectLater(
        service.checkForUpdate('development-build'),
        throwsA(
          isA<GitHubReleaseException>().having(
            (error) => error.kind,
            'kind',
            GitHubReleaseFailureKind.invalidCurrentVersion,
          ),
        ),
      );
      expect(requested, isFalse);
    });
  });
}

http.Response _jsonResponse(Object? body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
