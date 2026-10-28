import 'package:flutter/material.dart';

import '../../domain/repositories/supplies_repository.dart';
import 'orders_screen.dart';

class SuppliesCatalogScreen extends StatelessWidget {
  const SuppliesCatalogScreen({required this.houseId, this.aiDraft, super.key});
  final String houseId;
  final SupplyData? aiDraft;
  @override
  Widget build(BuildContext context) =>
      OrdersScreen(houseId: houseId, aiDraft: aiDraft);
}
