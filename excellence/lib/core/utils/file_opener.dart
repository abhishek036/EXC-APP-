import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../di/injection_container.dart';
import '../network/api_client.dart';
import '../services/download_registry.dart';
import 'file_opener_platform_stub.dart'
    if (dart.library.io) 'file_opener_platform_io.dart'
    if (dart.library.html) 'file_opener_platform_web.dart' as platform;

Future<String> downloadAndOpenFromUrl({
  required String url,
  String? fileName,
  String? mimeType,
  String? downloadKey,
}) async {
  final apiClient = sl<ApiClient>();
  final storageKey = downloadKey?.trim();
  final persistToCache = await _isOfflineCacheEnabled();

  if (storageKey != null && storageKey.isNotEmpty) {
    await DownloadRegistry.instance.ensureLoaded();
    final cachedPath = DownloadRegistry.instance.downloadedPath(storageKey);
    if (cachedPath != null && cachedPath.isNotEmpty) {
      try {
        await platform.openSavedFile(path: cachedPath, mimeType: mimeType);
        return cachedPath;
      } catch (_) {
        await DownloadRegistry.instance.clear(storageKey);
      }
    }
  }

  Response<List<int>>? response;
  Object? lastError;
  final browserUri = _resolveBrowserUri(
    url,
    baseUrl: apiClient.dio.options.baseUrl,
  );

  if (storageKey != null && storageKey.isNotEmpty) {
    await DownloadRegistry.instance.markDownloading(
      storageKey,
      fileName: fileName,
      mimeType: mimeType,
      persist: persistToCache,
    );
  }

  try {
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
      if (browserUri != null && await _launchExternalUrl(browserUri)) {
        if (storageKey != null && storageKey.isNotEmpty) {
          await DownloadRegistry.instance.clear(storageKey);
        }
        return browserUri.toString();
      }
      if (lastError is Exception) throw lastError;
      throw Exception('Unable to download file');
    }

    if (_looksLikeWebPage(response)) {
      if (await _launchExternalUrl(response.requestOptions.uri)) {
        if (storageKey != null && storageKey.isNotEmpty) {
          await DownloadRegistry.instance.clear(storageKey);
        }
        return response.requestOptions.uri.toString();
      }
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

    final savedPath = await platform.saveAndOpenBytes(
      bytes: bytes,
      fileName: resolvedName,
      mimeType: mimeType,
      storageKey: persistToCache ? storageKey : null,
      persistToCache: persistToCache,
    );

    if (storageKey != null && storageKey.isNotEmpty && savedPath.isNotEmpty) {
      await DownloadRegistry.instance.markDownloaded(
        storageKey,
        filePath: savedPath,
        fileName: resolvedName,
        mimeType: mimeType,
        persist: persistToCache,
      );
    }

    return savedPath;
  } catch (error) {
    final fallbackUri = response?.requestOptions.uri ?? browserUri;
    if (fallbackUri != null && await _launchExternalUrl(fallbackUri)) {
      if (storageKey != null && storageKey.isNotEmpty) {
        await DownloadRegistry.instance.clear(storageKey);
      }
      return fallbackUri.toString();
    }
    if (storageKey != null && storageKey.isNotEmpty) {
      await DownloadRegistry.instance.markFailed(
        storageKey,
        fileName: fileName,
        mimeType: mimeType,
        errorMessage: error.toString(),
        persist: persistToCache,
      );
    }
    rethrow;
  }
}

Uri? _resolveBrowserUri(String rawUrl, {required String baseUrl}) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return null;

  final parsed = Uri.tryParse(trimmed);
  if (parsed != null && parsed.hasScheme) {
    return parsed;
  }

  final baseUri = Uri.tryParse(baseUrl);
  if (baseUri == null) return null;

  final cleaned = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  if (cleaned.isEmpty) return baseUri;

  return baseUri.resolve(cleaned);
}

bool _looksLikeWebPage(Response<List<int>> response) {
  final contentType = response.headers.value('content-type')?.toLowerCase() ?? '';
  if (contentType.contains('text/html') ||
      contentType.contains('application/json') ||
      contentType.contains('text/plain')) {
    return true;
  }

  final body = response.data;
  if (body == null || body.isEmpty) return false;

  final preview = utf8
      .decode(body.take(512).toList(), allowMalformed: true)
      .trimLeft()
      .toLowerCase();

  return preview.startsWith('<!doctype html') ||
      preview.startsWith('<html') ||
      preview.contains('<html');
}

Future<bool> _launchExternalUrl(Uri uri) async {
  if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return false;
  }

  try {
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    return false;
  }

  return false;
}

Future<bool> _isOfflineCacheEnabled() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final offlineMode = prefs.getBool('offlineMode') ?? true;
    final autoDownload = prefs.getBool('autoDownload') ?? false;
    return offlineMode || (autoDownload && await _isOnWifi());
  } catch (_) {
    return true;
  }
}

Future<bool> _isOnWifi() async {
  try {
    final result = await Connectivity().checkConnectivity();
    return result.any(
      (item) => item == ConnectivityResult.wifi || item == ConnectivityResult.ethernet,
    );
      if (result is ConnectivityResult) {
      return result == ConnectivityResult.wifi || result == ConnectivityResult.ethernet;
    }
  } catch (_) {}
  return false;
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
