// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bounty_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BountyModel {

 String get id; String get choreOccurrenceId; String get choreName; String get postedByUserId; String get postedByDisplayName; double get amount;@JsonKey(fromJson: bountyStatusFromJson) BountyStatus get status; DateTime get expiresAt; String? get newAssigneeDisplayName; double? get forcedCompensationAmount;
/// Create a copy of BountyModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BountyModelCopyWith<BountyModel> get copyWith => _$BountyModelCopyWithImpl<BountyModel>(this as BountyModel, _$identity);

  /// Serializes this BountyModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BountyModel;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BountyModel&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.choreOccurrenceId, _this.choreOccurrenceId) || other.choreOccurrenceId == _this.choreOccurrenceId)&&(identical(other.choreName, _this.choreName) || other.choreName == _this.choreName)&&(identical(other.postedByUserId, _this.postedByUserId) || other.postedByUserId == _this.postedByUserId)&&(identical(other.postedByDisplayName, _this.postedByDisplayName) || other.postedByDisplayName == _this.postedByDisplayName)&&(identical(other.amount, _this.amount) || other.amount == _this.amount)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.expiresAt, _this.expiresAt) || other.expiresAt == _this.expiresAt)&&(identical(other.newAssigneeDisplayName, _this.newAssigneeDisplayName) || other.newAssigneeDisplayName == _this.newAssigneeDisplayName)&&(identical(other.forcedCompensationAmount, _this.forcedCompensationAmount) || other.forcedCompensationAmount == _this.forcedCompensationAmount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BountyModel;
  return Object.hash(runtimeType,_this.id,_this.choreOccurrenceId,_this.choreName,_this.postedByUserId,_this.postedByDisplayName,_this.amount,_this.status,_this.expiresAt,_this.newAssigneeDisplayName,_this.forcedCompensationAmount);
}

@override
String toString() {
  final _this = this as BountyModel;
  return 'BountyModel(id: ${_this.id}, choreOccurrenceId: ${_this.choreOccurrenceId}, choreName: ${_this.choreName}, postedByUserId: ${_this.postedByUserId}, postedByDisplayName: ${_this.postedByDisplayName}, amount: ${_this.amount}, status: ${_this.status}, expiresAt: ${_this.expiresAt}, newAssigneeDisplayName: ${_this.newAssigneeDisplayName}, forcedCompensationAmount: ${_this.forcedCompensationAmount})';
}


}

