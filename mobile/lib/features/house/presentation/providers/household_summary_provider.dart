import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../supplies/domain/repositories/supplies_repository.dart';
import '../../../supplies/presentation/providers/supplies_providers.dart';

typedef HouseholdSummaryQuery = ({
  String house,
  String from,
  String to,
  String? season,
});
final householdSummaryProvider = FutureProvider.autoDispose
    .family<SupplyData, HouseholdSummaryQuery>(
      (ref, q) => ref
          .watch(suppliesRepositoryProvider)
          .get(
            '/houses/${q.house}/summary?from=${q.from}&to=${q.to}${q.season == null ? '' : '&seasonId=${q.season}'}',
          ),
      retry: (_, _) => null,
    );
