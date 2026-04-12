import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import '../di/injection_container.dart';
import '../network/api_client.dart';

class CloudStorageService {
  static final CloudStorageService instance = CloudStorageService._();

  CloudStorageService._();

  /// Uploads a file using the custom backend B2 service
  Future<String> uploadFile(File file, String destination) async {
    final fileName = p.basename(file.path);
    final extName = p.extension(file.path).toLowerCase();

    // Mapping basic types for multer/B2
    String mimeType = 'application/octet-stream';
    if (extName == '.pdf') {
      mimeType = 'application/pdf';
    } else if (extName == '.png') {
      mimeType = 'image/png';
    } else if (extName == '.jpg' || extName == '.jpeg') {
      mimeType = 'image/jpeg';
    } else if (extName == '.mp4') {
      mimeType = 'video/mp4';
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ),
      'destination': destination,
    });

    final dio = sl<ApiClient>().dio;
    // Removed leading slash to prevent baseUrl segment loss
    final response = await dio.post('upload', data: formData);

    if (response.statusCode == 201 && response.data['success'] == true) {
      return response.data['data']['fileUrl'] as String;
    } else {
      throw Exception('Upload failed: ${response.data}');
    }
  }

  /// Uploads raw data (useful for Web where `File` uses byte streams)
  Future<String> uploadBytes(List<int> bytes, String destination, String fileName) async {
    String mimeType = 'application/octet-stream';
    if (fileName.endsWith('.pdf')) {
      mimeType = 'application/pdf';
    } else if (fileName.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) {
      mimeType = 'image/jpeg';
    } else if (fileName.endsWith('.mp4')) {
      mimeType = 'video/mp4';
    }

    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ),
      'destination': destination,
    });

    final dio = sl<ApiClient>().dio;
    // Removed leading slash to prevent baseUrl segment loss
    final response = await dio.post('upload', data: formData);

    if (response.statusCode == 201 && response.data['success'] == true) {
      return response.data['data']['fileUrl'] as String;
    } else {
      throw Exception('Upload failed: ${response.data}');
    }
  }
}
