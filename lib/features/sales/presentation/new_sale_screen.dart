import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_widgets.dart';
import '../../../models/enums.dart';
import '../../../models/product.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../routes/app_routes.dart';
import '../../../repositories/sales_repository.dart' show CartLine, SaleResult;
import '../application/cart_controller.dart';

/// Pantalla de nueva venta: buscar → carrito → método de pago → cobrar
/// (§15, §52).
class NewSaleScreen extends ConsumerStatefulWidget {
  const NewSaleScreen({super.key});

  @override
  ConsumerState<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends ConsumerState<NewSaleScreen> {
  final TextEditingController _search = TextEditingController();
  PaymentMethod _method = PaymentMethod.efectivo;
  bool _charging = false;
  double _discountPercent = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _charge() async {
    final CartSummary summary = ref.read(cartSummaryProvider);
    if (summary.isEmpty) {
      showToast(context, 'Agrega al menos un producto', isError: true);
      return;
    }
    setState(() => _charging = true);
    try {
      // Primero se refrescan precios y stock: lo que se cobra debe ser lo que
      // hay en el catálogo ahora, no lo que había al meter el producto.
      final CartNotifier cartNotifier = ref.read(cartProvider.notifier);
      cartNotifier.refreshFrom(ref.read(productRepositoryProvider).all());
      final CartState cart = ref.read(cartProvider);
      if (cart.isEmpty) {
        throw const ValidationException('Los productos ya no están disponibles');
      }
      final SaleResult result = await ref
          .read(salesRepositoryProvider)
          .checkout(
            lines: cart.lines,
            paymentMethod: _method,
            discount: cart.discountCents,
          );
      if (!mounted) return;
      cartNotifier.clear();
      if (!mounted) return;
      Navigator.of(context).pop(result.folio);
    } on AppException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _charging = false);
    }
  }

  void _openDiscount() {
    final CartSummary summary = ref.read(cartSummaryProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _DiscountSheet(
        initialPercent: _discountPercent,
        subtotal: summary.subtotal,
        onApply: (double percent) {
          setState(() => _discountPercent = percent);
          ref
              .read(cartProvider.notifier)
              .setDiscount(Money.discount(summary.subtotal, percent));
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CartState cart = ref.watch(cartProvider);
    final CartSummary summary = ref.watch(cartSummaryProvider);
    final AsyncValue<List<Product>> products = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva venta'),
        actions: <Widget>[
          if (cart.isNotEmpty)
            IconButton(
              tooltip: 'Vaciar carrito',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final bool ok = await ConfirmDialog.show(
                  context,
                  title: 'Vaciar carrito',
                  message: 'Se quitarán todos los productos de la venta.',
                  confirmLabel: 'Vaciar',
                );
                if (ok) ref.read(cartProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (String v) =>
                  ref.read(productSearchQueryProvider.notifier).set(v),
              decoration: InputDecoration(
                hintText: 'Buscar producto',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Venta rápida',
                  icon: const Icon(Icons.bolt),
                  onPressed: () => context.pushNamed(AppRoutes.quickSale),
                ),
              ),
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: <Widget>[
                  const TabBar(
                    tabs: <Widget>[
                      Tab(text: 'Productos'),
                      Tab(text: 'Carrito'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        _ProductPicker(
                          products: products,
                          onAdd: (Product p) =>
                              ref.read(cartProvider.notifier).add(p),
                        ),
                        _CartList(cart: cart, summary: summary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ChargeBar(
        summary: summary,
        method: _method,
        charging: _charging,
        hasDiscount: summary.discount > 0,
        onMethodChanged: (PaymentMethod m) => setState(() => _method = m),
        onDiscount: _openDiscount,
        onCharge: _charge,
      ),
    );
  }
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({required this.products, required this.onAdd});

  final AsyncValue<List<Product>> products;
  final ValueChanged<Product> onAdd;

  @override
  Widget build(BuildContext context) {
    return products.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace _) => Center(child: Text('Error: $e')),
      data: (List<Product> all) {
        final List<Product> active = all
            .where((Product p) => p.active)
            .toList()
          ..sort(
            (Product a, Product b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        if (active.isEmpty) {
          return EmptyState(
            title: 'Todavía no tienes productos.',
            message:
                'Puedes registrar ventas sin catálogo usando '
                '"Venta rápida".',
            icon: Icons.point_of_sale_outlined,
            actionLabel: 'Venta rápida',
            onAction: () =>
                context.pushNamed(AppRoutes.quickSale),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: active.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (BuildContext context, int i) {
            final Product p = active[i];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${Money.format(p.price)}  •  '
                  'stock ${_trim(p.stock)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: IconButton.filledTonal(
                  onPressed: p.stock <= 0 ? null : () => onAdd(p),
                  icon: const Icon(Icons.add),
                ),
                onTap: p.stock > 0 ? () => onAdd(p) : null,
              ),
            );
          },
        );
      },
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

class _CartList extends ConsumerWidget {
  const _CartList({required this.cart, required this.summary});

  final CartState cart;
  final CartSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (cart.isEmpty) {
      return const EmptyState(
        title: 'Carrito vacío',
        message: 'Toca un producto para agregarlo a la venta.',
        icon: Icons.shopping_cart_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: cart.lines.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int i) {
        final CartLine line = cart.lines[i];
        final int requested = line.quantity;
        final bool overStock = requested > line.availableStock;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            line.productName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${Money.format(line.unitPrice)} c/u  •  '
                'stock ${_trim(line.availableStock)}',
                style: theme.textTheme.bodySmall,
              ),
              if (overStock)
                Text(
                  'Sin stock suficiente',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => ref
                    .read(cartProvider.notifier)
                    .setQuantity(line.productId, line.quantity - 1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '${line.quantity}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => ref
                    .read(cartProvider.notifier)
                    .setQuantity(line.productId, line.quantity + 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => ref
                    .read(cartProvider.notifier)
                    .remove(line.productId),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          onTap: () => _editPrice(context, ref, line),
        );
      },
    );
  }

  /// Permite cambiar el precio de una línea (negociación en el mostrador).
  Future<void> _editPrice(
    BuildContext context,
    WidgetRef ref,
    CartLine line,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: Money.toEditableString(line.unitPrice),
    );
    final int? price = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(line.productName),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Precio unitario',
            prefixText: r'$ ',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final int? cents = Money.tryParseToCents(controller.text);
              if (cents == null || cents < 0) return;
              Navigator.of(ctx).pop(cents);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (price != null) {
      ref.read(cartProvider.notifier).setPrice(line.productId, price);
    }
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

class _ChargeBar extends StatelessWidget {
  const _ChargeBar({
    required this.summary,
    required this.method,
    required this.charging,
    required this.hasDiscount,
    required this.onMethodChanged,
    required this.onDiscount,
    required this.onCharge,
  });

  final CartSummary summary;
  final PaymentMethod method;
  final bool charging;
  final bool hasDiscount;
  final ValueChanged<PaymentMethod> onMethodChanged;
  final VoidCallback onDiscount;
  final VoidCallback onCharge;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: <Widget>[
                      for (final PaymentMethod m in PaymentMethod.values)
                        ChoiceChip(
                          label: Text(m.label, style: theme.textTheme.labelSmall),
                          selected: method == m,
                          onSelected: (_) => onMethodChanged(m),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Total (${summary.itemCount} '
                        '${summary.itemCount == 1 ? 'artículo' : 'artículos'})',
                        style: theme.textTheme.labelSmall,
                      ),
                      MoneyText(
                        summary.total,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (hasDiscount)
                        Text(
                          'Descuento ${Money.format(summary.discount)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.tertiary,
                          ),
                        ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: summary.isEmpty ? null : onDiscount,
                  child: const Text('Descuento'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: summary.isEmpty || charging ? null : onCharge,
                  icon: charging
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Cobrar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscountSheet extends StatefulWidget {
  const _DiscountSheet({
    required this.initialPercent,
    required this.subtotal,
    required this.onApply,
  });

  final double initialPercent;
  final int subtotal;
  final ValueChanged<double> onApply;

  @override
  State<_DiscountSheet> createState() => _DiscountSheetState();
}

class _DiscountSheetState extends State<_DiscountSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialPercent == 0
        ? ''
        : widget.initialPercent.toStringAsFixed(0),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final String raw = _controller.text.trim();
    if (raw.isEmpty) {
      widget.onApply(0);
      return;
    }
    final String? error = V.discountPercent(raw);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    widget.onApply(double.parse(raw));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Aplicar descuento', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Subtotal: ${Money.format(widget.subtotal)}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Descuento (%)',
              suffixText: '%',
              errorText: _error,
            ),
            onSubmitted: (_) => _apply(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final double p in <double>[5, 10, 15, 20, 50])
                ActionChip(
                  label: Text('${p.toInt()}%'),
                  onPressed: () => _controller.text = p.toStringAsFixed(0),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _apply, child: const Text('Aplicar')),
          ),
        ],
      ),
    );
  }
}
