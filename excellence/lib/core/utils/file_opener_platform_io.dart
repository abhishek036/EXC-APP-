import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'stable_token.dart';

Future<String> saveAndOpenBytes({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
  String? storageKey,
  required bool persistToCache,
}) async {
  final dir = await _resolveDownloadDirectory(persistToCache: persistToCache);
  final downloadsDir = Directory(
    p.join(dir.path, persistToCache ? 'offline_downloads' : 'temp_downloads'),
  );
  if (!downloadsDir.existsSync()) {
    await downloadsDir.create(recursive: true);
  }

  final path = _buildFilePath(
    downloadsDir.path,
    fileName,
    storageKey: storageKey,
    persistToCache: persistToCache,
  );
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);

  final openResult = await OpenFilex.open(file.path, type: mimeType);
  if (openResult.type != ResultType.done) {
    throw Exception('Unable to open downloaded file');
  }

  return file.path;
}

Future<void> openSavedFile({
  required String path,
  String? mimeType,
}) async {
  final openResult = await OpenFilex.open(path, type: mimeType);
  if (openResult.type != ResultType.done) {
    throw Exception('Unable to open downloaded file');
  }
}

Future<Directory> _resolveDownloadDirectory({required bool persistToCache}) async {
  if (!persistToCache) {
    return getTemporaryDirectory();
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isAndroid || Platform.isIOS) {
    final support = await getApplicationSupportDirectory();
    return support;
  }

  final downloads = await getDownloadsDirectory();
  if (downloads != null) return downloads;

  return getTemporaryDirectory();
}

String _buildFilePath(
  String directoryPath,
  String fileName, {
  String? storageKey,
  required bool persistToCache,
}) {
  final safeName = fileName.trim().isEmpty ? 'document.pdf' : fileName;
  final sanitizedName = safeName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  final baseName = p.basenameWithoutExtension(sanitizedName);
  final extension = p.extension(sanitizedName).isEmpty ? '.pdf' : p.extension(sanitizedName);

  if (persistToCache && storageKey != null && storageKey.trim().isNotEmpty) {
    final token = stableToken(storageKey.trim());
    return p.join(directoryPath, '${token}_$baseName$extension');
  }

  var candidate = p.join(directoryPath, sanitizedName);
  var index = 1;

  while (File(candidate).existsSync()) {
    final suffix = '_$index';
    candidate = p.join(directoryPath, '$baseName$suffix$extension');
    index += 1;
  }

  return candidate;
}
