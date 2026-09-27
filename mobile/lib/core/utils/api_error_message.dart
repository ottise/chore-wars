import 'package:dio/dio.dart';

String apiErrorMessage(Object error) {
  if (error is! DioException) {
    return error.toString();
  }

  final data = error.response?.data;
  if (data is Map) {
    final detail = data['detail'] ?? data['message'] ?? data['title'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail;
    }

    final errors = data['errors'];
    if (errors is Map) {
      final messages = <String>[];
      for (final value in errors.values) {
        if (value is Iterable) {
          messages.addAll(value.whereType<String>());
        } else if (value is String) {
          messages.add(value);
        }
      }
      if (messages.isNotEmpty) {
        return messages.join('\n');
      }
    }
  }

  return error.message ?? 'Something went wrong.';
}