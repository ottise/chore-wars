import 'package:flutter/material.dart';

import 'payment_history_screen.dart';

// Compatibility entry point; payment actions now live in My Debts.
class PaymentObligationsScreen extends StatelessWidget {
  const PaymentObligationsScreen({required this.houseId, super.key});
  final String? houseId;
  @override
  Widget build(BuildContext context) => houseId == null || houseId!.isEmpty
      ? const Scaffold(
          body: Center(child: Text('Select a house to view payment history.')),
        )
      : PaymentHistoryScreen(houseId: houseId!);
}
