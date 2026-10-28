import 'package:hive_ce/hive.dart';

import 'enums.dart';
import 'hive_type_ids.dart';

part 'cash_movement.g.dart';

/// Movimiento de caja / efectivo (§28).
@HiveType(typeId: HiveTypeIds.cashMovement)
class CashMovement extends HiveObject {
  CashMovement({
    this.id = '',
    CashMovementType type = CashMovementType.entrada,
    this.amount = 0,
    this.concept = '',
    this.referenceId,
    DateTime? date,
  })  : typeIndex = type.index,
        date = date ?? DateTime.now();

  @HiveField(0)
  String id;
  /// Índice de [CashMovementType]: Hive no serializa enums, se guarda el
  /// número y [type] lo traduce.
  @HiveField(1)
  int typeIndex;

  /// Monto en centavos, siempre > 0. El signo lo determina [type].
  @HiveField(2)
  int amount;

  @HiveField(3)
  String concept;

  /// Id de la venta o gasto relacionado.
  @HiveField(4)
  String? referenceId;

  @HiveField(5)
  DateTime date;

  int get signedAmount => type.increasesCash ? amount : -amount;

  CashMovementType get type => CashMovementType.values[
      typeIndex >= 0 && typeIndex < CashMovementType.values.length
          ? typeIndex
          : CashMovementType.entrada.index];

  set type(CashMovementType value) => typeIndex = value.index;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'tipo': type.name,
    'monto': amount,
    'concepto': concept,
    'referencia_id': referenceId,
    'fecha': date.toIso8601String(),
  };

  factory CashMovement.fromJson(Map<String, dynamic> json) => CashMovement(
    id: json['id'] as String? ?? '',
    type: CashMovementType.fromName(json['tipo'] as String? ?? 'entrada'),
    amount: (json['monto'] as num?)?.toInt() ?? 0,
    concept: json['concepto'] as String? ?? '',
    referenceId: json['referencia_id'] as String?,
    date: DateTime.tryParse(json['fecha'] as String? ?? ''),
  );
}
