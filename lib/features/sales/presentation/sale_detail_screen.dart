import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/money_widgets.dart';
import '../../../models/sale.dart';
import '../../../models/sale_item.dart';
import '../../../providers/repository_providers.dart';

/// Detalle de una venta con cancelación y devolución (§25, §26, §27).
///
/// **Las ventas nunca se borran.** Se cancelan: el stock vuelve, quedan los
/// movimientos y la venta sigue visible en el historial, fuera de las
/// estadísticas (§26).
class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Sale? sale = ref.watch(salesRepositoryProvider).byId(saleId);

    if (sale == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('La venta ya no existe')),
      );
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool active = sale.countsInStats;

    return Scaffold(
      appBar: AppBar(
        title: Text(sale.folio),
        actions: <Widget>[
          if (active)
            PopupMenuButton<String>(
              onSelected: (String value) => switch (value) {
                'return' => _return(context, ref, sale),
                _ => _cancel(context, ref, sale),
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'return',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.assignment_return_outlined),
                    title: Text('Devolver productos'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'cancel',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.cancel_outlined),
                    title: Text('Cancelar venta'),
                  ),
                ),
              ],
            ),
          if (!active)
            TextButton(
              onPressed: sale.isCancelled
                  ? () => _restore(context, ref, sale)
                  : null,
              child: const Text('Reabrir'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          if (!active)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.info_outline, color: scheme.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sale.isCancelled
                          ? 'Venta CANCELADA. No cuenta en tus estadísticas.'
                          : 'Venta DEVUELTA. No cuenta en tus estadísticas.',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),

          // --- Cabecera ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        Dates.formatDate(sale.date),
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      Text(
                        Dates.formatTime(sale.date),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DetailRow('Método de pago', null, textValue: sale.paymentMethod.label),
                  if (sale.isQuickSale)
                    const DetailRow('Origen', null, textValue: 'Venta rápida'),
                  if (sale.notes.isNotEmpty)
                    DetailRow('Notas', null, textValue: sale.notes),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // --- Partidas con snapshot (§39) ---
          Text('Productos', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: <Widget>[
                  for (final SaleItem item in sale.items)
                    _ItemRow(item: item),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // --- Totales ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  DetailRow('Subtotal', sale.subtotal),
                  if (sale.discount > 0)
                    DetailRow(
                      'Descuento',
                      -sale.discount,
                      valueColor: scheme.tertiary,
                    ),
                  const Divider(height: 20),
                  DetailRow('Total', sale.total, emphasized: true),
                  DetailRow(
                    'Costo',
                    -sale.costTotal,
                    valueColor: scheme.onSurfaceVariant,
                  ),
                  DetailRow(
                    'Ganancia',
                    sale.profit,
                    emphasized: true,
                    valueColor: sale.profit < 0 ? scheme.error : scheme.secondary,
                  ),
                  if (sale.hasUnknownCost) ...<Widget>[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: scheme.tertiary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Algunas partidas se vendieron sin costo registrado: '
                            'la ganancia es estimada.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.tertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (!active) ...<Widget>[
            const SizedBox(height: 20),
            if (sale.isCancelled)
              OutlinedButton.icon(
                onPressed: () => _restore(context, ref, sale),
                icon: const Icon(Icons.undo),
                label: const Text('Reabrir esta venta'),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Sale sale) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Cancelar venta ${sale.folio}?',
      message:
          'El stock de los productos volverá al inventario y la venta dejará de '
          'contar en las estadísticas.\n\nLa venta no se borra: seguirá '
          'visible en el historial.',
      confirmLabel: 'Cancelar venta',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(salesRepositoryProvider).cancelSale(sale.id);
      if (!context.mounted) return;
      showToast(context, 'Venta cancelada');
    } on AppException catch (e) {
      if (!context.mounted) return;
      showToast(context, e.message, isError: true);
    }
  }

  Future<void> _return(BuildContext context, WidgetRef ref, Sale sale) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Devolver productos',
      message:
          'Se devolverá todo lo vendido en ${sale.folio} al inventario y la '
          'venta dejará de contar en las estadísticas.',
      confirmLabel: 'Devolver',
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(salesRepositoryProvider).returnSale(sale.id);
      if (!context.mounted) return;
      showToast(context, 'Devolución registrada');
    } on AppException catch (e) {
      if (!context.mounted) return;
      showToast(context, e.message, isError: true);
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref, Sale sale) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Reabrir venta',
      message:
          'Se volverá a descontar el stock de los productos y la venta contará '
          'nuevamente en las estadísticas.',
      confirmLabel: 'Reabrir',
      destructive: false,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(salesRepositoryProvider).restoreSale(sale.id);
      if (!context.mounted) return;
      showToast(context, 'Venta reabierta');
    } on AppException catch (e) {
      if (!context.mounted) return;
      showToast(context, e.message, isError: true);
    }
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final SaleItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${item.quantity}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.productName,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${Money.format(item.price)} c/u',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          MoneyText(item.lineTotal, style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
