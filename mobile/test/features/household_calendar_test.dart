import 'dart:typed_data';
import 'dart:convert';

import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:chore_wars/features/house/domain/entities/house_calendar_models.dart';
import 'package:chore_wars/features/house/presentation/providers/house_calendar_providers.dart';
import 'package:chore_wars/features/house/presentation/widgets/household_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completion dates use Vietnam day rather than browser timezone', () {
    expect(
      vietnamDay(DateTime.utc(2026, 10, 27, 17, 5)),
      DateTime(2026, 10, 28),
    );
  });
  for (final count in [0, 1, 2, 3, 5]) {
    testWidgets(
      'calendar shows real previews and correct overflow for $count photos',
      (tester) async {
        tester.view.physicalSize = const Size(354, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final day = vietnamDay(DateTime.now());
        final ids = List.generate(count, (i) => 'evidence-$i');
        final bytes = Uint8List.fromList(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              houseCalendarProvider.overrideWith(
                (ref, range) async => [
                  HouseCalendarDay(
                    date: day,
                    scheduled: 1,
                    completed: 1,
                    overdue: 0,
                    photoCount: count,
                    previews: ids.take(2).toList(),
                    items: [
                      CalendarChore(
                        id: 'chore',
                        name: 'Clean kitchen',
                        status: 'COMPLETED',
                        dueDate: DateTime.now().toUtc(),
                        completedAt: DateTime.now().toUtc(),
                        assignedName: 'A',
                        completedByName: 'B',
                        evidenceIds: ids,
                      ),
                    ],
                  ),
                ],
              ),
              calendarPhotoProvider.overrideWith((ref, key) async => bytes),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: HouseholdCalendar(houseId: 'house'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Clean kitchen'), findsOneWidget);
        expect(find.textContaining('Completed by B'), findsOneWidget);
        if (count > 2) {
          expect(find.text('+${count - 2}'), findsOneWidget);
          await tester.tap(find.text('+${count - 2}'));
          await tester.pumpAndSettle();
          expect(find.text('Clean kitchen · B'), findsOneWidget);
          final lastPhoto = find.byWidgetPredicate(
            (w) =>
                w is CalendarEvidencePhoto &&
                !w.thumbnail &&
                w.evidenceId == ids.last,
          );
          await tester.scrollUntilVisible(
            lastPhoto,
            350,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.pumpAndSettle();
          expect(lastPhoto, findsOneWidget);
        } else {
          expect(find.textContaining('+'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
