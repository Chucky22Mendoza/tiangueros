import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_widgets.dart';
import '../../../models/cash_movement.dart';
import '../../../models/daily_closing.dart';
import '../../../models/enums.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../repositories/cash_repository.dart';
import '../../../repositories/reports_repository.dart';
import '../../../routes/app_routes.dart';

/// Control de caja: cuánto dinero debería haber y cuánto hay (§28).
///
/// Las ventas en efectivo, los gastos y las entradas y salidas manuales se
/// reflejan aquí. Las ventas con tarjeta o transferencia **no** entran: no son
/// efectivo del puesto.
class CashScreen extends ConsumerStatefulWidget {
  const CashScreen({super.key});

  @override
  ConsumerState<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends ConsumerState<CashScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  DateTime _day = DateTime.now();

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _shiftDay(int days) {
    setState(() {
      _day = _day.add(Duration(days: days));
      final DateTime now = DateTime.now();
      if (_day.isAfter(now)) _day = now;
    });
  }

  Future<void> _closing() async {
    final bool? ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext _) => DailyClosingScreen(day: _day),
      ),
    );
    if (ok == true && mounted) showToast(context, 'Cierre guardado');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CashBreakdown breakdown = ref.watch(cashBreakdownProvider);
    final DailyClosing? closing = ref
        .watch(reportsRepositoryProvider)
        .closingForDay(_day);
    final bool isToday = Dates.isSameDay(_day, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const <Widget>[
            Tab(text: 'Hoy'),
            Tab(text: 'Historial de cierres'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // heroTag explícito: con el shell de pestañas las cinco pantallas
        // quedan montadas a la vez y varios FAB con el tag por defecto hacen
        // que Flutter truene al animar la transición.
        heroTag: null,
        onPressed: _closing,
        icon: const Icon(Icons.point_of_sale_outlined),
        label: const Text('Cerrar día'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: <Widget>[
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => _shiftDay(-1),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Día anterior',
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        isToday ? 'Hoy' : Dates.relativeDay(_day),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: isToday ? null : () => _shiftDay(1),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Día siguiente',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _CashHero(breakdown: breakdown, day: _day),
              const SizedBox(height: 14),

              // Desglose: de dónde viene y a dónde fue (§28)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: <Widget>[
                      DetailRow('Fondo inicial', breakdown.openingFund),
                      DetailRow('Ventas en efectivo', breakdown.cashSales),
                      if (breakdown.entries > 0)
                        DetailRow('Entradas', breakdown.entries),
                      if (breakdown.exits > 0)
                        DetailRow('Salidas', -breakdown.exits),
                      if (breakdown.cashExpenses > 0)
                        DetailRow('Gastos', -breakdown.cashExpenses),
                      const Divider(height: 22),
                      DetailRow(
                        'Efectivo esperado',
                        breakdown.expected,
                        emphasized: true,
                      ),
                    ],
                  ),
                ),
              ),

              if (closing != null) ...<Widget>[
                const SizedBox(height: 14),
                _ClosedCard(closing: closing),
              ] else ...<Widget>[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _closing,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Hacer cierre del día'),
                ),
              ],

              const SizedBox(height: 22),
              _CashActions(onChanged: () => setState(() {})),
              const SizedBox(height: 22),
              Text('Movimientos del día', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              const _MovementsList(),
            ],
          ),
          const _ClosingsTab(),
        ],
      ),
    );
  }
}

class _CashHero extends StatelessWidget {
  const _CashHero({required this.breakdown, required this.day});

  final CashBreakdown breakdown;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool zero = breakdown.expected == 0;

    return Card(
      color: zero ? scheme.surfaceContainerHighest : scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              zero
                  ? 'Sin fondo inicial registrado'
                  : 'Efectivo en caja',
              style: theme.textTheme.labelLarge?.copyWith(
                color: zero
                    ? scheme.onSurfaceVariant
                    : scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              Money.format(breakdown.expected),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: zero ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
              ),
            ),
            if (zero) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Registra cuánto llevas al puesto para que el cuadre sea real.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CashActions extends ConsumerWidget {
  const _CashActions({required this.onChanged});

  final VoidCallback onChanged;

  Future<void> _open(BuildContext context, WidgetRef ref, bool isEntry) async {
    final result = await showModalBottomSheet<_CashFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext _) =>
          _CashFormSheet(isEntry: isEntry, day: DateTime.now()),
    );
    if (result == null) return;
    try {
      final CashRepository repo = ref.read(cashRepositoryProvider);
      if (isEntry) {
        await repo.recordEntry(result.amount, result.concept);
      } else {
        await repo.recordExit(result.amount, result.concept);
      }
      onChanged();
      if (!context.mounted) return;
      showToast(context, isEntry ? 'Entrada registrada' : 'Salida registrada');
    } on AppException catch (e) {
      if (!context.mounted) return;
      showToast(context, e.message, isError: true);
    }
  }

  Future<void> _openingFund(BuildContext context, WidgetRef ref) async {
    final int? amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext _) => const _OpeningFundSheet(),
    );
    if (amount == null) return;
    try {
      await ref.read(cashRepositoryProvider).setOpeningFund(amount);
      onChanged();
      if (!context.mounted) return;
      showToast(context, 'Fondo inicial registrado');
    } on AppException catch (e) {
      if (!context.mounted) return;
      showToast(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: () => _openingFund(context, ref),
          icon: const Icon(Icons.savings_outlined),
          label: const Text('Fondo inicial'),
        ),
        OutlinedButton.icon(
          onPressed: () => _open(context, ref, true),
          icon: const Icon(Icons.south_west),
          label: const Text('Entrada'),
        ),
        OutlinedButton.icon(
          onPressed: () => _open(context, ref, false),
          icon: const Icon(Icons.north_east),
          label: const Text('Salida'),
        ),
      ],
    );
  }
}

