/// Enums de dominio. Hive los serializa como `int` (índice).
library;

/// Método de pago de una venta (§15).
enum PaymentMethod {
  efectivo('Efectivo'),
  transferencia('Transferencia'),
  tarjeta('Tarjeta'),
  otro('Otro');

  const PaymentMethod(this.label);

  final String label;

  static PaymentMethod fromName(String name) => PaymentMethod.values.firstWhere(
    (PaymentMethod m) => m.name == name,
    orElse: () => PaymentMethod.efectivo,
  );
}

/// Estado de una venta. Nunca se borra físicamente (§26).
enum SaleStatus {
  activa('Activa'),
  cancelada('Cancelada'),
  devuelta('Devuelta');

  const SaleStatus(this.label);

  final String label;

  /// Sólo las ventas activas entran a estadísticas.
  bool get countsInStats => this == SaleStatus.activa;
}

/// Tipo de movimiento de inventario (§22).
enum MovementType {
  entrada('Entrada'),
  venta('Venta'),
  devolucion('Devolución'),
  ajuste('Ajuste'),
  merma('Merma');

  const MovementType(this.label);

  final String label;

  /// Si el movimiento suma o resta stock.
  bool get increasesStock =>
      this == MovementType.entrada || this == MovementType.devolucion;

  static MovementType fromName(String name) => MovementType.values.firstWhere(
    (MovementType t) => t.name == name,
    orElse: () => MovementType.ajuste,
  );
}

/// Estado de stock de un producto (§20).
enum StockState {
  disponible('Disponible'),
  stockBajo('Stock bajo'),
  agotado('Agotado');

  const StockState(this.label);

  final String label;
}

/// Tipo de movimiento de caja (§28).
enum CashMovementType {
  fondoInicial('Fondo inicial'),
  venta('Venta'),
  entrada('Entrada'),
  salida('Salida'),
  gasto('Gasto');

  const CashMovementType(this.label);

  final String label;

  /// Si el movimiento suma o resta efectivo.
  bool get increasesCash =>
      this == CashMovementType.fondoInicial ||
      this == CashMovementType.entrada ||
      this == CashMovementType.venta;

  static CashMovementType fromName(String name) =>
      CashMovementType.values.firstWhere(
        (CashMovementType t) => t.name == name,
        orElse: () => CashMovementType.entrada,
      );
}

/// Preferencia de tema (§10).
enum ThemePreference {
  claro('Claro'),
  oscuro('Oscuro'),
  sistema('Sistema');

  const ThemePreference(this.label);

  final String label;
}

/// Formato de fecha configurable (§36).
enum DateFormatPreference {
  diaMesAnio('dd/MM/aaaa'),
  mesDiaAnio('MM/dd/aaaa'),
  anioMesDia('aaaa-MM-dd');

  const DateFormatPreference(this.label);

  final String label;
}

/// Formato de archivo para exportar productos (§32).
enum ExportFormat { csv, json }

/// Cómo tratar productos ya existentes al importar (§33).
enum ImportConflictStrategy {
  actualizar('Actualizar productos existentes'),
  ignorar('Ignorar productos existentes');

  const ImportConflictStrategy(this.label);

  final String label;
}
