/// Constantes de dominio de Tianguis Control.
abstract final class AppConstants {
  AppConstants._();

  static const String appName = 'Tianguis Control';
  static const String appTagline = 'Tu puesto, bajo control.';
  static const String appVersion = '1.0.0';

  /// Versión del formato de respaldo. Incrementar ante cambios incompatibles.
  static const int backupVersion = 1;

  // --- Defaults de configuración inicial (§8) ---
  static const String defaultBusinessName = 'Mi Tianguis';
  static const String defaultOwnerName = 'Encargado';

  // --- Defaults de preferencias (§36) ---
  static const String defaultCurrency = 'MXN';
  static const int defaultMinStock = 5;
  static const String defaultSalePrefix = 'V';

  /// Cifras del folio de venta: V-000001 (§38).
  static const int saleFolioPadding = 6;

  // --- Nombres de cajas Hive ---
  static const String boxBusinessSettings = 'business_settings';
  static const String boxAppSettings = 'app_settings';
  static const String boxCategories = 'categories';
  static const String boxProducts = 'products';
  static const String boxSales = 'sales';
  static const String boxInventoryMovements = 'inventory_movements';
  static const String boxExpenses = 'expenses';
  static const String boxCashMovements = 'cash_movements';
  static const String boxDailyClosings = 'daily_closings';
  static const String boxMeta = 'meta';

  /// Claves dentro de `meta` que no son modelos Hive.
  static const String keyNextFolio = 'next_folio';
  static const String keyOnboardingDone = 'onboarding_done';

  /// Categorías de gasto por defecto (§23).
  static const List<String> defaultExpenseCategories = <String>[
    'Cuota del tianguis',
    'Transporte',
    'Comida',
    'Bolsas',
    'Mercancía',
    'Publicidad',
    'Otro',
  ];
}
