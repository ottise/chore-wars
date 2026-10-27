import 'dart:ui';

import 'package:chore_wars/core/utils/app_error_reporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('framework fallback never renders the exception or stack trace', (
    tester,
  ) async {
    final builder = ErrorWidget.builder;
    final handler = FlutterError.onError;
    final platformHandler = PlatformDispatcher.instance.onError;
    late Widget fallback;
    try {
      AppErrorReporter.install();
      fallback = ErrorWidget.builder(
        FlutterErrorDetails(
          exception: StateError('Npgsql.PostgresException SQL password=secret'),
          stack: StackTrace.fromString(
            'at System.Server.Run() file:///C:/server.cs:42',
          ),
        ),
      );
    } finally {
      ErrorWidget.builder = builder;
      FlutterError.onError = handler;
      PlatformDispatcher.instance.onError = platformHandler;
    }
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: fallback)));
    expect(find.text('This screen could not be displayed.'), findsOneWidget);
    expect(find.textContaining('PostgresException'), findsNothing);
    expect(find.textContaining('password='), findsNothing);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
