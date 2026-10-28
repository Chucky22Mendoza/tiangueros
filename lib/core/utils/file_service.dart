import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

/// Resultado de leer un archivo del dispositivo.
class PickedFile {
  const PickedFile({
    required this.path,
    required this.name,
    required this.bytes,
  });

  final String path;
  final String name;
  final Uint8List bytes;

  String get text => utf8.decode(bytes, allowMalformed: true);

  bool get looksLikeJson =>
      name.toLowerCase().endsWith('.json') ||
      text.trimLeft().startsWith('{') ||
      text.trimLeft().startsWith('[');
}

/// Lectura y escritura de archivos locales. Todo vive en el almacenamiento
/// interno de la app; nada sale a internet salvo que el usuario comparta el
/// archivo explícitamente (§6, §31).
abstract final class FileService {
  const FileService._();

  /// Raíz de los archivos de la app.
  ///
  /// [overrideBase] existe para tests: la app real siempre usa el directorio
  /// de documentos del sistema, pero los tests corren sin platform channels y
  /// necesitan una ruta real en disco.
  static Directory? overrideBase;

  static Future<Directory> _ensureDir(String name) async {
    final Directory base =
        overrideBase ?? await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${base.path}/$name');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Directorio de respaldos.
  static Future<Directory> backupDir() => _ensureDir('backups');

  /// Directorio de exportaciones CSV/JSON.
  static Future<Directory> exportDir() => _ensureDir('exports');

  /// Directorio del logo del negocio.
  static Future<Directory> logoDir() => _ensureDir('logos');

  /// Escribe contenido y devuelve la ruta. `filename` sin extensión.
  static Future<String> writeText(
    Directory dir,
    String filename,
    String content,
  ) async {
    final File file = File('${dir.path}/$filename');
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  /// Copia una imagen elegida por el usuario al directorio privado de la app.
  /// Así el logo sobrevive aunque el usuario borre el original.
  static Future<String> persistLogo(Uint8List bytes, String extension) async {
    final Directory dir = await logoDir();
    // Se eliminan logos previos: sólo hay uno activo a la vez.
    for (final File f in dir.listSync().whereType<File>()) {
      f.deleteSync();
    }
    final String name =
        'logo_${DateTime.now().millisecondsSinceEpoch}$extension';
    final File file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static void deleteFile(String? path) {
    if (path == null || path.isEmpty) return;
    final File f = File(path);
    if (f.existsSync()) f.deleteSync();
  }

  /// Nombre de archivo de respaldo con fecha: `tianguis_backup_2026-09-28.json`
  static String backupFileName() {
    final DateTime now = DateTime.now();
    final String y = now.year.toString().padLeft(4, '0');
    final String m = now.month.toString().padLeft(2, '0');
    final String d = now.day.toString().padLeft(2, '0');
    return 'tianguis_backup_$y-$m-$d.json';
  }

  static String productExportFileName(String extension) {
    final DateTime now = DateTime.now();
    final String y = now.year.toString().padLeft(4, '0');
    final String m = now.month.toString().padLeft(2, '0');
    final String d = now.day.toString().padLeft(2, '0');
    return 'productos_$y-$m-$d.$extension';
  }

  static String appVersion() => AppConstants.appVersion;
}
