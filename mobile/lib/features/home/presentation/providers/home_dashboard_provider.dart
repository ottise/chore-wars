import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/home_dashboard_repository.dart';
import '../../domain/entities/home_dashboard.dart';

final homeDashboardRepositoryProvider = Provider<HomeDashboardRepository>((ref) {
  return HomeDashboardRepository(ref.watch(dioProvider));
});

final homeDashboardProvider = FutureProvider.autoDispose.family<HomeDashboard, String>((ref, houseId) {
  return ref.watch(homeDashboardRepositoryProvider).getDashboard(houseId);
});