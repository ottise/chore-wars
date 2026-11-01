import 'package:chore_wars/core/network/api_client.dart';
import 'package:chore_wars/features/auth/domain/entities/auth_models.dart';
import 'package:chore_wars/features/auth/presentation/providers/auth_providers.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:chore_wars/features/house/presentation/screens/capacity_availability_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CapacityAvailabilityScreen loads and displays all unified sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.path.endsWith('/constraints')) {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {
                    'maxChoresPerWeek': 20,
                    'maxEffortMinutesPerDay': 120,
                  },
                ),
              );
            } else if (request.path.endsWith('/preferences')) {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: [
                    {'choreId': 'c1', 'choreName': 'Wash Dishes', 'type': 1},
                    {'choreId': 'c2', 'choreName': 'Clean Windows', 'type': 2},
                  ],
                ),
              );
            } else if (request.path.endsWith('/chores')) {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: [
                    {'id': 'c1', 'name': 'Wash Dishes'},
                    {'id': 'c2', 'name': 'Clean Windows'},
                    {'id': 'c3', 'name': 'Take out trash'},
                  ],
                ),
              );
            } else if (request.path.endsWith('/availability')) {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: {
                    'slots': {
                      '1': [
                        {'startMinute': 360, 'endMinute': 1200},
                      ],
                      '2': [
                        {'startMinute': 360, 'endMinute': 1200},
                      ],
                      '3': [
                        {'startMinute': 360, 'endMinute': 1200},
                      ],
                      '4': [
                        {'startMinute': 360, 'endMinute': 1200},
                      ],
                      '5': [
                        {'startMinute': 360, 'endMinute': 1200},
                      ],
                      '6': [
                        {'startMinute': 480, 'endMinute': 960},
                      ],
                      '0': [
                        {'startMinute': 480, 'endMinute': 960},
                      ],
                    },
                  },
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: 200,
                  data: <dynamic>[],
                ),
              );
            }
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
              name: 'The Gang',
              inviteCode: 'TEST',
              createdAt: DateTime.utc(2026),
            ),
          ),
          userProfileProvider.overrideWith(
            (ref) async => const UserProfile(
              id: 'u1',
              email: 'ma@example.test',
              displayName: 'Má',
            ),
          ),
        ],
        child: const MaterialApp(
          home: CapacityAvailabilityScreen(houseId: 'h1', seasonId: 's1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify header and top bar
    expect(find.text('Capacity & Availability'), findsOneWidget);
    expect(find.text('The Gang · Má'), findsOneWidget);
    expect(find.text('Active - Balanced auto-sync'), findsOneWidget);
    expect(find.text('Algorithm ON'), findsOneWidget);

    // Verify Workload Limits card
    expect(find.text('Workload Limits'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('chores / wk'), findsOneWidget);
    expect(find.text('2.0'), findsOneWidget);
    expect(find.text('hrs / day'), findsOneWidget);
    expect(find.text('Balanced workload'), findsOneWidget);

    // Verify Chore Preferences card
    expect(find.text('Chore Preferences'), findsOneWidget);
    expect(find.text('PREFERRED'), findsOneWidget);
    expect(find.text('Wash Dishes ✨'), findsOneWidget);
    expect(find.text('AVOID'), findsOneWidget);
    expect(find.text('Clean Windows ✕'), findsOneWidget);
    expect(find.text('Add Chore Preference'), findsOneWidget);

    // Verify Weekly Schedule card
    expect(find.text('Weekly Schedule'), findsOneWidget);
    expect(find.text('Weekdays (Mon – Fri)'), findsOneWidget);
    expect(find.text('Weekend (Sat – Sun)'), findsOneWidget);

    // Verify Bottom Save Changes button
    expect(find.text('Save Changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
