import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/enums.dart';
import '../../../providers/repository_providers.dart';
import '../../../repositories/sales_repository.dart';

/// Venta rápida: cobrar algo que **no está en el catálogo** (§16, §17).
///
/// El costo es opcional. Si no se captura, la ganancia se muestra
/// explícitamente como *estimada* para no engañar al usuario (§17).
class QuickSaleScreen extends ConsumerStatefulWidget {
  const QuickSaleScreen({super.key});

  @override
  ConsumerState<QuickSaleScreen> createState() => _QuickSaleScreenState();
}

class _QuickSaleScreenState extends ConsumerState<QuickSaleScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _concept = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _quantity = TextEditingController(text: '1');
  final TextEditingController _cost = TextEditingController();

  PaymentMethod _method = PaymentMethod.efectivo;
  bool _saving = false;
  bool _showCost = false;

  int get _priceCents => Money.tryParseToCents(_price.text) ?? 0;
  int get _quantityValue => int.tryParse(_quantity.text.trim()) ?? 0;
  int get _costCents => Money.tryParseToCents(_cost.text) ?? 0;
  int get _total => _priceCents * _quantityValue;
  bool get _costUnknown => !_showCost || _costCents == 0;

  @override
  void dispose() {
    _concept.dispose();
    _price.dispose();
    _quantity.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final SaleResult result = await ref
          .read(salesRepositoryProvider)
          .quickSale(
            concept: _concept.text,
            price: _priceCents,
            quantity: _quantityValue,
            cost: _costCents,
            paymentMethod: _method,
          );
      if (!mounted) return;
      Navigator.of(context).pop(result.folio);
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
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Venta rápida')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.bolt, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Registra una venta sin dar de alta el producto. '
                        'Podrás agregarlo al catálogo después.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _concept,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Concepto *',
                hintText: 'Artículo varios',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
              validator: (String? v) => (v == null || v.trim().isEmpty)
                  ? 'El concepto es obligatorio'
                  : null,
            ),
            const SizedBox(height: 14),

            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Precio *',
                      prefixText: r'$ ',
                    ),
                    validator: V.price,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(labelText: 'Cantidad *'),
                    validator: V.quantity,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Costo opcional (§17)
            if (!_showCost)
              OutlinedButton.icon(
                onPressed: () => setState(() => _showCost = true),
                icon: const Icon(Icons.add),
                label: const Text('Agregar costo (opcional)'),
              )
            else ...<Widget>[
              TextFormField(
                controller: _cost,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Costo unitario (opcional)',
                  prefixText: r'$ ',
                  helperText: 'Si lo dejas vacío la ganancia será estimada',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _cost.clear();
                      setState(() => _showCost = false);
                    },
                  ),
                ),
                validator: (String? v) {
                  final String? base = V.cost(v);
                  if (base != null) return base;
                  if (v != null &&
                      v.trim().isNotEmpty &&
                      _costCents > _priceCents) {
                    return 'El costo no puede ser mayor al precio';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
            ],

            const SizedBox(height: 22),
            Text('Método de pago', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final PaymentMethod m in PaymentMethod.values)
                  ChoiceChip(
                    label: Text(m.label),
                    selected: _method == m,
                    onSelected: (_) => setState(() => _method = m),
                  ),
              ],
            ),

            const SizedBox(height: 22),
            _TotalBox(
              total: _total,
              cost: _costUnknown ? 0 : _costCents * _quantityValue,
              estimated: _costUnknown,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            onPressed: _saving || _total <= 0 ? null : _register,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Registrar venta'),
          ),
        ),
      ),
    );
  }
}

class _TotalBox extends StatelessWidget {
  const _TotalBox({
    required this.total,
    required this.cost,
    required this.estimated,
  });

  final int total;
  final int cost;
  final bool estimated;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int profit = total - cost;

    return Card(
      color: scheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Text('Total', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(
                  Money.format(total),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: <Widget>[
                Text('Ganancia estimada', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Text(
                  Money.format(profit),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.secondary,
                  ),
                ),
              ],
            ),
            if (estimated) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    size: 15,
                    color: scheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'No capturaste el costo, así que esta ganancia puede no '
                      'ser real. Agrega el costo para calcularla bien.',
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
    );
  }
}
