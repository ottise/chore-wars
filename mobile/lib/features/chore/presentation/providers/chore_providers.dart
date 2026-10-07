import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../home/presentation/providers/home_dashboard_provider.dart';
import '../../data/datasources/chore_remote_data_source.dart';
import '../../data/repositories/chore_repository_impl.dart';
import '../../data/repositories/mock_chore_repository.dart';
import '../../domain/entities/chore_models.dart';
import '../../domain/repositories/chore_repository.dart';

final choreRepositoryProvider = Provider<ChoreRepository>((ref) {
  if (AppConstants.uiPreview) return MockChoreRepository();
  return ChoreRepositoryImpl(ChoreRemoteDataSource(ref.watch(dioProvider)));
});

final choreTemplatesProvider =
    FutureProvider.family<List<ChoreTemplate>, String>(
      (ref, houseId) =>
          ref.watch(choreRepositoryProvider).getHouseChores(houseId),
    );

final myChoresProvider = FutureProvider.family<List<ChoreOccurrence>, String>(
  (ref, houseId) => ref.watch(choreRepositoryProvider).getMyChores(houseId),
);

typedef ChoreDetailKey = ({String houseId, String occurrenceId});

final choreDetailProvider = FutureProvider.family<ChoreDetail, ChoreDetailKey>((
  ref,
  key,
) async {
  final repository = ref.watch(choreRepositoryProvider);
  final occurrence = await repository.getOccurrence(key.occurrenceId);
  final templates = await ref.watch(choreTemplatesProvider(key.houseId).future);
  ChoreTemplate? template;
  for (final item in templates) {
    if (item.id == occurrence.choreId) {
      template = item;
      break;
    }
  }
  return ChoreDetail(occurrence: occurrence, template: template);
});

void refreshChoreState(WidgetRef ref, String houseId, {String? occurrenceId}) {
  ref.invalidate(choreTemplatesProvider(houseId));
  ref.invalidate(myChoresProvider(houseId));
  ref.invalidate(homeDashboardProvider(houseId));
  if (occurrenceId != null) {
    ref.invalidate(
      choreDetailProvider((houseId: houseId, occurrenceId: occurrenceId)),
    );
  }
}
