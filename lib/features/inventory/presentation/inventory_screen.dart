import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_widgets.dart';
import '../../../models/enums.dart';
import '../../../models/inventory_movement.dart';
import '../../../models/product.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../repositories/inventory_repository.dart';
import '../../../routes/app_routes.dart';

/// Números de stock sin decimales inútiles: 5 en vez de 5.0, 1.5 tal cual.
String _num(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

enum _StockFilter { todos, bajo, agotado }

/// Inventario: existencias y rastro de movimientos (§21, §22, §23).
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final TextEditingController _search = TextEditingController();
  _StockFilter _filter = _StockFilter.todos;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(productSearchQueryProvider);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    ref.read(productSearchQueryProvider.notifier).set(value);
    setState(() {});
  }

  Future<void> _addStock(Product product) async {
    final double? added = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => StockEntrySheet(
        product: product,
        mode: StockMode.entrada,
      ),
    );
    if (added == null || !mounted) return;
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .addStock(productId: product.id, quantity: added);
      if (!mounted) return;
      showToast(context, 'Mercancía agregada a ${product.name}');
    } on AppException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, isError: true);
    }
  }

  Future<void> _adjustStock(Product product) async {
    final double? newStock = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => StockEntrySheet(
        product: product,
        mode: StockMode.ajuste,
      ),
    );
    if (newStock == null || !mounted) return;
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .setStockTo(productId: product.id, newStock: newStock);
      if (!mounted) return;
      showToast(context, 'Stock de ${product.name} ajustado');
    } on AppException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, isError: true);
    }
  }

  Future<void> _reportWaste(Product product) async {
    final double? amount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => StockEntrySheet(
        product: product,
        mode: StockMode.merma,
      ),
    );
    if (amount == null || !mounted) return;
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .reportWaste(productId: product.id, quantity: amount);
      if (!mounted) return;
      showToast(context, 'Merma registrada en ${product.name}');
    } on AppException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Product>> products = ref.watch(productsProvider);
    final String query = ref.watch(productSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const <Widget>[
            Tab(text: 'Existencias'),
            Tab(text: 'Movimientos'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // heroTag explícito: con el shell de pestañas las cinco pantallas
        // quedan montadas a la vez y varios FAB con el tag por defecto hacen
        // que Flutter truene al animar la transición.
        heroTag: null,
        onPressed: () => context.pushNamed(AppRoutes.stockEntry),
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('Entrada'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: <Widget>[
          products.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace _) => Center(child: Text('Error: $e')),
            data: (List<Product> all) {
              final List<Product> list = _applyFilter(all);
              if (all.isEmpty) {
                return EmptyState(
                  title: 'Sin productos en el catálogo.',
                  message: 'Agrega productos para controlar tu inventario.',
                  icon: Icons.inventory_2_outlined,
                  actionLabel: 'Nuevo producto',
                  onAction: () =>
                      context.pushNamed(AppRoutes.productForm),
                );
              }
              if (list.isEmpty) {
                return const EmptyState(
                  title: 'Nada por aquí',
                  message: 'No hay productos que coincidan con la búsqueda.',
                  icon: Icons.search_off,
                );
              }
              return Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _search,
                      onChanged: _searchChanged,
                      decoration: InputDecoration(
                        hintText: 'Buscar producto',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _search.clear();
                                  _searchChanged('');
                                },
                              ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: <Widget>[
                        _chip(_StockFilter.todos, 'Todos'),
                        _chip(_StockFilter.bajo, 'Stock bajo'),
                        _chip(_StockFilter.agotado, 'Agotados'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int i) =>
                          _StockTile(
                            product: list[i],
                            onAdd: () => _addStock(list[i]),
                            onAdjust: () => _adjustStock(list[i]),
                            onWaste: () => _reportWaste(list[i]),
                          ),
                    ),
                  ),
                ],
              );
            },
          ),
          const _MovementsTab(),
        ],
      ),
    );
  }

  Widget _chip(_StockFilter f, String label) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == f,
      onSelected: (_) => setState(() => _filter = f),
    ),
  );

  List<Product> _applyFilter(List<Product> all) {
    final String q = _search.text.trim().toLowerCase();
    return all
        .where(
          (Product p) =>
              p.active &&
              switch (_filter) {
                _StockFilter.todos => true,
                _StockFilter.bajo => p.stockState == StockState.stockBajo,
                _StockFilter.agotado => p.stockState == StockState.agotado,
              } &&
              (q.isEmpty ||
                  p.name.toLowerCase().contains(q) ||
                  p.sku.toLowerCase().contains(q)),
        )
        .toList()
      ..sort(
        (Product a, Product b) => a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        ),
      );
  }
}

