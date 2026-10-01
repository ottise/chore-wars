import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/house_remote_data_source.dart';
import '../../data/repositories/house_repository_impl.dart';
import '../../domain/entities/house_models.dart';
import '../../domain/repositories/house_repository.dart';

import '../../data/datasources/season_remote_data_source.dart';

final seasonRemoteDataSourceProvider = Provider<SeasonRemoteDataSource>((ref) {
  return SeasonRemoteDataSource(ref.watch(dioProvider));
});

final houseRepositoryProvider = Provider<HouseRepository>((ref) {
  return HouseRepositoryImpl(
    HouseRemoteDataSource(ref.watch(dioProvider)),
  );
});

final myHousesProvider = FutureProvider.autoDispose<List<House>>((ref) {
  return ref.watch(houseRepositoryProvider).getMyHouses();
});

final houseDetailProvider = FutureProvider.autoDispose.family<House, String>((
  ref,
  houseId,
) {
  return ref.watch(houseRepositoryProvider).getHouse(houseId);
});

final houseMembersProvider =
    FutureProvider.autoDispose.family<List<HouseMember>, String>((
      ref,
      houseId,
    ) {
      return ref.watch(houseRepositoryProvider).getMembers(houseId);
    });

void refreshHouseState(WidgetRef ref, {String? houseId}) {
  ref.invalidate(myHousesProvider);
  if (houseId != null) {
    ref.invalidate(houseDetailProvider(houseId));
    ref.invalidate(houseMembersProvider(houseId));
    ref.invalidate(activeSeasonProvider(houseId));
  }
}

final activeSeasonProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, houseId) async {
  try {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/api/houses/$houseId/seasons/current');
    return response.data as Map<String, dynamic>?;
  } catch (e) {
    return null;
  }
});

