# TIANGUIS CONTROL — PROMPT MAESTRO DE DESARROLLO

Quiero desarrollar una aplicación móvil Android llamada **Tianguis Control**, creada con **Flutter + Dart**, para llevar el control de ventas, productos, inventario, gastos y ganancias de un puesto de tianguis.

La aplicación será utilizada directamente por el dueño o encargado del puesto.

## OBJETIVO PRINCIPAL

La aplicación debe permitir administrar de forma sencilla y rápida:

* Productos.
* Costos.
* Precios de venta.
* Ganancias.
* Stock.
* Ventas.
* Ventas rápidas.
* Gastos.
* Caja/efectivo.
* Cierres diarios.
* Reportes.
* Importación y exportación de productos.
* Respaldos de información.
* Personalización del negocio.
* Logo.
* Tema claro/oscuro/sistema.

La aplicación será **100% offline**.

NO debe existir:

* Login.
* Registro de usuarios.
* Contraseñas.
* Firebase.
* Backend.
* API.
* Servidor.
* Base de datos remota.
* Sistema de cuentas.
* Suscripciones.

Toda la información debe almacenarse localmente en el dispositivo.

---

# 1. PLATAFORMA

La aplicación será desarrollada exclusivamente para:

**Android**

No es necesario desarrollar funcionalidades específicas para:

* iOS
* Web
* Desktop

El proyecto debe estar correctamente preparado para generar:

```text
flutter build apk --release
```

La aplicación será instalada directamente mediante APK en dispositivos Android.

No se publicará en Google Play Store.

Por lo tanto, no agregar dependencias o configuraciones relacionadas con publicación en Play Store que no sean necesarias.

---

# 2. STACK

Utilizar:

* Flutter
* Dart
* Material 3
* Hive / Hive CE
* Riverpod
* GoRouter
* intl
* fl_chart

Arquitectura:

```text
Presentation
    ↓
Domain
    ↓
Data
    ↓
Local Database
```

Mantener una arquitectura limpia pero práctica.

No crear una arquitectura excesivamente compleja.

---

# 3. BASE DE DATOS

Utilizar una base de datos local embebida:

**Hive / Hive CE**

La aplicación debe funcionar completamente sin conexión.

Modelos principales:

```text
BusinessSettings
Product
Category
Sale
SaleItem
InventoryMovement
Expense
CashMovement
DailyClosing
AppSettings
```

La información debe persistir aunque:

* Se cierre la aplicación.
* Se reinicie el teléfono.
* No exista conexión.
* Se abra nuevamente la aplicación.

---

# 4. IDENTIDAD VISUAL

La aplicación debe tener una identidad visual inspirada en los **tianguis mexicanos**.

No utilizar una apariencia corporativa fría.

La interfaz debe transmitir:

* Comercio.
* Mercado.
* Cercanía.
* Productos.
* Movimiento.
* Colores vivos.
* Confianza.
* Simplicidad.

## Paleta sugerida

Utilizar una combinación inspirada en puestos y mercados mexicanos:

```text
Rojo / Chile:
#C62828

Naranja:
#EF6C00

Amarillo:
#F9A825

Verde:
#2E7D32

Turquesa:
#00897B

Crema:
#FFF8E7

Café:
#6D4C41

Blanco:
#FFFFFF

Negro:
#212121
```

No utilizar todos los colores simultáneamente.

Crear una paleta Material 3 coherente a partir de estos colores.

El color principal puede ser una combinación de:

**Naranja + rojo + amarillo**

con verde/turquesa como colores secundarios.

---

# 5. LOGO DE LA APLICACIÓN

Crear un logo propio para la aplicación.

El logo debe tener temática de tianguis mexicano.

Concepto sugerido:

Un pequeño puesto/mercado visto de frente con:

* Un toldo.
* Cajas o productos.
* Elementos de comercio.
* Una pequeña etiqueta de precio.

Estilo:

* Moderno.
* Minimalista.
* Amigable.
* Fácilmente reconocible.
* Funcione correctamente como icono Android.

Evitar:

* Diseños demasiado complejos.
* Texto pequeño.
* Exceso de elementos.

