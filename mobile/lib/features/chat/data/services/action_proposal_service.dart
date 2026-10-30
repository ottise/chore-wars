import 'package:dio/dio.dart';
import 'package:chore_wars/core/network/api_endpoints.dart';
import 'package:chore_wars/features/chat/data/models/action_proposal_model.dart';

class ActionProposalService {
  final Dio _dio;

  ActionProposalService(this._dio);

  Future<ActionProposalModel> createProposal({
    required String houseId,
    required ProposalType type,
    required String title,
    String description = '',
    String payloadJson = '{}',
    List<String> targetUserIds = const [],
    DateTime? expiresAt,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.houseProposals(houseId),
      data: {
        'type': type.toBackendString(),
        'title': title,
        'description': description,
        'payloadJson': payloadJson,
        'targetUserIds': targetUserIds,
        if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
      },
    );
    return ActionProposalModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ActionProposalModel> respondProposal({
    required String proposalId,
    required ProposalConfirmationStatus status,
    String? reason,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.respondProposal(proposalId),
      data: {'status': status.toBackendString(), 'reason': reason},
    );
    return ActionProposalModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<ActionProposalModel>> getAssistantInbox(String houseId) async {
    final response = await _dio.get('/v1/houses/$houseId/assistant/requests');
    return (response.data as List)
        .map(
          (p) =>
              ActionProposalModel.fromJson(Map<String, dynamic>.from(p as Map)),
        )
        .toList();
  }

  Future<List<ActionProposalModel>> getActiveProposals(String roomId) async {
    final response = await _dio.get(ApiEndpoints.activeProposals(roomId));
    final data = response.data;
    if (data is List) {
      return data
          .map(
            (item) => ActionProposalModel.fromJson(
              item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    }
    return [];
  }
}
