import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DownloadStatus { downloading, downloaded, failed }

class DownloadRecord {
  final DownloadStatus status;
  final String? filePath;
  final String? fileName;
  final String? mimeType;
  final String? errorMessage;

  const DownloadRecord({
    required this.status,
    this.filePath,
    this.fileName,
    this.mimeType,
    this.errorMessage,
  });

  DownloadRecord copyWith({
    DownloadStatus? status,
    String? filePath,
    String? fileName,
    String? mimeType,
    String? errorMessage,
  }) {
    return DownloadRecord(
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'filePath': filePath,
      'fileName': fileName,
      'mimeType': mimeType,
      'errorMessage': errorMessage,
    };
  }

  factory DownloadRecord.fromJson(Map<String, dynamic> json) {
    final statusName = (json['status'] ?? 'downloaded').toString();
    final status = DownloadStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => DownloadStatus.downloaded,
    );
    return DownloadRecord(
      status: status,
      filePath: json['filePath']?.toString(),
      fileName: json['fileName']?.toString(),
      mimeType: json['mimeType']?.toString(),
      errorMessage: json['errorMessage']?.toString(),
    );
  }
}

class DownloadRegistry extends ChangeNotifier {
  DownloadRegistry._();

  static final DownloadRegistry instance = DownloadRegistry._();

  static const String _prefsKey = 'offline_download_registry_v1';

  final Map<String, DownloadRecord> _records = {};
  Future<void>? _loadFuture;

  Future<void> ensureLoaded() {
    return _loadFuture ??= _load();
  }

  DownloadRecord? recordFor(String key) {
    return _records[key];
  }

  String? downloadedPath(String key) {
    final record = _records[key];
    if (record == null || record.status != DownloadStatus.downloaded) {
      return null;
    }
    return record.filePath;
  }

  bool isDownloading(String key) {
    return _records[key]?.status == DownloadStatus.downloading;
  }

  bool isDownloaded(String key) {
    return _records[key]?.status == DownloadStatus.downloaded;
  }

  Future<void> markDownloading(
    String key, {
    String? fileName,
    String? mimeType,
    bool persist = true,
  }) async {
    await ensureLoaded();
    _records[key] = DownloadRecord(
      status: DownloadStatus.downloading,
      fileName: fileName,
      mimeType: mimeType,
    );
    notifyListeners();
  }

  Future<void> markDownloaded(
    String key, {
    required String filePath,
    String? fileName,
    String? mimeType,
    bool persist = true,
  }) async {
    await ensureLoaded();
    _records[key] = DownloadRecord(
      status: DownloadStatus.downloaded,
      filePath: filePath,
      fileName: fileName,
      mimeType: mimeType,
    );
    if (persist) {
      await _persistDownloadedOnly();
    }
    notifyListeners();
  }

  Future<void> markFailed(
    String key, {
    String? fileName,
    String? mimeType,
    String? errorMessage,
    bool persist = true,
  }) async {
    await ensureLoaded();
    _records[key] = DownloadRecord(
      status: DownloadStatus.failed,
      fileName: fileName,
      mimeType: mimeType,
      errorMessage: errorMessage,
    );
    notifyListeners();
  }

  Future<void> clear(String key) async {
    await ensureLoaded();
    final record = _records.remove(key);
    if (record != null) {
      await _deleteFile(record.filePath);
      await _persistDownloadedOnly();
      notifyListeners();
    }
  }

  Future<int> clearAll() async {
    await ensureLoaded();
    final files = _records.values
        .map((record) => record.filePath)
        .whereType<String>()
        .toList(growable: false);
    final count = _records.length;
    _records.clear();
    for (final path in files) {
      await _deleteFile(path);
    }
    await _persistDownloadedOnly();
    notifyListeners();
    return count;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              _records[key] = DownloadRecord.fromJson(value);
            } else if (value is Map) {
              _records[key] = DownloadRecord.fromJson(
                Map<String, dynamic>.from(value),
              );
            }
          });
        }
      }
    } catch (_) {
      _records.clear();
    } finally {
      notifyListeners();
    }
  }

  Future<void> _persistDownloadedOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloaded = <String, dynamic>{};
      for (final entry in _records.entries) {
        if (entry.value.status == DownloadStatus.downloaded) {
          downloaded[entry.key] = entry.value.toJson();
        }
      }
      await prefs.setString(_prefsKey, jsonEncode(downloaded));
    } catch (_) {}
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
