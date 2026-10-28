import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/file_service.dart';
import '../../../models/app_settings.dart';
import '../../../models/business_settings.dart';
import '../../../models/cash_movement.dart';
import '../../../models/category.dart';
import '../../../models/daily_closing.dart';
import '../../../models/enums.dart';
import '../../../models/expense.dart';
import '../../../models/inventory_movement.dart';
import '../../../models/product.dart';
import '../../../models/sale.dart';

/// Resumen de lo que se restauró, para confirmarlo al usuario (§34).
class RestoreResult {
  const RestoreResult({
    this.products = 0,
    this.categories = 0,
    this.sales = 0,
    this.movements = 0,
    this.expenses = 0,
    this.cash = 0,
    this.closings = 0,
  });

  final int products;
  final int categories;
  final int sales;
  final int movements;
  final int expenses;
  final int cash;
  final int closings;

  int get totalRecords =>
      products + categories + sales + movements + expenses + cash + closings;

  /// Resumen legible de lo que se restauró.
  String get summary =>
      '$totalRecords registros '
      '($products productos, $sales ventas, $expenses gastos)';
}

/// Respaldo completo en JSON: todos los datos del negocio (§34, §35).
///
/// El archivo lleva `backup_version`, `app_version` y `created_at` para
/// poder migrar en el futuro. Restaurar **reemplaza** los datos actuales.
class BackupService {
  BackupService();

  static const Uuid _uuid = Uuid();