class _StockTile extends StatelessWidget {
  const _StockTile({
    required this.product,
    required this.onAdd,
    required this.onAdjust,
    required this.onWaste,
  });

  final Product product;
  final VoidCallback onAdd;
  final VoidCallback onAdjust;
  final VoidCallback onWaste;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final (Color color, String label) = switch (product.stockState) {
      StockState.agotado => (scheme.error, 'Agotado'),
      StockState.stockBajo => (scheme.tertiary, 'Stock bajo'),
      StockState.disponible => (scheme.secondary, 'Disponible'),
    };

    return Card(
      child: InkWell(
        onTap: () => context.pushNamed(AppRoutes.productDetail, extra: product.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.name,
                      style: theme.textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'mín ${_num(product.minStock)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${_num(product.stock)} ${product.unit}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  MoneyText(
                    product.inventoryValue,
                    compact: true,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'Movimientos',
                icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
                onSelected: (String v) => switch (v) {
                  'add' => onAdd(),
                  'adjust' => onAdjust(),
                  _ => onWaste(),
                },
                itemBuilder: (BuildContext context) =>
                    const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'add',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.add_box_outlined),
                          title: Text('Agregar mercancía'),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'adjust',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.tune),
                          title: Text('Ajustar a cantidad'),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'waste',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline),
                          title: Text('Reportar merma'),
                        ),
                      ),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _MovementsTab extends ConsumerWidget {
  const _MovementsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<InventoryMovement>> movements = ref.watch(
      movementsProvider,
    );

    return movements.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace _) => Center(child: Text('Error: $e')),
      data: (List<InventoryMovement> list) {
        if (list.isEmpty) {
          return const EmptyState(
            title: 'Sin movimientos',
            message: 'Aquí verás cada cambio de stock de tus productos.',
            icon: Icons.swap_vert,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (BuildContext context, int i) =>
              _MovementTile(movement: list[i], theme: theme),
        );
      },
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement, required this.theme});

  final InventoryMovement movement;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = theme.colorScheme;
    final double delta = movement.delta;
    final bool positive = delta >= 0;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (positive ? scheme.secondary : scheme.error).withValues(
            alpha: 0.14,
          ),
          child: Icon(
            _iconFor(movement.type),
            size: 20,
            color: positive ? scheme.secondary : scheme.error,
          ),
        ),
        title: Text(
          movement.productName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${movement.type.label}  •  '
          '${Dates.relativeDay(movement.date)}\n'
          '${_num(movement.previousStock)} → ${_num(movement.newStock)}'
          '${movement.reason.isEmpty ? '' : '  •  ${movement.reason}'}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Text(
          '${positive ? '+' : ''}${_num(delta)}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: positive ? scheme.secondary : scheme.error,
            fontWeight: FontWeight.w800,
          ),
        ),
        onTap: () => context.pushNamed(AppRoutes.movementDetail, extra: movement.id),
      ),
    );
  }

  static IconData _iconFor(MovementType type) => switch (type) {
    MovementType.entrada => Icons.add,
    MovementType.venta => Icons.remove,
    MovementType.devolucion => Icons.undo,
    MovementType.ajuste => Icons.tune,
    MovementType.merma => Icons.delete_outline,
  };

}

enum StockMode { entrada, ajuste, merma }

/// Hoja para entrada de mercancía, ajuste a cantidad exacta o merma (§21).
class StockEntrySheet extends ConsumerStatefulWidget {
  const StockEntrySheet({
    super.key,
    required this.product,
    required this.mode,
  });

  final Product product;
  final StockMode mode;

  @override
  ConsumerState<StockEntrySheet> createState() => StockEntrySheetState();
}

