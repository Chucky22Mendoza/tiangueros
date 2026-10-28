import 'package:flutter/material.dart';

import '../utils/money.dart';

/// Texto de dinero con estilo consistente. Todo monto entra en centavos.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.cents, {
    super.key,
    this.style,
    this.compact = false,
    this.whole = false,
    this.color,
    this.signed = false,
  });

  final int cents;
  final TextStyle? style;
  final bool compact;
  final bool whole;
  final Color? color;

  /// Muestra `+`/`−` explícito cuando el monto es negativo.
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String text = compact
        ? Money.formatCompact(cents)
        : whole
        ? Money.formatWhole(cents)
        : Money.format(cents);

    final Color effective = color ?? _defaultColor(scheme);
    return Text(
      signed && cents > 0 ? '+$text' : text,
      style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
        color: effective,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }

  Color _defaultColor(ColorScheme scheme) =>
      cents < 0 ? scheme.error : scheme.onSurface;
}

/// Etiqueta + valor, usado en las cards de métricas del Dashboard (§12).
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
    this.compact = false,
    this.units = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  /// Formato `$1.2k` en vez de `$1,250.00`.
  final bool compact;

  /// El valor es una cantidad (productos, ventas), no dinero: se muestra como
  /// número entero. Formatear "3 productos" como `$3.00` Engaña (§12).
  final bool units;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color accent = color ?? scheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (units)
                Text(
                  Money.formatUnits(value),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                )
              else
                MoneyText(
                  value,
                  compact: compact,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila etiqueta/valor de un desglose (cierre, caja, reportes).
class DetailRow extends StatelessWidget {
  const DetailRow(
    this.label,
    this.value, {
    super.key,
    this.textValue,
    this.emphasized = false,
    this.valueColor,
    this.labelColor,
  });

  final String label;

  /// Si es `null` se muestra como texto plano; si es int, como dinero.
  final int? value;

  final String? textValue;
  final bool emphasized;
  final Color? valueColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = emphasized
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyLarge;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(color: labelColor),
            ),
          ),
          const SizedBox(width: 12),
          if (value != null)
            MoneyText(
              value!,
              style: style,
              color: valueColor,
              signed: true,
            )
          else
            Text(textValue ?? '', style: style?.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}
