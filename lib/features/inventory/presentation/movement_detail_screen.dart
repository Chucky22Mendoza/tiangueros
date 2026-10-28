import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/money_widgets.dart';
import '../../../models/inventory_movement.dart';

/// Detalle de un movimiento de inventario: por qué cambió el stock (§22).
class MovementDetailScreen extends StatelessWidget {
  const MovementDetailScreen({super.key, required this.movementId});

  final String movementId;

  @override
  Widget build(BuildContext context) {
    final InventoryMovement? movement = AppDatabase.movements.get(movementId);

    if (movement == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Movimiento')),
        body: const Center(child: Text('El movimiento ya no existe')),
      );
    }

    final ThemeData theme = Theme.of(context);
    final double delta = movement.delta;
    final bool positive = delta >= 0;

    return Scaffold(
      appBar: AppBar(title: Text(movement.type.label)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: <Widget>[
                  Text(
                    movement.productName,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${positive ? '+' : ''}${_num(delta)}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color:
                          positive
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.error,
                    ),
                  ),
                  Text(
                    movement.type.label,
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
                  DetailRow('Antes', null, textValue: _num(movement.previousStock)),
                  DetailRow('Después', null, textValue: _num(movement.newStock)),
                  DetailRow('Cantidad', null, textValue: _num(movement.quantity)),
                  if (movement.reason.isNotEmpty)
                    DetailRow('Motivo', null, textValue: movement.reason),
                  DetailRow('Fecha', null, textValue:
                      Dates.formatDateTime(movement.date)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _num(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
