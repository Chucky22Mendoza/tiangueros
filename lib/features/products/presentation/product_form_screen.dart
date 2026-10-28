import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../repositories/product_repository.dart';
import 'categories_screen.dart';

/// Alta y edición de producto (§18).
///
/// Todas las validaciones viven en [V] para que la app nunca acepte precios
/// negativos, stock negativo ni productos sin nombre (§45).
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  /// `null` ⇒ alta; con id ⇒ edición.
  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _cost;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _minStock;

  late String _unit;

  /// `true` mientras la app sea dueña del campo: si el usuario lo teclea, la
  /// autogeneración se apaga y no se le pisa lo que escribió.
  bool _skuAuto = false;
  bool _barcodeAuto = false;

  /// Unidades ofrecidas en el selector. La del producto se agrega si no está
  /// aquí, para no perder unidades viejas al editar.
  static const List<String> _unitChoices = <String>[
    'pieza', 'kg', 'g', 'litro', 'ml', 'paquete', 'caja', 'bolsa', 'par',
    'metro', 'libra', 'docena',
  ];

  String? _categoryId;
  bool _active = true;
  bool _saving = false;

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    final Product? existing = widget.productId == null
        ? null
        : ref.read(productRepositoryProvider).byId(widget.productId!);

    _name = TextEditingController(text: existing?.name ?? '');
    _description = TextEditingController(text: existing?.description ?? '');
    _sku = TextEditingController(text: existing?.sku ?? '');
    _barcode = TextEditingController(text: existing?.barcode ?? '');
    _cost = TextEditingController(
      text: existing == null ? '' : Money.toEditableString(existing.cost),
    );
    _price = TextEditingController(
      text: existing == null ? '' : Money.toEditableString(existing.price),
    );
    _stock = TextEditingController(
      text: existing == null
          ? '0'
          : existing.stock.toStringAsFixed(
              existing.stock == existing.stock.roundToDouble() ? 0 : 2,
            ),
    );
    _minStock = TextEditingController(text: '${existing?.minStock ?? 5}');
    _unit = existing?.unit ?? 'pieza';
    // En alta se llenan solos; al editar no se tocan los valores que ya tiene.
    _skuAuto = !_isEditing;
    _barcodeAuto = !_isEditing;
    _categoryId = existing?.categoryId;
    _active = existing?.active ?? true;
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _name, _description, _sku, _barcode, _cost, _price, _stock, _minStock,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// SKU y código de barras se derivan del nombre mientras el usuario no los
  /// escriba. El código sólo se genera una vez: después ya no está vacío.
  void _onNameChanged(String value) {
    if (value.trim().isEmpty) return;
    final ProductRepository repo = ref.read(productRepositoryProvider);
    if (_skuAuto) _sku.text = repo.generateSku(value);
    if (_barcodeAuto && _barcode.text.isEmpty) {
      _barcode.text = repo.generateBarcode();
    }
    setState(() {});
  }

  void _regenerateBarcode() {
    setState(() {
      _barcode.text = ref.read(productRepositoryProvider).generateBarcode();
      _barcodeAuto = true;
    });
  }

  /// Crea una categoría sin salir del alta y la deja asignada.
  Future<void> _createCategory() async {
    final ({String name, int color})? result = await showDialog<
      ({String name, int color})
    >(context: context, builder: (BuildContext ctx) => const CategoryDialog());
    if (result == null || !mounted) return;
    try {
      final Category category = await ref
          .read(productRepositoryProvider)
          .createCategory(result.name, colorValue: result.color);
      if (!mounted) return;
      setState(() => _categoryId = category.id);
      showToast(context, 'Categoría creada');
    } on AppException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, isError: true);
    }
  }

  /// Atajo: precio = costo + ganancia. Útil cuando el usuario conoce el
  /// margen que quiere, no el precio final (§19).
  void _applyMarginFromCost() {
    final int? cost = Money.tryParseToCents(_cost.text);
    if (cost == null) return;
    setState(() => _price.text = Money.toEditableString(cost));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      final ProductRepository repo = ref.read(productRepositoryProvider);
      final int cost = Money.parseToCentsOrZero(_cost.text);
      final int price = Money.tryParseToCents(_price.text) ?? 0;
      final double stock = double.tryParse(_stock.text.replaceAll(',', '.')) ?? 0;
      final int minStock = int.tryParse(_minStock.text.trim()) ?? 0;

      if (_isEditing) {
        final Product product = repo.byId(widget.productId!)!;
        product
          ..name = _name.text.trim()
          ..description = _description.text.trim()
          ..categoryId = _categoryId
          ..sku = _sku.text.trim()
          ..barcode = _barcode.text.trim()
          ..cost = cost
          ..price = price
          ..minStock = minStock
          ..unit = _unit
          ..active = _active;
        // El stock se cambia por inventario, no desde aquí: evitamos dejar
        // huecos sin movimiento registrado (§22).
        if (stock != product.stock) {
          await ref
              .read(inventoryRepositoryProvider)
              .setStockTo(
                productId: product.id,
                newStock: stock,
                reason: 'Edición desde ficha de producto',
              );
        }
        await repo.update(product);
      } else {
        await repo.create(
          name: _name.text.trim(),
          description: _description.text.trim(),
          categoryId: _categoryId,
          sku: _sku.text.trim(),
          barcode: _barcode.text.trim(),
          cost: cost,
          price: price,
          stock: stock,
          minStock: minStock,
          unit: _unit,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
      showToast(context, _isEditing ? 'Producto actualizado' : 'Producto creado');
    } on AppException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archive() async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Archivar producto',
      message:
          'El producto dejará de aparecer en ventas, pero se conserva todo su '
          'historial. Puedes reactivarlo después.',
      confirmLabel: 'Archivar',
    );
    if (!ok || !mounted) return;
    try {
      await ref
          .read(productRepositoryProvider)
          .archive(widget.productId!);
      if (!mounted) return;
      Navigator.of(context).pop();
      showToast(context, 'Producto archivado');
    } on AppException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Category> categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final int cost = Money.tryParseToCents(_cost.text) ?? 0;
    final int price = Money.tryParseToCents(_price.text) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar producto' : 'Nuevo producto'),
        actions: <Widget>[
          if (_isEditing)
            IconButton(
              tooltip: 'Archivar',
              icon: const Icon(Icons.archive_outlined),
              onPressed: _archive,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: <Widget>[
            TextFormField(
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                hintText: 'Playera básica',
              ),
              validator: V.productName,
              onChanged: _onNameChanged,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sin categoría'),
                ),
                for (final Category c in categories)
                  DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (String? v) => setState(() => _categoryId = v),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _createCategory,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva categoría'),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _sku,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'SKU',
                      hintText: 'P-001',
                    ),
                    onChanged: (_) => _skuAuto = false,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _barcode,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Código',
                      hintText: '7501234567890',
                      suffixIcon: IconButton(
                        tooltip: 'Generar otro',
                        icon: const Icon(Icons.casino_outlined, size: 20),
                        onPressed: _regenerateBarcode,
                      ),
                    ),
                    onChanged: (_) => _barcodeAuto = false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Precios', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Costo',
                      prefixText: r'$ ',
                      suffixIcon: IconButton(
                        tooltip: 'Usar costo como precio',
                        icon: const Icon(Icons.flash_on, size: 20),
                        onPressed: _applyMarginFromCost,
                      ),
                    ),
                    validator: V.cost,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Precio de venta *',
                      prefixText: r'$ ',
                    ),
                    validator: V.price,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (price > 0) ...<Widget>[
              const SizedBox(height: 10),
              _MarginPreview(cost: cost, price: price),
            ],
            const SizedBox(height: 20),
            Text('Inventario', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Stock'),
                    validator: V.stock,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _minStock,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(labelText: 'Stock mínimo'),
                    validator: V.minStock,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _unit,
              decoration: const InputDecoration(labelText: 'Unidad de inventario'),
              items: <DropdownMenuItem<String>>[
                for (final String u in <String>{
                  _unit,
                  ..._unitChoices,
                })
                  DropdownMenuItem<String>(value: u, child: Text(u)),
              ],
              onChanged: (String? v) => setState(() => _unit = v ?? _unit),
            ),
            const SizedBox(height: 10),
            _Advice(
              text:
                  'El stock mínimo es la cantidad a partir de la cual te avisamos '
                  'que el producto se está acabando.',
              extra:
                  _isEditing
                      ? ' Si cambias el stock aquí, queda registrado como ajuste '
                        'en el historial de movimientos.'
                      : null,
            ),
            if (_isEditing) ...<Widget>[
              const SizedBox(height: 12),
              SwitchListTile(
                value: _active,
                onChanged: (bool v) => setState(() => _active = v),
                title: const Text('Producto activo'),
                subtitle: const Text(
                  'Los inactivos no aparecen al buscar para vender',
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_isEditing ? 'Guardar cambios' : 'Crear producto'),
          ),
        ),
      ),
    );
  }
}

