import 'package:flutter/material.dart';
import 'package:openlogtool/l10n/l10n.dart';

class ServerQrScanControls extends StatelessWidget {
  const ServerQrScanControls({
    required this.torchVisible,
    required this.switchVisible,
    required this.onTorch,
    required this.onSwitchCamera,
    required this.onPickImage,
    super.key,
  });

  final bool torchVisible;
  final bool switchVisible;
  final VoidCallback onTorch;
  final VoidCallback onSwitchCamera;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (torchVisible)
            OutlinedButton.icon(
              key: const Key('server-scan-torch'),
              onPressed: onTorch,
              icon: const Icon(Icons.flashlight_on_outlined),
              label: Text(l10n.serverScanTorch),
            ),
          if (switchVisible)
            OutlinedButton.icon(
              key: const Key('server-scan-switch-camera'),
              onPressed: onSwitchCamera,
              icon: const Icon(Icons.cameraswitch_outlined),
              label: Text(l10n.serverScanSwitchCamera),
            ),
          OutlinedButton.icon(
            key: const Key('server-scan-image'),
            onPressed: onPickImage,
            icon: const Icon(Icons.image_search_outlined),
            label: Text(l10n.serverScanPickImage),
          ),
        ],
      ),
    );
  }
}
