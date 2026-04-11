import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../di/injection_container.dart';
import '../network/api_client.dart';
import 'file_opener_platform_stub.dart'
    if (dart.library.io) 'file_opener_platform_io.dart'
    if (dart.library.html) 'file_opener_platform_web.dart' as platform;

Future<void> downloadAndOpenFromUrl({
  required String url,
  String? fileName,
  String? mimeType,
}) async {
  final response = await sl<ApiClient>().dio.get<List<int>>(
    url,
    options: Options(
      responseType: ResponseType.bytes,
      followRedirects: true,
      validateStatus: (code) => code != null && code >= 200 && code < 400,
    ),
  );

  final bytes = Uint8List.fromList(response.data ?? const <int>[]);
  if (bytes.isEmpty) {
    throw Exception('Downloaded file is empty');
  }

  final resolvedName = _resolveFileName(
    explicitName: fileName,
    url: url,
    headers: response.headers,
  );

  await platform.saveAndOpenBytes(
    bytes: bytes,
    fileName: resolvedName,
    mimeType: mimeType,
  );
}

String _resolveFileName({
  required String? explicitName,
  required String url,
  required Headers headers,
}) {
  final trimmed = explicitName?.trim() ?? '';
  if (trimmed.isNotEmpty) {
    return _sanitizeFileName(trimmed);
  }

  final disposition = headers.value('content-disposition') ?? '';
  final fromHeader = _fileNameFromContentDisposition(disposition);
  if (fromHeader != null && fromHeader.trim().isNotEmpty) {
    return _sanitizeFileName(fromHeader.trim());
  }

  final uri = Uri.tryParse(url);
  if (uri != null && uri.pathSegments.isNotEmpty) {
    final segment = uri.pathSegments.last.trim();
    if (segment.isNotEmpty && segment != 'stream') {
      return _sanitizeFileName(segment);
    }
  }

  return 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
}

String? _fileNameFromContentDisposition(String value) {
  if (value.isEmpty) return null;
  final utf8Match = RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false)
      .firstMatch(value);
  if (utf8Match != null) {
    return Uri.decodeComponent(utf8Match.group(1) ?? '');
  }

  final simpleMatch = RegExp(r'filename="?([^";]+)"?', caseSensitive: false)
      .firstMatch(value);
  return simpleMatch?.group(1);
}

String _sanitizeFileName(String fileName) {
  final cleaned = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  if (cleaned.isEmpty) {
    return 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
  }

  if (!cleaned.contains('.')) {
    return '${p.basenameWithoutExtension(cleaned)}.pdf';
  }

  return cleaned;
}
