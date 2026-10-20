import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';

class FailedEventItem {
  final String id, topic, status, errorCode;
  final int failureCount, replayCount;
  final DateTime lastFailedAt;
  FailedEventItem.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      topic = json['topic'] as String,
      status = json['status'] as String,
      errorCode = json['errorCode'] as String,
      failureCount = (json['failureCount'] as num).toInt(),
      replayCount = (json['replayCount'] as num).toInt(),
      lastFailedAt = DateTime.parse(json['lastFailedAt'] as String);
}

class FailedEventPage {
  final List<FailedEventItem> items;
  final int total;
  FailedEventPage.fromJson(Map<String, dynamic> json)
    : items = (json['items'] as List)
          .map((x) => FailedEventItem.fromJson(Map<String, dynamic>.from(x)))
          .toList(),
      total = (json['total'] as num).toInt();
}

class FailedEventRepository {
  FailedEventRepository(this.dio);
  final Dio dio;
  Future<FailedEventPage> list(String house, String? status, int page) async {
    final result = await dio.get(
      '/houses/$house/failed-events',
      queryParameters: {'page': page, 'status': ?status},
    );
    return FailedEventPage.fromJson(Map<String, dynamic>.from(result.data));
  }

  Future<void> replay(String house, String id) async {
    await dio.post('/houses/$house/failed-events/$id/replay');
  }
}

final failedEventRepositoryProvider = Provider(
  (ref) => FailedEventRepository(ref.watch(dioProvider)),
);
final failedEventsProvider = FutureProvider.autoDispose
    .family<FailedEventPage, ({String house, String? status, int page})>(
      (ref, key) => ref
          .watch(failedEventRepositoryProvider)
          .list(key.house, key.status, key.page),
    );
