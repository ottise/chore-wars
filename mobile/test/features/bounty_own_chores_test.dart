import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/features/auth/domain/entities/auth_models.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/bounty/presentation/providers/bounty_providers.dart';
import 'package:chore_wars/features/bounty/presentation/screens/bounty_board_screen.dart';
import 'package:chore_wars/features/payment/presentation/providers/payment_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bounty picker shows only own unresolved assigned chores', (
    tester,
  ) async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: request.path.endsWith('/current')
                    ? {'id': 'season'}
                    : [
                        {
                          'id': 'mine',
                          'choreName': 'My chore',
                          'assignedUserId': 'ME',
                          'status': 0,
                        },
                        {
                          'id': 'other',
                          'choreName': 'Someone else',
                          'assignedUserId': 'B',
                          'status': 'ASSIGNED',
                        },
                        {
                          'id': 'done',
                          'choreName': 'Already completed',
                          'assignedUserId': 'me',
                          'status': 1,
                        },
                        {
                          'id': 'overdue',
                          'choreName': 'My overdue chore',
                          'assignedUserId': 'me',
                          'status': 3,
                        },
                        {
                          'id': 'free',
                          'choreName': 'Unassigned',
                          'status': 'ASSIGNED',
                        },
                      ],
              ),
            );
          },
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          userProfileProvider.overrideWith(
            (ref) async => const UserProfile(
              id: 'me',
              email: 'me@example.test',
              displayName: 'Me',
            ),
          ),
          bountyBoardProvider.overrideWith((ref, id) async => []),
          paymentListProvider.overrideWith((ref, id) async => []),
        ],
        child: const MaterialApp(home: BountyBoardScreen(houseId: 'house')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post Bounty'));
    await tester.pumpAndSettle();
    expect(find.text('My chore'), findsOneWidget);
    expect(find.text('My overdue chore'), findsOneWidget);
    expect(find.text('Someone else'), findsNothing);
    expect(find.text('Already completed'), findsNothing);
    expect(find.text('Unassigned'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
