# CONTEXT.md

Estado del proyecto Tianguis Control al 2026-09-28. Para el comportamiento
esperado, `PROMPT.md` es la especificación. Para reglas de trabajo, `AGENTS.md`.

## Qué es

POS Android 100% offline para puestos de tianguis. Sin servidor, cuenta, red ni
permiso `INTERNET`. Spanish-first, es-MX.

## Estado

Compila, pasa lint y pasa tests.

```
flutter analyze   -> No issues found!
flutter test      -> 86/86 passed
flutter build apk --release -> build/app/outputs/flutter-apk/app-release.apk (57.4 MB)
```

El APK está firmado con la clave de debug: sirve para instalar y probar, no para
publicar en Play.

### Funcionalidad cubierta

- Ventas: carrito, venta rápida, cambio, descuento, cancelación, ticket y
  detalle. Folios `V-000001` monotónicos. Toda venta guarda snapshot de nombre,
  costo y precio por renglón.
- Productos: alta/edición/archivado, SKU y código de barras únicos, categorías,
  búsqueda por nombre/SKU/código/categoría.
- Inventario: entradas, ajustes, movimientos con delta y motivo.
- Gastos, caja (abrir/cerrar), cortes y reportes.
- Ajustes: datos del negocio, logo, tema, formato de fecha, respaldo/restauración
  y exportación/importación de productos en CSV y JSON.
- Onboarding inicial.

### Decisiones que no se deben deshacer

- TypeId de Hive fijos 0-9 (`lib/models/hive_type_ids.dart`).
- Enums persistidos como índice `int`; el modelo traduce.
- Dinero en `int` centavos; stock en `double`.
- GoRouter con shell de 5 pestañas; los ids viajan en `extra`.
- El shell no define FAB: cada pantalla pone el suyo.
- Pantallas de alta/edición reciben `_optionalIdOf(state)` (nullable).

### Tests

- `product_inventory_repository_test.dart` (12), `sales_repository_test.dart`
  (13), `backup_transfer_test.dart` (11): repositorios y transferencia, con base
  Hive temporal.
- `app_router_test.dart` (2): arranque y shell. Un solo test monta el dashboard,
  y va último, porque deja el isolate sin terminar (ver `AGENTS.md`).

## Pendientes

0. ~~Auditoría de `PROMPT.md` sección por sección.~~ **Hecho:** 46 de 58
   secciones conformes. Los tres huecos que faltaban ya están cerrados: tests de
   Gastos y Caja (§50), sección de Inventario en Reportes y selector de periodo
   junto al de rango (§30). Queda como observación, no como tarea: `lazyInRange`
   filtra con `.values.where()`, que ya materializó la caja, así que el
   comentario de §49 promete más de lo que el código da; con 10,000 ventas se
   va a notar.

1. **Firma de release.** `android/app/build.gradle.kts` sigue usando la clave de
   debug. Hace falta keystore + `signingConfigs` para publicar.
2. **APK por ABI.** El APK de 57 MB trae todas las arquitecturas. Con
   `flutter build apk --release --split-per-abi` baja a ~20 MB por ABI.
3. ~~Revisar conversiones de navegación.~~ **Hecho:** no queda ningún
   `Navigator.pushNamed` en `lib/`, los 25 `GoRoute` declaran `name:` y las
   entradas del menú "Más" que apuntan a pestañas usan `goNamed`, no
   `pushNamed`, para no apilar el shell.

   El pie quedó `Inicio · Ventas · Productos · Reportes · Más` y el inventario
   se entra desde "Más". Es un cambio consciente frente a la especificación
   original, así que `PROMPT.md` §42 ya está actualizado y dice lo mismo que
   el código.
4. **Integración en dispositivo.** La app ya se abrió y se usó en un teléfono
   real (de ahí salieron los bugs de tema, ajustes y gráfica). Falta ejercitar
   en hardware lo que toca paquetes del sistema: **importar** (file_picker),
   **exportar** (share_plus), **logo del negocio** (image_picker) y el splash.
5. **Skills.** Hay 14 skills de Flutter/Dart instaladas en `.opencode/skills`;
   ninguna se ha usado todavía en este proyecto.

## Detalles de entorno

- Flutter 3.44.4 / Dart 3.12.2, Android SDK 36.1.0.
- Dependencias en `pubspec.yaml`; `flutter_launcher_icons` se retiró porque el
  icono se genera con `tool/generate_icon.dart`.
- El icono y el splash se rasterizan desde el mismo `AppLogo` que dibuja la app.
