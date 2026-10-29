import 'package:chore_wars/features/auth/domain/entities/auth_models.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:chore_wars/features/house/presentation/screens/review_schedule_screen.dart';
import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:chore_wars/features/house/presentation/screens/availability_screen.dart';
import 'package:chore_wars/features/house/presentation/screens/member_settings_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<void> mount(WidgetTester tester, Dio dio, Widget screen) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Returned')),
        routes: [GoRoute(path: 'edit', builder: (_, _) => screen)],
      ),
    ],
  );
  addTearDown(router.dispose);
  tester.view.physicalSize = const Size(354, 720);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  router.push('/edit');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'saving capacity preserves limits and never overwrites availability',
    (tester) async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              requests.add(request);
              final data = request.path.endsWith('/constraints')
                  ? {'maxChoresPerWeek': 55, 'maxEffortMinutesPerDay': 480}
                  : <dynamic>[];
              handler.resolve(
                Response(requestOptions: request, statusCode: 200, data: data),
              );
            },
          ),
        );
      await mount(
        tester,
        dio,
        const MemberSettingsScreen(houseId: 'h', seasonId: 's'),
      );
      expect(find.text('55 tasks'), findsOneWidget);
      expect(find.text('480 min'), findsOneWidget);
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      final writes = requests.where((r) => r.method == 'POST').toList();
      expect(writes.map((r) => r.path), [
        '/houses/h/constraints',
        '/houses/h/preferences',
      ]);
      expect(writes.first.data, {
        'maxChoresPerWeek': 55,
        'maxEffortMinutesPerDay': 480,
      });
      expect(requests.any((r) => r.path.contains('availability')), isFalse);
      expect(find.text('Returned'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed settings load cannot save fallback values', (
    tester,
  ) async {
    final writes = <RequestOptions>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.method == 'POST') writes.add(request);
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.connectionError,
              ),
            );
          },
        ),
      );
    await mount(
      tester,
      dio,
      const MemberSettingsScreen(houseId: 'h', seasonId: 's'),
    );
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save Changes'),
    );
    expect(save.onPressed, isNull);
    expect(writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'availability total merges overlap without changing saved intervals',
    (tester) async {
      final slots = {
        '0': [
          {'startMinute': 0, 'endMinute': 60},
        ],
        '1': [
          {'startMinute': 480, 'endMinute': 540},
          {'startMinute': 510, 'endMinute': 540},
        ],
        '2': <dynamic>[],
        '3': <dynamic>[],
        '4': <dynamic>[],
        '5': <dynamic>[],
        '6': [
          {'startMinute': 1380, 'endMinute': 1440},
        ],
      };
      Object? saved;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              if (request.method == 'POST') saved = request.data;
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {'slots': slots},
                ),
              );
            },
          ),
        );
      await mount(
        tester,
        dio,
        const AvailabilityScreen(houseId: 'h', seasonId: 's'),
      );
      expect(find.text('3.0 hrs available'), findsOneWidget);
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(saved, {'slots': slots});
      expect(find.text('Returned'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'schedule approval submits the displayed revision and shows rejected signatures',
    (tester) async {
      Object? saved;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              if (request.method == 'POST') saved = request.data;
              final Object data;
              if (request.path.endsWith('/seasons')) {
                data = [
                  {
                    'id': 's',
                    'name': 'Season 1',
                    'status': 1,
                    'scheduleRevision': 7,
                    'confirmations': [
                      {'userId': 'other', 'status': 2},
                    ],
                  },
                ];
              } else if (request.path.endsWith('/workload-summary')) {
                data = {
                  'members': [
                    {
                      'userId': 'me',
                      'displayName': 'An',
                      'totalAssignedKarma': 10,
                      'totalEstimatedMinutes': 15,
                      'totalChores': 1,
                    },
                    {
                      'userId': 'other',
                      'displayName': 'Bình',
                      'totalAssignedKarma': 10,
                      'totalEstimatedMinutes': 15,
                      'totalChores': 1,
                    },
                  ],
                  'warnings': <String>[],
                };
              } else {
                data = <dynamic>[];
              }
              handler.resolve(
                Response(requestOptions: request, statusCode: 200, data: data),
              );
            },
          ),
        );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(dio),
            houseDetailProvider.overrideWith(
              (ref, id) async => House(
                id: id,
                name: 'Home',
                inviteCode: 'CODE',
                createdAt: DateTime.utc(2026),
              ),
            ),
            userProfileProvider.overrideWith(
              (ref) async => const UserProfile(
                id: 'me',
                email: 'me@example.test',
                displayName: 'An',
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ReviewScheduleScreen(houseId: 'h', seasonId: 's'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Season 1 · Revision 7'), findsOneWidget);
      expect(find.text('Rejected'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Confirm & Approve Schedule'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Confirm & Approve Schedule'));
      await tester.pumpAndSettle();
      expect(saved, {'scheduleRevision': 7});
      expect(tester.takeException(), isNull);
    },
  );
}
