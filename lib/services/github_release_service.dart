import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

enum GitHubReleaseFailureKind {
  timeout,
  network,
  rateLimited,
  httpStatus,
  invalidCurrentVersion,
  invalidResponse,
}

final class GitHubReleaseException implements Exception {
  const GitHubReleaseException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.cause,
  });

  final GitHubReleaseFailureKind kind;
  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' ($statusCode)';
    return 'GitHubReleaseException$status: ${kind.name}: $message';
  }
}

final class ReleaseUpdateCheck {
  const ReleaseUpdateCheck({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUri,
    required this.updateAvailable,
  });

  final String currentVersion;
  final String latestVersion;
  final Uri releaseUri;
  final bool updateAvailable;
}

final class GitHubReleaseService {
  GitHubReleaseService({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _httpClient = httpClient {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'must be positive');
    }
  }

  static final Uri latestReleaseApiUri = Uri.https(
    'api.github.com',
    '/repos/Mazha0309/CallsignRollLog/releases/latest',
  );

  static const Map<String, String> requestHeaders = {
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2026-03-10',
    'User-Agent': 'OpenLogTool-update-checker',
  };

  final Duration timeout;
  final http.Client? _httpClient;

  Future<ReleaseUpdateCheck> checkForUpdate(String currentVersion) async {
    final parsedCurrent = _parseCurrentVersion(currentVersion);
    final http.Response response;
    final requestClient = _httpClient ?? http.Client();

    try {
      response = await requestClient
          .get(latestReleaseApiUri, headers: requestHeaders)
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw GitHubReleaseException(
        kind: GitHubReleaseFailureKind.timeout,
        message: 'The GitHub release request timed out',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw GitHubReleaseException(
        kind: GitHubReleaseFailureKind.network,
        message: 'The GitHub release request failed',
        cause: error,
      );
    } finally {
      // A default client is scoped to one check so transient service instances
      // used by the About dialog cannot leak sockets. Injected clients remain
      // caller-owned and reusable across tests or multiple checks.
      if (_httpClient == null) requestClient.close();
    }

    if (response.statusCode != 200) {
      final rateLimited = response.statusCode == 429 ||
          (response.statusCode == 403 &&
              response.headers['x-ratelimit-remaining'] == '0');
      throw GitHubReleaseException(
        kind: rateLimited
            ? GitHubReleaseFailureKind.rateLimited
            : GitHubReleaseFailureKind.httpStatus,
        message: rateLimited
            ? 'The GitHub API rate limit was exceeded'
            : 'GitHub returned HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw GitHubReleaseException(
        kind: GitHubReleaseFailureKind.invalidResponse,
        message: 'GitHub returned malformed release data',
        statusCode: response.statusCode,
        cause: error,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw GitHubReleaseException(
        kind: GitHubReleaseFailureKind.invalidResponse,
        message: 'GitHub returned an invalid release object',
        statusCode: response.statusCode,
      );
    }

    final tagValue = decoded['tag_name'];
    if (tagValue is! String || tagValue.trim().isEmpty) {
      throw GitHubReleaseException(
        kind: GitHubReleaseFailureKind.invalidResponse,
        message: 'The GitHub release has no valid tag name',
        statusCode: response.statusCode,
      );
    }

    final tagName = tagValue.trim();
    final latestVersion = _parseReleaseVersion(
      tagName,
      statusCode: response.statusCode,
    );
    final releaseUri = Uri(
      scheme: 'https',
      host: 'github.com',
      pathSegments: [
        'Mazha0309',
        'CallsignRollLog',
        'releases',
        'tag',
        tagName
      ],
    );

    return ReleaseUpdateCheck(
      currentVersion: parsedCurrent.toString(),
      latestVersion: latestVersion.toString(),
      releaseUri: releaseUri,
      updateAvailable: latestVersion > parsedCurrent,
    );
  }

  Version _parseCurrentVersion(String value) {
    try {
      return _parseVersion(value);
    } on FormatException catch (error) {
      throw GitHubReleaseException(
        kind: GitHubReleaseFailureKind.invalidCurrentVersion,
        message: 'The installed application version is invalid',
        cause: error,
      );
    }
  }

  Version _parseReleaseVersion(String value, {required int statusCode}) {
    try {
      return _parseVersion(value);
    } on FormatException catch (error) {
      throw GitHubReleaseException(
        kind: GitHubReleaseFailureKind.invalidResponse,
        message: 'The GitHub release tag is not a valid version',
        statusCode: statusCode,
        cause: error,
      );
    }
  }

  Version _parseVersion(String value) {
    var normalized = value.trim();
    if (normalized.startsWith('v') || normalized.startsWith('V')) {
      normalized = normalized.substring(1);
    }

    // CI appends build, commit, and run information after '+'. Release tags do
    // not include that metadata, and it must not affect update precedence.
    final buildSeparator = normalized.indexOf('+');
    if (buildSeparator >= 0) {
      normalized = normalized.substring(0, buildSeparator);
    }
    return Version.parse(normalized);
  }
}
