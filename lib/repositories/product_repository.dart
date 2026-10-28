import 'dart:math';

import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../core/database/app_database.dart';
import '../core/errors/app_exception.dart';
import '../models/category.dart';
import '../models/enums.dart';
import '../models/product.dart';

/// CRUD de productos y categorías, con búsqueda local rápida (§18, §40).
class ProductRepository {
  ProductRepository();

  static const Uuid _uuid = Uuid();
  static final Random _random = Random();

  /// Acentos que se quitan para que SKU y búsqueda sean ASCII plano.
  static const Map<String, String> _diacritics = <String, String>{
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
    'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U', 'Ñ': 'N',
  };

  // --- Lectura ---

  /// Stream de todos los productos. Hive emite al cambiar la caja, así que
  /// las pantallas se refrescan solas tras cada venta.
  Stream<List<Product>> watchAll() async* {
    // `box.watch()` sólo emite en cambios, no un valor inicial. Sin este primer
    // yield, con la base vacía el StreamProvider queda en `loading` para
    // siempre y la pantalla no sale del spinner.
    yield all();
    yield* AppDatabase.products.watch().map((BoxEvent _) => all());
  }

  /// Iteración perezosa: no materializa los 1,000+ productos de golpe (§49).
  Iterable<Product> lazyAll() => AppDatabase.products.values;

  List<Product> all() => AppDatabase.products.values.toList(growable: false);

  Product? byId(String id) => AppDatabase.products.get(id);

