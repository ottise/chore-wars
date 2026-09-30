import 'package:dio/dio.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/payment_obligation.dart';
import '../../domain/repositories/payment_repository.dart';
import '../models/payment_obligation_model.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  final Dio dio;

  const PaymentRepositoryImpl(this.dio);

  @override
  Future<List<PaymentObligation>> getPayments(String houseId) async {
    final response = await dio.get(ApiEndpoints.payments(houseId));
    final data = response.data;
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().map(PaymentObligationModel.fromJson).toList();
  }

  @override
  Future<PaymentObligation> getPayment({required String houseId, required String paymentId}) async {
    final response = await dio.get(ApiEndpoints.paymentDetails(houseId, paymentId));
    return PaymentObligationModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> settlePayment({required String houseId, required String paymentId}) async {
    await dio.post(ApiEndpoints.settlePayment(houseId, paymentId));
  }
}