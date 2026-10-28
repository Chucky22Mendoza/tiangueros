# Tianguis Control

POS offline para puestos de mercado. Todo vive en el teléfono: sin servidor, sin
cuenta, sin internet y sin permiso `INTERNET` en el manifest.

La app está en español, con el flujo del tianguero:venta rápida o con carrito,
cambio, ticket, movimientos de inventario, gastos, corte de caja y reportes.

## Requisitos

- Flutter 3.44.4 / Dart 3.12.2 (SDK ≥ 3.10)
- Android SDK 36.1.0, sólo Android por ahora
- JDK 17+ (el de Android Studio o el del sistema)

## Puesta en marcha

```bash
flutter pub get
flutter run                 # en un dispositivo o emulador Android
flutter build apk --release # APK de distribución
```

El APK sale en `build/app/outputs/flutter-apk/app-release.apk`. Va firmado con
la clave de debug, así que sirve para instalar y probar, **no** para subir a
Play. Para publicar hay que crear un keystore y wiring de `signingConfigs`.

## Verificación

```bash
flutter analyze   # debe salir "No issues found!"
flutter test      # 86 tests: repositorios, watchers, respaldos, transferencia y router
```

Los tests usan una base Hive temporal por test (`test/helpers.dart`), nunca la
del teléfono. Detalles no obvios de `flutter test` que ya costaron sangre están
documentados en `AGENTS.md`.

## Estructura

```
lib/
  main.dart            arranque: Hive -> ProviderScope -> MaterialApp.router
  models/              entidades Hive (typeId fijo 0-9) + enums como índices
  repositories/        la única capa que escribe en Hive
  providers/           Riverpod: repositorios, datos derivados, ajustes
  routes/              GoRouter: shell de 5 pestañas + rutas fuera del shell
  core/
    database/          cajas de Hive, adapters, migración, wipe
    theme/             Material 3 claro/oscuro desde la paleta del proyecto
    utils/             parsers de dinero, archivos, file_picker
  features/            pantallas por área + servicios de respaldo/importación
tool/
  generate_icon.dart   rasteriza AppLogo a los PNG de icono y splash
```

`PROMPT.md` es la especificación funcional completa (1766 líneas) y es la
fuente de verdad del comportamiento esperado. `CONTEXT.md` resume el estado del
proyecto y `AGENTS.md` las reglas para trabajar en él.

## Datos y respaldos

- Todos los importes son `int` en **centavos**. `double` sólo para stock y
  porcentajes.
- Las ventas guardan copia del nombre, costo y precio de cada producto, así que
  un cambio de precio después no altera la historia.
- Nada se borra físicamente: los productos y las ventas se archivan.
- Los folios (`V-000001`) son monotónicos y no se reutilizan.
- Ajustes → Datos respaldan todo a un archivo, lo restauran, e importan/exportan
  productos en CSV y JSON (pesos con dos decimales).

## Icono y splash

El logo se dibuja en código (`AppLogo`, un `CustomPainter`), no con assets
binarios: así queda nítido en cualquier densidad y sirve de logo dentro de la
app, del icono del lanzador y del splash. Para regenerar los PNG de Android:

```bash
flutter test tool/generate_icon.dart
```