Crear también una versión simplificada para:

* App icon.
* Splash screen.
* Imagen predeterminada del negocio.

---

# 6. LOGO PERSONALIZADO DEL NEGOCIO

El usuario podrá agregar opcionalmente un logo propio.

En configuración:

```text
Logo del negocio

[Imagen actual]

Cambiar logo
Eliminar logo
```

Si no existe un logo personalizado:

Utilizar automáticamente el logo de **Tianguis Control** como imagen predeterminada.

El logo personalizado debe almacenarse localmente.

No subir ninguna imagen a internet.

---

# 7. CONFIGURACIÓN INICIAL

La primera vez que se abre la aplicación debe detectar que todavía no existe una configuración inicial.

Mostrar una pantalla de bienvenida:

```text
┌──────────────────────────┐
│                          │
│       [LOGO APP]         │
│                          │
│    Tianguis Control      │
│                          │
│ Configura tu negocio     │
│                          │
│ Nombre del negocio       │
│ [____________________]   │
│                          │
│ Nombre del encargado     │
│ [____________________]   │
│                          │
│       [Continuar]        │
│                          │
│ Puedes configurarlo      │
│ después desde Ajustes.   │
└──────────────────────────┘
```

---

# 8. VALORES POR DEFAULT

Si el usuario no completa la configuración inicial, NO bloquear la aplicación.

Debe existir una configuración predeterminada.

Utilizar:

```text
Nombre del negocio:
Mi Tianguis

Nombre del encargado:
Encargado
```

Si el usuario entra a la pantalla inicial y:

* Deja los campos vacíos.
* Regresa.
* Cierra la aplicación.
* Presiona "Omitir".

No guardar valores vacíos.

Mantener los valores:

```text
Mi Tianguis
Encargado
```

Mostrar debajo de la configuración inicial:

> "Puedes personalizar estos datos después desde Configuración."

La aplicación debe permitir utilizarse inmediatamente.

---

# 9. CONFIGURACIÓN DEL NEGOCIO

Crear:

```text
Configuración
    └── Mi negocio
```

Permitir editar:

### Nombre del negocio

Ejemplo:

```text
Puesto El Güero
```

### Nombre del encargado

Ejemplo:

```text
Jesús
```

### Logo

Opcional.

Opciones:

```text
Cambiar logo
Eliminar logo
```

Si se elimina:

Volver automáticamente al logo predeterminado de la aplicación.

---

# 10. TEMA DE LA APLICACIÓN

Agregar configuración:

```text
Tema

○ Claro
○ Oscuro
○ Sistema
```

Por defecto:

```text
Sistema
```

La aplicación debe respetar la configuración de Android cuando se seleccione:

**Sistema**

El cambio debe realizarse inmediatamente.

Guardar la preferencia localmente.

---

# 11. DASHBOARD

El Dashboard debe ser la pantalla principal.

Mostrar arriba:

```text
[LOGO]

Puesto El Güero
Encargado: Jesús

Buenos días 👋
```

Dependiendo de la hora:

```text
Buenos días
Buenas tardes
Buenas noches
```

---

# 12. MÉTRICAS PRINCIPALES

Mostrar cards:

### Ventas de hoy

```text
$2,450
```

### Ganancia estimada

```text
$1,120
```

### Productos vendidos

```text
34
```

### Gastos

```text
$250
```

---

# 13. INVENTARIO EN DASHBOARD

Mostrar:

```text
Inventario

125 productos

⚠ 8 productos con stock bajo
✕ 3 productos agotados
```

Permitir tocar la sección para ir directamente a Inventario.

---

# 14. ACCIONES RÁPIDAS

El Dashboard debe tener acciones grandes:

```text
┌─────────────────┐
│  + NUEVA VENTA  │
└─────────────────┘

┌──────────┐ ┌──────────┐
│ Producto │ │  Gasto   │
└──────────┘ └──────────┘

┌──────────┐ ┌──────────┐
│ Inventario││ Venta    │
│           ││ rápida   │
└──────────┘ └──────────┘
```

---

# 15. VENTA NORMAL

Crear pantalla:

```text
Nueva venta
```

Permitir:

