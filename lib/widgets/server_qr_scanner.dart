import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/providers/server_provider.dart';
import 'package:openlogtool/utils/qr_image_decode.dart';
import 'package:openlogtool/utils/server_qr_image_pick.dart';
import 'package:openlogtool/utils/server_scan_rules.dart';
import 'package:openlogtool/utils/server_url.dart';
import 'package:openlogtool/widgets/server_qr_scan_controls.dart';
import 'package:openlogtool/widgets/server_scan_confirm_dialog.dart';
import 'package:provider/provider.dart';

bool get serverCameraScanSupported =>
    kIsWeb ||
    const {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);

MobileScannerController Function() createServerQrCameraController =
    _defaultServerQrCameraController;

MobileScannerController _defaultServerQrCameraController() =>
    MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
    );

class ServerQrScanner extends StatefulWidget {
  const ServerQrScanner({super.key});

  @override
  State<ServerQrScanner> createState() => _ServerQrScannerState();
}

class _ServerQrScannerState extends State<ServerQrScanner> {
  late final MobileScannerController _controller;
  bool _offering = false;
  bool _invalid = false;
  bool _torchFailed = false;
  bool _switchFailed = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      MobileScannerPlatform.instance
          .setWebBarcodeReader(WebBarcodeReader.zxingJs);
      MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl(
        Uri.base.resolve('vendor/zxing-0.23.0.min.js').toString(),
      );
    }
    _controller = createServerQrCameraController();
    _controller.addListener(_onController);
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onController);
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (!mounted || _offering) return;
    String? candidate;
    var sawInvalid = false;
    for (final code in capture.barcodes) {
      final parsed = validatedServerConnectionInput(code.rawValue ?? '');
      if (parsed == null) {
        sawInvalid = true;
        continue;
      }
      candidate = parsed;
      break;
    }
    if (candidate == null) {
      if (sawInvalid && mounted) setState(() => _invalid = true);
      return;
    }
    await _offer(candidate);
  }

  Future<void> _pickImage() async {
    if (_offering) return;
    final bytes = await pickServerQrImageBytes();
    if (!mounted || bytes == null) return;
    final candidate = validatedServerConnectionInput(decodeQrText(bytes) ?? '');
    if (candidate == null) {
      setState(() => _invalid = true);
      return;
    }
    await _offer(candidate);
  }

  Future<void> _offer(String candidate) async {
    if (!mounted || _offering) return;
    setState(() {
      _offering = true;
      _invalid = false;
    });
    try {
      await _controller.stop();
    } catch (_) {}
    if (!mounted) return;
    final server = context.read<ServerProvider>();
    final confirmed = await confirmScannedServerAddress(
      context,
      loggedIn: server.isLoggedIn,
      currentServerUrl: server.serverUrl,
      candidateUrl: candidate,
    );
    if (!mounted) return;
    if (!confirmed) {
      setState(() => _offering = false);
      try {
        await _controller.start();
      } catch (_) {}
      return;
    }
    Navigator.pop(context, candidate);
  }

  Future<void> _torch() async {
    try {
      await _controller.toggleTorch();
    } catch (_) {
      if (mounted) setState(() => _torchFailed = true);
    }
  }

  Future<void> _switchCamera() async {
    final previous = _controller.value.cameraDirection;
    try {
      await _controller.switchCamera();
    } catch (_) {
      if (mounted) setState(() => _switchFailed = true);
    }
    if (!mounted || _controller.value.error == null) return;
    setState(() => _switchFailed = true);
    if (previous == CameraFacing.unknown || previous == CameraFacing.external) {
      return;
    }
    await _controller.start(cameraDirection: previous);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = _controller.value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.serverScanTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.serverScanHint),
          ),
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _detected,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.serverScanCameraUnavailable),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(l10n.close),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_invalid)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l10n.serverScanInvalid),
            ),
          ServerQrScanControls(
            torchVisible: serverScanTorchVisible(
              failed: _torchFailed,
              torchAvailable: state.torchState != TorchState.unavailable,
            ),
            switchVisible: serverScanSwitchVisible(
              failed: _switchFailed,
              cameras: state.availableCameras,
            ),
            onTorch: () => unawaited(_torch()),
            onSwitchCamera: () => unawaited(_switchCamera()),
            onPickImage: () => unawaited(_pickImage()),
          ),
        ],
      ),
    );
  }
}
