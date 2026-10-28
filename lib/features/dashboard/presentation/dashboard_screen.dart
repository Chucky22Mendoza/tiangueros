import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/money_widgets.dart';
import '../../../models/business_settings.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/settings_provider.dart';
import '../../../repositories/reports_repository.dart';
import '../../../routes/app_routes.dart';

/// Pantalla principal: métricas de hoy, inventario y acciones rápidas
/// (§11, §12, §13, §14).
///
/// Prioridad de uso: **VELOCIDAD**. Todo lo accionable está a un toque y el
/// botón de Nueva venta domina visualmente.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final BusinessSettings business = ref.watch(businessSettingsProvider);
    final DashboardSnapshot snapshot = ref.watch(dashboardProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // El Dashboard ya se recalcula con cada cambio en Hive; el gesto
            // sólo da sensación de control.
            ref.invalidate(dashboardProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: <Widget>[
              _Header(business: business),
              const SizedBox(height: 20),

              // --- Métricas de hoy (§12) ---
              Text('Hoy', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: <Widget>[
                  MetricCard(
                    label: 'Ventas de hoy',
                    value: snapshot.revenue,
                    icon: Icons.payments_outlined,
                    color: scheme.primary,
                  ),
                  MetricCard(
                    label: 'Ganancia estimada',
                    value: snapshot.estimatedProfit,
                    icon: Icons.trending_up,
                    color: scheme.secondary,
                  ),
                  MetricCard(
                    label: 'Productos vendidos',
                    value: snapshot.itemsSold,
                    icon: Icons.shopping_bag_outlined,
                    color: scheme.tertiary,
                    units: true,
                  ),
                  MetricCard(
                    label: 'Gastos',
                    value: snapshot.expenses,
                    icon: Icons.receipt_long_outlined,
                    color: scheme.error,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${snapshot.salesCount} '
                '${snapshot.salesCount == 1 ? 'venta' : 'ventas'} registradas',
                style: theme.textTheme.bodySmall,
              ),

              // --- Acciones rápidas (§14) ---
              const SizedBox(height: 20),
              const _QuickActions(),

              // --- Inventario (§13) ---
              const SizedBox(height: 20),
              _InventoryCard(snapshot: snapshot),
              const SizedBox(height: 10),
              _ValueRow(snapshot: snapshot),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.business});

  final BusinessSettings business;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const BusinessLogo(size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                business.displayName,
                style: theme.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Encargado: ${business.displayOwner}',
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${Dates.greeting()} 👋',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Nueva venta a pantalla completa: el camino más importante (§14, §52).
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          height: 60,
          child: FilledButton.icon(
            onPressed: () =>
                context.pushNamed(AppRoutes.newSale),
            style: FilledButton.styleFrom(
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            icon: const Icon(Icons.point_of_sale, size: 24),
            label: const Text('NUEVA VENTA'),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _ActionButton(
                label: 'Producto',
                icon: Icons.add_box_outlined,
                onTap: () =>
                    context.pushNamed(AppRoutes.productForm),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                label: 'Gasto',
                icon: Icons.receipt_long_outlined,
                onTap: () =>
                    context.pushNamed(AppRoutes.expenseForm),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _ActionButton(
                label: 'Inventario',
                icon: Icons.inventory_2_outlined,
                onTap: () =>
                    context.goNamed(ShellRoutes.inventory),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                label: 'Venta rápida',
                icon: Icons.bolt,
                onTap: () =>
                    context.pushNamed(AppRoutes.quickSale),
                highlight: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlight = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SizedBox(
      height: 56,
      child: highlight
          ? FilledButton.tonalIcon(
              onPressed: onTap,
              icon: Icon(icon, size: 20),
              label: Text(label, style: theme.textTheme.labelLarge),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 20, color: scheme.primary),
              label: Text(label, style: theme.textTheme.labelLarge),
            ),
    );
  }
}

/// Resumen de inventario con acceso directo a la pantalla (§13).
class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

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
                  Text('Inventario', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${snapshot.totalProducts} '
                '${snapshot.totalProducts == 1 ? 'producto' : 'productos'}',
                style: theme.textTheme.bodyLarge,
              ),
              if (snapshot.lowStock > 0 || snapshot.outOfStock > 0) ...<Widget>[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (snapshot.lowStock > 0)
                      _Badge(
                        icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFF9A825),
                        label: '${snapshot.lowStock} con stock bajo',
                      ),
                    if (snapshot.outOfStock > 0)
                      _Badge(
                        icon: Icons.cancel,
                        color: const Color(0xFFC62828),
                        label: '${snapshot.outOfStock} agotados',
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.snapshot});

  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.account_balance_wallet_outlined,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Valor del inventario',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            Text(
              Money.formatCompact(snapshot.inventoryValue),
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta de la app, reutilizada por el splash y la pantalla de info.
class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const AppLogo(size: 72),
        const SizedBox(height: 12),
        Text(
          AppConstants.appName,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 2),
        Text(
          AppConstants.appTagline,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