* Buscar producto.
* Seleccionar producto.
* Agregar al carrito.
* Cambiar cantidad.
* Eliminar producto.
* Aplicar descuento.
* Seleccionar método de pago.
* Cobrar.

Métodos:

```text
Efectivo
Transferencia
Tarjeta
Otro
```

---

# 16. VENTA RÁPIDA

Crear una función especial:

## "Venta rápida"

Esta función NO requiere que exista un producto registrado.

Ejemplo:

El vendedor tiene un artículo que todavía no registró.

Toca:

```text
+ Venta rápida
```

Mostrar:

```text
Venta rápida

Concepto
[________________]

Precio
[$________]

Cantidad
[ 1 ]

Método de pago

○ Efectivo
○ Transferencia
○ Tarjeta
○ Otro

[Registrar venta]
```

Ejemplo:

```text
Concepto:
Artículo varios

Precio:
$50

Cantidad:
2

Total:
$100
```

Registrar la venta aunque no exista un producto.

---

# 17. VENTA RÁPIDA Y GANANCIA

Como una venta rápida no tiene necesariamente costo conocido:

Permitir opcionalmente introducir:

```text
Costo
[$______]
```

Si el usuario no lo proporciona:

```text
Costo:
$0
```

Mostrar:

```text
Ganancia estimada:
$100
```

Pero indicar claramente que es una ganancia estimada si el costo no fue registrado.

---

# 18. PRODUCTOS

Crear CRUD completo:

```text
Productos
```

Cada producto:

```text
ID
Nombre
Descripción
Categoría
SKU
Costo
Precio
Stock
Stock mínimo
Unidad
Activo
Fecha creación
Fecha actualización
```

---

# 19. PRODUCTO

Ejemplo:

```text
Playera básica

Costo
$80

Precio
$150

Ganancia
$70

Margen
46.67%

Stock
12

Stock mínimo
5
```

Calcular automáticamente:

```text
ganancia = precio - costo

margen =
ganancia / precio * 100
```

---

# 20. INVENTARIO

Mostrar:

```text
Producto
Stock
Mínimo
Costo
Valor
Estado
```

Estados:

```text
Disponible
Stock bajo
Agotado
```

Filtros:

```text
Todos
Stock bajo
Agotados
```

---

# 21. ENTRADA DE INVENTARIO

Permitir:

```text
Agregar mercancía

Producto:
Playera

Cantidad:
20

Costo:
$80

[Agregar]
```

Actualizar stock automáticamente.

Crear movimiento:

```text
ENTRADA
```

---

# 22. MOVIMIENTOS

Registrar:

```text
Entrada
Venta
Devolución
Ajuste
Merma
```

Guardar:

```text
Producto
Tipo
Cantidad
Stock anterior
Stock nuevo
Motivo
Fecha
```

---

# 23. GASTOS

Crear módulo:

```text
Gastos
```

Ejemplos:

```text
Cuota del tianguis
Transporte
Comida
Bolsas
Mercancía
Publicidad
Otro
```

Campos:

```text
Concepto
Categoría
Monto
Fecha
Notas
```

---

# 24. GANANCIAS

Calcular:

```text
Ingresos
- Costo de mercancía
= Ganancia bruta

Ganancia bruta
- Gastos
= Ganancia neta
```

Mostrar por:

```text
Hoy
7 días
30 días
Mes actual
Rango personalizado
```

---

# 25. HISTORIAL

Mostrar ventas:

```text
V-000124

28/09/2026
03:42 PM

$450

Efectivo
4 productos
```

Permitir:

* Ver detalle.
* Buscar.
* Filtrar.
* Cancelar.

---

# 26. CANCELACIÓN

Nunca eliminar físicamente una venta.

Marcar:

```text
CANCELADA
```

Restaurar stock.

Crear movimientos correspondientes.

Excluir de estadísticas.

Mantenerla visible en historial.

---

# 27. DEVOLUCIONES

Permitir devolver productos.

Restaurar stock.

Registrar movimiento.

Actualizar estadísticas correctamente.

---

# 28. CAJA

Crear:

```text
Control de caja
```

Registrar:

