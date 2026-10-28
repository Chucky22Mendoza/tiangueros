/// IDs de tipo de Hive.
///
/// **Regla: nunca cambiar ni reusar un id.** Hive persiste el typeId dentro del
/// archivo; reusarlo corrompe los datos ya guardados. Los ids nuevos se
/// agregan al final de la lista.
library;

abstract final class HiveTypeIds {
  const HiveTypeIds._();

  static const int businessSettings = 0;
  static const int appSettings = 1;
  static const int category = 2;
  static const int product = 3;
  static const int sale = 4;
  static const int saleItem = 5;
  static const int inventoryMovement = 6;
  static const int expense = 7;
  static const int cashMovement = 8;
  static const int dailyClosing = 9;

  /// IDs de enum. Van aparte para no chocar con los de entidad.
  static const int paymentMethod = 20;
  static const int saleStatus = 21;
  static const int movementType = 22;
  static const int cashMovementType = 23;
}
