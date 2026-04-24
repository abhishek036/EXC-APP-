import 'dart:typed_data';

Future<String> saveAndOpenBytes({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
  String? storageKey,
  required bool persistToCache,
}) async {
  throw UnsupportedError('Saving/opening files is not supported on this platform');
}

Future<void> openSavedFile({
  required String path,
  String? mimeType,
}) async {
  throw UnsupportedError('Saving/opening files is not supported on this platform');
}