class StockEntrySheetState extends ConsumerState<StockEntrySheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _qty = TextEditingController();
  final TextEditingController _reason = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == StockMode.ajuste) {
      _qty.text = widget.product.stock == widget.product.stock.roundToDouble()
          ? widget.product.stock.toInt().toString()
          : widget.product.stock.toString();
      _reason.text = 'Conteo físico';
    } else if (widget.mode == StockMode.merma) {
      _reason.text = 'Producto dañado';
    }
  }

  @override
  void dispose() {
    _qty.dispose();
    _reason.dispose();
    super.dispose();
  }

  String get _title => switch (widget.mode) {
    StockMode.entrada => 'Agregar mercancía',
    StockMode.ajuste => 'Ajustar stock',
    StockMode.merma => 'Reportar merma',
  };

  double get _amount => double.tryParse(_qty.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final NavigatorState navigator = Navigator.of(context);
    try {
      final InventoryRepository repo = ref.read(inventoryRepositoryProvider);
      switch (widget.mode) {
        case StockMode.entrada:
          await repo.addStock(
            productId: widget.product.id,
            quantity: _amount,
            reason: _reason.text.trim().isEmpty
                ? 'Entrada de mercancía'
                : _reason.text.trim(),
          );
        case StockMode.ajuste:
          await repo.setStockTo(
            productId: widget.product.id,
            newStock: _amount,
            reason: _reason.text.trim().isEmpty
                ? 'Ajuste manual'
                : _reason.text.trim(),
          );
        case StockMode.merma:
          await repo.reportWaste(
            productId: widget.product.id,
            quantity: _amount,
            reason: _reason.text.trim().isEmpty ? 'Merma' : _reason.text.trim(),
          );
      }
      navigator.pop(_amount);
    } on AppException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isAjuste = widget.mode == StockMode.ajuste;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(_title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  widget.product.name,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Stock actual: ${_num(widget.product.stock)} '
                  '${widget.product.unit}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _qty,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    labelText: isAjuste ? 'Nueva cantidad' : 'Cantidad',
                    helperText: isAjuste
                        ? 'Escribe el total que queda, no la diferencia'
                        : null,
                  ),
                  validator: (String? v) {
                    final double parsed =
                        double.tryParse((v ?? '').replaceAll(',', '.')) ?? -1;
                    if (parsed < 0) return 'Cantidad inválida';
                    if (parsed == 0) return 'La cantidad debe ser mayor a cero';
                    if (!isAjuste && parsed > widget.product.stock) {
                      return 'No tienes tanto stock (disponible: '
                          '${_num(widget.product.stock)})';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _reason,
                  decoration: const InputDecoration(
                    labelText: 'Motivo (opcional)',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isAjuste
                              ? 'Ajustar a ${_num(_amount)}'
                              : 'Registrar',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Entrada de mercancía choosing producto desde el catálogo (§21).
class StockEntryScreen extends ConsumerStatefulWidget {
  const StockEntryScreen({super.key, this.presetProductId});

  final String? presetProductId;

  @override
  ConsumerState<StockEntryScreen> createState() => _StockEntryScreenState();
}

class _StockEntryScreenState extends ConsumerState<StockEntryScreen> {
  final TextEditingController _search = TextEditingController();
  Product? _selected;

  @override
  void initState() {
    super.initState();
    if (widget.presetProductId != null) {
      _selected = ref.read(productRepositoryProvider).byId(widget.presetProductId!);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final String query = _search.text.trim().toLowerCase();
    final List<Product> all =
        ref.read(productsProvider).asData?.value ?? const <Product>[];
    final List<Product> list = all
        .where(
          (Product p) =>
              p.active &&
              (query.isEmpty ||
                  p.name.toLowerCase().contains(query) ||
                  p.sku.toLowerCase().contains(query)),
        )
        .toList();

    if (list.isEmpty) {
      showToast(context, 'No se encontraron productos', isError: true);
      return;
    }
    final Product? picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _ProductPicker(list: list, query: query),
    );
    if (picked != null) setState(() => _selected = picked);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Entrada de mercancía')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          Card(
            child: InkWell(
              onTap: _pick,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.inventory_2_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Producto',
                            style: theme.textTheme.labelMedium,
                          ),
                          Text(
                            _selected?.name ?? 'Toca para elegir',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: _selected == null
                                  ? theme.colorScheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                          if (_selected != null)
                            Text(
                              'Stock actual: ${_num(_selected!.stock)} '
                              '${_selected!.unit}',
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _selected == null
                ? null
                : () async {
                    final NavigatorState navigator = Navigator.of(context);
                    final double? amount = await showModalBottomSheet<double>(
                      context: context,
                      isScrollControlled: true,
                      builder: (BuildContext ctx) => StockEntrySheet(
                        product: _selected!,
                        mode: StockMode.entrada,
                      ),
                    );
                    if (amount == null || !mounted) return;
                    navigator.pop(amount);
                  },
            icon: const Icon(Icons.add),
            label: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({required this.list, required this.query});

  final List<Product> list;
  final String query;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 16),
          Text('Elegir producto', style: theme.textTheme.titleMedium),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (BuildContext context, int i) {
                final Product p = list[i];
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text(
                    'Stock: ${_num(p.stock)} ${p.unit}',
                  ),
                  onTap: () => Navigator.of(context).pop(p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
