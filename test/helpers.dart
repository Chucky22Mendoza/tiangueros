import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:tianguis_control/core/database/app_database.dart';
import 'package:tianguis_control/core/utils/file_service.dart';

/// Base de los tests: Hive real en un directorio temporal.
///
/// No se usa `Hive.initFlutter` porque en tests no hay `path_provider`; lo que
/// importa es que los repositorios hablen con las mismas cajas que en la app.
Directory? _dir;

/// Abre la base de datos de prueba.
///
/// [autoClose] registra la limpieza automática en el `tearDown`. Debe ser
/// `false` dentro de `testWidgets`: ahí el `tearDown` corre en la zona de async
/// falsa, y un `Hive.close()` (IO real) nunca termina, dejando el test colgado
/// hasta que vence el tiempo. En esos casos hay que cerrar con
/// [closeTestDatabase] dentro de `tester.runAsync`.
Future<void> openTestDatabase({bool autoClose = true}) async {
  final Directory dir = await Directory.systemTemp.createTemp('tianguis_test_');
  _dir = dir;
  await AppDatabase.openForTesting(dir.path);
  // Los servicios que escriben archivos usan el directorio de documentos, que
  // en tests no existe: se les da la carpeta temporal.
  FileService.overrideBase = dir;
  if (autoClose) addTearDown(closeTestDatabase);
}

/// Deja las cajas vacías sin cerrar Hive.
///
/// Es lo que usan los tests de widget: `Hive.close()` se queda colgado si
/// quedan suscripciones `box.watch()` vivas (los `StreamProvider` de la app),
/// y dentro de `testWidgets` no hay forma de esperar a que terminen. Vaciar las
/// cajas entre tests evita el problema y deja cada uno con datos limpios.
Future<void> clearTestDatabase() async {
  await AppDatabase.products.clear();
  await AppDatabase.sales.clear();
  await AppDatabase.movements.clear();
  await AppDatabase.expenses.clear();
  await AppDatabase.cash.clear();
  await AppDatabase.closings.clear();
  await AppDatabase.categories.clear();
  await AppDatabase.settings.clear();
  await AppDatabase.business.clear();
  await AppDatabase.meta.clear();
}

/// Abre la base para tests de widget: sin cierre automático, vaciada al entrar.
Future<void> openTestDatabaseForWidgetTests() async {
  await openTestDatabase(autoClose: false);
  await clearTestDatabase();
}

/// Cierra Hive y borra la carpeta temporal. Ver [openTestDatabase].
Future<void> closeTestDatabase() async {
  await Hive.close();
  FileService.overrideBase = null;
  final Directory? dir = _dir;
  _dir = null;
  if (dir != null && dir.existsSync()) await dir.delete(recursive: true);
}