```text
Fondo inicial
Ventas efectivo
Entradas
Salidas
Gastos efectivo
```

Calcular:

```text
Efectivo esperado
```

Permitir ingresar:

```text
Efectivo contado
```

Calcular diferencia.

---

# 29. CIERRE DEL DÍA

Mostrar:

```text
CIERRE DEL DÍA

Ventas:
27

Productos:
63

Efectivo:
$3,450

Transferencias:
$1,200

Tarjeta:
$850

----------------

Total:
$5,500

Costo:
$2,400

Ganancia:
$3,100

Gastos:
$350

UTILIDAD NETA:
$2,750
```

Guardar el cierre.

---

# 30. REPORTES

Crear:

```text
Reportes
```

Secciones:

### Ventas

* Ventas diarias.
* Ventas semanales.
* Ventas mensuales.
* Ventas por método de pago.

### Productos

* Más vendidos.
* Mayor facturación.
* Mayor ganancia.

### Inventario

* Stock bajo.
* Agotados.
* Valor del inventario.

### Finanzas

* Ingresos.
* Costos.
* Gastos.
* Ganancia bruta.
* Ganancia neta.

Utilizar gráficas con `fl_chart`.

---

# 31. IMPORTAR / EXPORTAR PRODUCTOS

Crear dentro de:

```text
Configuración
    └── Datos
          ├── Importar productos
          └── Exportar productos
```

La importación/exportación de productos debe ser independiente del backup completo.

---

# 32. EXPORTAR PRODUCTOS

Permitir exportar productos a:

```text
CSV
```

Y opcionalmente:

```text
JSON
```

CSV recomendado:

```text
nombre
descripcion
categoria
sku
unidad
costo
precio
stock
stock_minimo
activo
```

Ejemplo:

```text
Playera básica,Ropa,P-001,pieza,80,150,20,5,true
Gorra,Ropa,G-001,pieza,40,100,15,5,true
```

Permitir compartir/guardar el archivo desde Android.

---

# 33. IMPORTAR PRODUCTOS

Permitir seleccionar un archivo CSV o JSON desde el almacenamiento del dispositivo.

Mostrar una vista previa:

```text
Se encontraron:

50 productos

Nuevos:
35

Existentes:
15

Errores:
0
```

Antes de importar mostrar:

```text
¿Cómo deseas manejar productos existentes?

○ Actualizar productos existentes
○ Ignorar productos existentes
```

Validar:

* Nombre.
* Precio.
* Costo.
* Stock.
* Categoría.
* Formato.
* Duplicados.

No importar registros inválidos.

Mostrar errores de importación de manera clara.

---

# 34. BACKUP COMPLETO

Además de importar/exportar productos, crear:

```text
Configuración
    └── Respaldo
          ├── Exportar respaldo
          └── Restaurar respaldo
```

El backup completo debe incluir:

```text
Configuración
Productos
Categorías
Ventas
Detalles de venta
Inventario
Movimientos
Gastos
Caja
Cierres
```

Formato:

```text
JSON
```

Ejemplo:

```text
tianguis_backup_2026-09-28.json
```

---

# 35. VERSIONADO DE BACKUPS

El archivo debe contener:

```text
backup_version
app_version
created_at
```

Ejemplo:

```json
{
  "backup_version": 1,
  "app_version": "1.0.0",
  "created_at": "2026-09-28T15:30:00",
  "data": {}
}
```

Preparar el sistema para futuras migraciones.

---

# 36. CONFIGURACIÓN

Crear una pantalla:

```text
Configuración
```

Secciones:

### Mi negocio

* Nombre del negocio.
* Nombre del encargado.
* Logo.

### Apariencia

* Claro.
* Oscuro.
* Sistema.

### Datos

* Importar productos.
* Exportar productos.
* Exportar respaldo.
* Restaurar respaldo.

### Preferencias

* Moneda.
* Formato de fecha.
* Stock mínimo.
* Prefijo de ventas.

### Información

* Versión.
* Acerca de Tianguis Control.

---

# 37. MONEDA

Por defecto:

```text
MXN
```

Mostrar:

```text
$150.00
```

Usar valores enteros en centavos para cálculos financieros.

