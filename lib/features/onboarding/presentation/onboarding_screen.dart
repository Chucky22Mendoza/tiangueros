import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../providers/settings_provider.dart';
import '../../../routes/app_routes.dart';

/// Primera ejecución: pide nombre del negocio y del encargado (§7).
///
/// **No bloquea la app.** Si el usuario deja los campos vacíos, pulsa atrás o
/// cierra, se guardan los defaults `Mi Tianguis` / `Encargado` y se sigue
/// adelante (§8).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _business = TextEditingController();
  final TextEditingController _owner = TextEditingController();

  @override
  void dispose() {
    _business.dispose();
    _owner.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    // Se validan los campos si el usuario los llenó, pero nunca se bloquea la
    // entrada: los vacíos se sustituyen por los defaults.
    _formKey.currentState?.validate();

    await ref
        .read(businessSettingsProvider.notifier)
        .update(
          businessName: _business.text,
          ownerName: _owner.text,
        );
    await ref.read(onboardingDoneProvider.notifier).complete();

    if (!mounted) return;
    // `go` y no `pop`: la bienvenida es la ruta inicial, no hay pantalla
    // anterior a la que volver.
    context.go(ShellRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            children: <Widget>[
              const Center(child: AppLogo(size: 120)),
              const SizedBox(height: 28),
              Text('Tianguis Control', style: theme.textTheme.displaySmall),
              const SizedBox(height: 6),
              Text(
                'Configura tu negocio',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 32),

              TextFormField(
                controller: _business,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.organizationName],
                decoration: const InputDecoration(
                  labelText: 'Nombre del negocio',
                  hintText: 'Puesto El Güero',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                validator: (String? v) => (v == null || v.trim().isEmpty)
                    ? null // vacío ⇒ se usará el default
                    : (v.trim().length > 60
                          ? 'Máximo 60 caracteres'
                          : null),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _owner,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Nombre del encargado',
                  hintText: 'Jesús',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (String? v) => (v == null || v.trim().isEmpty)
                    ? null
                    : (v.trim().length > 60
                          ? 'Máximo 60 caracteres'
                          : null),
                onFieldSubmitted: (_) => _finish(),
              ),

              const SizedBox(height: 12),
              Text(
                'Si los dejas vacíos usaremos '
                '"${AppConstants.defaultBusinessName}" y '
                '"${AppConstants.defaultOwnerName}".',
                style: theme.textTheme.bodySmall,
              ),

              const SizedBox(height: 32),
              FilledButton(
                onPressed: _finish,
                child: const Text('Continuar'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _finish,
                child: const Text('Ahora no'),
              ),
              const SizedBox(height: 8),
              Text(
                'Puedes personalizar estos datos después desde Configuración.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
