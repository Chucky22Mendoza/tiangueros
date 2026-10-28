import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import 'package:share_plus/share_plus.dart';

import '../../../core/utils/file_service.dart';
import '../../../core/utils/pick_service.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../providers/data_providers.dart';
import '../../../features/backup/data/backup_service.dart';
import '../../../features/backup/data/product_transfer_codec.dart';
import '../../../models/enums.dart';
import '../../../features/backup/data/product_transfer_service.dart';
import '../../../providers/repository_providers.dart';
import '../../../repositories/reports_repository.dart' show DashboardSnapshot;

/// Datos, respaldos e intercambio con otros dispositivos (§33, §34, §35, §46).
class DataSettingsScreen extends ConsumerStatefulWidget {
  const DataSettingsScreen({super.key});

  @override
  ConsumerState<DataSettingsScreen> createState() =>
      _DataSettingsScreenState();
}

class _DataSettingsScreenState extends ConsumerState<DataSettingsScreen> {
  bool _busy = false;

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Respaldo ---

  Future<void> _exportBackup() => _guard(() async {
    final String path = await ref.read(backupServiceProvider).exportToFile();
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(path)],
        text: 'Respaldo de ${FileService.backupFileName()}',
      ),
    );
  });

  Future<void> _restoreBackup() => _guard(() async {
    final String? path = await _pickFile('json');
    if (path == null || !mounted) return;

    final String content = await File(path).readAsString();
    if (!mounted) return;
    final BackupService service = ref.read(backupServiceProvider);
    // Se inspecciona antes de tocar nada: restaurar **reemplaza** todo.
    final ImportPreviewOfBackup preview = service.inspect(content);
    if (!mounted) return;
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Restaurar respaldo',
      message:
          'Se REEMPLAZARÁN todos tus datos actuales por los del respaldo.\n\n'
          '${preview.summary}\n\n'
          'No se puede deshacer. Haz un respaldo de lo que tienes hoy antes '
          'de continuar.',
      confirmLabel: 'Reemplazar todo',
    );
    if (!ok || !mounted) return;

    final RestoreResult result = await service.restoreFromFile(path);
    if (!mounted) return;
    ref.invalidate(dashboardProvider);
    showToast(context, 'Restaurado: ${result.totalRecords} registros');
  });

  // --- Productos ---

  Future<void> _exportProducts() => _guard(() async {
    final ProductExportFormat? format = await _chooseFormat();
    if (format == null || !mounted) return;
    final String path = await ref
        .read(productTransferServiceProvider)
        .exportProducts(format);
    if (!mounted) return;
    await SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(path)]),
    );
  });

  Future<void> _importProducts() => _guard(() async {
    final String? path = await _pickFile('csv,json');
    if (path == null || !mounted) return;

    final String content = await File(path).readAsString();
    if (!mounted) return;
    final ProductTransferService service = ref.read(
      productTransferServiceProvider,
    );
    // Se analiza antes de escribir: el usuario ve qué trae el archivo y decide
    // qué hacer con los productos que ya existen (§33).
    final ImportPreview preview = service.preview(content);
    if (!preview.canImport) {
      showToast(
        context,
        preview.errorCount > 0
            ? 'Ninguna fila es válida (${preview.errorCount} con errores)'
            : 'El archivo no tiene productos',
        isError: true,
      );
      return;
    }

    ImportConflictStrategy strategy = ImportConflictStrategy.actualizar;
    if (preview.isExisting > 0) {
      final ImportConflictStrategy? chosen = await showDialog<
        ImportConflictStrategy
      >(
        context: context,
        builder: (BuildContext ctx) => SimpleDialog(
          title: Text('${preview.isExisting} productos ya existen'),
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text('¿Qué hacemos con los que ya tienes?'),
            ),
            for (final ImportConflictStrategy s in ImportConflictStrategy.values)
              SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(s),
                child: Text(s.label),
              ),
          ],
        ),
      );
      if (chosen == null || !mounted) return;
      strategy = chosen;
    }

    final ImportOutcome outcome = await service.importProducts(preview, strategy);
    if (!mounted) return;
    showToast(context, outcome.summary);
  });

  // --- Demo ---

  Future<void> _seedDemo() => _guard(() async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Cargar datos de ejemplo',
      message:
          'Se agregarán 14 productos y ventas de la última semana para que '
          'puedas probar la app.\n\nNo se borra nada de lo que ya tienes.',
      confirmLabel: 'Cargar',
      destructive: false,
    );
    if (!ok || !mounted) return;
    await ref.read(demoDataServiceProvider).seed();
    if (!mounted) return;
    ref.invalidate(dashboardProvider);
    showToast(context, 'Datos de ejemplo cargados');
  });

  Future<void> _clearDemo() => _guard(() async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Quitar datos de ejemplo',
      message: 'Se borrarán sólo los productos, ventas y gastos de ejemplo.',
      confirmLabel: 'Quitar',
    );
    if (!ok || !mounted) return;
    await ref.read(demoDataServiceProvider).clearDemo();
    if (!mounted) return;
    ref.invalidate(dashboardProvider);
    showToast(context, 'Datos de ejemplo eliminados');
  });

  // --- Borrado total ---

  Future<void> _wipe() => _guard(() async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Borrar todos los datos',
      message:
          'Se borrará TODO: productos, ventas, movimientos, gastos, caja y '
          'cierres.\n\nNo se puede deshacer. Si no estás seguro, cancela y haz '
          'un respaldo primero.',
      confirmLabel: 'Borrar todo',
    );
    if (!ok || !mounted) return;
    final NavigatorState navigator = Navigator.of(context);
    await ref.read(settingsRepositoryProvider).wipeEverything();
    if (!navigator.mounted) return;
    navigator.popUntil((Route<void> r) => r.isFirst);
  });

  Future<ProductExportFormat?> _chooseFormat() => showDialog<ProductExportFormat>(
    context: context,
    builder: (BuildContext ctx) => SimpleDialog(
      title: const Text('Formato de exportación'),
      children: <Widget>[
        for (final ProductExportFormat f in ProductExportFormat.values)
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(f),
            child: Text('${f.label} (${f.extension})'),
          ),
      ],
    ),
  );

  Future<String?> _pickFile(String type) => PickService.pick(type: type);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DashboardSnapshot snapshot = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Datos y respaldo'),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          _Header(
            icon: Icons.backup_outlined,
            title: 'Respaldo completo',
            subtitle: 'Un archivo con todo: negocio, catálogo, ventas, '
                'movimientos, gastos, caja y cierres.',
          ),
          _Action(
            icon: Icons.ios_share,
            title: 'Crear y compartir respaldo',
            onTap: _exportBackup,
          ),
          _Action(
            icon: Icons.restore,
            title: 'Restaurar desde un archivo',
            subtitle: 'Reemplaza todos los datos actuales',
            onTap: _restoreBackup,
            destructive: true,
          ),

          const SizedBox(height: 20),
          _Header(
            icon: Icons.table_chart_outlined,
            title: 'Sólo productos',
            subtitle: 'Para pasar el catálogo a otro dispositivo o abrirlo en '
                'una hoja de cálculo.',
          ),
          _Action(
            icon: Icons.file_download_outlined,
            title: 'Exportar productos',
            onTap: _exportProducts,
          ),
          _Action(
            icon: Icons.file_upload_outlined,
            title: 'Importar productos',
            subtitle: 'Agrega o actualiza por nombre y SKU',
            onTap: _importProducts,
          ),

          const SizedBox(height: 20),
          _Header(
            icon: Icons.science_outlined,
            title: 'Datos de ejemplo',
            subtitle: 'Para probar la app sin meter datos reales.',
          ),
          _Action(
            icon: Icons.auto_awesome,
            title: 'Cargar datos de ejemplo',
            onTap: _seedDemo,
          ),
          _Action(
            icon: Icons.cleaning_services_outlined,
            title: 'Quitar datos de ejemplo',
            onTap: _clearDemo,
          ),

          const SizedBox(height: 20),
          _Header(
            icon: Icons.delete_forever_outlined,
            title: 'Zona de riesgo',
            subtitle: '${snapshot.totalProducts} productos y '
                '${snapshot.salesCount} ventas de hoy en tu base.',
          ),
          _Action(
            icon: Icons.delete_forever,
            title: 'Borrar todos los datos',
            subtitle: 'Empieza de cero. No se puede deshacer.',
            onTap: _wipe,
            destructive: true,
          ),
          const SizedBox(height: 16),
          Text(
            'Tus datos viven sólo en este teléfono. Respaldar es tu única '
            'red de seguridad.',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleSmall),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(
          icon,
          color: destructive ? scheme.error : scheme.primary,
        ),
        title: Text(
          title,
          style: destructive
              ? TextStyle(color: scheme.error)
              : null,
        ),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
