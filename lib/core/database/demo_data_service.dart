import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/dates.dart';
import '../../models/category.dart';
import '../../models/daily_closing.dart';
import '../../models/enums.dart';
import '../../models/expense.dart';
import '../../models/inventory_movement.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../models/sale_item.dart';

/// Datos de prueba para desarrollo y demos (§48).
///
/// **No se carga automáticamente en producción.** Sólo se invoca desde
/// Configuración → Información, o desde un test.
class DemoDataService {
  DemoDataService({Random? random}) : _random = random ?? Random();

  final Random _random;
  static const Uuid _uuid = Uuid();

  /// Catálogo base del spec más algunos extras para que los reportes
  /// tengan algo que graficar.
  static const List<_DemoProduct> _catalog = <_DemoProduct>[
    _DemoProduct('Playera básica', 8000, 15000, 24, 'Ropa', 'pieza'),
    _DemoProduct('Playera estampada', 12000, 22000, 18, 'Ropa', 'pieza'),
    _DemoProduct('Gorra', 4000, 10000, 15, 'Accesorios', 'pieza'),
    _DemoProduct('Pantalón', 15000, 28000, 12, 'Ropa', 'pieza'),
    _DemoProduct('Short', 6000, 13000, 14, 'Ropa', 'pieza'),
    _DemoProduct('Calcetines', 1500, 4000, 40, 'Ropa', 'par'),
    _DemoProduct('Chamarra', 25000, 45000, 6, 'Ropa', 'pieza'),
    _DemoProduct('Cinturón', 5000, 12000, 3, 'Accesorios', 'pieza'),
    _DemoProduct('Mochila', 18000, 35000, 9, 'Accesorios', 'pieza'),
    _DemoProduct('Taza térmica', 7000, 16000, 11, 'Hogar', 'pieza'),
    _DemoProduct('Abanico', 9000, 18000, 4, 'Hogar', 'pieza'),
    _DemoProduct('Agua embotellada', 800, 1500, 60, 'Bebidas', 'pieza'),
  ];

  /// Cuántos días hacia atrás se generan ventas.
  static const int defaultDays = 14;

  bool get hasData => AppDatabase.products.isNotEmpty;

  /// Carga el catálogo, ventas, gastos y movimientos ficticios.
  Future<void> seed({int days = defaultDays, bool withSales = true}) async {
    final Map<String, Category> categories = <String, Category>{};
    for (final String name in <String>[
      'Ropa', 'Accesorios', 'Hogar', 'Bebidas',
    ]) {
      categories[name] = await _ensureCategory(name);
    }

    final List<Product> products = <Product>[];
    for (final _DemoProduct item in _catalog) {
      final Product product = Product(
        id: _uuid.v4(),
        name: item.name,
        description: '',
        categoryId: categories[item.category]?.id,
        sku: 'DEMO-${item.name.hashCode.abs() % 9000 + 1000}',
        cost: item.cost,
        price: item.price,
        stock: item.stock.toDouble(),
        minStock: 5,
        unit: item.unit,
        createdAt: DateTime.now().subtract(const Duration(days: 40)),
      );
      await AppDatabase.products.put(product.id, product);
      products.add(product);

      final String movementId = _uuid.v4();
      await AppDatabase.movements.put(
        movementId,
        InventoryMovement(
          id: movementId,
          productId: product.id,
          productName: product.name,
          type: MovementType.entrada,
          quantity: item.stock.toDouble(),
          previousStock: 0,
          newStock: item.stock.toDouble(),
          reason: 'Carga inicial',
        ),
      );
    }

    if (!withSales) return;

    final List<Product> live = <Product>[
      for (final String id in AppDatabase.products.keys.cast<String>())
        if (AppDatabase.products.get(id) case final Product p) p,
    ];

    int folio = 1;
    for (int dayOffset = days - 1; dayOffset >= 0; dayOffset--) {
      final DateTime day = Dates.startOfDay(
        DateTime.now().subtract(Duration(days: dayOffset)),
      );
      final int saleCount = 4 + _random.nextInt(8);

      for (int i = 0; i < saleCount; i++) {
        await _createDemoSale(day, live, folio++);
      }
      await _createDemoExpenses(day);
    }

    AppDatabase.meta.put(AppConstants.keyNextFolio, folio);
  }

  /// Borra sólo los datos con `isDemo`. Como los productos demo se marcan
  /// con un SKU `DEMO-`, se puede limpiar sin tocar los reales.
  Future<void> clearDemo() async {
    final List<String> demoProductIds = AppDatabase.products.values
        .where((Product p) => p.sku.startsWith('DEMO-'))
        .map((Product p) => p.id)
        .toList();
    await AppDatabase.products.deleteAll(demoProductIds);
    await AppDatabase.movements.deleteAll(
      AppDatabase.movements.values
          .where((InventoryMovement m) => demoProductIds.contains(m.productId))
          .map((InventoryMovement m) => m.id),
    );
  }