No utilizar `double` para operaciones monetarias críticas.

---

# 38. FOLIOS

Generar automáticamente:

```text
V-000001
V-000002
V-000003
```

Nunca reutilizar un folio.

---

# 39. PRODUCTOS Y VENTAS HISTÓRICAS

Una venta debe guardar snapshot de:

```text
Nombre
Costo
Precio
```

Por lo tanto, si el producto cambia posteriormente:

```text
Antes:

Playera
$80 costo
$150 venta
```

y después:

```text
Playera
$100 costo
$180 venta
```

La venta anterior debe continuar mostrando:

```text
$80
$150
```

---

# 40. BÚSQUEDA

Buscar productos por:

```text
Nombre
SKU
Código
Categoría
```

La búsqueda debe ser rápida y local.

Preparar la arquitectura para agregar lector de código de barras en una versión posterior.

---

# 41. EXPERIENCIA DE USUARIO

La aplicación está pensada para una persona que está atendiendo clientes.

Debe funcionar cómodamente:

* Con una mano.
* Bajo presión.
* Con clientes esperando.
* Con poca atención disponible.

Priorizar:

**Velocidad > cantidad de opciones > complejidad.**

La acción más importante siempre será:

```text
NUEVA VENTA
```

---

# 42. BOTTOM NAVIGATION

Utilizar:

```text
Inicio
Ventas
Productos
Reportes
Más
```

Dentro de "Más":

```text
Gastos
Caja
Inventario
Configuración
```

El cuarto destino es **Reportes**, no Inventario: es la pantalla que el dueño
abre todos los días para saber cómo van las ventas, y con Inventario en el
footer quedaba escondida a dos toques dentro de "Más". Inventario sigue
alcanzable desde "Más" y desde la ficha de cada producto.

---

# 43. DARK MODE

Todo el diseño debe funcionar correctamente en:

```text
Light
Dark
System
```

No usar colores fijos que desaparezcan en Dark Mode.

Crear correctamente:

```text
ColorScheme
ThemeData
DarkTheme
```

---

# 44. ESTADOS VACÍOS

Todas las pantallas deben tener estados vacíos.

Ejemplo:

```text
Todavía no tienes productos.

Agrega tu primer producto
para comenzar a controlar
tu inventario.

[+ Agregar producto]
```

---

# 45. VALIDACIONES

Validar todos los formularios.

Nunca permitir:

* Precios negativos.
* Costos negativos.
* Stock negativo.
* Cantidades cero.
* Productos sin nombre.
* Ventas sin productos.
* Gastos sin monto.

---

# 46. SEGURIDAD DE DATOS

Aunque no existe login, evitar pérdida accidental de información.

Antes de acciones destructivas:

```text
Eliminar producto
Eliminar categoría
Restaurar backup
Eliminar todos los datos
```

mostrar confirmación.

Para eliminar todos los datos:

```text
Esta acción eliminará toda la información
almacenada en este dispositivo.

Esta acción no se puede deshacer.

[Cancelar] [Eliminar todo]
```

---

# 47. APP ICON Y SPLASH

Crear:

### App icon

Inspirado en un puesto de tianguis.

### Splash screen

Mostrar:

```text
[LOGO]

Tianguis Control

Tu puesto, bajo control.
```

Mantener el splash sencillo.

---

# 48. DATOS DEMO

Durante desarrollo permitir cargar datos de prueba.

Ejemplo:

```text
Playera
Costo $80
Precio $150

Gorra
Costo $40
Precio $100

Pantalón
Costo $150
Precio $280
```

Crear ventas, gastos e inventario ficticios.

No mostrar datos demo automáticamente en producción.

---

# 49. PERFORMANCE

Debe funcionar correctamente con aproximadamente:

```text
1,000 productos
10,000 ventas
50,000 SaleItems
```

No cargar innecesariamente toda la información en memoria.

Optimizar consultas locales.

---

# 50. TESTS

Crear tests para:

* Ganancias.
* Márgenes.
* Descuentos.
* Stock.
* Ventas.
* Cancelaciones.
* Devoluciones.
* Gastos.
* Caja.
* Cierre diario.
* Importación.
* Exportación.
* Backup.
* Restauración.

