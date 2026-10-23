import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/features/chat/presentation/widgets/chat_notification_button.dart';
import 'package:chore_wars/features/notifications/presentation/providers/notification_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final failSave in [false, true]) {
    testWidgets(
      'chat notification preference persists only after success (failure=$failSave)',
      (tester) async {
        var enabled = true;
        final writes = <Object?>[];
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (request, handler) {
                expect(request.path, '/houses/h/chat/notification-settings');
                if (request.method == 'PUT') {
                  writes.add(request.data);
                  if (failSave) {
                    handler.reject(
                      DioException(
                        requestOptions: request,
                        type: DioExceptionType.badResponse,
                        response: Response(
                          requestOptions: request,
                          statusCode: 503,
                          data: {'detail': 'Please retry later.'},
                        ),
                      ),
                    );
                    return;
                  }
                  enabled = request.data['enabled'] as bool;
                }
                handler.resolve(
                  Response(
                    requestOptions: request,
                    statusCode: 200,
                    data: {'enabled': enabled},
                  ),
                );
              },
            ),
          );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioProvider.overrideWithValue(dio),
              unreadChatCountProvider.overrideWith((ref, house) => 0),
            ],
            child: const MaterialApp(
              home: Scaffold(body: ChatNotificationButton(houseId: 'h')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Mute Chat Notifications'));
        await tester.pumpAndSettle();
        expect(writes, [
          {'enabled': false},
        ]);
        expect(find.byType(SwitchListTile), findsNothing);
        if (failSave) {
          expect(find.text('Please retry later.'), findsOneWidget);
          expect(find.byTooltip('Mute Chat Notifications'), findsOneWidget);
        } else {
          expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
          await tester.tap(find.byTooltip('Enable Chat Notifications'));
          await tester.pumpAndSettle();
          expect(writes, [
            {'enabled': false},
            {'enabled': true},
          ]);
          expect(find.byTooltip('Mute Chat Notifications'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