class _MovementsList extends ConsumerWidget {
  const _MovementsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<CashMovement>> async = ref.watch(cashMovementsProvider);

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, StackTrace _) => Text('Error: $e'),
      data: (List<CashMovement> all) {
        final List<CashMovement> today = all
            .where((CashMovement m) => Dates.isSameDay(m.date, DateTime.now()))
            .toList()
          ..sort((CashMovement a, CashMovement b) => b.date.compareTo(a.date));
        if (today.isEmpty) {
          return const EmptyState(
            title: 'Sin movimientos hoy',
            message: 'Aquí verás las entradas y salidas de efectivo.',
            icon: Icons.account_balance_wallet_outlined,
          );
        }
        return Card(
          child: Column(
            children: <Widget>[
              for (final CashMovement m in today)
                ListTile(
                  leading: Icon(
                    _iconFor(m.type),
                    color: m.type.increasesCash
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.error,
                  ),
                  title: Text(m.concept),
                  subtitle: Text(
                    '${m.type.label}  •  ${Dates.formatTime(m.date)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Text(
                    '${m.signedAmount < 0 ? '-' : '+'}${Money.format(m.amount)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: m.type.increasesCash
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static IconData _iconFor(CashMovementType type) => switch (type) {
    CashMovementType.fondoInicial => Icons.savings_outlined,
    CashMovementType.venta => Icons.point_of_sale_outlined,
    CashMovementType.entrada => Icons.south_west,
    CashMovementType.salida => Icons.north_east,
    CashMovementType.gasto => Icons.receipt_long_outlined,
  };
}

class _ClosedCard extends StatelessWidget {
  const _ClosedCard({required this.closing});

  final DailyClosing closing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? diff = closing.difference;

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.lock_outline, color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Text(
                  'Día cerrado',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const Spacer(),
                Text(
                  Dates.formatDate(closing.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Efectivo contado',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      MoneyText(
                        closing.countedCash ?? 0,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                if (diff != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        diff == 0
                            ? 'Cuadra'
                            : diff > 0
                            ? 'Sobró'
                            : 'Faltó',
                        style: theme.textTheme.labelSmall,
                      ),
                      Text(
                        Money.format(diff.abs()),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosingsTab extends ConsumerWidget {
  const _ClosingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<DailyClosing> closings = ref.watch(closingsProvider);
    if (closings.isEmpty) {
      return const EmptyState(
        title: 'Sin cierres',
        message: 'Cierra el día para guardar el resumen de tus ventas.',
        icon: Icons.event_available_outlined,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: closings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int i) {
        final DailyClosing c = closings[i];
        final int? diff = c.difference;
        return Card(
          child: ListTile(
            title: Text(Dates.relativeDay(c.date)),
            subtitle: Text(
              '${c.salesCount} ventas  •  ganancia ${Money.format(c.grossProfit)}'
              '${diff == null ? '' : diff == 0 ? '  •  cuadra' : '  •  diferencia ${Money.format(diff)}'}',
            ),
            trailing: MoneyText(c.total, style: const TextStyle()),
            onTap: () => context.pushNamed(
              AppRoutes.closingDetail,
              extra: c.id,
            ),
          ),
        );
      },
    );
  }
}

class _CashFormResult {
  const _CashFormResult({required this.amount, required this.concept});

  final int amount;
  final String concept;
}

class _CashFormSheet extends StatefulWidget {
  const _CashFormSheet({required this.isEntry, required this.day});

  final bool isEntry;
  final DateTime day;

  @override
  State<_CashFormSheet> createState() => _CashFormSheetState();
}

class _CashFormSheetState extends State<_CashFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _concept = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _concept.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.isEntry ? 'Entrada de efectivo' : 'Salida de efectivo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monto *',
                    prefixText: r'$ ',
                  ),
                  validator: V.amount,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _concept,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Concepto *',
                    hintText: widget.isEntry ? 'Cambio de un cliente' : 'Pago a proveedor',
                  ),
                  validator: (String? v) => V.required(v, field: 'El concepto'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    if (!(_formKey.currentState?.validate() ?? false)) return;
                    Navigator.of(context).pop(
                      _CashFormResult(
                        amount: Money.parseToCentsOrZero(_amount.text),
                        concept: _concept.text.trim(),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(widget.isEntry ? 'Registrar entrada' : 'Registrar salida'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpeningFundSheet extends StatefulWidget {
  const _OpeningFundSheet();

  @override
  State<_OpeningFundSheet> createState() => _OpeningFundSheetState();
}

class _OpeningFundSheetState extends State<_OpeningFundSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '¿Cuánto dinero llevas hoy?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Es el punto de partida del cuadre de hoy.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monto *',
                  prefixText: r'$ ',
                ),
                validator: (String? v) {
                  final String? base = V.amount(v);
                  if (base != null) return base;
                  return (Money.parseToCentsOrZero(v ?? '') <= 0)
                      ? 'El monto debe ser mayor a cero'
                      : null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  Navigator.of(
                    context,
                  ).pop(Money.parseToCentsOrZero(_amount.text));
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cierre del día: compara el efectivo contado contra el esperado (§29).
class DailyClosingScreen extends ConsumerStatefulWidget {
  const DailyClosingScreen({super.key, this.day});

  final DateTime? day;

  @override
  ConsumerState<DailyClosingScreen> createState() => _DailyClosingScreenState();
}

class _DailyClosingScreenState extends ConsumerState<DailyClosingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _counted = TextEditingController();
  final TextEditingController _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _counted.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _countedCents => Money.tryParseToCents(_counted.text);

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final NavigatorState navigator = Navigator.of(context);
    try {
      final ReportsRepository repo = ref.read(reportsRepositoryProvider);
      final DailyClosing closing = repo.buildClosing(day: widget.day);
      await repo.saveClosing(
        DailyClosing(
          id: closing.id,
          date: closing.date,
          salesCount: closing.salesCount,
          itemsSold: closing.itemsSold,
          cashTotal: closing.cashTotal,
          transferTotal: closing.transferTotal,
          cardTotal: closing.cardTotal,
          otherTotal: closing.otherTotal,
          total: closing.total,
          costTotal: closing.costTotal,
          grossProfit: closing.grossProfit,
          expensesTotal: closing.expensesTotal,
          netProfit: closing.netProfit,
          countedCash: _countedCents,
          closingNote: _note.text.trim(),
        ),
      );
      navigator.pop(true);
    } on AppException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DailyClosing closing = ref
        .read(reportsRepositoryProvider)
        .buildClosing(day: widget.day);
    final int? counted = _countedCents;
    final int? diff = counted == null ? null : counted - closing.cashTotal;

    return Scaffold(
      appBar: AppBar(title: const Text('Cierre del día')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: <Widget>[
                    DetailRow('Ventas', closing.total, emphasized: true),
                    DetailRow('Efectivo', closing.cashTotal),
                    DetailRow('Transferencia', closing.transferTotal),
                    DetailRow('Tarjeta', closing.cardTotal),
                    if (closing.otherTotal > 0)
                      DetailRow('Otro', closing.otherTotal),
                    const Divider(height: 20),
                    DetailRow('Ganancia bruta', closing.grossProfit),
                    DetailRow('Gastos', -closing.expensesTotal),
                    DetailRow(
                      'Utilidad neta',
                      closing.netProfit,
                      emphasized: true,
                      valueColor: closing.netProfit < 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.secondary,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('¿Cuánto efectivo contaste?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Debería haber ${Money.format(closing.cashTotal)}.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _counted,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Efectivo contado *',
                prefixText: r'$ ',
                prefixIcon: Icon(Icons.money_outlined),
              ),
              validator: (String? v) => V.amount(v),
            ),
            if (diff != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: diff == 0
                      ? theme.colorScheme.secondaryContainer
                      : theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      diff == 0 ? Icons.check_circle : Icons.error_outline,
                      color: diff == 0
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        diff == 0
                            ? 'La caja cuadra exactamente.'
                            : diff > 0
                            ? 'Sobró ${Money.format(diff)}'
                            : 'Faltó ${Money.format(diff.abs())}',
                        style: TextStyle(
                          color: diff == 0
                              ? theme.colorScheme.onSecondaryContainer
                              : theme.colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                alignLabelWithHint: true,
                hintText: 'Ej. faltaba cambio por culpa de un cliente',
              ),
            ),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline),
              label: const Text('Guardar cierre'),
            ),
          ],
        ),
      ),
    );
  }
}