---

# 51. ESTRUCTURA DEL PROYECTO

Utilizar una estructura similar:

lib/

```text
core/
├── constants/
├── database/
├── errors/
├── theme/
├── utils/
└── widgets/

features/

├── onboarding/
│
├── dashboard/
│
├── products/
│   ├── data/
│   ├── domain/
│   └── presentation/
│
├── sales/
│
├── inventory/
│
├── expenses/
│
├── cash/
│
├── reports/
│
├── settings/
│
└── backup/

models/

providers/

repositories/

routes/

main.dart
```

---

# 52. FLUJO PRINCIPAL

El flujo más importante debe ser:

```text
ABRIR APP
     ↓
DASHBOARD
     ↓
+ NUEVA VENTA
     ↓
BUSCAR PRODUCTO
     ↓
AGREGAR PRODUCTOS
     ↓
CARRITO
     ↓
MÉTODO DE PAGO
     ↓
COBRAR
     ↓
VALIDAR STOCK
     ↓
GUARDAR VENTA
     ↓
DESCONTAR STOCK
     ↓
CALCULAR GANANCIA
     ↓
CONFIRMACIÓN
     ↓
DASHBOARD
```

---

# 53. FLUJO DE VENTA RÁPIDA

```text
DASHBOARD
     ↓
VENTA RÁPIDA
     ↓
CONCEPTO
     ↓
PRECIO
     ↓
CANTIDAD
     ↓
COSTO OPCIONAL
     ↓
MÉTODO DE PAGO
     ↓
REGISTRAR
     ↓
CONFIRMACIÓN
```

---

# 54. FLUJO DE PRIMER USO

```text
Instalar APK
     ↓
Abrir aplicación
     ↓
Splash
     ↓
Configuración inicial
     ↓
Nombre del negocio
Nombre del encargado
Logo opcional
     ↓
Continuar
     ↓
Dashboard
```

Si el usuario omite:

```text
Mi Tianguis
Encargado
Logo predeterminado
```

La aplicación continúa funcionando.

Posteriormente:

```text
Configuración
   ↓
Mi negocio
```

podrá personalizar todo.

---

# 55. IMPORTANTE SOBRE OFFLINE

La aplicación debe funcionar sin internet.

No debe aparecer ningún error porque el dispositivo esté en:

```text
Modo avión
```

Todas estas funciones deben funcionar offline:

* Dashboard.
* Ventas.
* Venta rápida.
* Productos.
* Inventario.
* Gastos.
* Caja.
* Reportes.
* Cierres.
* Importación.
* Exportación.
* Backup.

---

# 56. NO AGREGAR

No implementar:

* Login.
* Usuarios.
* Roles.
* Backend.
* API.
* Firebase.
* Supabase.
* Cloud database.
* Sincronización.
* Pagos online.
* Suscripciones.
* Publicación Play Store.
* Multiempresa.
* Multiusuario.

La aplicación es una herramienta local para un solo dispositivo.

---

# 57. CRITERIO DE CALIDAD

No quiero solamente pantallas visuales.

La aplicación debe tener funcionalidad real.

Los botones deben ejecutar operaciones reales sobre Hive.

Los cálculos deben funcionar.

El inventario debe actualizarse.

Las ventas deben persistir.

Los reportes deben utilizar los datos reales.

Los backups deben poder restaurarse.

La importación/exportación debe funcionar realmente.

---

# 58. RESULTADO FINAL

El resultado debe sentirse como:

**Un pequeño POS offline diseñado específicamente para un puesto de tianguis mexicano.**

Debe ser:

* Rápido.
* Simple.
* Bonito.
* Colorido.
* Fácil de utilizar.
* Offline.
* Con información local.
* Sin cuentas.
* Sin servidores.
* Sin internet.
* Instalable directamente mediante APK.

El usuario debe poder instalar el APK, abrirlo y comenzar a registrar ventas en cuestión de minutos.

Prioriza siempre:

**VENTA RÁPIDA → INVENTARIO → GANANCIA → SIMPLICIDAD → CONFIABILIDAD**
