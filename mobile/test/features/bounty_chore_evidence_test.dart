import 'dart:convert';

import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/features/auth/domain/entities/auth_models.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/bounty/domain/entities/bounty.dart';
import 'package:chore_wars/features/bounty/presentation/providers/bounty_providers.dart';
import 'package:chore_wars/features/bounty/presentation/screens/bounty_detail_screen.dart';
import 'package:chore_wars/features/chore/presentation/screens/chore_detail_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final scenario in [
    'missing chore',
    'missing link',
    'no photo',
    'photo',
    'missing photo',
    'invalid proof',
  ]) {
    testWidgets('bounty opens chore evidence: $scenario', (tester) async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              if (request.path == '/occurrences/task' &&
                      scenario == 'missing chore' ||
                  request.path == '/evidence/photo' &&
                      scenario == 'missing photo') {
                handler.reject(
                  DioException(
                    requestOptions: request,
                    response: Response(
                      requestOptions: request,
                      statusCode: 404,
                    ),
                    type: DioExceptionType.badResponse,
                  ),
                );
                return;
              }
              Object? data = <String, dynamic>{};
              if (request.path == '/occurrences/task') {
                data = {
                  'id': 'task',
                  'houseId': 'house',
                  'choreId': 'template',
                  'choreName': 'Clean kitchen',
                  'assignedUserId': 'other',
                  'dueDate': '2026-11-02T16:59:00Z',
                  'status': 'ASSIGNED',
                  if (scenario == 'photo' || scenario == 'missing photo')
                    'evidenceId': 'photo',
                  if (scenario == 'invalid proof')
                    'proofImageUrl': 'data:image/jpeg;base64,not-valid-base64',
                };
              } else if (request.path == '/evidence/photo') {
                data = base64Decode(
                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aH9sAAAAASUVORK5CYII=',
                );
              } else if (request.path.endsWith('/current')) {
                data = null;
              }
              handler.resolve(
                Response(requestOptions: request, statusCode: 200, data: data),
              );
            },
          ),
        );
      addTearDown(dio.close);
      final router = GoRouter(
        initialLocation: '/bounty',
        routes: [
          GoRoute(
            path: '/bounty',
            builder: (_, _) =>
                const BountyDetailScreen(houseId: 'house', bountyId: 'bounty'),
          ),
          GoRoute(
            path: '/houses/:house/chores/:id',
            builder: (_, state) => ChoreDetailScreen(
              houseId: state.pathParameters['house']!,
              occurrenceId: state.pathParameters['id']!,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(dio),
            userProfileProvider.overrideWith(
              (ref) async => const UserProfile(
                id: 'me',
                email: 'me@test.com',
                displayName: 'Me',
              ),
            ),
            bountyDetailProvider.overrideWith(
              (ref, key) async => Bounty(
                id: 'bounty',
                choreOccurrenceId: scenario == 'missing link' ? '' : 'task',
                choreName: 'Clean kitchen',
                postedByUserId: 'other',
                postedByDisplayName: 'Other',
                amount: 20000,
                status: BountyStatus.open,
                expiresAt: DateTime.utc(2026, 11, 2),
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open chore & photo evidence'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (scenario == 'missing link') {
        expect(
          find.text('No chore or photo evidence is available.'),
          findsOneWidget,
        );
        expect(find.text('Bounty Detail'), findsOneWidget);
        return;
      }
      expect(find.text('Chore detail'), findsOneWidget);
      if (scenario == 'missing chore') {
        expect(find.text('Chore not found'), findsOneWidget);
      } else {
        expect(find.text('Clean kitchen'), findsOneWidget);
        if (scenario == 'no photo') {
          expect(find.text('No photo evidence yet.'), findsOneWidget);
        }
        if (scenario == 'missing photo' || scenario == 'invalid proof') {
          await tester.scrollUntilVisible(
            find.text('Photo evidence is unavailable.'),
            200,
          );
          expect(find.text('Photo evidence is unavailable.'), findsOneWidget);
        }
        if (scenario == 'photo') {
          await tester.scrollUntilVisible(find.byType(Image), 200);
          expect(find.byType(Image), findsOneWidget);
        }
      }
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Bounty Detail'), findsOneWidget);
    });
  }
}
