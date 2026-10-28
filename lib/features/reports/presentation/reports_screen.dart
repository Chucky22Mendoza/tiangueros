import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/money_widgets.dart';
import '../../../models/enums.dart';
import '../../../models/product.dart';
import '../../../models/profit_summary.dart';
import '../../../providers/repository_providers.dart';
import '../../../routes/app_routes.dart';
import '../../../repositories/reports_repository.dart';

/// Reportes: cuánto vendiste, cuánto ganaste y qué se vendió más (§24, §31-37).
///
/// Los reportes se calculan sobre ventas **válidas**: las canceladas y las
/// devueltas quedan fuera de los totales, pero siguen en el historial (§26).
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportRange _range = ReportRange.sieteDias;
  DateTime? _from;
  DateTime? _to;
  ProductRankMetric _metric = ProductRankMetric.unidades;
  SeriesGranularity _granularity = SeriesGranularity.diario;

  (DateTime, DateTime) get _bounds => _range.resolve(from: _from, to: _to);

  Future<void> _pickCustom() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 6)),
        end: now,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = ReportRange.personalizado;
      _from = picked.start;
      _to = picked.end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ReportsRepository repo = ref.watch(reportsRepositoryProvider);
    final (DateTime from, DateTime to) = _bounds;
    final ProfitSummary summary = repo.summaryForRange(from, to);
    final List<TimePoint> series = repo.series(
      from,
      to,
      granularity: _granularity,
    );
    final List<ProductRank> ranking = repo.rankProducts(
      from,
      to,
      limit: 10,
      metric: _metric,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          // --- Selector de rango (§24) ---
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final ReportRange r in ReportRange.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r.label),
                      selected: _range == r,
                      onSelected: (_) {
                        if (r == ReportRange.personalizado) {
                          _pickCustom();
                        } else {
                          setState(() => _range = r);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // --- Cada cuánto se agrupa la gráfica, junto al rango (§30) ---
          Row(
            children: <Widget>[
              Text(
                'Agrupar',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      for (final SeriesGranularity g in SeriesGranularity.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(g.label),
                            selected: _granularity == g,
                            onSelected: (_) =>
                                setState(() => _granularity = g),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // --- Utilidad neta: el número que importa (§24) ---
          _NetProfitCard(summary: summary),
          const SizedBox(height: 12),

          // --- Ingresos, costo, gastos ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  DetailRow('Ventas', summary.revenue, emphasized: true),
                  DetailRow(
                    'Costo de mercancía',
                    -summary.costOfGoods,
                    valueColor: theme.colorScheme.onSurfaceVariant,
                  ),
                  const Divider(height: 20),
                  DetailRow('Ganancia bruta', summary.grossProfit),
                  DetailRow('Gastos', -summary.expenses),
                  const Divider(height: 20),
                  DetailRow(
                    'Ganancia neta',
                    summary.netProfit,
                    emphasized: true,
                    valueColor:
                        summary.netProfit < 0
                            ? theme.colorScheme.error
                            : theme.colorScheme.secondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // --- Ventas por método de pago ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Por método de pago', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 10),
                  for (final PaymentMethod m in PaymentMethod.values)
                    if (summary.totalFor(m) > 0)
                      DetailRow(m.label, summary.totalFor(m)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // --- Gráfica diaria (§30) ---
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 16),
                    child: Text(
                      'Ventas por ${_granularity.label.toLowerCase()}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  SizedBox(
                    height: 190,
                    child:
                        series.any((TimePoint p) => p.revenue > 0)
                            ? _DailyChart(points: series, granularity: _granularity)
                            : Center(
                              child: Text(
                                'Sin ventas en este periodo',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // --- Ranking de productos (§33) ---
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text('Productos top', style: theme.textTheme.titleSmall),
                      const Spacer(),
                      PopupMenuButton<ProductRankMetric>(
                        tooltip: 'Ordenar por',
                        initialValue: _metric,
                        onSelected: (ProductRankMetric v) =>
                            setState(() => _metric = v),
                        itemBuilder: (BuildContext _) =>
                            <PopupMenuEntry<ProductRankMetric>>[
                              for (final ProductRankMetric m
                                  in ProductRankMetric.values)
                                PopupMenuItem<ProductRankMetric>(
                                  value: m,
                                  child: Text(m.label),
                                ),
                            ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (ranking.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'Sin ventas en este periodo',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    )
                   else
                     for (int i = 0; i < ranking.length; i++)
                       _RankRow(rank: ranking[i], position: i + 1),
                 ],
               ),
             ),
           ),
           const SizedBox(height: 12),

           // --- Inventario (§30) ---
           _InventoryCard(report: repo.inventoryReport()),
         ],
      ),
    );
  }
}

class _NetProfitCard extends StatelessWidget {
  const _NetProfitCard({required this.summary});

  final ProfitSummary summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool negative = summary.netProfit < 0;

    return Card(
      color: negative ? scheme.errorContainer : scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Ganancia neta',
              style: theme.textTheme.labelLarge?.copyWith(
                color: negative ? scheme.onErrorContainer : scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            MoneyText(
              summary.netProfit,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: negative ? scheme.onErrorContainer : scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${summary.salesCount} ventas  •  '
              '${summary.itemsSold} productos  •  '
              'margen ${summary.netMarginPercent.toStringAsFixed(1)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: negative ? scheme.onErrorContainer : scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.points, required this.granularity});

  final List<TimePoint> points;
  final SeriesGranularity granularity;

  /// La etiqueta de un cubo depende de su tamaño: un mes no se etiqueta con
  /// un día suelto.
  String _label(DateTime d) => switch (granularity) {
    SeriesGranularity.diario => Dates.formatChartLabel(d),
    SeriesGranularity.semanal => Dates.formatChartLabel(d),
    SeriesGranularity.mensual => Dates.monthTitle(d),
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final List<FlSpot> revenue = <FlSpot>[
      for (int i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), (points[i].revenue / 100).toDouble()),
    ];
    final List<FlSpot> expenses = <FlSpot>[
      for (int i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), (points[i].expenses / 100).toDouble()),
    ];

    final double maxY = math.max(
      1,
      <double>[
        for (final FlSpot s in revenue) s.y,
        for (final FlSpot s in expenses) s.y,
      ].reduce(math.max),
    );

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (double _) => FlLine(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: maxY <= 5 ? 1 : maxY / 4,
              getTitlesWidget: (double value, TitleMeta meta) => Text(
                Money.formatCompact((value * 100).round()),
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: math.max(1, (points.length / 5).ceil()).toDouble(),
              getTitlesWidget: (double value, TitleMeta meta) {
                final int i = value.round();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _label(points[i].date),
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (List<LineBarSpot> spots) => spots
                .map(
                  (LineBarSpot s) => LineTooltipItem(
                    '${s.barIndex == 0 ? 'Ventas' : 'Gastos'}\n'
                    '${Money.format((s.y * 100).round())}',
                    TextStyle(
                      color: s.barIndex == 0 ? scheme.onInverseSurface : scheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: revenue,
            isCurved: true,
            curveSmoothness: 0.2,
            color: scheme.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withValues(alpha: 0.12),
            ),
          ),
          LineChartBarData(
            spots: expenses,
            isCurved: true,
            curveSmoothness: 0.2,
            color: scheme.error,
            barWidth: 2,
            dashArray: <int>[4, 3],
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.position});

  final ProductRank rank;
  final int position;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 22,
            child: Text(
              '$position',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  rank.name,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${rank.units} vendidos  •  ganancia ${Money.format(rank.profit)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          MoneyText(rank.revenue, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Inventario: valor, stock bajo y agotados (§30).
///
/// No depende del rango de fechas: el inventario es un estado, no una serie.
/// Toca la tarjeta para ir directo a la pantalla de inventario.
class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.report});

  final InventoryReport report;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.goNamed(ShellRoutes.inventory),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('Inventario', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  Text(
                    'Ver todo',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _InventoryStat(
                      label: 'Valor',
                      value: Money.format(report.inventoryValue),
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  Expanded(
                    child: _InventoryStat(
                      label: 'Productos',
                      value: '${report.totalProducts}',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _InventoryStat(
                      label: 'Stock bajo',
                      value: '${report.lowStock}',
                      icon: Icons.warning_amber_rounded,
                      color: report.lowStock > 0
                          ? theme.colorScheme.tertiary
                          : null,
                    ),
                  ),
                  Expanded(
                    child: _InventoryStat(
                      label: 'Agotados',
                      value: '${report.outOfStock}',
                      icon: Icons.cancel_outlined,
                      color: report.outOfStock > 0
                          ? theme.colorScheme.error
                          : null,
                    ),
                  ),
                ],
              ),
              if (report.outOfStockProducts.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'Agotados: ${report.outOfStockProducts.map((Product p) => p.name).join(', ')}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (report.lowStockProducts.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  'Por agotarse: ${report.lowStockProducts.map((Product p) => p.name).join(', ')}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (!report.needsAttention && report.totalProducts > 0) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'Todo el inventario con stock suficiente.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryStat extends StatelessWidget {
  const _InventoryStat({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: color ?? theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
