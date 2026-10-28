import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/money_widgets.dart';
import '../../../models/enums.dart';
import '../../../models/inventory_movement.dart';
import '../../../models/product.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../routes/app_routes.dart';

/// Ficha del producto: costo, precio, ganancia, margen, stock y movimientos
/// (§19, §22).
class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Product? product = ref
        .watch(productRepositoryProvider)
        .byId(productId);

    if (product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('El producto ya no existe')),
      );
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AsyncValue<List<InventoryMovement>> movements = ref.watch(
      productMovementsProvider(productId),
    );
    final double stockValue = product.stock * product.price;

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: <Widget>[
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.pushNamed(
              AppRoutes.productForm,
              extra: product.id,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // heroTag explícito: con el shell de pestañas las cinco pantallas
        // quedan montadas a la vez y varios FAB con el tag por defecto hacen
        // que Flutter truene al animar la transición.
        heroTag: null,
        onPressed: () => context.pushNamed(AppRoutes.stockEntry, extra: product.id),
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('Agregar mercancía')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: <Widget>[
          if (!product.active)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Banner(
                location: BannerLocation.topStart,
                message: 'Producto archivado: no aparece al buscar para vender.',
                color: scheme.surfaceContainerHighest,
                child: const SizedBox(height: 4),
              ),
            ),

          // --- Precio y ganancia (§19) ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  DetailRow('Costo', product.cost),
                  DetailRow('Precio', product.price, emphasized: true),
                  const Divider(height: 20),
                  DetailRow(
                    'Ganancia',
                    product.profit,
                    emphasized: true,
                    valueColor: product.profit < 0 ? scheme.error : scheme.secondary,
                  ),
                  DetailRow(
                    'Margen',
                    null,
                    textValue: '${product.marginPercent.toStringAsFixed(2)}%',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // --- Stock ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text('Stock', style: theme.textTheme.titleSmall),
                      ),
                      _StateChip(state: product.stockState),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _Stat(
                          label: 'Disponible',
                          value:
                              '${_trim(product.stock)} ${product.unit}',
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          label: 'Mínimo',
                          value: '${product.minStock}',
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          label: 'Valor',
                          value: Money.formatCompact(
                            (product.cost * product.stock).round(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Valor a precio de venta: ${Money.format(stockValue.round())}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.pushNamed(AppRoutes.stockEntry, extra: product.id),
                  icon: const Icon(Icons.add),
                  label: const Text('Entrada')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.pushNamed(AppRoutes.stockAdjust, extra: product.id),
                  icon: const Icon(Icons.tune),
                  label: const Text('Ajuste')),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- Movimientos (§22) ---
          Text('Movimientos', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          movements.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (Object e, StackTrace _) => Text('Error: $e'),
            data: (List<InventoryMovement> list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'Todavía no hay movimientos de este producto.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : Column(
                    children: <Widget>[
                      for (final InventoryMovement m in list)
                        _MovementTile(movement: m),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});

  final StockState state;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (state) {
      StockState.disponible => const Color(0xFF2E7D32),
      StockState.stockBajo => const Color(0xFFF9A825),
      StockState.agotado => const Color(0xFFC62828),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        state.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});

  final InventoryMovement movement;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool positive = movement.delta > 0;
    final Color color = positive
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(
          positive ? Icons.arrow_upward : Icons.arrow_downward,
          color: color,
          size: 18,
        ),
      ),
      title: Text(
        movement.type.label,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        '${Dates.formatDateTime(movement.date)}'
        '${movement.reason.isEmpty ? '' : '\n${movement.reason}'}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            '${positive ? '+' : '−'}'
            '${_trim(movement.quantity)}',
            style: theme.textTheme.titleSmall?.copyWith(color: color),
          ),
          Text(
            '${_trim(movement.previousStock)} → ${_trim(movement.newStock)}',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
