import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:openlogtool/utils/qr_image_decode.dart';
import 'package:openlogtool/utils/server_url.dart';
import 'package:zxing2/qrcode.dart';

void main() {
  test('a connect QR normalizes to the server origin', () {
    final text = decodeQrText(_qrPng('https://server.example/connect'));
    expect(text, 'https://server.example/connect');
    expect(validatedServerConnectionInput(text!), 'https://server.example');
  });

  test('garbage and a picture without a QR return null', () {
    expect(decodeQrText(Uint8List.fromList(const [1, 2, 3, 4])), isNull);
    final blank = img.Image(width: 32, height: 32, numChannels: 4);
    img.fill(blank, color: img.ColorRgba8(255, 255, 255, 255));
    expect(decodeQrText(img.encodePng(blank)), isNull);
  });
}

Uint8List _qrPng(String text) {
  final matrix = Encoder.encode(text, ErrorCorrectionLevel.m).matrix!;
  const scale = 8;
  const quiet = 4;
  final modules = matrix.width + quiet * 2;
  final image = img.Image(
    width: modules * scale,
    height: modules * scale,
    numChannels: 4,
  );
  img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));
  for (var y = 0; y < matrix.height; y++) {
    for (var x = 0; x < matrix.width; x++) {
      if (matrix.get(x, y) != 1) continue;
      final left = (x + quiet) * scale;
      final top = (y + quiet) * scale;
      img.fillRect(
        image,
        x1: left,
        y1: top,
        x2: left + scale,
        y2: top + scale,
        color: img.ColorRgba8(0, 0, 0, 255),
      );
    }
  }
  return img.encodePng(image);
}
