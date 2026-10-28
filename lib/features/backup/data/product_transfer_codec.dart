import 'dart:convert';

import 'package:csv/csv.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsers.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';

/// Fila parseada de un CSV/JSON, ya normalizada.
class ParsedProduct {
  const ParsedProduct({
    required this.name,
    this.description = '',
    this.categoryName,
    this.sku = '',
    this.barcode = '',
    this.unit = 'pieza',
    this.cost = 0,
    required this.price,
    this.stock = 0,
    this.minStock = 0,
    this.active = true,
  });

  final String name;
  final String description;
  final String? categoryName;
  final String sku;
  final String barcode;
  final String unit;
  final int cost;
  final int price;
  final double stock;
  final int minStock;
  final bool active;
}

/// Error de una fila concreta, para mostrarlo claro al usuario (§33).
class RowError {
  const RowError(this.row, this.message);

  final int row;
  final String message;

  @override
  String toString() => 'Fila $row: $message';
}

/// Resultado del parseo, antes de escribir nada.
class ImportPreview {
  const ImportPreview({
    required this.total,
    required this.isNew,
    required this.isExisting,
    required this.errors,
    required this.products,
  });

  final int total;
  final int isNew;
  final int isExisting;
  final List<RowError> errors;
  final List<ParsedProduct> products;

  bool get canImport => products.isNotEmpty;
  int get errorCount => errors.length;
}

/// Convierte productos a CSV/JSON y viceversa (§32, §33).
///
/// El formato CSV usa encabezados en snake_case, exactamente los del ejemplo
/// del spec: nombre, descripcion, categoria, sku, unidad, costo, precio,
/// stock, stock_minimo, activo.
abstract final class ProductTransferCodec {
  const ProductTransferCodec._();

  static const List<String> csvHeaders = <String>[
    'nombre',
    'descripcion',
    'categoria',
    'sku',
    'unidad',
    'costo',
    'precio',
    'stock',
    'stock_minimo',
    'activo',
  ];

  // --- Exportar (§32) ---

  static String toCsv(List<Product> products, Map<String, Category> categories) {
    final List<List<dynamic>> rows = <List<dynamic>>[
      csvHeaders,
      for (final Product p in products)
        <dynamic>[
          p.name,
          p.description,
          p.categoryId == null ? '' : (categories[p.categoryId]?.name ?? ''),
          p.sku,
          p.unit,
          (p.cost / 100).toStringAsFixed(2),
          (p.price / 100).toStringAsFixed(2),
          p.stock,
          p.minStock,
          p.active,
        ],
    ];
    // Configuración tipo Excel: compatibilidad con Sheets y Excel.
    return excel.encode(rows);
  }

