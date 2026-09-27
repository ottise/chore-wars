// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bounty_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BountyModel _$BountyModelFromJson(Map<String, dynamic> json) => _BountyModel(
  id: json['id'] as String,
  choreOccurrenceId: json['choreOccurrenceId'] as String,
  choreName: json['choreName'] as String,
  postedByUserId: json['postedByUserId'] as String,
  postedByDisplayName: json['postedByDisplayName'] as String,
  amount: (json['amount'] as num).toDouble(),
  status: bountyStatusFromJson(json['status']),
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  newAssigneeDisplayName: json['newAssigneeDisplayName'] as String?,
  forcedCompensationAmount: (json['forcedCompensationAmount'] as num?)
      ?.toDouble(),
);

Map<String, dynamic> _$BountyModelToJson(_BountyModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'choreOccurrenceId': instance.choreOccurrenceId,
      'choreName': instance.choreName,
      'postedByUserId': instance.postedByUserId,
      'postedByDisplayName': instance.postedByDisplayName,
      'amount': instance.amount,
      'status': _$BountyStatusEnumMap[instance.status]!,
      'expiresAt': instance.expiresAt.toIso8601String(),
      'newAssigneeDisplayName': instance.newAssigneeDisplayName,
      'forcedCompensationAmount': instance.forcedCompensationAmount,
    };

const _$BountyStatusEnumMap = {
  BountyStatus.open: 'open',
  BountyStatus.claimed: 'claimed',
  BountyStatus.completed: 'completed',
  BountyStatus.expired: 'expired',
  BountyStatus.cancelled: 'cancelled',
  BountyStatus.unknown: 'unknown',
};
