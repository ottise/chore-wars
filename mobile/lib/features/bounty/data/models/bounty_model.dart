import '../../domain/entities/bounty.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'bounty_model.freezed.dart';
part 'bounty_model.g.dart';

@Freezed(fromJson: true, toJson: true)
abstract class BountyModel with _$BountyModel {
  const BountyModel._();

  const factory BountyModel({
    required String id,
    required String choreOccurrenceId,
    required String choreName,
    required String postedByUserId,
    required String postedByDisplayName,
    required double amount,
    @JsonKey(fromJson: bountyStatusFromJson) required BountyStatus status,
    required DateTime expiresAt,
    String? newAssigneeDisplayName,
    double? forcedCompensationAmount,
  }) = _BountyModel;

  factory BountyModel.fromJson(Map<String, dynamic> json) {
    return _$BountyModelFromJson(json);
  }

  Bounty toEntity() => Bounty(
        id: id,
        choreOccurrenceId: choreOccurrenceId,
        choreName: choreName,
        postedByUserId: postedByUserId,
        postedByDisplayName: postedByDisplayName,
        amount: amount,
        status: status,
        expiresAt: expiresAt.toLocal(),
        newAssigneeDisplayName: newAssigneeDisplayName,
        forcedCompensationAmount: forcedCompensationAmount,
      );
}

BountyStatus bountyStatusFromJson(Object? value) {
  final status = value.toString().toLowerCase();
  if (status == 'open' || status == '0') return BountyStatus.open;
  if (status == 'claimed' || status == '1') return BountyStatus.claimed;
  if (status == 'completed' || status == '2') return BountyStatus.completed;
  if (status == 'expired' || status == '3') return BountyStatus.expired;
  if (status == 'cancelled' || status == '4') return BountyStatus.cancelled;
  return BountyStatus.unknown;
}