  static String toJson(List<Product> products, Map<String, Category> categories) {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'tipo': 'productos',
      'version': 1,
      'productos': products
          .map(
            (Product p) => <String, dynamic>{
              'nombre': p.name,
              'descripcion': p.description,
              'categoria': p.categoryId == null
                  ? null
                  : categories[p.categoryId]?.name,
              'sku': p.sku,
              'codigo_barras': p.barcode,
              'unidad': p.unit,
              // Pesos con dos decimales, igual que el CSV. Escribir aquí los
              // centavos crudos hacía que reimportar el propio archivo
              // multiplicara costo y precio por 100.
              'costo': (p.cost / 100).toStringAsFixed(2),
              'precio': (p.price / 100).toStringAsFixed(2),
              'stock': p.stock,
              'stock_minimo': p.minStock,
              'activo': p.active,
              'fecha_creacion': p.createdAt.toIso8601String(),
            },
          )
          .toList(),
    });
  }

  // --- Importar (§33) ---

  /// Parsea el contenido sin tocar la base de datos. `existingNames` y
  /// `existingSkus` sirven para clasificar nueva vs. existente.
  static ImportPreview parse(
    String content, {
    required Set<String> existingNames,
    required Set<String> existingSkus,
  }) {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw const ImportException('El archivo está vacío');
    }

    final List<ParsedProduct> products = <ParsedProduct>[];
    final List<RowError> errors = <RowError>[];

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      _parseJson(trimmed, products, errors);
    } else {
      _parseCsv(trimmed, products, errors);
    }

    int isNew = 0;
    int isExisting = 0;
    for (final ParsedProduct p in products) {
      final bool exists =
          existingNames.contains(_norm(p.name)) ||
          (p.sku.isNotEmpty && existingSkus.contains(p.sku.toLowerCase()));
      exists ? isExisting++ : isNew++;
    }

    return ImportPreview(
      total: products.length + errors.length,
      isNew: isNew,
      isExisting: isExisting,
      errors: errors,
      products: products,
    );
  }

  static void _parseJson(
    String content,
    List<ParsedProduct> out,
    List<RowError> errors,
  ) {
    Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException catch (e) {
      throw ImportException('JSON inválido: ${e.message}');
    }

    List<dynamic> list;
    if (decoded is List<dynamic>) {
      list = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final Object? raw = decoded['productos'] ?? decoded['products'];
      if (raw is List<dynamic>) {
        list = raw;
      } else {
        throw const ImportException(
          'El JSON no contiene una lista de productos',
        );
      }
    } else {
      throw const ImportException('Formato de JSON no reconocido');
    }

    for (int i = 0; i < list.length; i++) {
      final Object? entry = list[i];
      if (entry is! Map) {
        errors.add(RowError(i + 1, 'El registro no es un objeto'));
        continue;
      }
      final Map<String, dynamic> map = Map<String, dynamic>.from(entry);
      final ParsedProduct? product = _fromMap(map, i + 1, errors);
      if (product != null) out.add(product);
    }
  }

  static void _parseCsv(
    String content,
    List<ParsedProduct> out,
    List<RowError> errors,
  ) {
    List<List<dynamic>> rows;
    try {
      rows = csv.decode(content);
    } catch (e) {
      throw const ImportException('No se pudo leer el archivo CSV');
    }
    if (rows.isEmpty) return;

    // Encabezado: se normaliza para tolerar acentos, espacios y mayúsculas.
    final Map<String, int> headerIndex = <String, int>{};
    final List<dynamic> header = rows.first;
    for (int i = 0; i < header.length; i++) {
      headerIndex[Parsers.normalizeKey(header[i].toString())] = i;
    }

    if (!headerIndex.containsKey('nombre') || !headerIndex.containsKey('precio')) {
      throw const ImportException(
        'El CSV debe tener al menos las columnas "nombre" y "precio"',
      );
    }

    for (int r = 1; r < rows.length; r++) {
      final List<dynamic> row = rows[r];
      if (row.every((dynamic c) => c.toString().trim().isEmpty)) continue;

      final Map<String, dynamic> map = <String, dynamic>{};
      headerIndex.forEach((String key, int idx) {
        map[key] = idx < row.length ? row[idx] : null;
      });
      final ParsedProduct? product = _fromMap(map, r + 1, errors);
      if (product != null) out.add(product);
    }
  }

  /// Valida una fila y la convierte. Registra el error y devuelve `null` si
  /// es inválida: nunca se importa un registro malo (§33).
  static ParsedProduct? _fromMap(
    Map<String, dynamic> map,
    int rowNumber,
    List<RowError> errors,
  ) {
    String pick(String key) => map.containsKey(key) ? Parsers.asString(map[key]) : '';

    final String name = pick('nombre');
    if (name.isEmpty) {
      errors.add(RowError(rowNumber, 'Falta el nombre'));
      return null;
    }
    if (name.length > 80) {
      errors.add(RowError(rowNumber, 'Nombre demasiado largo (máx. 80)'));
      return null;
    }

    final String rawPrice = pick('precio');
    final int? price = Parsers.asCents(rawPrice);
    if (price == null) {
      errors.add(RowError(rowNumber, 'Precio inválido: "$rawPrice"'));
      return null;
    }
    if (price <= 0) {
      errors.add(RowError(rowNumber, 'El precio debe ser mayor a cero'));
      return null;
    }

    final String rawCost = pick('costo');
    final int? cost = rawCost.isEmpty ? 0 : Parsers.asCents(rawCost);
    if (cost == null) {
      errors.add(RowError(rowNumber, 'Costo inválido: "$rawCost"'));
      return null;
    }
    if (cost < 0) {
      errors.add(RowError(rowNumber, 'El costo no puede ser negativo'));
      return null;
    }
    if (cost > price) {
      errors.add(
        RowError(rowNumber, 'El costo no puede ser mayor al precio'),
      );
      return null;
    }

    final String rawStock = pick('stock');
    final double? stock = rawStock.isEmpty ? 0.0 : Parsers.asDouble(rawStock);
    if (stock == null || stock.isNaN || stock.isInfinite) {
      errors.add(RowError(rowNumber, 'Stock inválido: "$rawStock"'));
      return null;
    }
    if (stock < 0) {
      errors.add(RowError(rowNumber, 'El stock no puede ser negativo'));
      return null;
    }

    final String rawMin = pick('stock_minimo');
    final double? minStock = rawMin.isEmpty ? 0.0 : Parsers.asDouble(rawMin);
    if (minStock == null || minStock < 0) {
      errors.add(RowError(rowNumber, 'Stock mínimo inválido: "$rawMin"'));
      return null;
    }

    final String rawCategory = pick('categoria');
    if (rawCategory.length > 60) {
      errors.add(RowError(rowNumber, 'Categoría demasiado larga'));
      return null;
    }

    return ParsedProduct(
      name: name,
      description: pick('descripcion'),
      categoryName: rawCategory.isEmpty ? null : rawCategory,
      sku: pick('sku'),
      barcode: pick('codigo_barras'),
      unit: pick('unidad').isEmpty ? 'pieza' : pick('unidad'),
      cost: cost,
      price: price,
      stock: stock,
      minStock: minStock.round(),
      active: Parsers.asBool(map['activo'], fallback: true),
    );
  }

  static String _norm(String s) => s.trim().toLowerCase();
}

/// Formato de archivo de exportación de productos.
enum ProductExportFormat {
  csv('CSV', 'csv'),
  json('JSON', 'json');

  const ProductExportFormat(this.label, this.extension);

  final String label;
  final String extension;
}
