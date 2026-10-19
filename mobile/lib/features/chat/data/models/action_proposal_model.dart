enum ProposalType {
  choreSwap,
  urgentEvent,
  seasonApproval;

  static ProposalType fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'CHORE_SWAP':
      case '0':
        return ProposalType.choreSwap;
      case 'URGENT_EVENT':
      case '1':
        return ProposalType.urgentEvent;
      case 'SEASON_APPROVAL':
      case '2':
        return ProposalType.seasonApproval;
      default:
        return ProposalType.choreSwap;
    }
  }

  String toBackendString() {
    switch (this) {
      case ProposalType.choreSwap:
        return 'CHORE_SWAP';
      case ProposalType.urgentEvent:
        return 'URGENT_EVENT';
      case ProposalType.seasonApproval:
        return 'SEASON_APPROVAL';
    }
  }
}

enum ProposalStatus {
  pending,
  approved,
  rejected,
  cancelled;

  static ProposalStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'PENDING':
      case '0':
        return ProposalStatus.pending;
      case 'APPROVED':
      case '1':
        return ProposalStatus.approved;
      case 'REJECTED':
      case '2':
        return ProposalStatus.rejected;
      case 'CANCELLED':
      case '3':
        return ProposalStatus.cancelled;
      default:
        return ProposalStatus.pending;
    }
  }
}

enum ProposalConfirmationStatus {
  pending,
  confirmed,
  rejected;

  static ProposalConfirmationStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'PENDING':
      case '0':
        return ProposalConfirmationStatus.pending;
      case 'CONFIRMED':
      case '1':
        return ProposalConfirmationStatus.confirmed;
      case 'REJECTED':
      case '2':
        return ProposalConfirmationStatus.rejected;
      default:
        return ProposalConfirmationStatus.pending;
    }
  }

  String toBackendString() {
    switch (this) {
      case ProposalConfirmationStatus.confirmed:
        return 'CONFIRMED';
      case ProposalConfirmationStatus.rejected:
        return 'REJECTED';
      default:
        return 'PENDING';
    }
  }
}

class ProposalConfirmationModel {
  final String id;
  final String targetUserId;
  final ProposalConfirmationStatus status;
  final String? reason;
  final DateTime? respondedAt;

  const ProposalConfirmationModel({
    required this.id,
    required this.targetUserId,
    required this.status,
    this.reason,
    this.respondedAt,
  });

  factory ProposalConfirmationModel.fromJson(Map<String, dynamic> json) {
    return ProposalConfirmationModel(
      id: json['id']?.toString() ?? '',
      targetUserId: json['targetUserId']?.toString() ?? '',
      status: ProposalConfirmationStatus.fromString(json['status']?.toString()),
      reason: json['reason'] as String?,
      respondedAt: json['respondedAt'] != null
          ? DateTime.tryParse(json['respondedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'targetUserId': targetUserId,
    'status': status.toBackendString(),
    'reason': reason,
    'respondedAt': respondedAt?.toIso8601String(),
  };
}

class ActionProposalModel {
  final String id;
  final String houseId;
  final String roomId;
  final String creatorId;
  final ProposalType type;
  final ProposalStatus status;
  final String title;
  final String description;
  final String payloadJson;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final List<ProposalConfirmationModel> confirmations;

  const ActionProposalModel({
    required this.id,
    required this.houseId,
    required this.roomId,
    required this.creatorId,
    required this.type,
    required this.status,
    required this.title,
    required this.description,
    required this.payloadJson,
    required this.createdAt,
    this.expiresAt,
    this.confirmations = const [],
  });

  bool get isCompleted =>
      status == ProposalStatus.approved ||
      status == ProposalStatus.rejected ||
      status == ProposalStatus.cancelled;

  bool isTarget(String userId) =>
      confirmations.any((c) => c.targetUserId == userId);

  bool hasUserConfirmed(String userId) => confirmations.any(
      (c) => c.targetUserId == userId && c.status == ProposalConfirmationStatus.confirmed);

  bool hasUserResponded(String userId) => confirmations.any(
      (c) => c.targetUserId == userId && c.status != ProposalConfirmationStatus.pending);

  ProposalConfirmationModel? confirmationFor(String userId) {
    try {
      return confirmations.firstWhere((c) => c.targetUserId == userId);
    } catch (_) {
      return null;
    }
  }

  factory ActionProposalModel.fromJson(Map<String, dynamic> json) {
    final confList = json['confirmations'];
    final List<ProposalConfirmationModel> parsedConfirmations = [];
    if (confList is List) {
      for (final item in confList) {
        if (item is Map<String, dynamic>) {
          parsedConfirmations.add(ProposalConfirmationModel.fromJson(item));
        } else if (item is Map) {
          parsedConfirmations.add(
              ProposalConfirmationModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return ActionProposalModel(
      id: json['id']?.toString() ?? '',
      houseId: json['houseId']?.toString() ?? '',
      roomId: json['roomId']?.toString() ?? '',
      creatorId: json['creatorId']?.toString() ?? '',
      type: ProposalType.fromString(json['type']?.toString()),
      status: ProposalStatus.fromString(json['status']?.toString()),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      payloadJson: json['payloadJson']?.toString() ?? '{}',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      confirmations: parsedConfirmations,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'houseId': houseId,
    'roomId': roomId,
    'creatorId': creatorId,
    'type': type.toBackendString(),
    'status': status.name.toUpperCase(),
    'title': title,
    'description': description,
    'payloadJson': payloadJson,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt?.toIso8601String(),
    'confirmations': confirmations.map((c) => c.toJson()).toList(),
  };
}
