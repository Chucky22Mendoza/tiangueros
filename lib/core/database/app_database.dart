import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../models/app_settings.dart';
import '../../models/business_settings.dart';
import '../../models/cash_movement.dart';
import '../../models/category.dart';
import '../../models/daily_closing.dart';
import '../../models/expense.dart';
import '../../models/inventory_movement.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';
import '../../core/constants/app_constants.dart';

/// Acceso a Hive. Un solo punto de entrada a la base local.
///
/// La app es 100% offline: no hay red, ni sincronización, ni servidor.
/// Todo lo que se necesita para arrancar vive aquí.
abstract final class AppDatabase {
  const AppDatabase._();

  static bool _initialized = false;

  /// Abre Hive, registra adapters y crea las cajas.
  ///
  /// En tests se puede usar [openForTesting] con un directorio temporal.
  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter('tianguis_control');
    _registerAdapters();
    await _openBoxes();
    _initialized = true;
  }

  /// Variante para tests: usa un path explícito (típicamente temporal).
  static Future<void> openForTesting(String path) async {
    Hive.init(path);
    _registerAdapters();
    await _openBoxes();
    _initialized = true;
  }

  /// Registra cada adapter contra **su** tipo.
  ///
  /// Importante: `Hive.registerAdapter(adapter)` con la variable tipada como
  /// `dynamic` registra el adapter para `dynamic`, y entonces el primer
  /// adapter registrado gana para todas las escrituras: meter un `Product` en
  /// su caja acaba llamando a `BusinessSettingsAdapter.write` y revienta. Por
  /// eso cada registro lleva su tipo explícito.
  static void _registerAdapters() {
    _register<BusinessSettings>(BusinessSettingsAdapter());
    _register<AppSettings>(AppSettingsAdapter());
    _register<Category>(CategoryAdapter());
    _register<Product>(ProductAdapter());
    _register<Sale>(SaleAdapter());
    _register<SaleItem>(SaleItemAdapter());
    _register<InventoryMovement>(InventoryMovementAdapter());
    _register<Expense>(ExpenseAdapter());
    _register<CashMovement>(CashMovementAdapter());
    _register<DailyClosing>(DailyClosingAdapter());
  }

  static void _register<T>(TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter<T>(adapter);
    }
  }

  static Future<void> _openBoxes() async {
    await Future.wait<void>(<Future<void>>[
      Hive.openBox<BusinessSettings>(AppConstants.boxBusinessSettings),
      Hive.openBox<AppSettings>(AppConstants.boxAppSettings),
      Hive.openBox<Category>(AppConstants.boxCategories),
      Hive.openBox<Product>(AppConstants.boxProducts),
      Hive.openBox<Sale>(AppConstants.boxSales),
      Hive.openBox<InventoryMovement>(AppConstants.boxInventoryMovements),
      Hive.openBox<Expense>(AppConstants.boxExpenses),
      Hive.openBox<CashMovement>(AppConstants.boxCashMovements),
      Hive.openBox<DailyClosing>(AppConstants.boxDailyClosings),
      Hive.openBox<dynamic>(AppConstants.boxMeta),
    ]);
  }

  // --- Cajas tipadas ---
  static Box<BusinessSettings> get business =>
      Hive.box<BusinessSettings>(AppConstants.boxBusinessSettings);

  static Box<AppSettings> get settings =>
      Hive.box<AppSettings>(AppConstants.boxAppSettings);

  static Box<Category> get categories =>
      Hive.box<Category>(AppConstants.boxCategories);

  static Box<Product> get products =>
      Hive.box<Product>(AppConstants.boxProducts);

  static Box<Sale> get sales => Hive.box<Sale>(AppConstants.boxSales);

  static Box<InventoryMovement> get movements =>
      Hive.box<InventoryMovement>(AppConstants.boxInventoryMovements);

  static Box<Expense> get expenses =>
      Hive.box<Expense>(AppConstants.boxExpenses);

  static Box<CashMovement> get cash =>
      Hive.box<CashMovement>(AppConstants.boxCashMovements);

  static Box<DailyClosing> get closings =>
      Hive.box<DailyClosing>(AppConstants.boxDailyClosings);

  /// Caja clave-valor para folios y flags (no es un modelo Hive).
  static Box<dynamic> get meta => Hive.box<dynamic>(AppConstants.boxMeta);

  // --- Singletons de ajustes (clave fija dentro de su caja) ---
  static const String businessKey = 'current';
  static const String settingsKey = 'current';

  /// Si el usuario ya pasó la configuración inicial (§7).
  static bool get onboardingDone =>
      meta.get(AppConstants.keyOnboardingDone, defaultValue: false) as bool;

  static Future<void> setOnboardingDone(bool value) =>
      meta.put(AppConstants.keyOnboardingDone, value);

  /// Cierra todo. Sólo para tests.
  static Future<void> close() async {
    await Hive.close();
    _initialized = false;
  }

  /// Borra TODOS los datos del dispositivo (§46). Irreversible.
  /// Vacía todas las cajas y las deja abiertas otra vez.
  ///
  /// Hace falta reabrirlas porque los providers ya tienen referencias a las
  /// cajas viejas: si sólo se limpiaran, la app quedaría inservible justo
  /// después de borrar.
  static Future<void> wipeAll() async {
    await business.clear();
    await settings.clear();
    await categories.clear();
    await products.clear();
    await sales.clear();
    await movements.clear();
    await expenses.clear();
    await cash.clear();
    await closings.clear();
    await meta.clear();

    await Hive.close();
    await _openBoxes();
  }
}
