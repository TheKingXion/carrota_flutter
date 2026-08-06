# Guía de Carrota Flutter

## 1. Mapa del proyecto

La mayor parte del trabajo cotidiano está dentro de `lib/`:

```text
lib/
├── main.dart        Inicia Flutter y aplica el tema.
├── app.dart         Carcasa del teléfono, navegación y compositor.
├── screens.dart     Las cuatro pantallas principales.
├── sheets.dart      Paneles que suben desde la parte inferior.
├── app_store.dart   Estado y reglas del negocio.
├── models.dart      Formas de los datos.
├── theme.dart       Colores, tipografía y estilos generales.
└── widgets.dart     Componentes visuales reutilizables.
```

Otras carpetas:

```text
test/       Pruebas automáticas.
android/    Proyecto nativo que compila el APK.
web/        Archivos de arranque para Chrome.
windows/    Proyecto nativo de escritorio.
```

Normalmente no necesitas editar `android/`, `web/` ni `windows/` mientras
trabajas en las pantallas.

## 2. Cómo comienza la aplicación

`main.dart` contiene:

```dart
void main() {
  runApp(const CarrotaApp());
}
```

`CarrotaApp` crea `MaterialApp`, carga el tema y abre `AppShell`.

```text
main()
  → CarrotaApp
    → MaterialApp
      → AppShell
```

## 3. La carcasa móvil

`PhoneStage`, dentro de `app.dart`, consulta el ancho disponible.

- Con menos de 700 px usa toda la pantalla: se comporta como una app móvil.
- Desde 700 px coloca la interfaz dentro de un teléfono de 430 px.
- En escritorio agrega marco, sombra, isla superior y barra de estado.
- Desde 900 px también muestra la marca Carrota en el fondo exterior.

La carcasa no conoce las ventas ni el inventario. Su única responsabilidad es
presentar cualquier contenido como una aplicación móvil.

## 4. Navegación y entrada de mensajes

También en `app.dart`:

- `_MobileNavigation` cambia entre Inicio, Hoy, Memoria y Negocio.
- `_Composer` contiene micrófono, cámara, campo de texto y botón de envío.
- `IndexedStack` mantiene vivas las cuatro pantallas al cambiar de pestaña.

Cuando se envía texto:

```text
_Composer
  → AppShell.send()
    → AppStore.send()
      → interpreta el texto
      → crea un mensaje o una propuesta de venta
      → notifyListeners()
      → Flutter vuelve a dibujar los widgets afectados
```

Las palabras relacionadas con llegada o cierre abren directamente sus paneles.

## 5. Estado y reglas de negocio

`app_store.dart` es la fuente de verdad temporal de la aplicación.

Contiene:

- `products`: inventario.
- `chat`: conversación actual.
- `memories`: recuerdos del negocio.
- `timeline`: actividad del día.

`send()` interpreta frases como:

```text
Vendí dos tomates y una lechuga
```

`confirmSale()`:

1. Guarda el método de pago.
2. Descuenta las cantidades del inventario.
3. Agrega la venta a la actividad.
4. Crea un recuerdo.
5. Añade una confirmación al chat.
6. Notifica a la interfaz.

Actualmente los datos viven en memoria. Al cerrar la aplicación vuelven a sus
valores iniciales. El siguiente paso natural sería conectarlos a SQLite,
Supabase, Firebase o una API propia.

## 6. Modelos

`models.dart` define las estructuras usadas por el estado:

- `Product`: producto, precio, stock y proveedor.
- `SaleLine`: producto y cantidad de una venta.
- `Sale`: total, pago, hora y líneas.
- `ChatMessage`: mensaje del usuario o de Lumo.
- `MemoryEvent`: recuerdo.
- `TimelineEvent`: actividad.

Si necesitas añadir un campo permanente, primero suele añadirse al modelo y
después se actualizan el store y los widgets que lo muestran.

## 7. Pantallas

`screens.dart` contiene:

- `HomeScreen`: saludo, resumen, métricas, chat y alertas.
- `TodayScreen`: ingresos, gráfica y actividad.
- `MemoryScreen`: búsqueda y recuerdos.
- `BusinessScreen`: inventario, preferencias y ajustes.

Las pantallas reciben `AppStore`; leen datos y llaman funciones, pero las reglas
de negocio permanecen centralizadas en el store.

## 8. Paneles inferiores

`sheets.dart` contiene:

- Detalle de producto.
- Compra sugerida.
- Recepción de mercadería.
- Venta simulada por voz.
- Cierre del día.

Se abren mediante funciones como:

```dart
showProductSheet(context, store, productId);
showDeliverySheet(context, store);
showClosingSheet(context);
```

## 9. Diseño

`theme.dart` concentra:

- Paleta verde de Carrota.
- Colores de superficie y fondo.
- Tipografía.
- Tarjetas.
- Campos de texto.

`widgets.dart` reúne piezas repetidas:

- `LumoMark`
- `SectionLabel`
- `TagChip`
- `MetricCard`
- `SheetScaffold`

Si deseas cambiar el verde de toda la aplicación, modifica `primary` en
`theme.dart`. Si deseas cambiar solamente una tarjeta de una pantalla, modifica
esa pantalla.

## 10. Pruebas

`test/app_test.dart` verifica:

1. Que una venta en español se interprete y cambie el stock.
2. Que aparezca el onboarding.
3. Que la carcasa de teléfono aparezca en escritorio y no en móvil.

Ejecuta:

```cmd
flutter analyze
flutter test
```

## 11. Ejecutar y ver cambios

```cmd
flutter run -d chrome
```

Mientras está ejecutándose:

- `r`: hot reload.
- `R`: hot restart.
- `q`: detener.

Usa hot reload para colores, tamaños y widgets. Usa hot restart cuando cambies
el estado inicial o la forma en que arranca la aplicación.
