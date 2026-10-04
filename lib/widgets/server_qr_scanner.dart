import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/utils/server_url.dart';

bool get serverCameraScanSupported =>
    kIsWeb ||
    const {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);

class ServerQrScanner extends StatefulWidget {
  const ServerQrScanner({super.key});
  @override
  State<ServerQrScanner> createState() => _ServerQrScannerState();
}

class _ServerQrScannerState extends State<ServerQrScanner> {
  late final MobileScannerController _controller;
  bool _accepted = false, _invalid = false;
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Bundle the decoder: scanning must not load code from a third-party CDN.
      MobileScannerPlatform.instance
          .setWebBarcodeReader(WebBarcodeReader.zxingJs);
      MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl(
          Uri.base.resolve('vendor/zxing-0.23.0.min.js').toString());
    }
    _controller = MobileScannerController(
        formats: [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates);
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (!mounted || _accepted) return;
    for (final code in capture.barcodes) {
      final candidate = validatedServerConnectionInput(code.rawValue ?? '');
      if (candidate == null) {
        setState(() => _invalid = true);
        continue;
      }
      _accepted = true;
      await _controller.stop();
      if (mounted) Navigator.pop(context, candidate);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return Scaffold(
      appBar: AppBar(title: Text(zh ? '扫描服务器二维码' : 'Scan server QR code')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Text(zh
                ? '扫描后只填入地址，由你确认连接。相机画面不会上传。'
                : 'Scanning only fills the address. You confirm the connection; camera frames are not uploaded.')),
        Expanded(
            child: MobileScanner(
                controller: _controller,
                onDetect: _detected,
                errorBuilder: (context, error) => Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(zh
                              ? '无法使用相机。请检查相机权限；网页版需使用 HTTPS。你也可以返回粘贴连接地址。'
                              : 'Camera unavailable. Check camera permission and use HTTPS on the web, or go back and paste a connection address.'),
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(context.l10n.close)),
                        ]))))),
        if (_invalid)
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text(zh
                  ? '这不是有效的服务器连接地址，请扫描服务器“连接这台服务器”页面的二维码。'
                  : 'Not a valid server address. Scan the QR code on the server connection page.')),
      ]),
    );
  }
}
