import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:tianguis_control/core/constants/app_constants.dart';
import 'package:tianguis_control/core/database/app_database.dart';
import 'package:tianguis_control/core/theme/app_theme.dart';
import 'package:tianguis_control/features/sales/presentation/new_sale_screen.dart';
import 'package:tianguis_control/routes/app_router.dart';
import 'package:tianguis_control/routes/app_routes.dart';

import 'helpers.dart';

/// Smoke test del armazón: arranque, redirect de onboarding y navegación.
///
/// Usa [createAppRouter] y el mismo `MaterialApp.router` que `main.dart`, para
/// que un cambio de rutas o del redirect reviente aquí y no en el teléfono.
///
/// **Un solo test de widget** por archivo a propósito. El dashboard abre
/// suscripciones `box.watch()` vía `StreamProvider` y, dentro de un mismo
/// isolate de test, esas suscripciones dejan el isolate en un estado del que
/// ningún `testWidgets` posterior logra terminar. Por eso el caso del shell
/// (que monta el dashboard) va último y concentra todas sus aserciones.
void main() {
  /// Escribe en Hive dentro de `runAsync`.
  ///
  /// El cuerpo de un `testWidgets` corre en una zona de async falsa: una
  /// promesa de IO real (escribir en Hive) nunca se resuelve ahí y el test se
  /// queda colgado para siempre.
  Future<void> marcarOnboarding(WidgetTester tester, {required bool done}) async {
    await tester.runAsync(
      () => AppDatabase.meta.put(AppConstants.keyOnboardingDone, done),
    );
  }

  /// `pump` y no `pumpAndSettle`: los `StreamProvider` arrancan en estado
  /// `loading` y su `CircularProgressIndicator` nunca deja de girar, así que
  /// `pumpAndSettle` esperaría para siempre.
  Future<GoRouter> pumpApp(WidgetTester tester) async {
    final GoRouter router = createAppRouter();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pump();
    return router;
  }

  setUp(openTestDatabaseForWidgetTests);

  testWidgets('sin onboarding, arranca en la bienvenida y sin barra de tabs', (
    WidgetTester tester,
  ) async {
    await marcarOnboarding(tester, done: false);
    await pumpApp(tester);

    expect(find.text('Configura tu negocio'), findsOneWidget);
    expect(find.text('Tianguis Control'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('con onboarding, el shell muestra el inicio y sus cinco destinos', (
    WidgetTester tester,
  ) async {
    await marcarOnboarding(tester, done: true);
    final GoRouter router = await pumpApp(tester);

    // la bienvenida ya no aparece
    expect(find.text('Configura tu negocio'), findsNothing);
    expect(find.text('Hoy'), findsOneWidget);

    // barra inferior con los cinco destinos de §42
    final NavigationBar bar =
        tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 5);
    expect(bar.selectedIndex, 0);
    for (final String label in <String>[
      'Inicio',
      'Ventas',
      'Productos',
      'Reportes',
      'Más',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'falta la pestaña $label');
    }

    // Con la base vacía cada pestaña debe mostrar su estado vacío, no un
    // spinner eterno: `box.watch()` no emite valor inicial, y sin el primer
    // yield de los repos el StreamProvider se queda en `loading` para siempre.
    await tester.tap(find.text('Ventas'));
    // dos pumps: el primero procesa el tap, el segundo la emisión del stream
    // (el `async*` de los repos entrega su primer valor en un microtask)
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Todavía no tienes ventas.'), findsOneWidget);

    // cambiar de pestaña mueve la selección
    await tester.tap(find.text('Productos'));
    await tester.pump();
    await tester.pump();
    final NavigationBar afterTap =
        tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(afterTap.selectedIndex, 2);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Cada pantalla tiene su propio FAB: exactamente uno, no dos superpuestos.
    expect(
      find.byType(FloatingActionButton),
      findsOneWidget,
      reason: 'el shell no debe duplicar el FAB de la pantalla',
    );

    // La venta nueva se abre en el navigator raíz: queda por encima del shell,
    // que sigue montado debajo (por eso la barra aún está en el árbol, sólo
    // tapada). Lo que se comprueba es que la pantalla se abrió de verdad.
    //
    // `pushNamed` y no `go`: es la API que usa la app, y falla si al `GoRoute`
    // le falta `name` ("unknown route name"). Este test la cubre.
    router.pushNamed(AppRoutes.newSale);
    // dos pumps: el primero procesa la navegación, el segundo construye la
    // página (go_router entrega la ruta a través del RouteInformationProvider)
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(NewSaleScreen), findsOneWidget);
  });
}