  /// Construye el JSON del respaldo. Además de `toJson()` de cada modelo,
  /// incluye un bloque `raw` con los campos exactos de Hive, para que una
  /// restauración sea un `putAll` fiel.
  String buildJson() {
    final Map<String, dynamic> data = <String, dynamic>{
      'negocio': <String, dynamic>{
        'nombre': AppDatabase.business
            .get(AppDatabase.businessKey)
            ?.businessName,
        'encargado': AppDatabase.business
            .get(AppDatabase.businessKey)
            ?.ownerName,
        'logo': AppDatabase.business.get(AppDatabase.businessKey)?.logoPath,
      },
      'preferencias': <String, dynamic>{
        'tema': AppDatabase.settings
            .get(AppDatabase.settingsKey)
            ?.themePreference
            .name,
        'moneda': AppDatabase.settings.get(AppDatabase.settingsKey)?.currency,
        'formato_fecha': AppDatabase.settings
            .get(AppDatabase.settingsKey)
            ?.dateFormat
            .name,
        'stock_minimo':
            AppDatabase.settings.get(AppDatabase.settingsKey)?.defaultMinStock,
        'prefijo_ventas':
            AppDatabase.settings.get(AppDatabase.settingsKey)?.salePrefix,
      },
      'categorias': AppDatabase.categories.values
          .map(
            (Category c) => <String, dynamic>{
              'id': c.id,
              'nombre': c.name,
              'color': c.colorValue,
              'creada': c.createdAt.toIso8601String(),
            },
          )
          .toList(),
      'productos': AppDatabase.products.values
          .map(
            (Product p) => <String, dynamic>{
              'id': p.id,
              'nombre': p.name,
              'descripcion': p.description,
              'categoria_id': p.categoryId,
              'sku': p.sku,
              'codigo_barras': p.barcode,
              'unidad': p.unit,
              'costo': p.cost,
              'precio': p.price,
              'stock': p.stock,
              'stock_minimo': p.minStock,
              'activo': p.active,
              'creado': p.createdAt.toIso8601String(),
              'actualizado': p.updatedAt.toIso8601String(),
            },
          )
          .toList(),
      'ventas': AppDatabase.sales.values.map((Sale s) => s.toJson()).toList(),
      'movimientos': AppDatabase.movements.values
          .map(
            (InventoryMovement m) => <String, dynamic>{
              'id': m.id,
              'producto_id': m.productId,
              'producto': m.productName,
              'tipo': m.type.name,
              'cantidad': m.quantity,
              'stock_anterior': m.previousStock,
              'stock_nuevo': m.newStock,
              'motivo': m.reason,
              'referencia': m.referenceId,
              'fecha': m.date.toIso8601String(),
            },
          )
          .toList(),
      'gastos': AppDatabase.expenses.values
          .map((Expense e) => e.toJson())
          .toList(),
      'caja': AppDatabase.cash.values
          .map((CashMovement c) => c.toJson())
          .toList(),
      'cierres': AppDatabase.closings.values
          .map((DailyClosing c) => c.toJson())
          .toList(),
      'meta': <String, dynamic>{
        AppConstants.keyNextFolio: AppDatabase.meta.get(
          AppConstants.keyNextFolio,
          defaultValue: 1,
        ),
      },
    };

    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'backup_version': AppConstants.backupVersion,
      'app_version': AppConstants.appVersion,
      'created_at': DateTime.now().toIso8601String(),
      'data': data,
    });
  }

  /// Exporta a un archivo y devuelve la ruta.
  Future<String> exportToFile() async {
    final Directory dir = await FileService.backupDir();
    return FileService.writeText(
      dir,
      FileService.backupFileName(),
      buildJson(),
    );
  }

  /// Inspecciona un respaldo sin tocar la base de datos. Permite al usuario
  /// ver qué trae antes de confirmar la restauración.
  ImportPreviewOfBackup inspect(String content) {
    final Map<String, dynamic> decoded = _dataRootOf(_decode(content));
    final Map<String, dynamic> data = _dataOf(decoded);
    return ImportPreviewOfBackup(
      backupVersion: _asInt(decoded['backup_version']),
      appVersion: decoded['app_version'] as String? ?? 'desconocida',
      createdAt: DateTime.tryParse(decoded['created_at'] as String? ?? ''),
      counts: <String, int>{
        'Categorías': _listOf(data, 'categorias').length,
        'Productos': _listOf(data, 'productos').length,
        'Ventas': _listOf(data, 'ventas').length,
        'Movimientos': _listOf(data, 'movimientos').length,
        'Gastos': _listOf(data, 'gastos').length,
        'Movimientos de caja': _listOf(data, 'caja').length,
        'Cierres': _listOf(data, 'cierres').length,
      },
    );
  }

  /// Restaura desde el respaldo. **Reemplaza** todos los datos actuales.
  Future<RestoreResult> restoreFromContent(String content) async {
    final Map<String, dynamic> data = _dataOf(_dataRootOf(_decode(content)));

    // Secuencial y esperado: `Box.clear()` y `Box.put()` son asíncronos. Si no
    // se esperan, el método devolvería antes de que el respaldo quedara escrito
    // y un cierre abrupto de la app perdería los datos restaurados.
    final RestoreResult result = RestoreResult(
      categories: await _restoreCategories(data),
      products: await _restoreProducts(data),
      sales: await _restoreSales(data),
      movements: await _restoreMovements(data),
      expenses: await _restoreExpenses(data),
      cash: await _restoreCash(data),
      closings: await _restoreClosings(data),
    );

    await _restoreBusiness(data);
    await _restorePreferences(data);
    await _restoreMeta(data);

    return result;
  }

  Future<RestoreResult> restoreFromFile(String path) async {
    final File file = File(path);
    if (!file.existsSync()) {
      throw const ImportException('No se encontró el archivo de respaldo');
    }
    return restoreFromContent(await file.readAsString());
  }

  // --- Decodificación y validación ---

  Object? _decode(String content) {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const ImportException('El archivo está vacío');
    }
    try {
      return jsonDecode(trimmed);
    } on FormatException catch (e) {
      throw ImportException('El archivo no es un JSON válido: ${e.message}');
    }
  }

  /// Valida la raíz del respaldo y devuelve sus campos.
  static Map<String, dynamic> _dataRootOf(Object? decoded) {
    if (decoded is! Map) {
      throw const ImportException(
        'El respaldo no tiene el formato esperado',
      );
    }
    final Map<String, dynamic> root = Map<String, dynamic>.from(decoded);
    final int version = _asInt(root['backup_version']);
    if (version == 0) {
      throw const ImportException(
        'El archivo no tiene "backup_version": no es un respaldo de Tianguis Control',
      );
    }
    if (version > AppConstants.backupVersion) {
      throw ImportException(
        'El respaldo es de una versión más nueva de la app '
        '(backup $version). Actualiza la aplicación para restaurarlo.',
      );
    }

    return root;
  }

  static Map<String, dynamic> _dataOf(Map<String, dynamic> root) {
    final Object? data = root['data'];
    if (data is! Map) {
      throw const ImportException('El respaldo no contiene datos');
    }
    return Map<String, dynamic>.from(data);
  }

  static List<Map<String, dynamic>> _listOf(
    Map<String, dynamic> data,
    String key,
  ) {
    final Object? raw = data[key];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String _str(Map<String, dynamic> map, String key) =>
      map[key] as String? ?? '';

  static int _int(Map<String, dynamic> map, String key) =>
      _asInt(map[key]);

  static double _dbl(Map<String, dynamic> map, String key) {
    final Object? v = map[key];
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  // --- Restauración por bloque ---

  Future<void> _restoreBusiness(Map<String, dynamic> data) async {
    final Object? raw = data['negocio'];
    if (raw is! Map) return;
    final Map<String, dynamic> neg = Map<String, dynamic>.from(raw);
    final String name = _str(neg, 'nombre').trim();
    final String owner = _str(neg, 'encargado').trim();
    if (name.isEmpty && owner.isEmpty) return;

    final BusinessSettings settings =
        AppDatabase.business.get(AppDatabase.businessKey) ?? BusinessSettings();
    if (name.isNotEmpty) settings.businessName = name;
    if (owner.isNotEmpty) settings.ownerName = owner;
    final String logo = _str(neg, 'logo').trim();
    if (logo.isNotEmpty) settings.logoPath = logo;
    await AppDatabase.business.put(AppDatabase.businessKey, settings);
  }

  Future<void> _restorePreferences(Map<String, dynamic> data) async {
    final Object? raw = data['preferencias'];
    if (raw is! Map) return;
    final Map<String, dynamic> pref = Map<String, dynamic>.from(raw);
    final AppSettings s =
        AppDatabase.settings.get(AppDatabase.settingsKey) ?? AppSettings();

    s.themePreference = _enumByName(
      _str(pref, 'tema'),
      ThemePreference.values,
      s.themePreference,
    );
    s.dateFormat = _enumByName(
      _str(pref, 'formato_fecha'),
      DateFormatPreference.values,
      s.dateFormat,
    );
    final String currency = _str(pref, 'moneda').trim();
    if (currency.isNotEmpty) s.currency = currency;
    final int minStock = _int(pref, 'stock_minimo');
    if (minStock >= 0) s.defaultMinStock = minStock;
    final String prefix = _str(pref, 'prefijo_ventas').trim();
    if (prefix.isNotEmpty) s.salePrefix = prefix.toUpperCase();

    await AppDatabase.settings.put(AppDatabase.settingsKey, s);
  }

  Future<int> _restoreCategories(Map<String, dynamic> data) async {
    final List<Map<String, dynamic>> rows = _listOf(data, 'categorias');
    await AppDatabase.categories.clear();
    int written = 0;
    for (final Map<String, dynamic> r in rows) {
      final String name = _str(r, 'nombre').trim();
      if (name.isEmpty) continue;
      final Category category = Category(
        id: _str(r, 'id').isEmpty ? _uuid.v4() : _str(r, 'id'),
        name: name,
        colorValue: _int(r, 'color'),
        createdAt: DateTime.tryParse(_str(r, 'creada')),
      );
      await AppDatabase.categories.put(category.id, category);
      written++;
    }
    return written;
  }

  Future<int> _restoreProducts(Map<String, dynamic> data) async {
    final List<Map<String, dynamic>> rows = _listOf(data, 'productos');
    await AppDatabase.products.clear();
    for (final Map<String, dynamic> r in rows) {
      final String name = _str(r, 'nombre').trim();
      if (name.isEmpty) continue;
      final String id = _str(r, 'id').isEmpty ? _uuid.v4() : _str(r, 'id');
      final Product product = Product(
        id: id,
        name: name,
        description: _str(r, 'descripcion'),
        categoryId: r['categoria_id'] as String?,
        sku: _str(r, 'sku'),
        barcode: _str(r, 'codigo_barras'),
        unit: _str(r, 'unidad').isEmpty ? 'pieza' : _str(r, 'unidad'),
        cost: _int(r, 'costo'),
        price: _int(r, 'precio'),
        stock: _dbl(r, 'stock'),
        minStock: _int(r, 'stock_minimo'),
        active: r['activo'] as bool? ?? true,
        createdAt: DateTime.tryParse(_str(r, 'creado')),
        updatedAt: DateTime.tryParse(_str(r, 'actualizado')),
      );
      await AppDatabase.products.put(id, product);
    }
    return rows.length;
  }

  Future<int> _restoreSales(Map<String, dynamic> data) async {
    final List<Map<String, dynamic>> rows = _listOf(data, 'ventas');
    await AppDatabase.sales.clear();
    int written = 0;
    for (final Map<String, dynamic> r in rows) {
      try {
        final Sale sale = Sale.fromJson(r);
        if (sale.id.isEmpty) continue;
        await AppDatabase.sales.put(sale.id, sale);
        written++;
      } catch (_) {
        // Una venta corrupta no debe abortar toda la restauración.
      }
    }
    return written;
  }

  Future<int> _restoreMovements(Map<String, dynamic> data) async {
    final List<Map<String, dynamic>> rows = _listOf(data, 'movimientos');
    await AppDatabase.movements.clear();
    int written = 0;
    for (final Map<String, dynamic> r in rows) {
      final String productId = _str(r, 'producto_id');
      if (productId.isEmpty) continue;
      final InventoryMovement movement = InventoryMovement(
        id: _str(r, 'id').isEmpty ? _uuid.v4() : _str(r, 'id'),
        productId: productId,
        productName: _str(r, 'producto'),
        type: MovementType.fromName(_str(r, 'tipo')),
        quantity: _dbl(r, 'cantidad'),
        previousStock: _dbl(r, 'stock_anterior'),
        newStock: _dbl(r, 'stock_nuevo'),
        reason: _str(r, 'motivo'),
        referenceId: r['referencia'] as String?,
        date: DateTime.tryParse(_str(r, 'fecha')),
      );
      await AppDatabase.movements.put(movement.id, movement);
      written++;
    }
    return written;
  }

  Future<int> _restoreExpenses(Map<String, dynamic> data) async {
    final List<Map<String, dynamic>> rows = _listOf(data, 'gastos');
    await AppDatabase.expenses.clear();
    int written = 0;
    for (final Map<String, dynamic> r in rows) {
      try {
        final Expense expense = Expense.fromJson(r);
        if (expense.id.isEmpty) continue;
        await AppDatabase.expenses.put(expense.id, expense);
        written++;
      } catch (_) {
        // idem: una fila mala no detiene el resto.
      }
    }
    return written;
  }

  Future<int> _restoreCash(Map<String, dynamic> data) async {
    final List<Map<String, dynamic>> rows = _listOf(data, 'caja');
    await AppDatabase.cash.clear();
    int written = 0;
    for (final Map<String, dynamic> r in rows) {
      try {
        final CashMovement movement = CashMovement.fromJson(r);
        if (movement.id.isEmpty) continue;
        await AppDatabase.cash.put(movement.id, movement);
        written++;
      } catch (_) {}
    }
    return written;
  }

  Future<int> _restoreClosings(Map<String, dynamic> data) async {
    final List<Map<String, dynamic>> rows = _listOf(data, 'cierres');
    await AppDatabase.closings.clear();
    int written = 0;
    for (final Map<String, dynamic> r in rows) {
      try {
        final DailyClosing closing = DailyClosing.fromJson(r);
        if (closing.id.isEmpty) continue;
        await AppDatabase.closings.put(closing.id, closing);
        written++;
      } catch (_) {}
    }
    return written;
  }

  Future<void> _restoreMeta(Map<String, dynamic> data) async {
    final Object? meta = data['meta'];
    int next = 1;
    if (meta is Map) {
      next = _asInt(Map<String, dynamic>.from(meta)[AppConstants.keyNextFolio]);
    }
    // Se toma el mayor entre el meta guardado y el folio más alto visto, para
    // que restaurar un respaldo antiguo nunca reutilice folios (§38).
    final int highest = AppDatabase.sales.values
        .map((Sale s) {
          final int dash = s.folio.lastIndexOf('-');
          return dash < 0 ? 0 : (int.tryParse(s.folio.substring(dash + 1)) ?? 0);
        })
        .fold<int>(0, (int a, int b) => a > b ? a : b);
    await AppDatabase.meta.put(
      AppConstants.keyNextFolio,
      next > highest + 1 ? next : highest + 1,
    );
  }

  /// Resuelve un enum por nombre, cayendo al valor por defecto.
  static T _enumByName<T extends Enum>(
    String name,
    List<T> values,
    T fallback,
  ) {
    for (final T value in values) {
      if ((value as Enum).name == name) return value;
    }
    return fallback;
  }
}

/// Vista previa de un respaldo antes de restaurar.
class ImportPreviewOfBackup {
  const ImportPreviewOfBackup({
    required this.backupVersion,
    required this.appVersion,
    required this.createdAt,
    required this.counts,
  });

  final int backupVersion;
  final String appVersion;
  final DateTime? createdAt;
  final Map<String, int> counts;

  int get totalRecords =>
      counts.values.fold<int>(0, (int a, int b) => a + b);

  /// Resumen de una línea para la confirmación previa a restaurar.
  String get summary {
    final StringBuffer b = StringBuffer();
    if (createdAt != null) {
      b.write('Creado el ${createdAt!.toIso8601String().split('T').first}.');
    }
    b.write(' Trae $totalRecords registros:');
    counts.forEach((String key, int value) {
      if (value > 0) b.write(' $value ${key.toLowerCase()},');
    });
    return b.toString();
  }
}
