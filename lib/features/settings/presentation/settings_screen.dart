import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/app_settings.dart';
import '../../../models/business_settings.dart';
import '../../../models/enums.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/settings_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../repositories/reports_repository.dart' show DashboardSnapshot;

/// Hub de configuración (§40-45).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BusinessSettings business = ref.watch(businessSettingsProvider);
    final AppSettings settings = ref.watch(appSettingsProvider);
    final DashboardSnapshot snapshot = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          _Tile(
            icon: Icons.storefront_outlined,
            title: 'Negocio',
            subtitle: '${business.businessName}  •  ${business.ownerName}',
            onTap: () =>
                context.pushNamed(AppRoutes.businessSettings),
          ),
          _Tile(
            icon: Icons.tune,
            title: 'Preferencias',
            subtitle:
                'Tema ${settings.themePreference.label.toLowerCase()}  •  '
                'stock mínimo ${settings.defaultMinStock}',
            onTap: () => context.pushNamed(AppRoutes.preferencesSettings),
          ),
          _Tile(
            icon: Icons.storage_outlined,
            title: 'Datos y respaldo',
            subtitle: 'Respaldar, restaurar, importar y exportar',
            onTap: () =>
                context.pushNamed(AppRoutes.dataSettings),
          ),
          _Tile(
            icon: Icons.info_outline,
            title: 'Acerca de',
            subtitle: 'Versión ${AppConstants.appVersion}',
            onTap: () =>
                context.pushNamed(AppRoutes.aboutSettings),
          ),

          const SizedBox(height: 24),
          Text(
            'Alcance de los datos',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '${snapshot.totalProducts} productos  •  '
            'inventario ${_money(snapshot.inventoryValue)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Todo se guarda en este teléfono. No hay servidores ni cuentas.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static String _money(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';
}

/// Negocio: nombre, encargado y logo (§6, §40).
class BusinessSettingsScreen extends ConsumerStatefulWidget {
  const BusinessSettingsScreen({super.key});

  @override
  ConsumerState<BusinessSettingsScreen> createState() =>
      _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState
    extends ConsumerState<BusinessSettingsScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _business = TextEditingController(
    text: ref.read(businessSettingsProvider).businessName,
  );
  late final TextEditingController _owner = TextEditingController(
    text: ref.read(businessSettingsProvider).ownerName,
  );
  bool _saving = false;

