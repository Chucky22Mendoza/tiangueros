import 'package:flutter/material.dart';

/// Diálogos de confirmación para acciones destructivas (§46).
///
/// Sin login no hay red de seguridad: antes de borrar un producto, restaurar
/// un respaldo o eliminar todo, siempre se pregunta.
abstract final class ConfirmDialog {
  const ConfirmDialog._();

  /// Confirmación simple. Devuelve `true` sólo si el usuario acepta.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Eliminar',
    String cancelLabel = 'Cancelar',
    bool destructive = true,
  }) async {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Confirmación para "eliminar todos los datos" (§46): doble advertencia.
  static Future<bool> wipeEverything(BuildContext context) => show(
    context,
    title: '¿Eliminar todos los datos?',
    message:
        'Esta acción eliminará toda la información almacenada en este '
        'dispositivo.\n\nEsta acción no se puede deshacer.\n\n'
        'Te recomendamos exportar un respaldo antes de continuar.',
    confirmLabel: 'Eliminar todo',
  );
}

/// Aviso efímero de éxito o error.
///
/// La app es offline y de un solo paso: los errores de validación se muestran
/// aquí en vez de en un diálogo modal que corta el flujo.
void showToast(
  BuildContext context,
  String message, {
  bool isError = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  final Color fg = isError ? scheme.onErrorContainer : scheme.onInverseSurface;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: fg,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: fg))),
          ],
        ),
        backgroundColor: isError
            ? scheme.errorContainer
            : scheme.inverseSurface,
        duration: Duration(seconds: isError ? 4 : 2),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: fg,
                onPressed: onAction,
              ),
      ),
    );
}
