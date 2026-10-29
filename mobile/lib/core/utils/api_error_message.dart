import 'package:dio/dio.dart';

String apiErrorMessage(Object error) {
  if (error is! DioException) {
    return 'An unexpected error occurred. Please try again.';
  }

  final data = error.response?.data;
  final status = error.response?.statusCode;
  if (status == 404 &&
      (error.requestOptions.path == '/auth/google' ||
          error.requestOptions.uri.path == '/api/auth/google')) {
    return 'Google sign-in is temporarily unavailable. Please use email and password or try again later.';
  }
  if (status != null && status >= 500) return _statusMessage(status);
  if (data is Map) {
    final detail = _mapValue(data, 'detail') ?? _mapValue(data, 'message');
    if (_safeMessage(detail)) {
      return (detail as String).trim();
    }

    final errors = _mapValue(data, 'errors');
    if (errors is Map) {
      final messages = <String>[];
      for (final value in errors.values) {
        if (value is Iterable) {
          messages.addAll(value.whereType<String>().where(_safeMessage));
        } else if (value is String) {
          if (_safeMessage(value)) messages.add(value);
        }
      }
      if (messages.isNotEmpty) {
        return messages.toSet().take(3).join('\n');
      }
    }

    final title = _mapValue(data, 'title');
    if (_safeMessage(title)) return (title as String).trim();
  }

  return switch (error.type) {
    DioExceptionType.connectionTimeout =>
      'We could not connect right now. Please try again in a moment.',
    DioExceptionType.sendTimeout =>
      'The server took too long to accept the request. Please try again.',
    DioExceptionType.receiveTimeout =>
      'The server is taking too long to respond. Please try again in a moment.',
    DioExceptionType.transformTimeout =>
      'The server response took too long to process. Please try again.',
    DioExceptionType.connectionError =>
      'Could not connect. Check your connection and try again.',
    DioExceptionType.badCertificate =>
      'A secure connection could not be established. Please try again later.',
    DioExceptionType.cancel => 'The request was cancelled.',
    DioExceptionType.badResponse => _statusMessage(error.response?.statusCode),
    DioExceptionType.unknown =>
      'We could not connect right now. Please try again in a moment.',
  };
}

final _technicalDetails = RegExp(
  r'exception|stack\s*trace|sqlstate|npgsql|system\.|microsoft\.|'
  r'assertion|traceback|package:|file://|\.dart:\d|\.cs:\d|'
  r'\bat\s+\S+\([^)]*\)|<html|<!doctype|connectionstring|password\s*=',
  caseSensitive: false,
);

bool _safeMessage(Object? value) =>
    value is String &&
    value.trim().isNotEmpty &&
    value.length <= 350 &&
    value.split('\n').length <= 3 &&
    !_technicalDetails.hasMatch(value);

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
