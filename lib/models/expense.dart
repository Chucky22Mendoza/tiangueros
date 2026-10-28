import 'package:hive_ce/hive.dart';

import 'hive_type_ids.dart';

part 'expense.g.dart';

/// Gasto del puesto: cuota, transporte, comida, bolsas… (§23).
@HiveType(typeId: HiveTypeIds.expense)
class Expense extends HiveObject {
  Expense({
    this.id = '',
    this.concept = '',
    this.category = 'Otro',
    this.amount = 0,
    this.notes = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();

  @HiveField(0)
  String id;
  @HiveField(1)
  String concept;
  @HiveField(2)
  String category;

  /// Monto en centavos, siempre > 0.
  @HiveField(3)
  int amount;

  @HiveField(4)
  String notes;
  @HiveField(5)
  DateTime date;

  /// `true` si el gasto salió de la caja en efectivo.
  bool get affectsCash => category.toLowerCase() != 'transferencia';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'concepto': concept,
    'categoria': category,
    'monto': amount,
    'fecha': date.toIso8601String(),
    'notas': notes,
  };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String? ?? '',
    concept: json['concepto'] as String? ?? '',
    category: json['categoria'] as String? ?? 'Otro',
    amount: (json['monto'] as num?)?.toInt() ?? 0,
    notes: json['notas'] as String? ?? '',
    date: DateTime.tryParse(json['fecha'] as String? ?? ''),
  );
}
