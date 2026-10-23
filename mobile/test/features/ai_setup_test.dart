import 'package:chore_wars/features/ai/data/ai_repository.dart';
import 'package:chore_wars/features/ai/presentation/ai_housekeeper_screen.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _OfflineAi extends AiRepository {
  _OfflineAi() : super(Dio());
  final paths = <String>[];
  @override
  Future<Map<String, dynamic>> get(String house, String path) async {
    paths.add(path);
    return {'enabled': true, 'configured': false};
  }
}

void main() {
  testWidgets(
    'unconfigured AI shows setup status and never requests profiles or model endpoints',
    (tester) async {
      final api = _OfflineAi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiRepositoryProvider.overrideWithValue(api),
            houseDetailProvider.overrideWith(
              (ref, id) async => House(
                id: id,
                name: 'Test',
                inviteCode: 'TESTCODE',
                createdAt: DateTime.utc(2026),
                myRole: HouseRole.owner,
              ),
            ),
          ],
          child: const MaterialApp(home: AiHousekeeperScreen(houseId: 'house')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 8));
      expect(find.text('Assistant Setup Required'), findsOneWidget);
      expect(api.paths, ['settings']);
      expect(find.text('Suggestions'), findsNothing);
    },
  );
}
