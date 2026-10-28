import 'package:hive_ce/hive.dart';

import 'hive_type_ids.dart';

part 'daily_closing.g.dart';

/// Cierre del día: foto financiera del día, ya guardada (§29).
@HiveType(typeId: HiveTypeIds.dailyClosing)
class DailyClosing extends HiveObject {
  DailyClosing({
    this.id = '',
    DateTime? date,
    this.salesCount = 0,
    this.itemsSold = 0,
    this.cashTotal = 0,
    this.transferTotal = 0,
    this.cardTotal = 0,
    this.otherTotal = 0,
    this.total = 0,
    this.costTotal = 0,
    this.grossProfit = 0,
    this.expensesTotal = 0,
    this.netProfit = 0,
    this.countedCash,
    this.closingNote = '',
    DateTime? createdAt,
  }) : date = date ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now();

  @HiveField(0)
  String id;
  @HiveField(1)
  DateTime date;

  @HiveField(2)
  int salesCount;
  @HiveField(3)
  int itemsSold;

  @HiveField(4)
  int cashTotal;
  @HiveField(5)
  int transferTotal;
  @HiveField(6)
  int cardTotal;
  @HiveField(7)
  int otherTotal;

  @HiveField(8)
  int total;
  @HiveField(9)
  int costTotal;

  /// total - costTotal
  @HiveField(10)
  int grossProfit;

  @HiveField(11)
  int expensesTotal;

  /// grossProfit - expensesTotal
  @HiveField(12)
  int netProfit;

  /// Efectivo contado por el usuario al cerrar.
  @HiveField(13)
  int? countedCash;

  @HiveField(14)
  String closingNote;
  @HiveField(15)
  DateTime createdAt;

  /// contado - esperado. Positivo = sobrante, negativo = faltante.
  int? get difference => countedCash == null ? null : countedCash! - cashTotal;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'fecha': date.toIso8601String(),
    'ventas': salesCount,
    'productos': itemsSold,
    'efectivo': cashTotal,
    'transferencias': transferTotal,
    'tarjeta': cardTotal,
    'otro': otherTotal,
    'total': total,
    'costo': costTotal,
    'ganancia_bruta': grossProfit,
    'gastos': expensesTotal,
    'utilidad_neta': netProfit,
    'efectivo_contado': countedCash,
    'nota': closingNote,
    'creado': createdAt.toIso8601String(),
  };

  factory DailyClosing.fromJson(Map<String, dynamic> json) => DailyClosing(
    id: json['id'] as String? ?? '',
    date: DateTime.tryParse(json['fecha'] as String? ?? ''),
    salesCount: (json['ventas'] as num?)?.toInt() ?? 0,
    itemsSold: (json['productos'] as num?)?.toInt() ?? 0,
    cashTotal: (json['efectivo'] as num?)?.toInt() ?? 0,
    transferTotal: (json['transferencias'] as num?)?.toInt() ?? 0,
    cardTotal: (json['tarjeta'] as num?)?.toInt() ?? 0,
    otherTotal: (json['otro'] as num?)?.toInt() ?? 0,
    total: (json['total'] as num?)?.toInt() ?? 0,
    costTotal: (json['costo'] as num?)?.toInt() ?? 0,
    grossProfit: (json['ganancia_bruta'] as num?)?.toInt() ?? 0,
    expensesTotal: (json['gastos'] as num?)?.toInt() ?? 0,
    netProfit: (json['utilidad_neta'] as num?)?.toInt() ?? 0,
    countedCash: (json['efectivo_contado'] as num?)?.toInt(),
    closingNote: json['nota'] as String? ?? '',
    createdAt: DateTime.tryParse(json['creado'] as String? ?? ''),
  );
}
