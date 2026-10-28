import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tianguis_control/core/database/app_database.dart';
import 'package:tianguis_control/core/errors/app_exception.dart';
import 'package:tianguis_control/features/backup/data/backup_service.dart';
import 'package:tianguis_control/features/backup/data/product_transfer_service.dart';
import 'package:tianguis_control/models/enums.dart';
import 'package:tianguis_control/models/inventory_movement.dart';
import 'package:tianguis_control/features/backup/data/product_transfer_codec.dart';
import 'package:tianguis_control/models/product.dart';
import 'package:tianguis_control/models/sale.dart';
import 'package:tianguis_control/repositories/inventory_repository.dart';
import 'package:tianguis_control/repositories/product_repository.dart';
import 'package:tianguis_control/repositories/sales_repository.dart';

import 'helpers.dart';

void main() {
  late BackupService backup;
  late ProductTransferService transfer;
  late ProductRepository products;
  late SalesRepository sales;

  setUp(() async {
    await openTestDatabase();
    backup = BackupService();
    transfer = ProductTransferService();
    products = ProductRepository();
    sales = SalesRepository(InventoryRepository());
  });

  group('BackupService', () {
    test('crea un respaldo con todo el contenido y lo inspecciona bien', () async {
      final Product p = await products.create(
        name: 'Refresco',
        cost: 1000,
        price: 1500,
        sku: 'ref-350',
        stock: 10,
      );
      await sales.checkout(
        lines: <CartLine>[
          CartLine(
            productId: p.id,
            productName: p.name,
            unitCost: p.cost,
            unitPrice: p.price,
            quantity: 2,
            availableStock: p.stock,
          ),
        ],
        paymentMethod: PaymentMethod.efectivo,
      );

      final Map<String, dynamic> data =
          jsonDecode(backup.buildJson()) as Map<String, dynamic>;
      expect(data['backup_version'], isNotNull);
      expect(data['data']['productos'], hasLength(1));
      expect(data['data']['ventas'], hasLength(1));
      expect(data['data']['movimientos'], isNotEmpty);
      expect(data['data']['caja'], isNotEmpty);

      final ImportPreviewOfBackup preview = backup.inspect(backup.buildJson());
      expect(preview.backupVersion, greaterThan(0));
      expect(preview.counts['Productos'], 1);
      expect(preview.counts['Ventas'], 1);
      expect(preview.totalRecords, greaterThan(3));
      expect(preview.summary, contains('productos'));
    });

    test('restaurar deja los datos igual que estaban', () async {
      await products.create(name: 'Café', cost: 2000, price: 3000, stock: 5);
      final String json = backup.buildJson();
      final String originalProductId = AppDatabase.products.values.single.id;

      // se borra todo y se restaura
      await AppDatabase.wipeAll();
      expect(AppDatabase.products, isEmpty);

      final RestoreResult result = await backup.restoreFromContent(json);

      expect(result.totalRecords, greaterThan(0));
      expect(AppDatabase.products.length, 1);
      expect(AppDatabase.products.values.single.id, originalProductId);
      expect(AppDatabase.products.values.single.name, 'Café');
      // los enums sobreviven el viaje por disco
      expect(AppDatabase.products.values.single.price, 3000);
    });

    test('los enums de venta se guardan y se leen con el mismo valor', () async {
      final Product p = await products.create(
        name: 'Té',
        cost: 1000,
        price: 1500,
        stock: 5,
      );
      final SaleResult r = await sales.checkout(
        lines: <CartLine>[
          CartLine(
            productId: p.id,
            productName: p.name,
            unitCost: p.cost,
            unitPrice: p.price,
            quantity: 1,
            availableStock: p.stock,
          ),
        ],
        paymentMethod: PaymentMethod.efectivo,
      );

      final String json = backup.buildJson();
      await AppDatabase.wipeAll();
      await backup.restoreFromContent(json);

      final Sale restaurada = AppDatabase.sales.get(r.sale.id)!;
      expect(restaurada.paymentMethod, PaymentMethod.efectivo);
      expect(restaurada.status, SaleStatus.activa);
      final InventoryMovement m = AppDatabase.movements.values.first;
      expect(m.type, MovementType.venta);
    });
  });

  group('ProductTransferService', () {
    test('exporta a JSON y a CSV legibles', () async {
      await products.create(
        name: 'Refresco, lata',
        cost: 1000,
        price: 1500,
        sku: 'ref-350',
        barcode: '7501234567890',
        stock: 10,
      );

      final String jsonPath = await transfer.exportProducts(ProductExportFormat.json);
      expect(jsonPath, endsWith('.json'));
      final String json = await File(jsonPath).readAsString();
      expect(json, contains('Refresco'));
      final ImportPreview previewJson = transfer.preview(json);
      expect(previewJson.total, 1);
      expect(previewJson.canImport, isTrue);

      final String csvPath = await transfer.exportProducts(ProductExportFormat.csv);
      expect(csvPath, endsWith('.csv'));
      final String csv = await File(csvPath).readAsString();
      expect(csv, contains('Refresco, lata'));
      expect(csv.split('\n').first, contains('sku'));
    });

    test('exportar y reimportar deja el producto igual (ida y vuelta)', () async {
      // Cada formato se prueba desde cero: el CSV no lleva código de barras,
      // así que encadenarlos perdería ese campo antes de exportar el segundo.
      for (final ProductExportFormat format in ProductExportFormat.values) {
        await AppDatabase.products.clear();
        await products.create(
          name: 'Refresco',
          description: 'Lata 350ml',
          cost: 1250,
          price: 1800,
          sku: 'ref-350',
          barcode: '7501234567890',
          stock: 12.5,
          minStock: 4,
          unit: 'botella',
        );

        final String raw =
            await File(await transfer.exportProducts(format)).readAsString();

        // catálogo vacío, como si fuera otra phone
        await AppDatabase.products.clear();
        expect(AppDatabase.products, isEmpty);

        final ImportPreview preview = transfer.preview(raw);
        expect(preview.canImport, isTrue, reason: 'formato ${format.name}');
        expect(preview.isNew, 1, reason: 'formato ${format.name}');

        final ImportOutcome outcome = await transfer.importProducts(
          preview,
          ImportConflictStrategy.actualizar,
        );
        expect(outcome.created, 1, reason: 'formato ${format.name}');

        final Product p = AppDatabase.products.values.single;
        expect(p.name, 'Refresco', reason: 'formato ${format.name}');
        expect(p.description, 'Lata 350ml');
        expect(p.cost, 1250, reason: 'costo en formato ${format.name}');
        expect(p.price, 1800, reason: 'precio en formato ${format.name}');
        expect(p.stock, 12.5);
        expect(p.minStock, 4);
        expect(p.unit, 'botella');
        expect(p.sku, 'ref-350');
        // El CSV de §32 no trae columna de código de barras, así que sólo el
        // JSON lo conserva. Es lo que dice el formato, no un error.
        if (format == ProductExportFormat.json) {
          expect(p.barcode, '7501234567890');
        }
      }
    });

    test('previsualiza sin escribir nada y detecta existentes', () async {
      final Product existente = await products.create(
        name: 'Refresco',
        cost: 1000,
        price: 1500,
        sku: 'ref-350',
        stock: 10,
      );

      final String json = await File(
        await transfer.exportProducts(ProductExportFormat.json),
      ).readAsString();
      final ImportPreview preview = transfer.preview(json);
      expect(preview.total, 1);
      expect(preview.isExisting, 1);
      expect(preview.isNew, 0);
      // previsualizar no toca la base
      expect(AppDatabase.products.length, 1);
      expect(existente.price, 1500);
    });

    test('importar con estrategia actualizar conserva el id', () async {
      final Product existente = await products.create(
        name: 'Refresco',
        cost: 1000,
        price: 1500,
        sku: 'ref-350',
        stock: 10,
      );
      final String path = await transfer.exportProducts(ProductExportFormat.json);

      // se cambia el precio en el "archivo" (pesos, no centavos)
      final String raw = await File(path).readAsString();
      // `json` es el nombre de un getter de dart:convert; aquí se renombra
      final String editado = raw.replaceFirst('"precio": "15.00"', '"precio": "18.00"');
      expect(editado, isNot(raw), reason: 'el precio debe cambiar en el archivo');

      final ImportPreview preview = transfer.preview(editado);
      final ImportOutcome outcome = await transfer.importProducts(
        preview,
        ImportConflictStrategy.actualizar,
      );

      expect(outcome.updated, 1);
      expect(outcome.applied, 1);
      expect(AppDatabase.products.length, 1);
      final Product p = AppDatabase.products.get(existente.id)!;
      expect(p.id, existente.id);
      expect(p.price, 1800);
    });

    test('importar con estrategia omitir no pisa el producto', () async {
      final Product existente = await products.create(
        name: 'Refresco',
        cost: 1000,
        price: 1500,
        sku: 'ref-350',
        stock: 10,
      );
      final String json = await File(
        await transfer.exportProducts(ProductExportFormat.json),
      ).readAsString();
      final ImportPreview preview = transfer.preview(json);

      final ImportOutcome outcome = await transfer.importProducts(
        preview,
        ImportConflictStrategy.ignorar,
      );
      expect(outcome.skipped, 1);
      expect(AppDatabase.products.get(existente.id)?.price, 1500);
    });

    test('un archivo que no es CSV/JSON da error claro, no una app rota', () {
      expect(
        () => transfer.preview('basura'),
        throwsA(isA<ImportException>()),
      );
    });

    test('filas inválidas se reportan y no se importan', () async {
      const String csv = 'nombre,precio\nRefresco,1500\n,900\nCafé,no-es-numero\n';
      final ImportPreview preview = transfer.preview(csv);
      // sólo la primera fila es utilizable
      expect(preview.total, 3);
      expect(preview.products.length, 1);
      expect(preview.errorCount, 2);
      expect(preview.canImport, isTrue);

      final ImportOutcome outcome = await transfer.importProducts(
        preview,
        ImportConflictStrategy.actualizar,
      );
      expect(outcome.created, 1);
      expect(AppDatabase.products.length, 1);
      expect(AppDatabase.products.values.single.name, 'Refresco');
    });

    test('importar sin productos válidos lanza ImportException', () async {
      final ImportPreview preview = transfer.preview(
        'nombre,precio\n,900\nCafé,no-es-numero\n',
      );
      expect(preview.canImport, isFalse);
      expect(
        () => transfer.importProducts(preview, ImportConflictStrategy.actualizar),
        throwsA(isA<ImportException>()),
      );
      expect(AppDatabase.products, isEmpty);
    });
  });
}
