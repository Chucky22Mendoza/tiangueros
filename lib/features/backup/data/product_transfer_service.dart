import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/file_service.dart';
import '../../../models/category.dart';
import '../../../models/enums.dart';
import '../../../models/inventory_movement.dart';
import '../../../models/product.dart';
import 'product_transfer_codec.dart';

/// Resultado de una importación ya aplicada.
class ImportOutcome {
  const ImportOutcome({
    this.created = 0,
    this.updated = 0,
    this.skipped = 0,
    this.categoriesCreated = 0,
  });

  final int created;
  final int updated;
  final int skipped;
  final int categoriesCreated;

  int get applied => created + updated;

  /// Resumen legible de lo que hizo la importación.
  String get summary =>
      '$created nuevos, $updated actualizados, $skipped sin cambios'
      '${categoriesCreated > 0 ? ', $categoriesCreated categorías' : ''}';
}

/// Importa y exporta sólo productos, independiente del backup completo (§31).
class ProductTransferService {
  ProductTransferService();

  static const Uuid _uuid = Uuid();

  // --- Exportar (§32) ---

  /// Escribe el archivo y devuelve la ruta para compartirlo.
  Future<String> exportProducts(ProductExportFormat format) async {
    final List<Product> products = AppDatabase.products.values.toList()
      ..sort((Product a, Product b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (products.isEmpty) {
      throw const ValidationException('No hay productos para exportar');
    }

    final Map<String, Category> categories = <String, Category>{
      for (final Category c in AppDatabase.categories.values) c.id: c,
    };

    final String content = switch (format) {
      ProductExportFormat.csv =>
        ProductTransferCodec.toCsv(products, categories),
      ProductExportFormat.json =>
        ProductTransferCodec.toJson(products, categories),
    };

    final Directory dir = await FileService.exportDir();
    return FileService.writeText(
      dir,
      FileService.productExportFileName(format.extension),
      content,
    );
  }

  // --- Importar (§33) ---

  /// Analiza el archivo sin escribir. La UI muestra el resultado antes de
  /// preguntar cómo tratar los duplicados.
  ImportPreview preview(String content) {
    final Set<String> names = AppDatabase.products.values
        .map((Product p) => p.name.trim().toLowerCase())
        .toSet();
    final Set<String> skus = AppDatabase.products.values
        .where((Product p) => p.sku.trim().isNotEmpty)
        .map((Product p) => p.sku.trim().toLowerCase())
        .toSet();
    return ProductTransferCodec.parse(
      content,
      existingNames: names,
      existingSkus: skus,
    );
  }

  /// Aplica la importación. Los registros inválidos nunca se escriben.
  Future<ImportOutcome> importProducts(
    ImportPreview preview,
    ImportConflictStrategy strategy,
  ) async {
    if (!preview.canImport) {
      throw const ImportException(
        'No hay productos válidos para importar',
      );
    }

    final Map<String, Category> categoriesByName = <String, Category>{
      for (final Category c in AppDatabase.categories.values)
        c.name.trim().toLowerCase(): c,
    };
    int categoriesCreated = 0;

    int created = 0;
    int updated = 0;
    int skipped = 0;

    for (final ParsedProduct row in preview.products) {
      // 1. Resolver o crear la categoría por nombre.
      String? categoryId;
      final String catName = row.categoryName?.trim() ?? '';
      if (catName.isNotEmpty) {
        final String key = catName.toLowerCase();
        final Category? found = categoriesByName[key];
        if (found != null) {
          categoryId = found.id;
        } else {
          final Category created_ = Category(
            id: _uuid.v4(),
            name: catName,
            colorValue: 0,
          );
          await AppDatabase.categories.put(created_.id, created_);
          categoriesByName[key] = created_;
          categoryId = created_.id;
          categoriesCreated++;
        }
      }

      // 2. Localizar el producto existente por nombre o SKU.
      final Product? existing = _findExisting(row);

      if (existing == null) {
        final Product product = Product(
          id: _uuid.v4(),
          name: row.name,
          description: row.description,
          categoryId: categoryId,
          sku: row.sku,
          barcode: row.barcode,
          unit: row.unit,
          cost: row.cost,
          price: row.price,
          stock: row.stock,
          minStock: row.minStock,
          active: row.active,
        );
        await AppDatabase.products.put(product.id, product);
        created++;
        continue;
      }

      if (strategy == ImportConflictStrategy.ignorar) {
        skipped++;
        continue;
      }

      // Actualizar: el stock se adopta tal cual, con movimiento de ajuste para
      // que el inventario quede trazado.
      final double previousStock = existing.stock;
      existing.name = row.name;
      existing.description = row.description;
      if (categoryId != null) existing.categoryId = categoryId;
      existing.sku = row.sku.isEmpty ? existing.sku : row.sku;
      if (row.barcode.isNotEmpty) existing.barcode = row.barcode;
      existing.unit = row.unit;
      existing.cost = row.cost;
      existing.price = row.price;
      existing.minStock = row.minStock;
      existing.active = row.active;
      existing.updatedAt = DateTime.now();
      if (previousStock != row.stock) {
        existing.stock = row.stock;
        await InventoryMovementBridge.record(
          product: existing,
          previousStock: previousStock,
          newStock: row.stock,
          reason: 'Actualización por importación',
        );
      }
      await AppDatabase.products.put(existing.id, existing);
      updated++;
    }

    return ImportOutcome(
      created: created,
      updated: updated,
      skipped: skipped,
      categoriesCreated: categoriesCreated,
    );
  }

  Product? _findExisting(ParsedProduct row) {
    final String nameKey = row.name.trim().toLowerCase();
    for (final Product p in AppDatabase.products.values) {
      if (p.name.trim().toLowerCase() == nameKey) return p;
    }
    if (row.sku.trim().isNotEmpty) {
      final String skuKey = row.sku.trim().toLowerCase();
      for (final Product p in AppDatabase.products.values) {
        if (p.sku.trim().toLowerCase() == skuKey) return p;
      }
    }
    return null;
  }
}

/// Deja rastro del cambio de stock al adoptar el stock del archivo.
abstract final class InventoryMovementBridge {
  const InventoryMovementBridge._();

  static Future<void> record({
    required Product product,
    required double previousStock,
    required double newStock,
    required String reason,
  }) async {
    final double delta = (newStock - previousStock).abs();
    if (delta == 0) return;
    final InventoryMovement movement = InventoryMovement(
      id: const Uuid().v4(),
      productId: product.id,
      productName: product.name,
      type: delta > 0 ? MovementType.entrada : MovementType.ajuste,
      quantity: delta,
      previousStock: previousStock,
      newStock: newStock,
      reason: reason,
    );
    await AppDatabase.movements.put(movement.id, movement);
  }
}
