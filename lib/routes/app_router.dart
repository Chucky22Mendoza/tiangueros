import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/database/app_database.dart';

import '../features/cash/presentation/cash_screen.dart';
import '../features/cash/presentation/closing_detail_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/expenses/presentation/expenses_screen.dart';
import '../features/inventory/presentation/inventory_screen.dart';
import '../features/inventory/presentation/movement_detail_screen.dart';
import '../features/inventory/presentation/stock_adjust_screen.dart';
import '../features/more/presentation/more_menu_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/products/presentation/categories_screen.dart';
import '../features/products/presentation/product_detail_screen.dart';
import '../features/products/presentation/product_form_screen.dart';
import '../features/products/presentation/products_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/sales/presentation/new_sale_screen.dart';
import '../features/sales/presentation/quick_sale_screen.dart';
import '../features/sales/presentation/sale_detail_screen.dart';
import '../features/sales/presentation/sales_history_screen.dart';
import '../features/settings/presentation/data_settings_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'app_routes.dart';

/// Enrutado de la app.
///
/// **Nueva venta vive fuera del shell**, a pantalla completa y por encima de
/// la barra de navegación: cuando estás atendiendo a un cliente no quieres un
/// `bottomNavigationBar` que tequite espacio ni un tab que pueda cambiar por
/// error. Al terminar, el flujo vuelve al historial de ventas.
/// Crea el enrutado completo.
///
/// Se expone como fábrica y no sólo como instancia global para que los tests
/// puedan levantar su propio router: un `GoRouter` compartido entre tests
/// arrastra el estado de navegación del caso anterior.
GoRouter createAppRouter() {
  final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'root',
  );
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: ShellRoutes.dashboard,
    redirect: (BuildContext context, GoRouterState state) {
      // Se lee el flag de Hive y no un provider: `redirect` se evalúa en cada
      // navegación, incluso antes de que exista un `BuildContext` de widget.
      final bool done = AppDatabase.onboardingDone;
      final bool atOnboarding = state.matchedLocation == AppRoutes.onboarding;

      if (!done && !atOnboarding) return AppRoutes.onboarding;
      // Ya configurado y el usuario volvió atrás hasta la bienvenida: se sale.
      if (done && atOnboarding) return ShellRoutes.dashboard;
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        name: AppRoutes.onboarding,
        path: AppRoutes.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),

      // --- Shell: cinco pestañas (§42) ---
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell shell,
            ) => AppShell(shell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                name: ShellRoutes.dashboard,
                path: ShellRoutes.dashboard,
                builder: (BuildContext context, GoRouterState state) =>
                    const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                name: ShellRoutes.sales,
                path: ShellRoutes.sales,
                builder: (BuildContext context, GoRouterState state) =>
                    const SalesHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                name: ShellRoutes.products,
                path: ShellRoutes.products,
                builder: (BuildContext context, GoRouterState state) =>
                    const ProductsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                name: ShellRoutes.reports,
                path: ShellRoutes.reports,
                builder: (BuildContext context, GoRouterState state) =>
                    const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                name: ShellRoutes.more,
                path: ShellRoutes.more,
                builder: (BuildContext context, GoRouterState state) =>
                    const MoreMenuScreen(),
              ),
            ],
          ),
        ],
      ),

      // --- Ventas: fuera del shell ---
      GoRoute(
        name: AppRoutes.newSale,
        path: AppRoutes.newSale,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            const MaterialPage<void>(
              fullscreenDialog: true,
              child: NewSaleScreen(),
            ),
      ),
      GoRoute(
        name: AppRoutes.quickSale,
        path: AppRoutes.quickSale,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const QuickSaleScreen(),
      ),
      GoRoute(
        name: AppRoutes.saleDetail,
        path: AppRoutes.saleDetail,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            SaleDetailScreen(saleId: _idOf(state)),
      ),

      // --- Productos ---
      GoRoute(
        name: AppRoutes.productForm,
        path: AppRoutes.productForm,
        builder: (BuildContext context, GoRouterState state) =>
            ProductFormScreen(productId: _optionalIdOf(state)),
      ),
      GoRoute(
        name: AppRoutes.productDetail,
        path: AppRoutes.productDetail,
        builder: (BuildContext context, GoRouterState state) =>
            ProductDetailScreen(productId: _idOf(state)),
      ),
      GoRoute(
        name: AppRoutes.categoryForm,
        path: AppRoutes.categoryForm,
        builder: (BuildContext context, GoRouterState state) =>
            const CategoriesScreen(),
      ),

      // --- Inventario ---
      GoRoute(
        name: AppRoutes.stockEntry,
        path: AppRoutes.stockEntry,
        builder: (BuildContext context, GoRouterState state) =>
            StockEntryScreen(presetProductId: _optionalIdOf(state)),
      ),
      GoRoute(
        name: AppRoutes.stockAdjust,
        path: AppRoutes.stockAdjust,
        builder: (BuildContext context, GoRouterState state) =>
            StockAdjustScreen(productId: _idOf(state)),
      ),
      GoRoute(
        name: AppRoutes.movementDetail,
        path: AppRoutes.movementDetail,
        builder: (BuildContext context, GoRouterState state) =>
            MovementDetailScreen(movementId: _idOf(state)),
      ),

      // --- Gastos ---
      GoRoute(
        name: AppRoutes.expenses,
        path: AppRoutes.expenses,
        builder: (BuildContext context, GoRouterState state) =>
            const ExpensesScreen(),
      ),
      GoRoute(
        name: AppRoutes.expenseForm,
        path: AppRoutes.expenseForm,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const ExpenseFormScreen(),
      ),

      // --- Caja y reportes ---
      GoRoute(
        name: AppRoutes.cash,
        path: AppRoutes.cash,
        builder: (BuildContext context, GoRouterState state) =>
            const CashScreen(),
      ),
      GoRoute(
        name: AppRoutes.closingDetail,
        path: AppRoutes.closingDetail,
        builder: (BuildContext context, GoRouterState state) =>
            ClosingDetailScreen(closingId: _idOf(state)),
      ),
      // --- Configuración ---
      GoRoute(
        name: AppRoutes.settings,
        path: AppRoutes.settings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
      GoRoute(
        name: AppRoutes.businessSettings,
        path: AppRoutes.businessSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const BusinessSettingsScreen(),
      ),
      GoRoute(
        name: AppRoutes.preferencesSettings,
        path: AppRoutes.preferencesSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const PreferencesScreen(),
      ),
      GoRoute(
        name: AppRoutes.dataSettings,
        path: AppRoutes.dataSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const DataSettingsScreen(),
      ),
      GoRoute(
        name: AppRoutes.aboutSettings,
        path: AppRoutes.aboutSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const AboutScreen(),
      ),
    ],
  );
}

