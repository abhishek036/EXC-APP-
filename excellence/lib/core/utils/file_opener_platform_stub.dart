import 'dart:typed_data';

Future<void> saveAndOpenBytes({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
}) async {
  throw UnsupportedError('Saving/opening files is not supported on this platform');
}
