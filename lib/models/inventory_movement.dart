import 'package:hive_ce/hive.dart';

import 'enums.dart';
import 'hive_type_ids.dart';

part 'inventory_movement.g.dart';

/// Rastro de todo cambio de stock (§22).
///
/// Permite auditar por qué un producto tiene cierta cantidad y por qué cambió.
@HiveType(typeId: HiveTypeIds.inventoryMovement)
class InventoryMovement extends HiveObject {
  InventoryMovement({
    this.id = '',
    this.productId = '',
    this.productName = '',
    MovementType type = MovementType.entrada,
    this.quantity = 0,
    this.previousStock = 0,
    this.newStock = 0,
    this.reason = '',
    this.referenceId,
    DateTime? date,
  })  : typeIndex = type.index,
        date = date ?? DateTime.now();

  @HiveField(0)
  String id;
  @HiveField(1)
  String productId;

  /// Snapshot del nombre para que el historial no cambie si se renombra.
  @HiveField(2)
  String productName;

  /// Índice de [MovementType] dentro del enum: Hive no sabe serializar un
  /// enum, así que se guarda el número y [type] lo traduce.
  @HiveField(3)
  int typeIndex;

  /// Cantidad en valor absoluto. El signo lo determina [type].
  @HiveField(4)
  double quantity;

  @HiveField(5)
  double previousStock;
  @HiveField(6)
  double newStock;
  @HiveField(7)
  String reason;

  /// Id de la venta o entrada que originó el movimiento, si aplica.
  @HiveField(8)
  String? referenceId;

  @HiveField(9)
  DateTime date;

  /// Delta efectivo aplicado al stock.
  ///
  /// Se calcula desde el antes y el después, no desde [type]: un ajuste puede
  /// subir o bajar el stock y ambos casos son válidos. Derivar el signo del
  /// tipo mostraría "-5" en un ajuste que subió 5 unidades.
  double get delta => newStock - previousStock;

  /// Tipo de movimiento, traducido desde el índice guardado.
  ///
  /// El índice se acota al rango válido: un enum puede crecer en el futuro y un
  /// valor viejo fuera de rango no debe romper la app al abrir el historial.
  MovementType get type => MovementType.values[
      typeIndex >= 0 && typeIndex < MovementType.values.length
          ? typeIndex
          : MovementType.entrada.index];

  set type(MovementType value) => typeIndex = value.index;
}
