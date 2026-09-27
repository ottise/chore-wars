import '../entities/payment_obligation.dart';

abstract interface class PaymentRepository {
  Future<List<PaymentObligation>> getPayments(String houseId);
  Future<PaymentObligation> getPayment({required String houseId, required String paymentId});
  Future<void> settlePayment({required String houseId, required String paymentId});
}