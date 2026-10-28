import 'package:flutter_test/flutter_test.dart';
import 'package:tianguis_control/core/constants/app_constants.dart';
import 'package:tianguis_control/core/database/app_database.dart';
import 'package:tianguis_control/core/errors/app_exception.dart';
import 'package:tianguis_control/models/category.dart';
import 'package:tianguis_control/models/enums.dart';
import 'package:tianguis_control/models/inventory_movement.dart';
import 'package:tianguis_control/models/product.dart';
import 'package:tianguis_control/repositories/inventory_repository.dart';
import 'package:tianguis_control/repositories/product_repository.dart';

import 'helpers.dart';

void main() {
  late ProductRepository products;
  late InventoryRepository inventory;

  setUp(() async {
    await openTestDatabase();
    products = ProductRepository();
    inventory = InventoryRepository();
  });

  group('ProductRepository', () {
    test('crea producto y lo guarda con id', () async {
      final Product p = await products.create(
        name: '  Refresco  ',
        cost: 1000,
        price: 1500,
        stock: 10,
      );
      expect(p.id, isNotEmpty);
      expect(p.name, 'Refresco');
      expect(AppDatabase.products.get(p.id)?.name, 'Refresco');
    });

    test('rechaza precio cero, costo o stock negativos', () async {
      expect(
        () => products.create(name: 'X', cost: 0, price: 0),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => products.create(name: 'X', cost: -1, price: 100),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => products.create(name: 'X', cost: 0, price: 100, stock: -1),
        throwsA(isA<ValidationException>()),
      );
    });

    test('no permite dos productos con el mismo SKU', () async {
      await products.create(name: 'A', cost: 10, price: 20, sku: 'SKU-1');
      expect(
        () => products.create(name: 'B', cost: 10, price: 20, sku: 'SKU-1'),
        throwsA(isA<ConflictException>()),
      );
    });

    test('busca por nombre, SKU y código de barras ignorando mayúsculas', () async {
      await products.create(
        name: 'Coca Cola',
        cost: 1000,
        price: 1500,
        sku: 'ref-350',
        barcode: '7501234567890',
      );
      expect(products.search('coca').length, 1);
      expect(products.search('REF-350').length, 1);
      expect(products.search('7501234567890').length, 1);
      expect(products.search('inexistente'), isEmpty);
    });

    test('busca por el NOMBRE de la categoría, no por su id (§40)', () async {
      await AppDatabase.categories.put('cat-bebidas', Category(
        id: 'cat-bebidas',
        name: 'Bebidas',
      ));
      final Product conCat = await products.create(
        name: 'Agua',
        cost: 500,
        price: 800,
        categoryId: 'cat-bebidas',
      );
      await products.create(name: 'Cepillo', cost: 1500, price: 2500);

      expect(products.search('bebidas').map((Product p) => p.id), <String>[conCat.id]);
      // el id crudo no debe dar resultados: nadie lo teclea
      expect(products.search('cat-bebidas'), isEmpty);
    });

    test('isLowStock e isOutOfStock respetan el mínimo', () async {
      final Product p = await products.create(
        name: 'Papas',
        cost: 1000,
        price: 1500,
        stock: 3,
        minStock: 5,
      );
      expect(p.isOutOfStock, isFalse);
      expect(p.isLowStock, isTrue);

      await inventory.setStockTo(productId: p.id, newStock: 0);
      expect(AppDatabase.products.get(p.id)?.isOutOfStock, isTrue);
    });
  });

  group('watchers', () {
    // `box.watch()` sólo emite en cambios. Si el stream no manda un valor
    // inicial, el `StreamProvider` se queda en `loading` para siempre y las
    // pantallas de ventas/productos/inventario/gastos no salen del spinner.
    test('watchAll emite de inmediato aunque la caja esté vacía', () async {
      expect(
        await products.watchAll().first.timeout(const Duration(seconds: 2)),
        isEmpty,
      );
    });

    test('watchCategories emite de inmediato aunque la caja esté vacía', () async {
      expect(
        await products.watchCategories().first.timeout(const Duration(seconds: 2)),
        isEmpty,
      );
    });

    test('watchMovements emite de inmediato aunque la caja esté vacía', () async {
      expect(
        await inventory.watchMovements().first.timeout(const Duration(seconds: 2)),
        isEmpty,
      );
    });

    test('watchAll refleja un producto recién creado', () async {
      await products.create(name: 'Refresco', cost: 1000, price: 1500);
      final List<Product> list =
          await products.watchAll().first.timeout(const Duration(seconds: 2));
      expect(list.map((Product p) => p.name), contains('Refresco'));
    });
  });

  group('InventoryRepository', () {
    test('setStockTo sube y baja con delta con signo', () async {
      final Product p = await products.create(
        name: 'Café',
        cost: 2000,
        price: 3000,
        stock: 10,
      );

      final m1 = await inventory.setStockTo(productId: p.id, newStock: 25);
      expect(m1.delta, 15);
      expect(AppDatabase.products.get(p.id)?.stock, 25);

      final m2 = await inventory.setStockTo(productId: p.id, newStock: 5);
      expect(m2.delta, -20);
      expect(AppDatabase.products.get(p.id)?.stock, 5);
      // `quantity` es la magnitud, siempre positiva
      expect(m2.quantity, 20);
    });

    test('setStockTo al mismo valor no genera movimiento', () async {
      final Product p = await products.create(
        name: 'Té',
        cost: 1000,
        price: 1500,
        stock: 7,
      );
      expect(
        () => inventory.setStockTo(productId: p.id, newStock: 7),
        throwsA(isA<ValidationException>()),
      );
      expect(AppDatabase.movements.length, 0);
    });

    test('setStockTo a negativo se rechaza y no toca stock', () async {
      final Product p = await products.create(
        name: 'Jugo',
        cost: 1000,
        price: 1500,
        stock: 4,
      );
      expect(
        () => inventory.setStockTo(productId: p.id, newStock: -1),
        throwsA(isA<ValidationException>()),
      );
      expect(AppDatabase.products.get(p.id)?.stock, 4);
    });

    test('entrada y salida mueven el stock y dejan rastro', () async {
      final Product p = await products.create(
        name: 'Pan',
        cost: 500,
        price: 900,
        stock: 0,
      );

      await inventory.applyMovement(
        product: p,
        type: MovementType.entrada,
        amount: 20,
        reason: 'Compra',
      );
      expect(AppDatabase.products.get(p.id)?.stock, 20);

      await inventory.applyMovement(
        product: p,
        type: MovementType.merma,
        amount: 3,
        reason: 'Se echó a perder',
      );
      final Product after = AppDatabase.products.get(p.id)!;
      expect(after.stock, 17);
      expect(AppDatabase.movements.length, 2);
      // Hive no garantiza orden de `values`, así que se busca por atributo.
      final List<String> reasons = AppDatabase.movements.values
          .map((InventoryMovement m) => m.reason)
          .toList();
      expect(reasons, containsAll(<String>['Compra', 'Se echó a perder']));
    });

    test('no permite vender más de lo que hay', () async {
      final Product p = await products.create(
        name: 'Leche',
        cost: 1000,
        price: 1500,
        stock: 2,
      );
      expect(
        () => inventory.applyMovement(
          product: p,
          type: MovementType.venta,
          amount: 5,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(AppDatabase.products.get(p.id)?.stock, 2);
    });

    test('wipe deja las cajas utilizables', () async {
      await products.create(name: 'Algo', cost: 1, price: 2, stock: 1);
      await AppDatabase.meta.put(AppConstants.keyNextFolio, 5);
      expect(AppDatabase.products.length, 1);

      await AppDatabase.wipeAll();

      expect(AppDatabase.products, isEmpty);
      expect(AppDatabase.meta.get(AppConstants.keyNextFolio), isNull);
      // sigue operable: es lo que hace "wipe" durante el arranque
      final Product p = await products.create(name: 'Nuevo', cost: 10, price: 20);
      expect(AppDatabase.products.get(p.id), isNotNull);
    });
  });
}
