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
  final apiClient = sl<ApiClient>();
  Response<List<int>>? response;
  Object? lastError;

  for (final candidate in _buildDownloadUrlCandidates(
    url,
    baseUrl: apiClient.dio.options.baseUrl,
  )) {
    try {
      response = await apiClient.dio.get<List<int>>(
        candidate,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (code) => code != null && code >= 200 && code < 400,
        ),
      );
      break;
    } catch (e) {
      lastError = e;
    }
  }

  if (response == null) {
    if (lastError is Exception) throw lastError;
    throw Exception('Unable to download file');
  }

  final bytes = Uint8List.fromList(response.data ?? const <int>[]);
  if (bytes.isEmpty) {
    throw Exception('Downloaded file is empty');
  }

  final resolvedName = _resolveFileName(
    explicitName: fileName,
    url: response.requestOptions.uri.toString(),
    headers: response.headers,
  );

  await platform.saveAndOpenBytes(
    bytes: bytes,
    fileName: resolvedName,
    mimeType: mimeType,
  );
}

List<String> _buildDownloadUrlCandidates(String rawUrl, {required String baseUrl}) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return const [];

  final candidates = <String>[];
  final seen = <String>{};

  void add(String candidate) {
    final normalized = candidate.trim();
    if (normalized.isEmpty || seen.contains(normalized)) return;
    seen.add(normalized);
    candidates.add(normalized);
  }

  add(trimmed);

  final uri = Uri.tryParse(trimmed);
  if (uri != null) {
    final pathWithQuery = _pathWithQuery(uri);
    if (pathWithQuery.isNotEmpty) {
      add(pathWithQuery);
      add(pathWithQuery.startsWith('/') ? pathWithQuery.substring(1) : pathWithQuery);

      final afterApi = _pathAfterApiPrefix(pathWithQuery);
      if (afterApi != null && afterApi.isNotEmpty) {
        add(afterApi);
      }
    }

    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri != null &&
        uri.hasScheme &&
        uri.host.isNotEmpty &&
        baseUri.host.isNotEmpty &&
        uri.host.toLowerCase() != baseUri.host.toLowerCase()) {
      if (pathWithQuery.isNotEmpty) {
        add(pathWithQuery.startsWith('/') ? pathWithQuery.substring(1) : pathWithQuery);
      }
    }
  }

  if (trimmed.startsWith('/')) {
    add(trimmed.substring(1));
  }

  return candidates;
}

String _pathWithQuery(Uri uri) {
  final path = uri.path.isEmpty ? '/' : uri.path;
  return uri.hasQuery ? '$path?${uri.query}' : path;
}

String? _pathAfterApiPrefix(String pathWithQuery) {
  final lower = pathWithQuery.toLowerCase();

  final apiV1Index = lower.indexOf('/api/v1/');
  if (apiV1Index >= 0) {
    return pathWithQuery.substring(apiV1Index + '/api/v1/'.length);
  }

  final apiIndex = lower.indexOf('/api/');
  if (apiIndex >= 0) {
    return pathWithQuery.substring(apiIndex + '/api/'.length);
  }

  if (lower.startsWith('api/v1/')) {
    return pathWithQuery.substring('api/v1/'.length);
  }

  if (lower.startsWith('api/')) {
    return pathWithQuery.substring('api/'.length);
  }

  return null;
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
