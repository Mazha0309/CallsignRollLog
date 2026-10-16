import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

typedef ServerQrImagePicker = Future<Uint8List?> Function();

ServerQrImagePicker pickServerQrImageBytes = _pickServerQrImageBytes;

Future<Uint8List?> _pickServerQrImageBytes() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) return null;
  return result.files.single.bytes;
}
