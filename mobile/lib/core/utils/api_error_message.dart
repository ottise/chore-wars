import 'package:dio/dio.dart';

String apiErrorMessage(Object error) {
  if (error is! DioException) {
    return 'An unexpected error occurred. Please try again.';
  }

  final data = error.response?.data;
  if (data is Map) {
    final detail = _mapValue(data, 'detail') ?? _mapValue(data, 'message');
    if (detail is String && detail.trim().isNotEmpty) {
      return detail;
    }

    final errors = _mapValue(data, 'errors');
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

    final title = _mapValue(data, 'title');
    if (title is String && title.trim().isNotEmpty) return title;
  }

  return switch (error.type) {
    DioExceptionType.connectionTimeout => 'Could not connect to the server. Check that the API is running and try again.',
    DioExceptionType.sendTimeout =>
      'The server took too long to accept the request. Please try again.',
    DioExceptionType.receiveTimeout =>
      'The server is taking too long to respond. Please try again in a moment.',
    DioExceptionType.transformTimeout =>
      'The server response took too long to process. Please try again.',
    DioExceptionType.connectionError =>
      'Cannot reach the server. Check your network connection and API address.',
    DioExceptionType.badCertificate =>
      'The server security certificate could not be verified.',
    DioExceptionType.cancel => 'The request was cancelled.',
    DioExceptionType.badResponse => _statusMessage(error.response?.statusCode),
    DioExceptionType.unknown => 'A network error occurred. Check that the server is running and try again.',
  };
}

Object? _mapValue(Map<dynamic, dynamic> map, String key) {
  for (final entry in map.entries) {
    if (entry.key.toString().toLowerCase() == key) return entry.value;
  }
  return null;
}

String _statusMessage(int? statusCode) => switch (statusCode) {
  400 => 'The request is invalid. Check the entered information.',
  401 => 'Your session has expired. Please sign in again.',
  403 => 'You do not have permission to perform this action.',
  404 => 'The requested information could not be found.',
  409 => 'This action conflicts with the current data. Refresh and try again.',
  429 => 'Too many requests. Please wait a moment and try again.',
  int code when code >= 500 =>
    'The server encountered an error. Please try again later.',
  _ => 'The request could not be completed. Please try again.',
};
