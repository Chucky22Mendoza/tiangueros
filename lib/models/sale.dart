import 'package:hive_ce/hive.dart';

import 'enums.dart';
import 'hive_type_ids.dart';
import 'sale_item.dart';

part 'sale.g.dart';

/// Venta registrada. Nunca se elimina físicamente: se marca CANCELADA (§26).
@HiveType(typeId: HiveTypeIds.sale)
class Sale extends HiveObject {
  Sale({
    this.id = '',
    this.folio = '',
    List<SaleItem>? items,
    this.subtotal = 0,
    this.discount = 0,
    this.total = 0,
    this.costTotal = 0,
    this.profit = 0,
    PaymentMethod paymentMethod = PaymentMethod.efectivo,
    this.isQuickSale = false,
    SaleStatus status = SaleStatus.activa,
    this.notes = '',
    DateTime? date,
    this.voidedAt,
    this.returnedAt,
  }) : items = items ?? <SaleItem>[],
       paymentMethodIndex = paymentMethod.index,
       statusIndex = status.index,
       date = date ?? DateTime.now();

  @HiveField(0)
  String id;

  /// Folio único e irrepetible: `V-000001` (§38).
  @HiveField(1)
  String folio;

  @HiveField(2)
  List<SaleItem> items;

  /// Suma de líneas antes de descuento.
  @HiveField(3)
  int subtotal;

  /// Descuento aplicado, en centavos.
  @HiveField(4)
  int discount;

  /// subtotal - discount. Es lo que se cobró.
  @HiveField(5)
  int total;

  /// Suma de costos (snapshot) de las líneas.
  @HiveField(6)
  int costTotal;

  /// Ganancia = total - costTotal. Negativa si hubo descuento.
  @HiveField(7)
  int profit;

  /// Índices de los enums: Hive no serializa enums, se guarda el número.
  @HiveField(8)
  int paymentMethodIndex;

  /// `true` si viene de "Venta rápida" (sin producto registrado) (§16).
  @HiveField(9)
  bool isQuickSale;

  @HiveField(10)
  int statusIndex;
  @HiveField(11)
  String notes;
  @HiveField(12)
  DateTime date;
  @HiveField(13)
  DateTime? voidedAt;
  @HiveField(14)
  DateTime? returnedAt;

  PaymentMethod get paymentMethod => PaymentMethod.values[
      paymentMethodIndex >= 0 && paymentMethodIndex < PaymentMethod.values.length
          ? paymentMethodIndex
          : PaymentMethod.efectivo.index];

  set paymentMethod(PaymentMethod value) => paymentMethodIndex = value.index;

  SaleStatus get status => SaleStatus.values[
      statusIndex >= 0 && statusIndex < SaleStatus.values.length
          ? statusIndex
          : SaleStatus.activa.index];

  set status(SaleStatus value) => statusIndex = value.index;

  bool get isCancelled => status == SaleStatus.cancelada;
  bool get countsInStats => status == SaleStatus.activa;

  int get itemCount =>
      items.fold<int>(0, (int sum, SaleItem i) => sum + i.quantity);

  /// Ganancia estimada: si el costo nunca se capturó, es igual al total.
  /// La UI lo marca como estimado cuando hay líneas con costo 0 (§17).
  bool get hasUnknownCost => items.any((SaleItem i) => i.cost == 0);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'folio': folio,
    'fecha': date.toIso8601String(),
    'lineas': items.map((SaleItem i) => i.toJson()).toList(),
    'subtotal': subtotal,
    'descuento': discount,
    'total': total,
    'costo_total': costTotal,
    'ganancia': profit,
    'metodo_pago': paymentMethod.name,
    'venta_rapida': isQuickSale,
    'estado': status.name,
    'notas': notes,
  };

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
    id: json['id'] as String? ?? '',
    folio: json['folio'] as String? ?? '',
    date: DateTime.tryParse(json['fecha'] as String? ?? ''),
    items: (json['lineas'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> e) => SaleItem.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList(),
    subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
    discount: (json['descuento'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
    costTotal: (json['costo_total'] as num?)?.toInt() ?? 0,
    profit: (json['ganancia'] as num?)?.toInt() ?? 0,
    paymentMethod: PaymentMethod.fromName(
      json['metodo_pago'] as String? ?? 'efectivo',
    ),
    isQuickSale: json['venta_rapida'] as bool? ?? false,
    status: SaleStatus.values.firstWhere(
      (SaleStatus s) => s.name == json['estado'],
      orElse: () => SaleStatus.activa,
    ),
    notes: json['notas'] as String? ?? '',
  );
}