/// Router de la app. `main.dart` usa éste; los tests, [createAppRouter].
final GoRouter appRouter = createAppRouter();

/// Id de la entidad que se abre. Viaja en `extra` y lo pone quien navega
/// (`context.pushNamed(ruta, extra: id)`).
///
/// Si falta, se pasa cadena vacía: las pantallas de detalle muestran su
/// estado "ya no existe" en vez de reventar.
/// Id obligatorio: cadena vacía si no llega `extra`.
///
/// Las pantallas de detalle/carga necesitan un id sí o sí y con `''` muestran su
/// estado de "no encontrado". Para las pantallas que distinguen alta de
/// edición hay que usar [_optionalIdOf].
String _idOf(GoRouterState state) {
  final Object? extra = state.extra;
  return extra is String ? extra : '';
}

/// Id opcional: `null` cuando no llega `extra`.
///
/// `ProductFormScreen` decide alta vs. edición con `productId != null`, así que
/// mandar `''` en vez de `null` lo ponía a editar un producto inexistente.
String? _optionalIdOf(GoRouterState state) {
  final Object? extra = state.extra;
  return extra is String && extra.isNotEmpty ? extra : null;
}

/// Shell con barra inferior de cinco destinos (§42).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sin FAB aquí a propósito: cada pantalla define el suyo y dos botones
    // flotantes se solaparían en las cinco pestañas. El dashboard sí trae su
    // acción grande de "Nueva venta" (§11).
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (int index) => shell.goBranch(
          index,
          // Volver a tocar la pestaña activa la sube, como en Android.
          initialLocation: index == shell.currentIndex,
        ),
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Ventas',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Productos',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Reportes',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}