  Future<Category> _ensureCategory(String name) async {
    for (final Category c in AppDatabase.categories.values) {
      if (c.name.toLowerCase() == name.toLowerCase()) return c;
    }
    final Category category = Category(
      id: _uuid.v4(),
      name: name,
      colorValue: 0,
    );
    await AppDatabase.categories.put(category.id, category);
    return category;
  }

  Future<void> _createDemoSale(
    DateTime day,
    List<Product> products,
    int folioNumber,
  ) async {
    final List<Product> available =
        products.where((Product p) => p.stock > 0).toList();
    if (available.isEmpty) return;

    final int lines = 1 + _random.nextInt(3);
    final Set<int> picked = <int>{};
    final List<SaleItem> items = <SaleItem>[];
    int total = 0;
    int costTotal = 0;

    for (int i = 0; i < lines; i++) {
      final int index = _random.nextInt(available.length);
      if (!picked.add(index)) continue;
      final Product p = available[index];
      final int qty = 1 + _random.nextInt(2);
      if (p.stock < qty) continue;
      items.add(
        SaleItem(
          productId: p.id,
          productName: p.name,
          cost: p.cost,
          price: p.price,
          quantity: qty,
          unit: p.unit,
        ),
      );
      total += p.price * qty;
      costTotal += p.cost * qty;
    }
    if (items.isEmpty) return;

    final PaymentMethod method = PaymentMethod.values[_random.nextInt(3)];
    final DateTime at = day.add(
      Duration(
        hours: 9 + _random.nextInt(11),
        minutes: _random.nextInt(60),
      ),
    );

    final Sale sale = Sale(
      id: _uuid.v4(),
      folio: 'V-${folioNumber.toString().padLeft(6, '0')}',
      items: items,
      subtotal: total,
      discount: 0,
      total: total,
      costTotal: costTotal,
      profit: total - costTotal,
      paymentMethod: method,
      isQuickSale: false,
      date: at,
    );
    await AppDatabase.sales.put(sale.id, sale);

    for (final SaleItem item in items) {
      final Product? p = AppDatabase.products.get(item.productId);
      if (p == null) continue;
      p.stock -= item.quantity;
      await AppDatabase.products.put(p.id, p);
      final String movementId = _uuid.v4();
      await AppDatabase.movements.put(
        movementId,
        InventoryMovement(
          id: movementId,
          productId: p.id,
          productName: p.name,
          type: MovementType.venta,
          quantity: item.quantity.toDouble(),
          previousStock: p.stock + item.quantity,
          newStock: p.stock,
          reason: 'Venta ${sale.folio}',
          referenceId: sale.id,
          date: at,
        ),
      );
    }
  }

  Future<void> _createDemoExpenses(DateTime day) async {
    const List<List<dynamic>> pool = <List<dynamic>>[
      <dynamic>['Cuota del tianguis', 15000, 'Pago semanal'],
      <dynamic>['Transporte', 8000, 'Flete del día'],
      <dynamic>['Bolsas', 2500, ''],
      <dynamic>['Comida', 6000, ''],
    ];
    final int count = _random.nextInt(3);
    for (int i = 0; i < count; i++) {
      final List<dynamic> row = pool[_random.nextInt(pool.length)];
      final Expense expense = Expense(
        id: _uuid.v4(),
        concept: row[0] as String,
        category: row[0] as String,
        amount: row[1] as int,
        notes: row[2] as String,
        date: day.add(Duration(hours: 10 + i)),
      );
      await AppDatabase.expenses.put(expense.id, expense);
    }
  }

  /// Crea un cierre de ayer para que la pantalla no arranque vacía.
  Future<void> seedClosing() async {
    final DailyClosing closing = DailyClosing(
      id: _uuid.v4(),
      date: Dates.startOfDay(DateTime.now().subtract(const Duration(days: 1))),
      salesCount: 12,
      itemsSold: 24,
      cashTotal: 145000,
      transferTotal: 60000,
      cardTotal: 45000,
      otherTotal: 0,
      total: 250000,
      costTotal: 140000,
      grossProfit: 110000,
      expensesTotal: 31500,
      netProfit: 78500,
      countedCash: 145000,
    );
    await AppDatabase.closings.put(closing.id, closing);
  }
}

class _DemoProduct {
  const _DemoProduct(
    this.name,
    this.cost,
    this.price,
    this.stock,
    this.category,
    this.unit,
  );

  final String name;
  final int cost;
  final int price;
  final int stock;
  final String category;
  final String unit;
}
