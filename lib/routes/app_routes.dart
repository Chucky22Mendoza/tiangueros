/// Rutas de la app.
///
/// Regla de navegación: el usuario está atendiendo clientes. Lo que más se usa
/// (Nueva venta) debe estar a un toque desde cualquier pantalla, y el flujo de
/// cobro nunca debe perderse en un stack profundo.
library;

/// Rutas del shell con bottom nav (§42).
abstract final class ShellRoutes {
  const ShellRoutes._();

  static const String dashboard = '/';
  static const String sales = '/ventas';
  static const String products = '/productos';
  static const String inventory = '/inventario';
  static const String reports = '/reportes';
  static const String more = '/mas';

  /// Destinos del bottom nav, en orden.
  static const List<String> tabs = <String>[
    dashboard,
    sales,
    products,
    reports,
    more,
  ];
}

/// Pantallas de segundo nivel: se abren sobre el shell o a pantalla completa.
abstract final class AppRoutes {
  const AppRoutes._();

  static const String onboarding = '/bienvenida';

  static const String newSale = '/venta/nueva';
  static const String quickSale = '/venta/rapida';
  static const String saleDetail = '/venta/detalle';

  static const String productForm = '/producto/formulario';
  static const String productDetail = '/producto/detalle';
  static const String categoryForm = '/categoria/formulario';

  static const String stockEntry = '/inventario/entrada';
  static const String stockAdjust = '/inventario/ajuste';
  static const String movementDetail = '/inventario/movimiento';

  static const String expenses = '/gastos';
  static const String expenseForm = '/gasto/formulario';

  static const String cash = '/caja';
  static const String closingDetail = '/caja/cierre/detalle';

  static const String settings = '/configuracion';
  static const String businessSettings = '/configuracion/negocio';
  static const String dataSettings = '/configuracion/datos';
  static const String preferencesSettings = '/configuracion/preferencias';
  static const String aboutSettings = '/configuracion/acerca-de';
}
