enum AiRecognitionErrorKind {
  invalidConfiguration,
  unsupportedProtocol,
  missingCredentials,
  audioRejected,
  timeout,
  network,
  httpStatus,
  invalidResponse,
  nothingRecognized,
  cancelled,
  closed,
}

final class AiRecognitionException implements Exception {
  const AiRecognitionException({
    required this.kind,
    required this.message,
    this.providerId,
    this.statusCode,
    this.responseBody,
    this.cause,
  });

  final AiRecognitionErrorKind kind;
  final String message;
  final String? providerId;
  final int? statusCode;
  final String? responseBody;
  final Object? cause;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' ($statusCode)';
    final provider = providerId == null ? '' : ' [$providerId]';
    return 'AiRecognitionException$status$provider: ${kind.name}: $message';
  }
}

/// 面向用户的错误文案：只说「出了什么问题」与「下一步做什么」。
///
/// 内部错误码、异常文本、HTTP 状态行与响应体片段一律不得进入界面
/// （设计文档 §13）。诊断细节走日志。
///
/// **已知限制（Plan 2 处理）**：文案目前是硬编码简体中文，而仓库支持英文界面
/// （`lib/l10n/app_en.arb`）。用户可见文案本应走 l10n；等 Plan 2 做配置与复核
/// 界面的文案时一并把这里改为语义键 + `.arb` 渲染，届时本函数只负责「分类」。
String aiUserFacingErrorMessage(AiRecognitionException error) =>
    switch (error.kind) {
      AiRecognitionErrorKind.missingCredentials => '还没填 API Key',
      AiRecognitionErrorKind.httpStatus => _httpStatusMessage(error.statusCode),
      AiRecognitionErrorKind.timeout => '网络不通或响应太慢，检查是否需要代理',
      AiRecognitionErrorKind.network => '连不上服务商，检查网络',
      AiRecognitionErrorKind.audioRejected => '服务商拒收了这段录音，换个格式或缩短一点再试',
      AiRecognitionErrorKind.invalidConfiguration => '配置与服务商不匹配，建议换回官方预设',
      AiRecognitionErrorKind.unsupportedProtocol => '该服务商不支持这种调用方式，建议换回官方预设',
      AiRecognitionErrorKind.invalidResponse => '服务商返回的内容无法解析，稍后重试或换个模型',
      AiRecognitionErrorKind.nothingRecognized => '没有听清内容，请再说一次',
      AiRecognitionErrorKind.cancelled => '已取消',
      AiRecognitionErrorKind.closed => '识别已结束',
    };

String _httpStatusMessage(int? statusCode) => switch (statusCode) {
      401 || 403 => 'API Key 无效，或该 Key 没有这个模型的权限',
      404 => '模型名或接口地址不对，检查是否选错服务商预设',
      413 || 415 => '这段录音的格式或大小不被接受，缩短一点再试',
      429 => '请求太频繁，稍等几秒再试',
      _ => '服务商返回错误，稍后重试',
    };
