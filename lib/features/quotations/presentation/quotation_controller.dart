import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/business_database_provider.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../data/local_quotation_repository.dart';

final quotationRepositoryProvider = Provider<QuotationRepository>(
  (ref) => LocalQuotationRepository(ref.watch(businessDatabaseProvider)),
);
final quotationsProvider =
    FutureProvider.autoDispose<List<Map<String, Object?>>>((ref) async {
      final uid = ref.watch(inventoryUidProvider);
      if (uid == null) return [];
      return ref.watch(quotationRepositoryProvider).list(uid);
    });
