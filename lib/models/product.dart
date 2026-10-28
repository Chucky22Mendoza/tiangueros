import 'package:hive_ce/hive.dart';

import 'enums.dart';
import 'hive_type_ids.dart';

part 'product.g.dart';

/// Producto del inventario (§18).
@HiveType(typeId: HiveTypeIds.product)
class Product extends HiveObject {
  Product({
    this.id = '',
    this.name = '',
    this.description = '',
    this.categoryId,
    this.sku = '',
    this.barcode = '',
    this.cost = 0,
    this.price = 0,
    this.stock = 0,
    this.minStock = 5,
    this.unit = 'pieza',
    this.active = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  @HiveField(0)
  String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String description;
  @HiveField(3)
  String? categoryId;
  @HiveField(4)
  String sku;

  /// Preparado para lector de códigos de barras (§40).
  @HiveField(5)
  String barcode;

  /// Costo unitario en centavos.
  @HiveField(6)
  int cost;

  /// Precio de venta unitario en centavos.
  @HiveField(7)
  int price;

  @HiveField(8)
  double stock;
  @HiveField(9)
  int minStock;
  @HiveField(10)
  String unit;
  @HiveField(11)
  bool active;
  @HiveField(12)
  DateTime createdAt;
  @HiveField(13)
  DateTime updatedAt;

  /// ganancia = precio - costo (§19)
  int get profit => price - cost;

  /// margen = ganancia / precio * 100 (§19). `0` si el precio es 0.
  double get marginPercent => price == 0 ? 0 : profit / price * 100;

  /// valor = costo * stock
  int get inventoryValue => (cost * stock).round();

  /// Estado según stock vs. stock mínimo (§20).
  StockState get stockState {
    if (stock <= 0) return StockState.agotado;
    if (stock <= minStock) return StockState.stockBajo;
    return StockState.disponible;
  }

  bool get isLowStock => stockState == StockState.stockBajo;
  bool get isOutOfStock => stockState == StockState.agotado;

  /// Texto buscable: nombre, SKU, código de barras y categoría (§40).
  /// Búsqueda por nombre, SKU, código de barras o **nombre de categoría** (§40).
  ///
  /// [categoryName] es el nombre de la categoría a la que pertenece el
  /// producto, ya resuelto por quien llama: un id de categoría no lo teclea ni
  /// lo recuerda nadie, el nombre sí.
  bool matches(String query, {String? categoryName}) {
    if (query.trim().isEmpty) return true;
    final String q = query.trim().toLowerCase();
    return name.toLowerCase().contains(q) ||
        sku.toLowerCase().contains(q) ||
        barcode.toLowerCase().contains(q) ||
        (categoryName?.toLowerCase().contains(q) ?? false);
  }
}
