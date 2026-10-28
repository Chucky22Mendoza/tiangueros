import 'package:hive_ce/hive.dart';

import 'hive_type_ids.dart';

part 'sale_item.g.dart';

/// Línea de venta con **snapshot** de nombre, costo y precio (§39).
///
/// Si el producto cambia de precio después, la venta vieja debe seguir
/// mostrando los valores con los que se cobró.
@HiveType(typeId: HiveTypeIds.saleItem)
class SaleItem extends HiveObject {
  SaleItem({
    this.productId,
    this.productName = '',
    this.cost = 0,
    this.price = 0,
    this.quantity = 1,
    this.unit = 'pieza',
  });

  /// `null` para venta rápida: concepto sin producto registrado (§16).
  @HiveField(0)
  String? productId;

  @HiveField(1)
  String productName;

  /// Costo unitario congelado al momento de la venta.
  @HiveField(2)
  int cost;

  /// Precio unitario congelado al momento de la venta.
  @HiveField(3)
  int price;

  @HiveField(4)
  int quantity;
  @HiveField(5)
  String unit;

  int get lineTotal => price * quantity;
  int get lineCost => cost * quantity;
  int get lineProfit => lineTotal - lineCost;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'product_id': productId,
    'product_name': productName,
    'costo': cost,
    'precio': price,
    'cantidad': quantity,
    'unidad': unit,
  };

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
    productId: json['product_id'] as String?,
    productName: json['product_name'] as String? ?? '',
    cost: (json['costo'] as num?)?.toInt() ?? 0,
    price: (json['precio'] as num?)?.toInt() ?? 0,
    quantity: (json['cantidad'] as num?)?.toInt() ?? 1,
    unit: json['unidad'] as String? ?? 'pieza',
  );
}
