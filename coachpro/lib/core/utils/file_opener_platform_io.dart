import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> saveAndOpenBytes({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
}) async {
  final dir = await getTemporaryDirectory();
  final path = p.join(dir.path, fileName);
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);

  final opened = await launchUrl(
    Uri.file(file.path),
    mode: LaunchMode.externalApplication,
  );

  if (!opened) {
    throw Exception('Unable to open downloaded file');
  }
}
