import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// The text inside a QR picture, or null when the bytes are not a readable QR.
String? decodeQrText(Uint8List bytes) {
  if (bytes.isEmpty) return null;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  try {
    final rgba = decoded.convert(numChannels: 4);
    final raw = Uint8List.fromList(
      rgba.getBytes(order: img.ChannelOrder.abgr),
    );
    final result = QRCodeReader().decode(
      BinaryBitmap(
        HybridBinarizer(
          RGBLuminanceSource(
            rgba.width,
            rgba.height,
            raw.buffer.asInt32List(),
          ),
        ),
      ),
    );
    final text = result.text.trim();
    return text.isEmpty ? null : text;
  } catch (_) {
    return null;
  }
}
