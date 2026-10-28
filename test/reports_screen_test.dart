import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tianguis_control/features/reports/presentation/reports_screen.dart';
import 'package:tianguis_control/models/enums.dart';
import 'package:tianguis_control/models/product.dart';
import 'package:tianguis_control/repositories/expense_repository.dart';
import 'package:tianguis_control/repositories/inventory_repository.dart';
import 'package:tianguis_control/repositories/product_repository.dart';
import 'package:tianguis_control/repositories/sales_repository.dart';

import 'helpers.dart';

void main() {
  setUp(() async {
    await openTestDatabaseForWidgetTests();
    final Product p = await ProductRepository().create(
      name: 'Refresco',
      cost: 1000,
      price: 1250000,
      stock: 1000,
    );
    final SalesRepository sales = SalesRepository(InventoryRepository());
    for (int i = 0; i < 5; i++) {
      await sales.checkout(
        lines: <CartLine>[
          CartLine(
            productId: p.id,
            productName: p.name,
            unitCost: p.cost,
            unitPrice: p.price,
            quantity: 3,
            availableStock: p.stock,
          ),
        ],
        paymentMethod: i.isEven ? PaymentMethod.efectivo : PaymentMethod.tarjeta,
      );
    }
    await ExpenseRepository().create(
      concept: 'Transporte',
      category: 'Transporte',
      amount: 5000,
      date: DateTime.now().subtract(const Duration(days: 2)),
    );
  });

  // Montos grandes a propósito: las etiquetas del eje de la gráfica llaman a
  // `Money.formatCompact`, que antes reventaba desde $1,000.
  testWidgets('reportes con datos: scroll completo sin excepción', (
    WidgetTester tester,
  ) async {
    // Pantalla angosta de teléfono: es donde un monto largo se desborda.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ReportsScreen())),
    );
    await tester.pump();

    for (int i = 0; i < 8; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -320));
      await tester.pump();
      final Object? e = tester.takeException();
      expect(e, isNull, reason: 'excepción al hacer scroll $i');
    }
  });
}