/// @nodoc
abstract mixin class $BountyModelCopyWith<$Res>  {
  factory $BountyModelCopyWith(BountyModel value, $Res Function(BountyModel) _then) = _$BountyModelCopyWithImpl;
@useResult
$Res call({
 String id, String choreOccurrenceId, String choreName, String postedByUserId, String postedByDisplayName, double amount,@JsonKey(fromJson: bountyStatusFromJson) BountyStatus status, DateTime expiresAt, String? newAssigneeDisplayName, double? forcedCompensationAmount
});




}
/// @nodoc
class _$BountyModelCopyWithImpl<$Res>
    implements $BountyModelCopyWith<$Res> {
  _$BountyModelCopyWithImpl(this._self, this._then);

  final BountyModel _self;
  final $Res Function(BountyModel) _then;

/// Create a copy of BountyModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? choreOccurrenceId = null,Object? choreName = null,Object? postedByUserId = null,Object? postedByDisplayName = null,Object? amount = null,Object? status = null,Object? expiresAt = null,Object? newAssigneeDisplayName = freezed,Object? forcedCompensationAmount = freezed,}) {
  return _then(BountyModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,choreOccurrenceId: null == choreOccurrenceId ? _self.choreOccurrenceId : choreOccurrenceId // ignore: cast_nullable_to_non_nullable
as String,choreName: null == choreName ? _self.choreName : choreName // ignore: cast_nullable_to_non_nullable
as String,postedByUserId: null == postedByUserId ? _self.postedByUserId : postedByUserId // ignore: cast_nullable_to_non_nullable
as String,postedByDisplayName: null == postedByDisplayName ? _self.postedByDisplayName : postedByDisplayName // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BountyStatus,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,newAssigneeDisplayName: freezed == newAssigneeDisplayName ? _self.newAssigneeDisplayName : newAssigneeDisplayName // ignore: cast_nullable_to_non_nullable
as String?,forcedCompensationAmount: freezed == forcedCompensationAmount ? _self.forcedCompensationAmount : forcedCompensationAmount // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [BountyModel].
extension BountyModelPatterns on BountyModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BountyModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BountyModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BountyModel value)  $default,){
final _that = this;
switch (_that) {
case _BountyModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BountyModel value)?  $default,){
final _that = this;
switch (_that) {
case _BountyModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String choreOccurrenceId,  String choreName,  String postedByUserId,  String postedByDisplayName,  double amount, @JsonKey(fromJson: bountyStatusFromJson)  BountyStatus status,  DateTime expiresAt,  String? newAssigneeDisplayName,  double? forcedCompensationAmount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BountyModel() when $default != null:
return $default(_that.id,_that.choreOccurrenceId,_that.choreName,_that.postedByUserId,_that.postedByDisplayName,_that.amount,_that.status,_that.expiresAt,_that.newAssigneeDisplayName,_that.forcedCompensationAmount);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String choreOccurrenceId,  String choreName,  String postedByUserId,  String postedByDisplayName,  double amount, @JsonKey(fromJson: bountyStatusFromJson)  BountyStatus status,  DateTime expiresAt,  String? newAssigneeDisplayName,  double? forcedCompensationAmount)  $default,) {final _that = this;
switch (_that) {
case _BountyModel():
return $default(_that.id,_that.choreOccurrenceId,_that.choreName,_that.postedByUserId,_that.postedByDisplayName,_that.amount,_that.status,_that.expiresAt,_that.newAssigneeDisplayName,_that.forcedCompensationAmount);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String choreOccurrenceId,  String choreName,  String postedByUserId,  String postedByDisplayName,  double amount, @JsonKey(fromJson: bountyStatusFromJson)  BountyStatus status,  DateTime expiresAt,  String? newAssigneeDisplayName,  double? forcedCompensationAmount)?  $default,) {final _that = this;
switch (_that) {
case _BountyModel() when $default != null:
return $default(_that.id,_that.choreOccurrenceId,_that.choreName,_that.postedByUserId,_that.postedByDisplayName,_that.amount,_that.status,_that.expiresAt,_that.newAssigneeDisplayName,_that.forcedCompensationAmount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BountyModel extends BountyModel {
  const _BountyModel({required this.id, required this.choreOccurrenceId, required this.choreName, required this.postedByUserId, required this.postedByDisplayName, required this.amount, @JsonKey(fromJson: bountyStatusFromJson) required this.status, required this.expiresAt, this.newAssigneeDisplayName, this.forcedCompensationAmount}): super._();
  factory _BountyModel.fromJson(Map<String, dynamic> json) => _$BountyModelFromJson(json);

@override final  String id;
@override final  String choreOccurrenceId;
@override final  String choreName;
@override final  String postedByUserId;
@override final  String postedByDisplayName;
@override final  double amount;
@override@JsonKey(fromJson: bountyStatusFromJson) final  BountyStatus status;
@override final  DateTime expiresAt;
@override final  String? newAssigneeDisplayName;
@override final  double? forcedCompensationAmount;

/// Create a copy of BountyModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BountyModelCopyWith<_BountyModel> get copyWith => __$BountyModelCopyWithImpl<_BountyModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BountyModelToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BountyModel&&(identical(other.id, id) || other.id == id)&&(identical(other.choreOccurrenceId, choreOccurrenceId) || other.choreOccurrenceId == choreOccurrenceId)&&(identical(other.choreName, choreName) || other.choreName == choreName)&&(identical(other.postedByUserId, postedByUserId) || other.postedByUserId == postedByUserId)&&(identical(other.postedByDisplayName, postedByDisplayName) || other.postedByDisplayName == postedByDisplayName)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.status, status) || other.status == status)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.newAssigneeDisplayName, newAssigneeDisplayName) || other.newAssigneeDisplayName == newAssigneeDisplayName)&&(identical(other.forcedCompensationAmount, forcedCompensationAmount) || other.forcedCompensationAmount == forcedCompensationAmount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,choreOccurrenceId,choreName,postedByUserId,postedByDisplayName,amount,status,expiresAt,newAssigneeDisplayName,forcedCompensationAmount);
}

@override
String toString() {
    return 'BountyModel(id: $id, choreOccurrenceId: $choreOccurrenceId, choreName: $choreName, postedByUserId: $postedByUserId, postedByDisplayName: $postedByDisplayName, amount: $amount, status: $status, expiresAt: $expiresAt, newAssigneeDisplayName: $newAssigneeDisplayName, forcedCompensationAmount: $forcedCompensationAmount)';
}


}

/// @nodoc
abstract mixin class _$BountyModelCopyWith<$Res> implements $BountyModelCopyWith<$Res> {
  factory _$BountyModelCopyWith(_BountyModel value, $Res Function(_BountyModel) _then) = __$BountyModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String choreOccurrenceId, String choreName, String postedByUserId, String postedByDisplayName, double amount,@JsonKey(fromJson: bountyStatusFromJson) BountyStatus status, DateTime expiresAt, String? newAssigneeDisplayName, double? forcedCompensationAmount
});




}
/// @nodoc
class __$BountyModelCopyWithImpl<$Res>
    implements _$BountyModelCopyWith<$Res> {
  __$BountyModelCopyWithImpl(this._self, this._then);

  final _BountyModel _self;
  final $Res Function(_BountyModel) _then;

/// Create a copy of BountyModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? choreOccurrenceId = null,Object? choreName = null,Object? postedByUserId = null,Object? postedByDisplayName = null,Object? amount = null,Object? status = null,Object? expiresAt = null,Object? newAssigneeDisplayName = freezed,Object? forcedCompensationAmount = freezed,}) {
  return _then(_BountyModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,choreOccurrenceId: null == choreOccurrenceId ? _self.choreOccurrenceId : choreOccurrenceId // ignore: cast_nullable_to_non_nullable
as String,choreName: null == choreName ? _self.choreName : choreName // ignore: cast_nullable_to_non_nullable
as String,postedByUserId: null == postedByUserId ? _self.postedByUserId : postedByUserId // ignore: cast_nullable_to_non_nullable
as String,postedByDisplayName: null == postedByDisplayName ? _self.postedByDisplayName : postedByDisplayName // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as BountyStatus,expiresAt: null == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime,newAssigneeDisplayName: freezed == newAssigneeDisplayName ? _self.newAssigneeDisplayName : newAssigneeDisplayName // ignore: cast_nullable_to_non_nullable
as String?,forcedCompensationAmount: freezed == forcedCompensationAmount ? _self.forcedCompensationAmount : forcedCompensationAmount // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
