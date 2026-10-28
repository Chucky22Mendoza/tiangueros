import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/cash_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/reports_repository.dart';
import '../repositories/sales_repository.dart';
import '../repositories/settings_repository.dart';
import '../features/backup/data/backup_service.dart';
import '../features/backup/data/product_transfer_service.dart';
import '../core/database/demo_data_service.dart';

/// Repositorios como providers.
///
/// Son stateless y conversión pura: `ref.watch` de uno re-resuelve a la
/// misma instancia, así que no provocan reconstrucciones innecesarias.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (Ref ref) => SettingsRepository(),
);

final productRepositoryProvider = Provider<ProductRepository>(
  (Ref ref) => ProductRepository(),
);

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (Ref ref) => InventoryRepository(),
);

final cashRepositoryProvider = Provider<CashRepository>(
  (Ref ref) => CashRepository(),
);

final salesRepositoryProvider = Provider<SalesRepository>(
  (Ref ref) => SalesRepository(ref.watch(inventoryRepositoryProvider)),
);

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (Ref ref) => ExpenseRepository(),
);

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (Ref ref) => ReportsRepository(),
);

final backupServiceProvider = Provider<BackupService>(
  (Ref ref) => BackupService(),
);

final productTransferServiceProvider = Provider<ProductTransferService>(
  (Ref ref) => ProductTransferService(),
);

final demoDataServiceProvider = Provider<DemoDataService>(
  (Ref ref) => DemoDataService(),
);
