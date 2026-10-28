# AGENTS.md

Reglas para trabajar en Tianguis Control. Están para que no haya que
redescubrirlas cada vez; si algo aquí contradice a `PROMPT.md`, gana
`PROMPT.md` (es la especificación) y hay que corregir este archivo.

## Comandos

```bash
flutter pub get
flutter analyze            # tiene que salir limpio antes de dar algo por hecho
flutter test               # 86 tests; ~1 min
flutter build apk --release
flutter test tool/generate_icon.dart   # regenera icono y splash de Android
```

Si tocaste un modelo Hive: `dart run build_runner build --delete-conflicting-outputs`.
Los `.g.dart` van versionados.

## Reglas del dominio

Estas no son preferencias, son invariantes. Romper una rompe datos de usuarios.

- **Dinero en `int` de centavos.** Nunca `double` para dinero, nunca pesos
  "redondos". Hay helpers en `lib/core/utils/parsers.dart`; usarlos.
- **Stock en `double`** (pesos de producto) y no negativo.
- **Los typeId de Hive son fijos** (`lib/models/hive_type_ids.dart`, 0-9). No
  cambiar, no reordenar, no reutilizar uno retirado. Romper esto deja las bases
  existentes ilegibles.
- **Nada se borra físicamente.** Productos y ventas se archivan; el historial
  manda.
- **Los folios no se reutilizan.** `V-000001` y contando. Cancelar una venta
  tampoco libera el folio.
- **Toda venta guarda snapshot** de nombre, costo y precio de cada renglón.
  Cambiar el precio de un producto después no debe alterar la historia.
- **Sólo los repositorios escriben en Hive.** Las pantallas y los providers
  llaman repositorios; si necesitas un dato nuevo, va en un repositorio.
- **Enums se guardan como índice `int`**, no como objeto. Hive no sabe
  serializarlos (`Cannot write, unknown type: MovementType`) y el `typeId` de un
  enum genérico no es estable. El getter/setter del modelo es quien traduce.
- **Sin red.** No agregar paquetes ni código que hagan HTTP, ni el permiso
  `INTERNET`. Todo es local.

## Trampas de Flutter/Hive ya pisadas

Cada una costó un rato. No repetirlas.

### Los tests no pueden hablar con el disco dentro de `testWidgets`

El cuerpo de un `testWidgets` corre en una zona de async falsa: un `await` de IO
real (escribir en Hive, en un archivo) **nunca** se resuelve y el test se cuelga
hasta que expira. Para IO real hay que usar `tester.runAsync(...)`.

```dart
await tester.runAsync(() => AppDatabase.meta.put('onboardingDone', true));
```

### `Hive.close()` se cuelga si hay suscripciones `box.watch()` vivas

Los `StreamProvider` de la app se suscriben a `box.watch()`. Si al final del
test se cierra Hive con esas suscripciones Alive, `Hive.close()` no termina
nunca. Por eso los tests de widget usan `openTestDatabaseForWidgetTests()`, que
**vacía** las cajas entre tests y no cierra Hive.

Corolario: un `testWidgets` que monta el dashboard deja el isolate en un estado
del que **ningún `testWidgets` posterior termina**. Por eso
`test/app_router_test.dart` tiene un solo test que monta el shell, con todas sus
aserciones juntas y de último. Si necesitas otro test de widget que monte el
dashboard, va en su propio archivo (cada archivo corre en su isolate).

### `pumpAndSettle` no sirve si hay `StreamProvider` en loading

`pumpAndSettle` espera a que no queden frames pedidos, y un
`CircularProgressIndicator` en estado `loading` pide frames para siempre. Usar
`pump()` a mano.

### `toImage`/`dispose` y el rasterizador del isolate

En `flutter test`, rasterizar **dos veces seguidas** en el mismo test cuelga el
isolate, y `image.dispose()` deja el rasterizador por software en mal estado
para el siguiente `pump`. Por eso `tool/generate_icon.dart` hace un solo render
y no hace `dispose()`.

### `runAsync` + `toImage` no se mezclan

`tester.runAsync(() => boundary.toImage())` se queda colgado. El render va en
el cuerpo del test; el IO de disco, como IO síncrono (`writeAsBytesSync`,
`Process.runSync`) para no depender del event loop.

### `box.watch()` no emite el valor inicial

`Box.watch()` sólo dispara en cambios. Un `StreamProvider` que lo use directo
queda en `loading` para siempre con la base vacía y la pantalla se queda en el
spinner. Todo `watch*` de los repos arranca con el estado actual:

```dart
Stream<List<Product>> watchAll() async* {
  yield all();                                   // estado actual, ya
  yield* AppDatabase.products.watch().map((_) => all());
}
```

### Varios FAB con el hero tag por defecto

El shell usa `StatefulShellRoute.indexedStack`: las pestañas visitadas quedan
montadas a la vez, así que sus FAB conviven en el mismo Navigator. Con el
`heroTag` por defecto Flutter truena al animar
(`multiple heroes that share the same tag`). Los FAB de pantalla llevan
`heroTag: null`.

### Mutar un `HiveObject` en sitio no notifica a Riverpod

Hive devuelve **la misma instancia** del objeto mientras la caja la tenga
cargada. Un `Notifier` que haga `state = repo.getSettings()` después de mutar
ese objeto reasigna la misma referencia: `identical(previo, nuevo)` es `true`,
Riverpod no emite y la UI no se entera del cambio (el tema no cambiaba al
clickearlo, igual que moneda, fecha y nombre del negocio).

