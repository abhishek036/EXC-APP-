import 'package:excellence/core/di/injection_container.dart';
import 'package:excellence/core/network/api_client.dart';
import 'package:excellence/core/services/secure_storage_service.dart';
import 'package:excellence/features/teacher/data/repositories/teacher_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Future<RequestOptions> _runUpload({
  required String type,
  String? fileUrl,
  DateTime? dueDate,
}) async {
  sl.registerSingleton<SecureStorageService>(SecureStorageService());
  final apiClient = ApiClient();
  apiClient.dio.interceptors.clear();

  late RequestOptions captured;
  apiClient.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        captured = options;
        handler.resolve(
          Response(
            requestOptions: options,
            statusCode: 201,
            data: {
              'success': true,
              'data': {'id': 'item-1'},
            },
          ),
        );
      },
    ),
  );

  sl.registerSingleton<ApiClient>(apiClient);

  final repo = TeacherRepository();
  await repo.uploadMaterial(
    title: 'Sample Material',
    subject: 'Physics',
    type: type,
    batchId: '00000000-0000-0000-0000-000000000101',
    fileUrl: fileUrl,
    description: 'demo',
    dueDate: dueDate,
  );

  return captured;
}

void main() {
  setUp(() async {
    await sl.reset();
  });

  tearDown(() async {
    await sl.reset();
  });

  test('maps legacy note type to backend enum using file extension', () async {
    final request = await _runUpload(
      type: 'note',
      fileUrl: 'https://cdn.example.com/folder/chapter-1.png',
    );

    expect(request.path, equals('content/notes'));
    final payload = Map<String, dynamic>.from(request.data as Map);
    expect(payload['file_type'], equals('image'));
  });

  test('keeps already valid note file_type values', () async {
    final request = await _runUpload(
      type: 'docx',
      fileUrl: 'https://cdn.example.com/folder/chapter-1.docx',
    );

    expect(request.path, equals('content/notes'));
    final payload = Map<String, dynamic>.from(request.data as Map);
    expect(payload['file_type'], equals('docx'));
  });

  test('routes assignment uploads to assignments endpoint', () async {
    final request = await _runUpload(
      type: 'assignment',
      fileUrl: 'https://cdn.example.com/folder/sheet.pdf',
      dueDate: DateTime.utc(2026, 5, 1),
    );

    expect(request.path, equals('content/assignments'));
    final payload = Map<String, dynamic>.from(request.data as Map);
    expect(payload.containsKey('due_date'), isTrue);
    expect(payload.containsKey('file_type'), isFalse);
  });
}

