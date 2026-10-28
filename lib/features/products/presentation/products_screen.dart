import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/category.dart';
import '../../../models/product.dart';
import '../../../providers/data_providers.dart';
import '../../../routes/app_routes.dart';

/// Filtro de la lista de productos.
enum ProductFilter {
  todos('Todos'),
  stockBajo('Stock bajo'),
  agotados('Agotados'),
  inactivos('Inactivos');

  const ProductFilter(this.label);

  final String label;
}

final productFilterProvider =
    NotifierProvider<ProductFilterNotifier, ProductFilter>(
      ProductFilterNotifier.new,
    );

class ProductFilterNotifier extends Notifier<ProductFilter> {
  @override
  ProductFilter build() => ProductFilter.todos;
  void set(ProductFilter value) => state = value;
}

/// CRUD de productos (§18).
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Product> _apply(
    ProductFilter filter,
    String query,
    List<Product> all,
    Map<String, String> categoryNames,
  ) {
    final Iterable<Product> base = switch (filter) {
      ProductFilter.todos => all.where((Product p) => p.active),
      ProductFilter.stockBajo => all.where((Product p) => p.isLowStock),
      ProductFilter.agotados => all.where((Product p) => p.isOutOfStock),
      ProductFilter.inactivos => all.where((Product p) => !p.active),
    };
    return base
        .where(
          (Product p) => p.matches(
            query,
            categoryName:
                p.categoryId == null ? null : categoryNames[p.categoryId],
          ),
        )
        .toList()
      ..sort((Product a, Product b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Product>> products = ref.watch(productsProvider);
    final ProductFilter filter = ref.watch(productFilterProvider);
    final String query = ref.watch(productSearchQueryProvider);
    final List<Category> categories = ref.watch(categoriesProvider).value ?? const <Category>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Categorías',
            icon: const Icon(Icons.category_outlined),
            onPressed: () =>
                context.pushNamed(AppRoutes.categoryForm),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // heroTag explícito: con el shell de pestañas las cinco pantallas
        // quedan montadas a la vez y varios FAB con el tag por defecto hacen
        // que Flutter truene al animar la transición.
        heroTag: null,
        onPressed: () => context.pushNamed(AppRoutes.productForm),
        icon: const Icon(Icons.add),
        label: const Text('Producto'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (String v) =>
                  ref.read(productSearchQueryProvider.notifier).set(v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, SKU o código',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          ref
                              .read(productSearchQueryProvider.notifier)
                              .clear();
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
                for (final ProductFilter f in ProductFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.label),
                      selected: filter == f,
                      onSelected: (_) =>
                          ref.read(productFilterProvider.notifier).set(f),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace _) => Center(
                child: Text('No se pudieron cargar los productos:\n$e'),
              ),
              data: (List<Product> all) {
                final List<Product> list = _apply(
                  filter,
                  query,
                  all,
                  <String, String>{
                    for (final Category c in categories) c.id: c.name,
                  },
                );
                if (all.isEmpty) {
                  return EmptyState(
                    title: 'Todavía no tienes productos.',
                    message:
                        'Agrega tu primer producto\npara comenzar a controlar '
                        'tu inventario.',
                    icon: Icons.inventory_2_outlined,
                    actionLabel: 'Agregar producto',
                    onAction: () => context.pushNamed(AppRoutes.productForm),
                  );
                }
                if (list.isEmpty) {
                  return const EmptyState(
                    title: 'Sin resultados',
                    message: 'No hay productos que coincidan con el filtro.',
                    icon: Icons.search_off,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int i) =>
                      _ProductTile(product: list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(AppRoutes.productDetail, extra: product.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            product.name,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        ),
                        if (!product.active) ...<Widget>[
                          const SizedBox(width: 6),
                          _Tag(label: 'Inactivo', color: scheme.outline),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Money.format(product.cost)} → '
                      '${Money.format(product.price)}  •  '
                      '${_stock(product.stock)} ${product.unit}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        _StockChip(product: product),
                        const SizedBox(width: 8),
                        Text(
                          'Ganancia ${Money.format(product.profit)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  static String _stock(double value) =>
      value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

class _StockChip extends StatelessWidget {
  const _StockChip({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (product.stockState.name) {
      'agotado' => const Color(0xFFC62828),
      'stockBajo' => const Color(0xFFF9A825),
      _ => const Color(0xFF2E7D32),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        product.stockState.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
