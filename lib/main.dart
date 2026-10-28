import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/app_database.dart';
import 'core/theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'routes/app_router.dart';

/// Punto de entrada de Tianguis Control.
///
/// La base local se abre **antes** de correr la app: cualquier pantalla
/// assumirá que Hive ya está listo. Si Hive falla, se muestra el error en
/// pantalla en vez de arrancar a medias y reventar en la primera lectura.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppDatabase.init();
  } catch (e) {
    runApp(_BootstrapErrorApp(error: e));
    return;
  }
  runApp(const ProviderScope(child: TianguisApp()));
}

class TianguisApp extends ConsumerWidget {
  const TianguisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Tianguis Control',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}

/// Si la base local no abre, el usuario necesita saberlo, no ver un crash.
class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'No se pudo abrir tu información',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Cierra la app por completo y vuelve a abrirla. Si sigue '
                  'fallando, tus datos siguen en el teléfono: no se borró nada.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
