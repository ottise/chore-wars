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
  testWidgets('bounty picker uses the server eligible-chores contract', (
    tester,
  ) async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(request.path, '/houses/house/bounties/eligible-chores');
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
    expect(find.text('My overdue chore'), findsNothing);
    expect(find.text('Someone else'), findsNothing);
    expect(find.text('Already completed'), findsNothing);
    expect(find.text('Unassigned'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
