import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/payment_repository_impl.dart';
import '../../domain/entities/payment_obligation.dart';
import '../../domain/repositories/payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepositoryImpl(ref.watch(dioProvider));
});

final paymentListProvider = FutureProvider.autoDispose.family<List<PaymentObligation>, String>((ref, houseId) {
  return ref.watch(paymentRepositoryProvider).getPayments(houseId);
});