/// Aviso informativo bajo los campos.
///
/// Los `helperText` de un campo se cortan a media palabra cuando el campo va
/// en una fila angosta; el aviso va completo o no va.
class _Advice extends StatelessWidget {
  const _Advice({required this.text, this.extra});

  final String text;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.lightbulb_outline,
            size: 20,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                children: <InlineSpan>[
                  TextSpan(text: text),
                  if (extra != null) TextSpan(text: extra),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ganancia y margen calculados en vivo (§19).
class _MarginPreview extends StatelessWidget {
  const _MarginPreview({required this.cost, required this.price});

  final int cost;
  final int price;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int profit = price - cost;
    final double margin = cost == price ? 0 : profit / price * 100;
    final bool negative = profit < 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (negative ? scheme.error : scheme.secondary).withValues(
          alpha: 0.10,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Ganancia',
              style: theme.textTheme.labelMedium,
            ),
          ),
          Text(
            Money.format(profit),
            style: theme.textTheme.titleSmall?.copyWith(
              color: negative ? scheme.error : scheme.secondary,
            ),
          ),
          const SizedBox(width: 14),
          Text('Margen', style: theme.textTheme.labelMedium),
          const SizedBox(width: 6),
          Text(
            '${margin.toStringAsFixed(1)}%',
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
