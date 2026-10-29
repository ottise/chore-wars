import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../supplies/domain/repositories/supplies_repository.dart';
import '../../../supplies/presentation/providers/supplies_providers.dart';

typedef HistoryQuery = ({
  String house,
  String from,
  String to,
  String direction,
  int page,
});
final paymentHistoryProvider = FutureProvider.autoDispose
    .family<SupplyData, HistoryQuery>(
      (ref, query) => ref
          .watch(suppliesRepositoryProvider)
          .get(
            '/houses/${query.house}/me/payment-history?from=${query.from}&to=${query.to}&direction=${query.direction}&page=${query.page}&pageSize=30',
          ),
      retry: (_, _) => null,
    );
