/// Excepciones de la app. La capa de presentación las traduce a mensajes
///legibles; ninguna función debe lanzar `Exception` genérica.
library;

sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Regla de negocio violada (validaciones de formulario, stock insuficiente…).
class ValidationException extends AppException {
  const ValidationException(super.message, {this.field});

  final String? field;
}

/// Violación de unicidad (folio, SKU duplicado, id repetido).
class ConflictException extends AppException {
  const ConflictException(super.message);
}

/// Error de persistencia local (Hive, E/S).
class StorageException extends AppException {
  const StorageException(super.message);
}

/// Archivo inválido o corrupto al importar/restaurar.
class ImportException extends AppException {
  const ImportException(super.message, {this.line});

  final int? line;
}
