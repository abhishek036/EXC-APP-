// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

Future<String> saveAndOpenBytes({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
  String? storageKey,
  required bool persistToCache,
}) async {
  final blob = html.Blob([
    bytes,
  ], mimeType ?? 'application/octet-stream');

  final objectUrl = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: objectUrl)
    ..setAttribute('download', fileName)
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  html.window.open(objectUrl, '_blank');
  anchor.remove();

  Timer(const Duration(minutes: 2), () {
    html.Url.revokeObjectUrl(objectUrl);
  });

  return '';
}

Future<void> openSavedFile({
  required String path,
  String? mimeType,
}) async {
  throw UnsupportedError('Opening previously saved files is not supported on web');
}
