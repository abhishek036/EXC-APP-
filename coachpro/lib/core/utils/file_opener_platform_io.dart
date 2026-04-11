import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> saveAndOpenBytes({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
}) async {
  final dir = await _resolveDownloadDirectory();
  final downloadsDir = Directory(p.join(dir.path, 'downloads'));
  if (!downloadsDir.existsSync()) {
    await downloadsDir.create(recursive: true);
  }

  final path = _buildUniqueFilePath(downloadsDir.path, fileName);
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);

  final openResult = await OpenFilex.open(file.path, type: mimeType);
  if (openResult.type != ResultType.done) {
    throw Exception('Unable to open downloaded file');
  }
}

Future<Directory> _resolveDownloadDirectory() async {
  if (Platform.isAndroid) {
    final external = await getExternalStorageDirectory();
    if (external != null) return external;
  }

  final downloads = await getDownloadsDirectory();
  if (downloads != null) return downloads;

  if (Platform.isIOS) {
    return getApplicationDocumentsDirectory();
  }

  return getTemporaryDirectory();
}

String _buildUniqueFilePath(String directoryPath, String fileName) {
  final safeName = fileName.trim().isEmpty ? 'document.pdf' : fileName;
  final baseName = p.basenameWithoutExtension(safeName);
  final extension = p.extension(safeName);

  var candidate = p.join(directoryPath, safeName);
  var index = 1;

  while (File(candidate).existsSync()) {
    final suffix = '_$index';
    candidate = p.join(directoryPath, '$baseName$suffix$extension');
    index += 1;
  }

  return candidate;
}