  Product? bySku(String sku) {
    final String q = sku.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final Product p in AppDatabase.products.values) {
      if (p.sku.toLowerCase() == q) return p;
    }
    return null;
  }

  /// Búsqueda por nombre, SKU, código de barras o categoría (§40).
  List<Product> search(String query, {bool includeInactive = false}) {
    if (query.trim().isEmpty) return active();
    return AppDatabase.products.values
        .where(
          (Product p) =>
              (includeInactive || p.active) &&
              p.matches(query, categoryName: categoryNameOf(p.categoryId)),
        )
        .toList(growable: false);
  }

  /// Nombre de la categoría con ese id, o `null` si ya no existe.
  String? categoryNameOf(String? categoryId) {
    if (categoryId == null || categoryId.isEmpty) return null;
    return AppDatabase.categories.get(categoryId)?.name;
  }

  List<Product> active() =>
      AppDatabase.products.values.where((Product p) => p.active).toList();

  int get totalCount => AppDatabase.products.length;

  // --- Escritura ---

  Future<Product> create({
    required String name,
    String description = '',
    String? categoryId,
    String sku = '',
    String barcode = '',
    required int cost,
    required int price,
    double stock = 0,
    int? minStock,
    String unit = 'pieza',
  }) async {
    if (cost < 0) {
      throw const ValidationException('El costo no puede ser negativo');
    }
    if (price <= 0) {
      throw const ValidationException('El precio debe ser mayor a cero');
    }
    if (stock < 0) {
      throw const ValidationException('El stock no puede ser negativo');
    }

    if (sku.trim().isNotEmpty && bySku(sku) != null) {
      throw ConflictException('Ya existe un producto con el SKU "$sku"');
    }

    final Product product = Product(
      id: _uuid.v4(),
      name: name.trim(),
      description: description.trim(),
      categoryId: categoryId,
      sku: sku.trim(),
      barcode: barcode.trim(),
      cost: cost,
      price: price,
      stock: stock,
      minStock: minStock ?? _defaultMinStock(),
      unit: unit.trim().isEmpty ? 'pieza' : unit.trim(),
    );
    await AppDatabase.products.put(product.id, product);
    return product;
  }

  Future<Product> update(Product product) async {
    if (product.cost < 0) {
      throw const ValidationException('El costo no puede ser negativo');
    }
    if (product.price <= 0) {
      throw const ValidationException('El precio debe ser mayor a cero');
    }
    if (product.stock < 0) {
      throw const ValidationException('El stock no puede ser negativo');
    }
    if (product.sku.trim().isNotEmpty) {
      final Product? duplicate = bySku(product.sku);
      if (duplicate != null && duplicate.id != product.id) {
        throw ConflictException(
          'Ya existe otro producto con el SKU "${product.sku}"',
        );
      }
    }
    product.updatedAt = DateTime.now();
    await AppDatabase.products.put(product.id, product);
    return product;
  }

  /// Baja lógica: se marca inactivo para no perder el historial de ventas.
  Future<void> archive(String id) async {
    final Product? product = byId(id);
    if (product == null) throw StorageException('Producto no encontrado');
    product.active = false;
    product.updatedAt = DateTime.now();
    await AppDatabase.products.put(id, product);
  }

  Future<void> restore(String id) async {
    final Product? product = byId(id);
    if (product == null) throw StorageException('Producto no encontrado');
    product.active = true;
    product.updatedAt = DateTime.now();
    await AppDatabase.products.put(id, product);
  }

  /// Borrado físico. Sólo para productos nunca vendidos; en cualquier otro
  /// caso la app ofrece archivar en su lugar (§46).
  Future<void> delete(String id) async {
    await AppDatabase.products.delete(id);
  }

  Future<void> putAll(Iterable<Product> products) =>
      AppDatabase.products.putAll(<String, Product>{
        for (final Product p in products) p.id: p,
      });

  int _defaultMinStock() => 5;

  // --- Generación de códigos ---

  /// SKU a partir del nombre: iniciales de las primeras palabras más un
  /// correlativo libre.
  ///
  /// `Playera básica negra` ⇒ `PBN-001`. Si ese correlativo ya existe, sube al
  /// siguiente; la unicidad se comprueba contra la caja, no se supone.
  String generateSku(String name) {
    final String letters = _skuLetters(name);
    int n = _nextCorrelative(letters);
    while (true) {
      final String candidate = '$letters-${n.toString().padLeft(3, '0')}';
      if (bySku(candidate) == null) return candidate;
      n++;
    }
  }

  /// Código de barras EAN-13 con su dígito verificador (§40).
  ///
  /// Es opcional en la ficha: si el usuario no escribe uno, la app lo genera
  /// para que el producto se pueda escanear después.
  String generateBarcode() {
    for (int attempt = 0; attempt < 20; attempt++) {
      final String candidate = _withCheckDigit(_randomPayload());
      if (!_barcodeExists(candidate)) return candidate;
    }
    // Red de seguridad: si los 20 intentos chocaron, se avanza con el reloj.
    return _withCheckDigit(
      _stripDiacritics(DateTime.now().millisecondsSinceEpoch.toString())
          .padLeft(12, '0')
          .substring(0, 12),
    );
  }

  /// 12 dígitos para un EAN-13: el primero de 0 a 8 (rango válido de EAN-13) y
  /// los demás al azar. `Random.nextInt` no llega a 10^12, así que el cuerpo se
  /// arma con dos tramos de seis.
  String _randomPayload() {
    final int head = _random.nextInt(1000000) * 100000;
    final int tail = _random.nextInt(100000);
    return '${_random.nextInt(9)}${(head + tail).toString().padLeft(11, '0')}';
  }

  /// Letras del SKU, sin acentos.
  ///
  /// Varias palabras ⇒ iniciales de las tres primeras (`Playera básica negra`
  /// ⇒ `PBN`). Una sola ⇒ sus primeras letras (`Gorra` ⇒ `GOR`), porque `G-001`
  /// no distingue nada. Sin texto utilizable ⇒ `PRD`.
  static String _skuLetters(String name) {
    final String clean = _stripDiacritics(name).toUpperCase();
    final List<String> words = clean
        .split(RegExp(r'[^A-Z0-9]+'))
        .where((String w) => RegExp(r'^[A-Z]').hasMatch(w))
        .toList();
    if (words.isEmpty) return 'PRD';
    if (words.length == 1) {
      final String only = words.first;
      return only.substring(0, only.length < 3 ? only.length : 3);
    }
    return words.take(3).map((String w) => w[0]).join();
  }

  static String _stripDiacritics(String value) => value
      .split('')
      .map((String c) => _diacritics[c] ?? c)
      .join();

  /// Siguiente correlativo para el prefijo dado, según los SKU ya guardados.
  int _nextCorrelative(String prefix) {
    final RegExp pattern = RegExp('^${RegExp.escape(prefix)}-(\\d+)');
    int max = 0;
    for (final Product p in AppDatabase.products.values) {
      final Match? m = pattern.firstMatch(p.sku.trim());
      if (m == null) continue;
      final int n = int.tryParse(m.group(1)!) ?? 0;
      if (n > max) max = n;
    }
    return max + 1;
  }

  /// Los 12 dígitos de un EAN-13, con su dígito verificador al final. Las
  /// posiciones 1, 3, 5… pesan 1 y las pares pesan 3.
  static String _withCheckDigit(String payload) {
    int sum = 0;
    for (int i = 0; i < payload.length; i++) {
      final int digit = int.parse(payload[i]);
      sum += i.isEven ? digit : digit * 3;
    }
    return '$payload${(10 - sum % 10) % 10}';
  }

  bool _barcodeExists(String code) {
    for (final Product p in AppDatabase.products.values) {
      if (p.barcode.trim() == code) return true;
    }
    return false;
  }

  // --- Categorías ---

  Stream<List<Category>> watchCategories() async* {
    // Valor inicial antes de los cambios: ver `watchAll`.
    yield AppDatabase.categories.values.toList();
    yield* AppDatabase.categories.watch().map(
      (BoxEvent _) => AppDatabase.categories.values.toList(),
    );
  }

  List<Category> allCategories() =>
      AppDatabase.categories.values.toList(growable: false);

  Category? categoryById(String? id) =>
      id == null ? null : AppDatabase.categories.get(id);

  Future<Category> createCategory(String name, {int colorValue = 0}) async {
    final String clean = name.trim();
    if (clean.isEmpty) {
      throw const ValidationException('El nombre de la categoría es obligatorio');
    }
    if (_categoryNameExists(clean, null)) {
      throw ConflictException('Ya existe la categoría "$clean"');
    }
    final Category category = Category(
      id: _uuid.v4(),
      name: clean,
      colorValue: colorValue,
    );
    await AppDatabase.categories.put(category.id, category);
    return category;
  }

  Future<void> updateCategory(Category category) async {
    if (_categoryNameExists(category.name, category.id)) {
      throw ConflictException(
        'Ya existe la categoría "${category.name}"',
      );
    }
    await AppDatabase.categories.put(category.id, category);
  }

  /// Elimina la categoría y deja sus productos sin categoría.
  Future<void> deleteCategory(String id) async {
    for (final Product p in AppDatabase.products.values) {
      if (p.categoryId == id) {
        p.categoryId = null;
        p.updatedAt = DateTime.now();
        await AppDatabase.products.put(p.id, p);
      }
    }
    await AppDatabase.categories.delete(id);
  }

  // --- Inventario (agregados) ---

  int countByState(StockState state) => AppDatabase.products.values
      .where((Product p) => p.active && p.stockState == state)
      .length;

  int get lowStockCount => countByState(StockState.stockBajo);

  int get outOfStockCount => countByState(StockState.agotado);

  int get totalInventoryValue => AppDatabase.products.values
      .where((Product p) => p.active)
      .fold<int>(0, (int sum, Product p) => sum + p.inventoryValue);

  bool _categoryNameExists(String name, String? exceptId) {
    final String q = name.trim().toLowerCase();
    return AppDatabase.categories.values.any(
      (Category c) => c.id != exceptId && c.name.toLowerCase() == q,
    );
  }
}
