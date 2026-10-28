import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../errors/app_exception.dart';

/// Selección de archivos para respaldos e importaciones (§34).
///
/// Envuelve `file_picker` para que el resto de la app no dependa del plugin y
/// los errores lleguen ya traducidos como [ImportException].
abstract final class PickService {
  const PickService._();

  /// Abre el selector y devuelve la ruta del archivo elegido, o `null` si el
  /// usuario cancela.
  ///
  /// [type] acepta los filtros de `file_picker` sin el punto, por ejemplo
  /// `json` o `csv,json`.
  static Future<String?> pick({String type = 'json,csv'}) async {
    try {
      final List<String> extensions = type
          .split(',')
          .map((String t) => t.trim().replaceFirst(RegExp(r'^\*?\.?'), '').toLowerCase())
          .where((String t) => t.isNotEmpty)
          .toList();

      final PlatformFile? file = await FilePicker.pickFile(
        type: extensions.isEmpty ? FileType.any : FileType.custom,
        allowedExtensions: extensions.isEmpty ? null : extensions,
      );
      if (file == null) return null;
      final String? path = file.path;
      if (path == null) {
        throw const ImportException('No se pudo leer el archivo seleccionado');
      }
      return path;
    } on ImportException {
      rethrow;
    } catch (e) {
      throw ImportException('No se pudo abrir el archivo: $e');
    }
  }

  /// Borra un archivo si existe. No falla si ya no está.
  static void deleteIfExists(String? path) {
    if (path == null) return;
    final File file = File(path);
    if (file.existsSync()) {
      try {
        file.deleteSync();
      } catch (_) {
        // Un archivo que no se puede borrar no debe romper el flujo.
      }
    }
  }
}
