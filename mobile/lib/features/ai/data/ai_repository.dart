import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/session_provider.dart';
import '../../../core/network/api_client.dart';

typedef AiQuery = ({String house, String path});

class AiRepository {
  AiRepository(this.dio);
  final Dio dio;

  Future<Map<String, dynamic>> get(String house, String path) async {
    final response = await dio.get('/houses/$house/ai/$path');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> post(
    String house,
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await dio.post('/houses/$house/ai/$path', data: body);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> put(String house, String path, Map<String, dynamic> body) async {
    await dio.put('/houses/$house/ai/$path', data: body);
  }

  Future<bool> observe(
    String house,
    String request,
    String entity,
    String kind,
  ) async {
    try {
      final response = await dio.post(
        '/houses/$house/ai/observations',
        data: {'clientRequestId': request, 'entityId': entity, 'kind': kind},
      );
      return response.data is Map && (response.data as Map)['recorded'] == true;
    } on DioException {
      // Optional view telemetry must not interrupt the actual chore/bounty flow.
      return false;
    }
  }
}

final aiRepositoryProvider = Provider(
  (ref) => AiRepository(ref.watch(dioProvider)),
);
final aiSeasonsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, house) async {
      ref.watch(sessionEpochProvider);
      final response = await ref
          .watch(dioProvider)
          .get('/houses/$house/seasons');
      return (response.data as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
    });
final aiDataProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, AiQuery>((ref, query) {
      ref.watch(sessionEpochProvider);
      return ref.watch(aiRepositoryProvider).get(query.house, query.path);
    });
