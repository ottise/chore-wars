import 'package:chore_wars/core/utils/api_error_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RequestOptions request() => RequestOptions(path: '/test');

  test('uses backend ProblemDetails detail', () {
    final error = DioException(
      requestOptions: request(),
      type: DioExceptionType.badResponse,
      response: Response<Map<String, dynamic>>(
        requestOptions: request(),
        statusCode: 403,
        data: {'detail': 'Only the house owner can generate a schedule.'},
      ),
    );

    expect(
      apiErrorMessage(error),
      'Only the house owner can generate a schedule.',
    );
  });

  test('supports legacy PascalCase error payloads', () {
    final error = DioException(
      requestOptions: request(),
      type: DioExceptionType.badResponse,
      response: Response<Map<String, dynamic>>(
        requestOptions: request(),
        statusCode: 409,
        data: {'Detail': 'The season is no longer in draft state.'},
      ),
    );

    expect(apiErrorMessage(error), 'The season is no longer in draft state.');
  });

  test('shows field validation errors before the generic problem title', () {
    final error = DioException(
      requestOptions: request(),
      type: DioExceptionType.badResponse,
      response: Response<Map<String, dynamic>>(
        requestOptions: request(),
        statusCode: 400,
        data: {
          'title': 'One or more validation errors occurred.',
          'errors': {
            'file': ['The file field is required.'],
          },
        },
      ),
    );
    expect(apiErrorMessage(error), 'The file field is required.');
  });

  test('replaces Dio timeout diagnostics with a user-friendly message', () {
    final error = DioException(
      requestOptions: request(),
      type: DioExceptionType.receiveTimeout,
    );

    final message = apiErrorMessage(error);
    expect(message, contains('taking too long'));
    expect(message, isNot(contains('RequestOptions')));
  });

  test(
    'never exposes server exception details even in structured responses',
    () {
      final error = DioException(
        requestOptions: request(),
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: request(),
          statusCode: 500,
          data: {
            'detail': 'Npgsql.PostgresException: relation AIChatInsights does not exist',
            'errors': {
              'database': ['System.InvalidOperationException at Server.Run()'],
            },
          },
        ),
      );
      expect(
        apiErrorMessage(error),
        'The server encountered an error. Please try again later.',
      );
    },
  );

  test('filters technical diagnostics without losing useful field errors', () {
    final error = DioException(
      requestOptions: request(),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: request(),
        statusCode: 400,
        data: {
          'detail': 'System.ArgumentException at Server.Run()',
          'errors': {
            'email': ['Enter a valid email address.'],
            'internal': ['SqlState: 42P01'],
          },
        },
      ),
    );
    expect(apiErrorMessage(error), 'Enter a valid email address.');
  });

  test('replaces HTML gateway failures and technical non-network errors', () {
    final error = DioException(
      requestOptions: request(),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: request(),
        statusCode: 502,
        data: '<html>upstream unavailable</html>',
      ),
    );
    expect(apiErrorMessage(error), isNot(contains('<html>')));
    expect(
      apiErrorMessage(StateError('file:///C:/server.cs:42')),
      'An unexpected error occurred. Please try again.',
    );
  });
}
