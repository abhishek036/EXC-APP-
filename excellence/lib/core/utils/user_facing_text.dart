import 'package:dio/dio.dart';

final RegExp _urlPattern = RegExp(
  r'(?:https?://|ftp://|www\.)\S+',
  caseSensitive: false,
);

String redactUrls(String input, {String replacement = '[link hidden]'}) {
  final text = input.trim();
  if (text.isEmpty) return text;

  var redacted = text.replaceAll(_urlPattern, replacement);
  redacted = redacted.replaceAll(
    RegExp(r'\bapi\.excellenceacademy\.site\b', caseSensitive: false),
    'internal-api',
  );
  redacted = redacted.replaceAll(RegExp(r'\s{2,}'), ' ');
  return redacted.trim();
}

String friendlyErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  String message = '';

  if (error is DioException) {
    message = error.message ?? '';
    final responseMessage = _extractDioResponseMessage(error.response?.data);
    if (responseMessage.isNotEmpty) {
      message = responseMessage;
    } else if (message.isEmpty) {
      message = error.error?.toString() ?? '';
    }
  } else {
    message = error.toString();
  }

  message = message.trim();
  if (message.isEmpty) return fallback;

  message = message.replaceFirst(
    RegExp(
      r'^(?:Exception|DioException|SocketException|FormatException)(?:\s*\[[^\]]*\])?:\s*',
    ),
    '',
  );
  message = message.replaceFirst(RegExp(r'^Error:\s*', caseSensitive: false), '');
  message = redactUrls(message);

  return message.isEmpty ? fallback : message;
}

String _extractDioResponseMessage(dynamic data) {
  if (data is Map) {
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
    }

    if (error is Map) {
      final nestedMessage = error['message'];
      if (nestedMessage is String && nestedMessage.trim().isNotEmpty) {
        return nestedMessage.trim();
      }
    }
  } else if (data is String && data.trim().isNotEmpty) {
    return data.trim();
  }

  return '';
}