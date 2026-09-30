import 'package:dio/dio.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/bounty.dart';
import '../../domain/repositories/bounty_repository.dart';
import '../models/bounty_model.dart';

class BountyRepositoryImpl implements BountyRepository {
  final Dio dio;

  const BountyRepositoryImpl(this.dio);

  @override
  Future<List<Bounty>> getBounties(String houseId) async {
    final response = await dio.get(ApiEndpoints.bounties(houseId));
    final data = response.data;
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(BountyModel.fromJson)
      .map((model) => model.toEntity())
        .toList();
  }

  @override
  Future<Bounty> getBounty({required String houseId, required String bountyId}) async {
    final response = await dio.get(ApiEndpoints.bountyDetails(houseId, bountyId));
    return BountyModel.fromJson(response.data as Map<String, dynamic>).toEntity();
  }

  @override
  Future<Bounty> createBounty({
    required String houseId,
    required String choreOccurrenceId,
    required double amount,
  }) async {
    final response = await dio.post(
      ApiEndpoints.bounties(houseId),
      data: {
        'choreOccurrenceId': choreOccurrenceId,
        'amount': amount,
      },
    );
    return BountyModel.fromJson(response.data as Map<String, dynamic>).toEntity();
  }

  @override
  Future<void> acceptBounty({
    required String houseId,
    required String bountyId,
  }) async {
    await dio.post(ApiEndpoints.acceptBounty(houseId, bountyId));
  }
}