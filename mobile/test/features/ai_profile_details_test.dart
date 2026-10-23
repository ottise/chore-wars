import 'package:chore_wars/features/ai/presentation/ai_profile_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows unknown rate with its actual denominator and sample count',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiProfileDetails(
                houseId: 'house',
                profile: {
                  'metrics': {
                    'on_time_episode_rate': {
                      'value': null,
                      'numerator': 0,
                      'denominator': 0,
                      'sample_count': 0,
                      'unit': 'ratio',
                      'evidence_ids': [],
                    },
                  },
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Metric Sources & Samples'));
      await tester.pumpAndSettle();
      expect(
        find.text('Insufficient Samples · 0 samples · 0/0'),
        findsOneWidget,
      );
      expect(find.text('Your Declared Preferences'), findsNothing);
    },
  );

  testWidgets('cleared declaration remains distinct from dislike', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiProfileDetails(
            houseId: 'house',
            profile: {
              'preference_profile': [
                {
                  'chore_name': 'Rửa bát',
                  'current_declared': null,
                  'positive_count': 1,
                  'negative_count': 0,
                  'sample_count': 1,
                  'smoothed_positive_score': 2 / 3,
                  'evidence_ids': [],
                },
              ],
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Your Declared Preferences'));
    await tester.pumpAndSettle();
    expect(find.text('Preference Removed'), findsOneWidget);
    expect(find.text('Currently disliked'), findsNothing);
  });
}
