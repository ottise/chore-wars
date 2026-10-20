import 'package:dio/dio.dart';

class CustomReward {
  final String id, name, description;
  final int cost;
  final bool enabled;
  const CustomReward(
    this.id,
    this.name,
    this.description,
    this.cost,
    this.enabled,
  );
  factory CustomReward.fromJson(Map<String, dynamic> json) => CustomReward(
    json['id'] as String,
    json['name'] as String,
    json['description'] as String,
    (json['cost'] as num).toInt(),
    json['enabled'] as bool,
  );
}

class CustomRewardRepository {
  final Dio dio;
  CustomRewardRepository(this.dio);
  String base(String houseId) => '/houses/$houseId/rewards';
  Future<List<CustomReward>> list(String houseId) async {
    final result = await dio.get(base(houseId));
    return (result.data as List)
        .map((x) => CustomReward.fromJson(Map<String, dynamic>.from(x)))
        .toList();
  }

  Future<void> create(
    String houseId,
    String name,
    String description,
    int cost,
  ) async {
    await dio.post(
      base(houseId),
      data: {'name': name, 'description': description, 'cost': cost},
    );
  }

  Future<void> redeem(String houseId, String rewardId, String requestId) async {
    await dio.post(
      '${base(houseId)}/$rewardId/redeem',
      data: {'clientRequestId': requestId},
    );
  }

  Future<void> update(
    String houseId,
    String rewardId,
    String name,
    String description,
    int cost,
    bool enabled,
  ) async {
    await dio.put(
      '${base(houseId)}/$rewardId',
      data: {
        'name': name,
        'description': description,
        'cost': cost,
        'enabled': enabled,
      },
    );
  }
}
