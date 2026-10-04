/// Returns the stable configured origin used for one OpenLogTool server.
///
/// The server API accepts both the deployment root and its `/api/v1` endpoint.
/// Keeping a single representation prevents a harmless spelling change from
/// being mistaken for an authentication-context switch.
String normalizeServerUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return trimmed.replaceFirst(RegExp(r'/+$'), '');
  }

  var path = uri.path.replaceFirst(RegExp(r'/+$'), '');
  const apiSuffix = '/api/v1';
  if (path.endsWith(apiSuffix)) {
    final deploymentRoot = path.substring(0, path.length - apiSuffix.length);
    // Avoid changing an intentionally repeated `/api/v1/api/v1` endpoint:
    // ServerApi would otherwise see the remaining suffix as already complete.
    if (!deploymentRoot.endsWith(apiSuffix)) path = deploymentRoot;
  }
  if (path == '/') path = '';

  return Uri(
    scheme: uri.scheme.toLowerCase(),
    userInfo: uri.userInfo,
    host: uri.host.toLowerCase(),
    port: uri.hasPort ? uri.port : null,
    path: path,
  ).toString();
}

/// Interpret a newly pasted portal URL without changing persisted server identity.
String serverUrlFromConnectionInput(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !['https', 'http'].contains(uri.scheme)) {
    return normalizeServerUrl(value);
  }
  final entry =
      RegExp(r'/(?:connect|client|app|admin)(?:/.*)?$').firstMatch(uri.path);
  return normalizeServerUrl(entry == null
      ? value
      : uri
          .replace(
              path: uri.path.substring(0, entry.start), query: '', fragment: '')
          .toString());
}

/// Only addresses, never credentials or executable/custom URL schemes.
String? validatedServerConnectionInput(String value) {
  if (value.length > 4096) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !['https', 'http'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return serverUrlFromConnectionInput(value);
}
