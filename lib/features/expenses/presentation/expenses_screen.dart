import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_widgets.dart';
import '../../../models/expense.dart';
import '../../../providers/data_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../repositories/expense_repository.dart';

/// Gastos del puesto: cuotas, transporte, comida, bolsas… (§30).
class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  int _rangeDays = 30;

  List<Expense> _inRange(List<Expense> all) {
    final DateTime from = DateTime.now().subtract(
      Duration(days: _rangeDays - 1),
    );
    return all
        .where((Expense e) => !e.date.isBefore(from))
        .toList()
      ..sort((Expense a, Expense b) => b.date.compareTo(a.date));
  }

  Future<void> _edit([Expense? expense]) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext _) => ExpenseFormScreen(expense: expense),
      ),
    );
    if (saved == true && mounted) showToast(context, 'Gasto guardado');
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Expense>> async = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos')),
      floatingActionButton: FloatingActionButton.extended(
        // heroTag explícito: con el shell de pestañas las cinco pantallas
        // quedan montadas a la vez y varios FAB con el tag por defecto hacen
        // que Flutter truene al animar la transición.
        heroTag: null,
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Gasto'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text('Error: $e')),
        data: (List<Expense> all) {
          if (all.isEmpty) {
            return EmptyState(
              title: 'Sin gastos registrados',
              message: 'Anota tus gastos para saber cuánto ganas de verdad.',
              icon: Icons.receipt_long_outlined,
              actionLabel: 'Registrar gasto',
              onAction: () => _edit(),
            );
          }
          final List<Expense> list = _inRange(all);
          final int total = list.fold<int>(0, (int s, Expense e) => s + e.amount);

          // Agrupado por mes, como en un libro de gastos.
          final Map<String, List<Expense>> byMonth = <String, List<Expense>>{};
          for (final Expense e in list) {
            byMonth.putIfAbsent(Dates.monthTitle(e.date), () => <Expense>[]).add(e);
          }

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Total últimos $_rangeDays días',
                                style: theme.textTheme.labelMedium,
                              ),
                              const SizedBox(height: 2),
                              MoneyText(
                                total,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownButton<int>(
                          value: _rangeDays,
                          underline: const SizedBox.shrink(),
                          items: const <DropdownMenuItem<int>>[
                            DropdownMenuItem<int>(value: 7, child: Text('7 días')),
                            DropdownMenuItem<int>(
                              value: 30,
                              child: Text('30 días'),
                            ),
                            DropdownMenuItem<int>(
                              value: 90,
                              child: Text('90 días'),
                            ),
                          ],
                          onChanged: (int? v) => setState(
                            () => _rangeDays = v ?? 30,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: <Widget>[
                    for (final MapEntry<String, List<Expense>> entry
                        in byMonth.entries) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                        child: Row(
                          children: <Widget>[
                            Text(
                              entry.key,
                              style: theme.textTheme.titleSmall,
                            ),
                            const Spacer(),
                            MoneyText(
                              entry.value.fold<int>(
                                0,
                                (int s, Expense e) => s + e.amount,
                              ),
                              style: theme.textTheme.labelLarge,
                            ),
                          ],
                        ),
                      ),
                      for (final Expense e in entry.value)
                        _ExpenseTile(
                          expense: e,
                          onTap: () => _edit(e),
                          onDelete: () => _delete(e),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(Expense expense) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Eliminar gasto',
      message: 'Se eliminará "${expense.concept}". '
          '${expense.affectsCash ? 'También se revertirá el movimiento de caja.' : ''}',
      confirmLabel: 'Eliminar',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(expenseRepositoryProvider).delete(expense.id);
      if (!mounted) return;
      showToast(context, 'Gasto eliminado');
    } on AppException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, isError: true);
    }
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.onTap,
    required this.onDelete,
  });

  final Expense expense;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.errorContainer,
          child: Icon(
            Icons.receipt_outlined,
            color: scheme.onErrorContainer,
            size: 20,
          ),
        ),
        title: Text(expense.concept, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${expense.category}  •  ${Dates.relativeDay(expense.date)}'
          '${expense.affectsCash ? '' : '  •  sin salida de caja'}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            MoneyText(
              expense.amount,
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
              onSelected: (String _) => onDelete(),
              itemBuilder: (BuildContext _) => const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'delete',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline),
                    title: Text('Eliminar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Alta y edición de un gasto (§30).
class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, this.expense});

  final Expense? expense;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _concept = TextEditingController(
    text: widget.expense?.concept ?? '',
  );
  late final TextEditingController _amount = TextEditingController(
    text: widget.expense == null
        ? ''
        : Money.toEditableString(widget.expense!.amount),
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.expense?.notes ?? '',
  );
  late String _category = widget.expense?.category ?? 'Otro';
  late DateTime _date = widget.expense?.date ?? DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _concept.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  int get _amountCents => Money.tryParseToCents(_amount.text) ?? 0;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final NavigatorState navigator = Navigator.of(context);
    try {
      final ExpenseRepository repo = ref.read(expenseRepositoryProvider);
      if (widget.expense == null) {
        await repo.create(
          concept: _concept.text,
          category: _category,
          amount: _amountCents,
          date: _date,
          notes: _notes.text,
        );
      } else {
        final Expense updated = repo.byId(widget.expense!.id) ?? widget.expense!;
        updated
          ..concept = _concept.text
          ..category = _category
          ..amount = _amountCents
          ..date = _date
          ..notes = _notes.text;
        await repo.update(updated);
      }
      navigator.pop(true);
    } on AppException catch (e) {
      if (!mounted) return;
      showToast(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final List<String> categories = ref.watch(expenseCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Nuevo gasto' : 'Editar gasto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            TextFormField(
              controller: _concept,
              autofocus: widget.expense == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Concepto *',
                hintText: 'Cuota del puesto',
                prefixIcon: Icon(Icons.edit_note),
              ),
              validator: (String? v) => V.required(v, field: 'El concepto'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto *',
                prefixText: r'$ ',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: V.amount,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: categories.contains(_category) ? _category : null,
              decoration: const InputDecoration(
                labelText: 'Categoría *',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: <DropdownMenuItem<String>>[
                for (final String c in categories)
                  DropdownMenuItem<String>(value: c, child: Text(c)),
              ],
              onChanged: (String? v) =>
                  setState(() => _category = v ?? 'Otro'),
              validator: (String? v) =>
                  v == null ? 'Elige una categoría' : null,
            ),
            const SizedBox(height: 6),
            if (_category.toLowerCase() != 'transferencia')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Este gasto descontará efectivo de la caja.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Una transferencia no afecta el efectivo de la caja.',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Fecha'),
              subtitle: Text(Dates.formatDateTime(_date)),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                alignLabelWithHint: true,
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
                  : const Icon(Icons.check),
              label: Text(widget.expense == null ? 'Registrar gasto' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
