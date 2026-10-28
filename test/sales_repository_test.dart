import 'package:flutter_test/flutter_test.dart';
import 'package:tianguis_control/core/constants/app_constants.dart';
import 'package:tianguis_control/core/database/app_database.dart';
import 'package:tianguis_control/core/errors/app_exception.dart';
import 'package:tianguis_control/models/enums.dart';
import 'package:tianguis_control/models/inventory_movement.dart';
import 'package:tianguis_control/models/product.dart';
import 'package:tianguis_control/repositories/inventory_repository.dart';
import 'package:tianguis_control/repositories/product_repository.dart';
import 'package:tianguis_control/models/sale.dart';
import 'package:tianguis_control/repositories/sales_repository.dart';
import 'package:tianguis_control/repositories/settings_repository.dart';

import 'helpers.dart';

void main() {
  late SalesRepository sales;
  late SettingsRepository settings;

  setUp(() async {
    await openTestDatabase();
    sales = SalesRepository(InventoryRepository());
    settings = SettingsRepository();
  });

  CartLine lineaDe(Product p, {int cantidad = 1}) => CartLine(
        productId: p.id,
        productName: p.name,
        unitCost: p.cost,
        unitPrice: p.price,
        quantity: cantidad,
        availableStock: p.stock,
      );

  /// Alta real vía repositorio, para tener el mismo camino que la app.
  Future<Product> crearProducto({
    String name = 'Refresco',
    int cost = 1000,
    int price = 1500,
    double stock = 10,
  }) {
    return ProductRepository().create(
      name: name,
      cost: cost,
      price: price,
      stock: stock,
    );
  }

  group('watchers de ventas y gastos', () {
    // Ver el comentario en product_inventory_repository_test: sin un valor
    // inicial, las pantallas se quedan cargando con la base vacía.
    test('watchAll de ventas emite de inmediato aunque la caja esté vacía', () async {
      expect(
        await sales.watchAll().first.timeout(const Duration(seconds: 2)),
        isEmpty,
      );
    });

    test('watchRange de ventas emite de inmediato aunque la caja esté vacía', () async {
      final DateTime now = DateTime.now();
      expect(
        await sales
            .watchRange(now.subtract(const Duration(days: 1)), now)
            .first
            .timeout(const Duration(seconds: 2)),
        isEmpty,
      );
    });
  });

  group('SalesRepository - folios', () {
    test('primer folio es V-000001 y avanza de uno en uno (§38)', () async {
      final Product p = await crearProducto(stock: 10);

      final SaleResult r1 = await sales.checkout(
        lines: <CartLine>[lineaDe(p, cantidad: 1)],
        paymentMethod: PaymentMethod.efectivo,
      );
      expect(r1.folio, 'V-000001');
      expect(r1.sale.folio, 'V-000001');

      final SaleResult r2 = await sales.checkout(
        lines: <CartLine>[lineaDe(p, cantidad: 1)],
        paymentMethod: PaymentMethod.tarjeta,
      );
      expect(r2.folio, 'V-000002');

      // el prefijo es configurable
      await settings.setSalePrefix('tng');
      expect(settings.folioPrefix, 'TNG');
    });

    test('las ventas se guardan y son recuperables por id', () async {
      final Product p = await crearProducto(stock: 5);
      final SaleResult r = await sales.checkout(
        lines: <CartLine>[lineaDe(p, cantidad: 2)],
        paymentMethod: PaymentMethod.efectivo,
      );

      final Sale? guardada = AppDatabase.sales.get(r.sale.id);
      expect(guardada, isNotNull);
      expect(guardada!.folio, 'V-000001');
      expect(guardada.total, 3000);
      expect(guardada.items.single.productName, 'Refresco');
      expect(guardada.items.single.quantity, 2);
      // snapshot: el costo queda congelado en la venta
      expect(guardada.costTotal, 2000);
    });
  });

  group('SalesRepository - totales y validación', () {
    test('total = subtotal - descuento y la ganancia usa el costo', () async {
      final Product p = await crearProducto(cost: 1000, price: 2000, stock: 10);

      final SaleResult r = await sales.checkout(
        lines: <CartLine>[lineaDe(p, cantidad: 3)],
        paymentMethod: PaymentMethod.efectivo,
        discount: 1000,
      );
      expect(r.sale.subtotal, 6000);
      expect(r.sale.discount, 1000);
      expect(r.sale.total, 5000);
      expect(r.sale.profit, 5000 - 3000);
    });

    test('rechaza carrito vacío, descuento negativo o mayor al total', () async {
      expect(
        () => sales.checkout(
          lines: <CartLine>[],
          paymentMethod: PaymentMethod.efectivo,
        ),
        throwsA(isA<ValidationException>()),
      );

      final Product p = await crearProducto(stock: 5);

      expect(
        () => sales.checkout(
          lines: <CartLine>[lineaDe(p)],
          paymentMethod: PaymentMethod.efectivo,
          discount: -1,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => sales.checkout(
          lines: <CartLine>[lineaDe(p)],
          paymentMethod: PaymentMethod.efectivo,
          discount: 999999,
        ),
        throwsA(isA<ValidationException>()),
      );
      // nada debe haberse escrito
      expect(AppDatabase.sales, isEmpty);
    });

    test('rechaza vender más stock del disponible y no descuenta nada', () async {
      final Product p = await crearProducto(stock: 2);

      expect(
        () => sales.checkout(
          lines: <CartLine>[lineaDe(p, cantidad: 5)],
          paymentMethod: PaymentMethod.efectivo,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(AppDatabase.products.get(p.id)?.stock, 2);
      expect(AppDatabase.sales, isEmpty);
      expect(AppDatabase.movements, isEmpty);
      // tampoco se consumió el folio
      expect(AppDatabase.meta.get(AppConstants.keyNextFolio), isNull);
    });

    test('cantidad cero o negativa se rechaza', () async {
      final Product p = await crearProducto(stock: 5);
      expect(
        () => sales.checkout(
          lines: <CartLine>[lineaDe(p, cantidad: 0)],
          paymentMethod: PaymentMethod.efectivo,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('SalesRepository - stock y caja', () {
    test('la venta descuenta stock y deja movimiento con delta negativo', () async {
      final Product p = await crearProducto(cost: 1000, price: 1500, stock: 10);

      final SaleResult r = await sales.checkout(
        lines: <CartLine>[lineaDe(p, cantidad: 4)],
        paymentMethod: PaymentMethod.tarjeta,
      );

      expect(AppDatabase.products.get(p.id)?.stock, 6);
      final InventoryMovement m = r.movements.single;
      expect(m.type, MovementType.venta);
      expect(m.previousStock, 10);
      expect(m.newStock, 6);
      expect(m.delta, -4);
      expect(m.quantity, 4);
      expect(m.referenceId, r.sale.id);
      expect(m.reason, contains(r.folio));
    });

    test('pago en efectivo suma a la caja; con tarjeta no', () async {
      final Product p = await crearProducto(cost: 1000, price: 1500, stock: 10);

      await sales.checkout(
        lines: <CartLine>[lineaDe(p, cantidad: 1)],
        paymentMethod: PaymentMethod.efectivo,
      );
      expect(AppDatabase.cash.length, 1);
      expect(AppDatabase.cash.values.single.signedAmount, 1500);

      await sales.checkout(
        lines: <CartLine>[lineaDe(p, cantidad: 1)],
        paymentMethod: PaymentMethod.tarjeta,
      );
      // la segunda no toca la caja
      expect(AppDatabase.cash.length, 1);
    });

    test('venta rápida no toca inventario pero sí caja y folio (§16)', () async {
      final SaleResult r = await sales.quickSale(
        concept: 'Venta de pulseras',
        price: 5000,
        quantity: 2,
        paymentMethod: PaymentMethod.efectivo,
      );
      expect(r.folio, 'V-000001');
      expect(r.sale.total, 10000);
      expect(r.sale.isQuickSale, isTrue);
      expect(r.sale.items.single.productId, isNull);
      expect(r.movements, isEmpty);
      expect(AppDatabase.movements, isEmpty);
      expect(AppDatabase.cash.length, 1);
    });

    test('venta rápida valida precio, cantidad y costo', () async {
      expect(
        () => sales.quickSale(
          concept: '',
          price: 100,
          paymentMethod: PaymentMethod.efectivo,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => sales.quickSale(
          concept: 'X',
          price: 0,
          paymentMethod: PaymentMethod.efectivo,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => sales.quickSale(
          concept: 'X',
          price: 100,
          quantity: 0,
          paymentMethod: PaymentMethod.efectivo,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => sales.quickSale(
          concept: 'X',
          price: 100,
          cost: 500,
          paymentMethod: PaymentMethod.efectivo,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(AppDatabase.sales, isEmpty);
    });
  });

  group('SalesRepository - cancelación y reapertura (§26)', () {
    test('cancelar devuelve stock, revierte caja y conserva la venta', () async {
      final Product p = await crearProducto(cost: 1000, price: 1500, stock: 10);
      final SaleResult r = await sales.checkout(
        lines: <CartLine>[lineaDe(p, cantidad: 3)],
        paymentMethod: PaymentMethod.efectivo,
      );
      expect(AppDatabase.products.get(p.id)?.stock, 7);
      expect(AppDatabase.cash.length, 1);

      final Sale cancelada = await sales.cancelSale(r.sale.id, reason: 'Cliente se arrepintió');
      expect(cancelada.status, SaleStatus.cancelada);
      expect(cancelada.isCancelled, isTrue);
      // el registro sigue ahí, no se borra
      expect(AppDatabase.sales.get(r.sale.id), isNotNull);
      // el stock volvió
      expect(AppDatabase.products.get(p.id)?.stock, 10);
      // la caja se revirtió
      expect(AppDatabase.cash, isEmpty);
    });

    test('no se puede cancelar dos veces ni una venta inexistente', () async {
      final Product p = await crearProducto(stock: 10);
      final SaleResult r = await sales.checkout(
        lines: <CartLine>[lineaDe(p)],
        paymentMethod: PaymentMethod.efectivo,
      );

      await sales.cancelSale(r.sale.id);
      expect(
        () => sales.cancelSale(r.sale.id),
        throwsA(isA<ConflictException>()),
      );
      expect(
        () => sales.cancelSale('no-existe'),
        throwsA(isA<StorageException>()),
      );
    });

    test('reabrir vuelve a descontar stock y reaplica el efectivo', () async {
      final Product p = await crearProducto(cost: 1000, price: 1500, stock: 10);
      final SaleResult r = await sales.checkout(
        lines: <CartLine>[lineaDe(p, cantidad: 2)],
        paymentMethod: PaymentMethod.efectivo,
      );

      await sales.cancelSale(r.sale.id);
      expect(AppDatabase.products.get(p.id)?.stock, 10);

      await sales.restoreSale(r.sale.id);
      expect(AppDatabase.sales.get(r.sale.id)?.status, SaleStatus.activa);
      expect(AppDatabase.products.get(p.id)?.stock, 8);
      expect(AppDatabase.cash.length, 1);
    });
  });
}