  @override
  void dispose() {
    _business.dispose();
    _owner.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(businessSettingsProvider.notifier)
          .update(businessName: _business.text, ownerName: _owner.text);
      if (!mounted) return;
      showToast(context, 'Negocio actualizado');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final BusinessSettings business = ref.watch(businessSettingsProvider);
    final String? logo = ref.watch(businessLogoPathProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Negocio')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            Center(
              child: Column(
                children: <Widget>[
                  BusinessLogo(size: 88),
                  const SizedBox(height: 10),
                  if (logo == null)
                    Text(
                      'Usa el logo de la app',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        TextButton.icon(
                          onPressed: () => ref
                              .read(businessSettingsProvider.notifier)
                              .setLogo(null),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Quitar logo'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _business,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del negocio',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _owner,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Encargado',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Estos datos no aparecen en los tickets ni en la app: sólo son '
              'para que sepas de quién es el puesto.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Guardar'),
            ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restart_alt),
              title: const Text('Repetir configuración inicial'),
              subtitle: const Text('Vuelve a pedirte el nombre del negocio'),
              onTap: () => ref.read(onboardingDoneProvider.notifier).complete(),
            ),
            const SizedBox(height: 4),
            Text(
              'Nombre actual: ${business.displayName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Preferencias: tema, moneda, formatos y folio (§36, §37, §38).
class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

/// Los dos campos de texto son controllers, no `initialValue`: el valor se
/// escribe al salir del campo y `initialValue` no se relee del estado.
class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  late final TextEditingController _minStock;
  late final TextEditingController _prefix;

  @override
  void initState() {
    super.initState();
    final AppSettings s = ref.read(appSettingsProvider);
    _minStock = TextEditingController(text: '${s.defaultMinStock}');
    _prefix = TextEditingController(text: s.safePrefix);
  }

  @override
  void dispose() {
    _minStock.dispose();
    _prefix.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSettings settings = ref.watch(appSettingsProvider);
    final AppSettingsNotifier notifier = ref.read(
      appSettingsProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Preferencias')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          const _Section('Apariencia'),
          RadioGroup<ThemePreference>(
            groupValue: settings.themePreference,
            onChanged: (ThemePreference? v) {
              if (v != null) notifier.setTheme(v);
            },
            child: Column(
              children: <Widget>[
                for (final ThemePreference p in ThemePreference.values)
                  RadioListTile<ThemePreference>(
                    value: p,
                    title: Text(p.label),
                    subtitle: Text(_themeHint(p)),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          _Section('Dinero'),
          ListTile(
            title: const Text('Moneda'),
            subtitle: Text('Sólo cambia cómo se muestra; los montos no se '
                'convierten'),
            trailing: DropdownButton<String>(
              value: settings.currency,
              underline: const SizedBox.shrink(),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'MXN', child: Text('MXN')),
                DropdownMenuItem<String>(value: 'USD', child: Text('USD')),
                DropdownMenuItem<String>(value: 'EUR', child: Text('EUR')),
              ],
              onChanged: (String? v) {
                if (v != null) notifier.setCurrency(v);
              },
            ),
          ),
          ListTile(
            title: const Text('Stock mínimo por defecto'),
            subtitle: const Text('Se usa al crear un producto nuevo'),
            trailing: SizedBox(
              width: 90,
              child: TextFormField(
                controller: _minStock,
                textAlign: TextAlign.end,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.number,
                onFieldSubmitted: (_) => _commitMinStock(notifier),
                onTapOutside: (_) {
                  FocusScope.of(context).unfocus();
                  _commitMinStock(notifier);
                },
              ),
            ),
          ),

          const SizedBox(height: 12),
          _Section('Ventas'),
          ListTile(
            title: const Text('Prefijo del folio'),
            subtitle: Text(
              'Tus ventas se numeran ${settings.safePrefix}-000001',
            ),
            trailing: SizedBox(
              width: 90,
              child: TextFormField(
                controller: _prefix,
                textAlign: TextAlign.end,
                textInputAction: TextInputAction.done,
                maxLength: 4,
                onFieldSubmitted: (_) => _commitSalePrefix(notifier),
                onTapOutside: (_) {
                  FocusScope.of(context).unfocus();
                  _commitSalePrefix(notifier);
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Text(
              'El folio nunca se reutiliza, aunque borres o restatures datos.',
              style: theme.textTheme.labelSmall,
            ),
          ),

          const SizedBox(height: 12),
          _Section('Fechas'),
          SegmentedButton<DateFormatPreference>(
            segments: <ButtonSegment<DateFormatPreference>>[
              for (final DateFormatPreference f in DateFormatPreference.values)
                ButtonSegment<DateFormatPreference>(value: f, label: Text(f.label)),
            ],
            selected: <DateFormatPreference>{settings.dateFormat},
            onSelectionChanged: (Set<DateFormatPreference> s) =>
                notifier.setDateFormat(s.first),
          ),
        ],
      ),
    );
  }

  /// Guarda lo tecleado. La pantalla no tiene botón de guardar, así que el
  /// valor tiene que quedar en Hive al salir del campo.
  ///
  /// En Android e iOS el `onTapOutside` por omisión de Flutter no quita el
  /// foco (sólo lo hace en escritorio), así que tocar otro campo no guardaba
  /// nada y el cambio se perdía al salir de la pantalla.
  void _commitMinStock(AppSettingsNotifier notifier) {
    final int parsed = int.tryParse(_minStock.text.trim()) ?? -1;
    if (parsed < 0) {
      showToast(context, 'Valor inválido', isError: true);
      return;
    }
    notifier.setDefaultMinStock(parsed);
  }

  void _commitSalePrefix(AppSettingsNotifier notifier) {
    notifier.setSalePrefix(_prefix.text);
  }

  static String _themeHint(ThemePreference p) => switch (p) {
    ThemePreference.sistema => 'Sigue a Android',
    ThemePreference.claro => 'Siempre claro',
    ThemePreference.oscuro => 'Siempre oscuro',
  };
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
    child: Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
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
      margin: const EdgeInsets.only(bottom: 8),
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

/// Acerca de: qué hace la app y qué no hace (§45).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: <Widget>[
          Center(
            child: Column(
              children: <Widget>[
                BusinessLogo(size: 72),
                const SizedBox(height: 12),
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${AppConstants.appTagline}  •  v${AppConstants.appVersion}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Text('Qué hace', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          const Text(
            'Registra ventas, controla tu inventario, anota tus gastos y te '
            'dice cuánto ganaste de verdad, descontando lo que vendiste y lo '
            'que gastaste.',
          ),
          const SizedBox(height: 20),
          Text('Cómo funciona con tus datos', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          const Text(
            'Todo vive en este teléfono. La app no pide internet, no tiene '
            'cuentas de usuario y nada sale de aquí. Si se descompone el '
            'teléfono, respalda con frecuencia desde Datos y respaldo.',
          ),
          const SizedBox(height: 20),
          Text('Hecho para', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          const Text(
            'Puestos de tianguis y pequeños comercios. Pensado para usarlo '
            'con las manos ocupadas y sin internet.',
          ),
        ],
      ),
    );
  }
}