Regla: el notifier muta una **copia** con identidad nueva y guarda ésa.

```dart
final AppSettings next = mutate(repo.getSettings().copy());
await repo.saveSettings(next);
state = next;                  // instancia nueva ⇒ sí notifica
```

Los modelos con estado persistido exponen `copy()` para esto.

### Los adapters de Hive se registran con su tipo genérico

`Hive.registerAdapter(BusinessSettingsAdapter())` registra el typeId **de
`dynamic`**, y no el del adapter. Así `Hive.isAdapterRegistered` da `true` para
cualquier typeId y `Product` termina escrito con el adapter equivocado.
`AppDatabase._registerAdapters` los registra uno por uno con
`Hive.registerAdapter<T>(adapter)`.

## Reportes

- **El inventario no es un rango.** `ReportsRepository.inventoryReport()` es el
  estado de hoy, con o sin filtro de fechas, y `todaySnapshot` lee los mismos
  números: dos recorridos distintos para el mismo dato divergent.
- **La serie estira el rango hasta el final del último día.** `series()`
  aplica `Dates.endOfDay(to)` antes de filtrar. Sin eso, si el rango llega a
  medianoche, todo lo que pasó durante ese día se salía de la gráfica sin
  avisar.
- Los cubos van anclados: la semana en lunes, el mes en el día 1.

## Utilidad neta

- **Los gastos se restan en el repositorio, no en la pantalla.**
  `ReportsRepository.summaryForRange` ya mete `expenses` en el `ProfitSummary`,
  así que `netProfit` viene con la cuenta hecha (§24: ingresos − costo − gastos).
  Si una pantalla los resta aparte, otro día se olvida y termina enseñando la
  ganancia bruta con la etiqueta de neta. `todaySnapshot` y `buildClosing` toman
  `sales.expenses`, no su propio recorrido.

## Montos

- **`NumberFormat.format` pide `num`, no `String`.** Pasarle el resultado de
  `toStringAsFixed` truena adentro con `NoSuchMethodError: 'String' has no
  getter isNegative`, y no lo detecta el analizador. `Money._scaled` hace el
  `double.parse` explícito.
- Compactar tiene un caso de borde: $999,999.99 escalado a `k` daría
  `$1,000.0k`, así que por encima de $999,950 se sube a `M`.
- `fl_chart` se cuelga en bucle infinito si un `SideTitles.interval` llega a
  0 (`while (axisSeek <= end + epsilon) { axisSeek += interval; }`). Un
  `maxY / 4` con `maxY` en 0 lo dispara. `Math.max(1, ...)` en el eje.

## Códigos de producto

- El **SKU** se autogenera en alta a partir del nombre: iniciales de las tres
  primeras palabras (`Playera básica negra` ⇒ `PBN-001`); si es una sola palabra,
  sus tres primeras letras (`Gorra` ⇒ `GOR-001`). El correlativo se calcula
  contra la caja con `_nextCorrelative`, nunca se supone libre.
- El **código de barras** es EAN-13 de 13 dígitos con dígito verificador. El
  primer dígito va de 0 a 8. Opcional: si el usuario no escribe, se genera.
- `Random.nextInt` no llega a 10^12; el payload del EAN-13 se arma con dos
  tramos de seis (`_randomPayload`).
- Mientras el usuario no escriba el campo, la app lo autogenera; al teclearlo,
  deja de hacerlo (`_skuAuto` / `_barcodeAuto`). En edición no se toca lo que ya
  tenía.

## Navegación

- Las rutas viven en `lib/routes/app_routes.dart`. No hardcodear paths.
- **Todo `GoRoute` declara `name:` además de `path:`.** La app navega con
  `context.pushNamed`, y sin `name` go_router truena con
  `unknown route name: /venta/nueva`. El nombre es el mismo string que el path.
- Los ids viajan en `extra`, no en el path.
- `createAppRouter()` crea un router nuevo; `appRouter` es la instancia de la
  app. Los tests usan `createAppRouter()` para no compartir estado.
- Pantallas que distinguen alta de edición (p. ej. `ProductFormScreen`, que usa
  `productId != null`) reciben `_optionalIdOf(state)`, que da `null` sin
  `extra`. `_idOf` devuelve `''` y sólo es para rutas que exigen un id.
- El shell no lleva FAB: cada pantalla define el suyo. Dos FABs se solapan.
- Se usa `context.pushNamed(...)`, no `Navigator.pushNamed`. Quedan
  conversiones por revisar con `grep -rn "Navigator.pushNamed" lib/`.

## Imports y exportaciones

- CSV y JSON de productos van en **pesos con dos decimales**, no en centavos
  crudos. `Parsers.asCents` multiplica por 100, así que exportar centavos
  duplica los precios al reimportar.
- El CSV no lleva código de barras (así lo pide la especificación).
- Un archivo que no es CSV/JSON lanza `ImportException`; la UI lo muestra, no
  se rompe.

## Skills

En `.opencode/skills/` hay 14 skills oficiales de `flutter/agent-plugins`
(`flutter-*`) y `dart-lang/skills` (`dart-*`), separadas por nombre. Son de
Flutter y Dart: arquitectura, widget tests, layout, JSON, routing, localización,
tests unitarios, análisis estático, errores en runtime y documentación.

No incluye `flutter-use-http-package` a propósito: la app es offline y agregar
HTTP violaría la regla de arriba. Para actualizarlas, clonar
`github.com/flutter/agent-plugins` y copiar `skills/<nombre>/`; el CLI
`npx skills` funciona pero siembra un directorio por cada agente conocido.

