import '../errors/app_exception.dart';
import 'money.dart';

/// Validadores de formulario (§45).
///
/// Reglas que la app nunca debe permitir: precios/costos/stock negativos,
/// cantidades cero, productos sin nombre, ventas sin productos, gastos sin
/// monto.
abstract final class V {
  const V._();

  static String? required(String? value, {String field = 'Este campo'}) {
    if (value == null || value.trim().isEmpty) return '$field es obligatorio';
    return null;
  }

  /// Nombre de producto: no vacío, sin saltos de línea, máx. 80 chars.
  static String? productName(String? value) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) return 'El nombre es obligatorio';
    if (v.length > 80) return 'Máximo 80 caracteres';
    if (v.contains('\n')) return 'El nombre no puede tener saltos de línea';
    return null;
  }

  /// Costo: no negativo. Vacío se trata como 0 (artículos sin costo conocido).
  static String? cost(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final int? cents = Money.tryParseToCents(value);
    if (cents == null) return 'Monto inválido';
    if (cents < 0) return 'El costo no puede ser negativo';
    return null;
  }

  /// Precio: obligatorio y mayor a cero.
  static String? price(String? value) {
    if (value == null || value.trim().isEmpty) return 'El precio es obligatorio';
    final int? cents = Money.tryParseToCents(value);
    if (cents == null) return 'Monto inválido';
    if (cents <= 0) return 'El precio debe ser mayor a cero';
    return null;
  }

  /// Monto de gasto: obligatorio y mayor a cero.
  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) return 'El monto es obligatorio';
    final int? cents = Money.tryParseToCents(value);
    if (cents == null) return 'Monto inválido';
    if (cents <= 0) return 'El monto debe ser mayor a cero';
    return null;
  }

  /// Stock: entero >= 0. Admite decimales de a 1 (0.5 kg de fruta).
  static String? stock(String? value) {
    if (value == null || value.trim().isEmpty) return 'El stock es obligatorio';
    final double? parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null) return 'Cantidad inválida';
    if (parsed < 0) return 'El stock no puede ser negativo';
    return null;
  }

  /// Stock mínimo: entero >= 0, vacío se normaliza a 0.
  static String? minStock(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final int? parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Debe ser un número entero';
    if (parsed < 0) return 'No puede ser negativo';
    return null;
  }

  /// Cantidad de venta: entero > 0.
  static String? quantity(String? value) {
    if (value == null || value.trim().isEmpty) return 'La cantidad es obligatoria';
    final int? parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Debe ser un número entero';
    if (parsed <= 0) return 'La cantidad debe ser mayor a cero';
    return null;
  }

  /// Descuento: 0..100.
  static String? discountPercent(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final double? parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null) return 'Porcentaje inválido';
    if (parsed < 0) return 'No puede ser negativo';
    if (parsed > 100) return 'No puede ser mayor a 100%';
    return null;
  }

  /// Lanza [ValidationException] si hay error. Usar en submit.
  static void check(String? error) {
    if (error != null) throw ValidationException(error);
  }

  /// Verifica que haya al menos una línea en el carrito.
  static void checkNotEmpty(bool isEmpty, String message) {
    if (isEmpty) throw ValidationException(message);
  }
}
