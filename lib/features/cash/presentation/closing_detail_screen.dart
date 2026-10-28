import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/dates.dart';
import '../../../core/widgets/money_widgets.dart';
import '../../../models/daily_closing.dart';
import '../../../providers/data_providers.dart';
import '../../../routes/app_routes.dart';

/// Detalle de un cierre ya guardado (§29).
///
/// Los cierres son un registro histórico: se pueden consultar, no editar. Un
/// día ya cerrado no se recalcula aunque después se registren movimientos.
class ClosingDetailScreen extends ConsumerWidget {
  const ClosingDetailScreen({super.key, required this.closingId});

  final String closingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    DailyClosing? closing;
    for (final DailyClosing c in ref.watch(closingsProvider)) {
      if (c.id == closingId) {
        closing = c;
        break;
      }
    }

    if (closing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('El cierre ya no existe')),
      );
    }

    final int? diff = closing.difference;

    return Scaffold(
      appBar: AppBar(title: Text(Dates.formatDate(closing.date))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: <Widget>[
                  Text('Total vendido', style: theme.textTheme.labelMedium),
                  MoneyText(
                    closing.total,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${closing.salesCount} ventas  •  '
                    '${closing.itemsSold} productos',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  DetailRow('Efectivo', closing.cashTotal),
                  DetailRow('Transferencia', closing.transferTotal),
                  DetailRow('Tarjeta', closing.cardTotal),
                  if (closing.otherTotal > 0)
                    DetailRow('Otro', closing.otherTotal),
                  const Divider(height: 22),
                  DetailRow('Costo de mercancía', -closing.costTotal),
                  DetailRow('Ganancia bruta', closing.grossProfit),
                  DetailRow('Gastos', -closing.expensesTotal),
                  const Divider(height: 22),
                  DetailRow(
                    'Utilidad neta',
                    closing.netProfit,
                    emphasized: true,
                    valueColor:
                        closing.netProfit < 0
                            ? theme.colorScheme.error
                            : theme.colorScheme.secondary,
                  ),
                ],
              ),
            ),
          ),
          if (closing.countedCash != null) ...<Widget>[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    DetailRow('Efectivo esperado', closing.cashTotal),
                    DetailRow('Efectivo contado', closing.countedCash!),
                    const Divider(height: 22),
                    DetailRow(
                      diff == 0
                          ? 'Diferencia'
                          : diff! > 0
                          ? 'Sobró'
                          : 'Faltó',
                      diff?.abs() ?? 0,
                      emphasized: true,
                      valueColor:
                          diff == 0
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.error,
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (closing.closingNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Nota del cierre', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(closing.closingNote),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => context.pushNamed(AppRoutes.cash),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Ir a Caja'),
          ),
        ],
      ),
    );
  }
}
