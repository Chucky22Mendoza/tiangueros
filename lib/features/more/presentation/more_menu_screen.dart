import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../models/business_settings.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/settings_provider.dart';
import '../../../repositories/reports_repository.dart' show DashboardSnapshot;
import '../../../routes/app_routes.dart';

/// Menú "Más": todo lo que no cabe en las cinco pestañas (§43).
class MoreMenuScreen extends ConsumerWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final BusinessSettings business = ref.watch(businessSettingsProvider);
    final DashboardSnapshot snapshot = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          // Identidad del negocio (§6)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  BusinessLogo(size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          business.businessName,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          business.ownerName,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hoy: ${snapshot.salesCount} ventas  •  '
                          '${snapshot.totalProducts} productos',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Configuración',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () =>
                        context.pushNamed(AppRoutes.settings),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          _SectionLabel('Ventas', theme),
          _MenuTile(
            icon: Icons.point_of_sale_outlined,
            title: 'Nueva venta',
            subtitle: 'Vender productos del catálogo',
            onTap: () => context.pushNamed(AppRoutes.newSale),
          ),
          _MenuTile(
            icon: Icons.bolt,
            title: 'Venta rápida',
            subtitle: 'Cobrar algo que no está en el catálogo',
            onTap: () => context.pushNamed(AppRoutes.quickSale),
          ),
          _MenuTile(
            icon: Icons.receipt_long_outlined,
            title: 'Historial de ventas',
            subtitle: 'Consultar, cancelar o devolver',
            onTap: () => context.goNamed(ShellRoutes.sales),
          ),

          const SizedBox(height: 14),
          _SectionLabel('Dinero', theme),
          _MenuTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Caja',
            subtitle: 'Cuadre de efectivo y cierre del día',
            onTap: () => context.pushNamed(AppRoutes.cash),
          ),
          _MenuTile(
            icon: Icons.payments_outlined,
            title: 'Gastos',
            subtitle: 'Cuotas, transporte, comida, bolsas',
            onTap: () => context.pushNamed(AppRoutes.expenses),
          ),
          _MenuTile(
            icon: Icons.insights_outlined,
            title: 'Reportes',
            subtitle: 'Ganancias, productos que más venden',
            onTap: () => context.goNamed(ShellRoutes.reports),
          ),

          const SizedBox(height: 14),
          _SectionLabel('Catálogo', theme),
          _MenuTile(
            icon: Icons.inventory_2_outlined,
            title: 'Productos',
            subtitle: 'Alta, precios y archivo',
            onTap: () => context.goNamed(ShellRoutes.products),
          ),
          _MenuTile(
            icon: Icons.swap_vert,
            title: 'Inventario',
            subtitle: 'Entradas, ajustes y movimientos',
            onTap: () => context.goNamed(ShellRoutes.inventory),
          ),

          const SizedBox(height: 14),
          _SectionLabel('App', theme),
          _MenuTile(
            icon: Icons.settings_outlined,
            title: 'Configuración',
            subtitle: 'Negocio, preferencias, datos y respaldo',
            onTap: () => context.pushNamed(AppRoutes.settings),
          ),
          _MenuTile(
            icon: Icons.info_outline,
            title: 'Acerca de',
            subtitle: 'Versión ${AppConstants.appVersion}',
            onTap: () => context.pushNamed(AppRoutes.aboutSettings),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.theme);

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
    child: Text(
      text.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
