import 'dart:convert';

void main() {
  final responseData = {
    "success": true,
    "data": [
      {
        "id": "002463a3-8124-452c-8df8-b455a68468e9",
        "title": "Quiz Submitted",
        "body": "Bholu submitted \"bvxcfg\" and scored 4/4.",
        "type": "exam",
        "role_target": "all",
        "user_id": "ef277c23-e134-48fe-813d-b0fd23fc2700",
        "institute_id": "00000000-0000-0000-0000-000000000001",
        "read_status": false,
        "meta": {
          "route": "/teacher/batches/cef330a2-2298-4d30-8ae8-fc465425b062?tab=tests",
          "quiz_id": "0d99a766-c9f1-464a-8744-28f8290503f3",
          "student_id": "82e0ef9c-9da6-4453-8e90-6bdc9e3da673"
        },
        "created_at": "2026-04-20T16:28:25.272Z"
      }
    ],
    "meta": { "page": 1, "perPage": 20 }
  };

  final extracted = extractList(responseData);
  print('Extracted: $extracted');
  final normalized = extracted.map(normalizeNotification).toList();
  print('Normalized: $normalized');
}

List<Map<String, dynamic>> extractList(dynamic responseData) {
  final payload = responseData is Map<String, dynamic>
      ? responseData['data']
      : null;

  if (payload is List) {
    return payload.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
  return const [];
}

bool isTruthy(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value == null) return false;

  final normalized = value.toString().trim().toLowerCase();
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes' ||
      normalized == 'y';
}

Map<String, dynamic> normalizeNotification(Map<String, dynamic> input) {
  final rawDate = input['created_at'] ?? input['date'];
  DateTime? dt;
  if (rawDate != null) {
    dt = DateTime.tryParse(rawDate.toString())?.toLocal();
  }
  return {
    ...input,
    'isRead':
        isTruthy(input['read_status']) ||
        isTruthy(input['isRead']) ||
        isTruthy(input['readStatus']) ||
        isTruthy(input['is_read']),
    'title': input['title'] ?? 'Notification',
    'body': input['body'] ?? input['message'] ?? '',
    'type': (input['type'] ?? 'system').toString(),
    'time': (input['created_at'] ?? input['date'] ?? '').toString(),
    'dateTime': dt,
    'batchName':
        input['batch_name'] ??
        input['batchName'] ??
        (input['meta'] is Map ? input['meta']['batchName'] : null),
  };
}
