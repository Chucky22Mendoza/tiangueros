import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/dates.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_widgets.dart';
import '../../../models/enums.dart';
import '../../../models/sale.dart';
import '../../../providers/data_providers.dart';
import '../../../routes/app_routes.dart';

/// Filtro del historial.
enum SaleFilter {
  todas('Todas'),
  hoy('Hoy'),
  semana('Esta semana'),
  mes('Este mes'),
  canceladas('Canceladas');

  const SaleFilter(this.label);

  final String label;
}

final saleFilterProvider = NotifierProvider<SaleFilterNotifier, SaleFilter>(
  SaleFilterNotifier.new,
);

class SaleFilterNotifier extends Notifier<SaleFilter> {
  @override
  SaleFilter build() => SaleFilter.todas;
  void set(SaleFilter f) => state = f;
}

/// Historial de ventas con búsqueda y filtros (§25).
class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key, this.highlightFolio});

  /// Folio a destacar al llegar desde una venta recién cobrada.
  final String? highlightFolio;

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  final TextEditingController _search = TextEditingController();
  SaleFilter _filter = SaleFilter.todas;

  @override
  void initState() {
    super.initState();
    if (widget.highlightFolio != null) {
      _search.text = widget.highlightFolio!;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Sale> _apply(List<Sale> all) {
    final DateTime now = DateTime.now();
    final Iterable<Sale> byFilter = switch (_filter) {
      SaleFilter.todas => all,
      SaleFilter.hoy => all.where(
        (Sale s) => Dates.isSameDay(s.date, now),
      ),
      SaleFilter.semana => all.where(
        (Sale s) => !s.date.isBefore(Dates.startOfWeek(now)),
      ),
      SaleFilter.mes => all.where((Sale s) => !s.date.isBefore(Dates.startOfMonth(now))),
      SaleFilter.canceladas => all.where((Sale s) => s.isCancelled),
    };

    final String q = _search.text.trim().toLowerCase();
    final List<Sale> list = q.isEmpty
        ? byFilter.toList()
        : byFilter
              .where(
                (Sale s) =>
                    s.folio.toLowerCase().contains(q) ||
                    s.items.any(
                      (dynamic i) => (i.productName as String).toLowerCase().contains(q),
                    ),
              )
              .toList();

    list.sort((Sale a, Sale b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Sale>> sales = ref.watch(salesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Venta rápida',
            icon: const Icon(Icons.bolt),
            onPressed: () => context.pushNamed(AppRoutes.quickSale),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // heroTag explícito: con el shell de pestañas las cinco pantallas
        // quedan montadas a la vez y varios FAB con el tag por defecto hacen
        // que Flutter truene al animar la transición.
        heroTag: null,
        onPressed: () => context.pushNamed(AppRoutes.newSale),
        icon: const Icon(Icons.add),
        label: const Text('Venta'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar por folio o producto',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
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
                for (final SaleFilter f in SaleFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: sales.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace _) => Center(child: Text('Error: $e')),
              data: (List<Sale> all) {
                if (all.isEmpty) {
                  return EmptyState(
                    title: 'Todavía no tienes ventas.',
                    message: 'Registra tu primera venta para ver el historial.',
                    icon: Icons.receipt_long_outlined,
                    actionLabel: 'Nueva venta',
                    onAction: () =>
                        context.pushNamed(AppRoutes.newSale),
                  );
                }
                final List<Sale> list = _apply(all);
                if (list.isEmpty) {
                  return const EmptyState(
                    title: 'Sin resultados',
                    message: 'No hay ventas con ese filtro o búsqueda.',
                    icon: Icons.search_off,
                  );
                }
                final int totalCents = list
                    .where((Sale s) => s.countsInStats)
                    .fold<int>(0, (int sum, Sale s) => sum + s.total);

                return Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        children: <Widget>[
                          Text(
                            '${list.length} '
                            '${list.length == 1 ? 'venta' : 'ventas'}',
                            style: theme.textTheme.labelMedium,
                          ),
                          const Spacer(),
                          Text('Total ', style: theme.textTheme.labelMedium),
                          MoneyText(
                            totalCents,
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (BuildContext context, int i) => _SaleTile(
                          sale: list[i],
                          highlight: list[i].folio == widget.highlightFolio,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale, this.highlight = false});

  final Sale sale;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      color: highlight ? scheme.primaryContainer.withValues(alpha: 0.5) : null,
      child: InkWell(
        onTap: () => context.pushNamed(AppRoutes.saleDetail, extra: sale.id),
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
                        Text(sale.folio, style: theme.textTheme.titleSmall),
                        if (sale.isQuickSale) ...<Widget>[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.bolt,
                            size: 14,
                            color: scheme.tertiary),
                        ],
                        if (!sale.countsInStats) ...<Widget>[
                          const SizedBox(width: 6),
                          _StatusTag(status: sale.status),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Dates.formatDate(sale.date)}  •  '
                      '${Dates.formatTime(sale.date)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      '${sale.paymentMethod.label}  •  '
                      '${sale.itemCount} '
                      '${sale.itemCount == 1 ? 'producto' : 'productos'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              MoneyText(
                sale.total,
                style: theme.textTheme.titleMedium?.copyWith(
                  decoration: sale.isCancelled
                      ? TextDecoration.lineThrough
                      : null,
                  color: sale.isCancelled ? scheme.outline : scheme.onSurface,
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.status});

  final SaleStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      SaleStatus.activa => const Color(0xFF2E7D32),
      SaleStatus.cancelada => const Color(0xFFC62828),
      SaleStatus.devuelta => const Color(0xFFEF6C00),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}
