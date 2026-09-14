# Carrota Flutter

Demo móvil y offline para operar un pequeño negocio. El Inicio adopta un
formato TikTok Shop: video vertical en reproducción, capas de información,
acciones laterales y una tarjeta de producto contextual.

## Qué funciona

- Onboarding con responsable, negocio, tipo y moneda.
- Registro de ventas escribiendo frases en español.
- Confirmación de efectivo, tarjeta, transferencia o pago combinado.
- Inventario, llegadas, precios y compra sugerida.
- Métricas, actividad, memoria y cierre de caja.
- Asistente de respuestas fijas basado en los datos locales.
- Botón central de Lumo que abre un apartado independiente de conversación.
- Sugerencias rápidas para consultar ventas, caja e inventario.
- Cinco videos verticales en bucle, con pausa/reproducción y sonido activable.
- Desplazamiento vertical animado con indicaciones para subir o bajar.
- Precarga del video actual y los adyacentes para reducir tirones al navegar.
- Me gusta, comentarios y guardados independientes para cada producto.
- Compartir mediante el menú nativo del sistema (Android `ACTION_SEND`).
- Carrito persistente con cantidades, subtotal, eliminar, vaciar y compartir.
- Checkout local de demostración que registra la venta y descuenta inventario.
- Producto superpuesto con detalle real y botón para agregar al carrito.
- Persistencia SQLite automática y versionada.
- Cámara y micrófono visibles como funciones futuras.

La app no llama a OpenAI, DeepSeek ni otro servicio de inteligencia artificial.
Las consultas funcionan sin internet y no salen del dispositivo.

Inicio está reservado al feed: no muestra el mensaje de configuración ni el
chat del asistente. Los comentarios del video son independientes. Lumo se abre
desde el botón central elevado de la barra inferior y tiene su propia pantalla,
historial y campo de texto.

## Preguntas locales reconocidas

Puedes escribir variaciones de:

- `¿Cómo va el negocio?`
- `¿Cuánto vendí hoy?`
- `¿Cuánto debería haber en caja?`
- `¿Qué falta en inventario?`
- `¿Cuál es el producto más vendido?`
- `¿Cómo va la lista de compra?`
- `¿El día está cerrado?`
- `Ayuda`

También puedes registrar ventas como:

```text
Vendí dos tomates y una lechuga
```

## Videos de la demo

El feed usa cinco MP4 verticales optimizados en `assets/videos/`:

- `fresh_fruit.mp4`
- `lettuce.mp4`
- `apples.mp4`
- `lemons.mp4`
- `citrus.mp4`

Son clips de prueba descargados gratuitamente desde la colección vertical de
[Mixkit Healthy Food](https://mixkit.co/free-stock-video/discover/healthy-food/?orientation=vertical),
ofrecida sin marca de agua bajo las condiciones indicadas por Mixkit. Antes de
publicar comercialmente, reemplázalos por contenido propio del negocio o valida
la licencia vigente de cada clip. En Android se reproducen automáticamente, en
bucle y silenciados; el botón superior activa el audio y tocar el video pausa o
reanuda la reproducción.

## Persistencia local

SQLite crea `carrota_local.db` dentro del directorio privado de la app. Guarda:

- Perfil y onboarding.
- Productos, precios y stock.
- Ventas y pagos.
- Conversación local.
- Memoria y actividad.
- Compra sugerida, ajustes y cierre.
- Carrito, cantidades y pedidos confirmados en la demo.

Los datos sobreviven al cierre, reinicio y actualización. Android los elimina
si desinstalas la app o usas “Borrar datos”.

## Ejecutar y verificar

Android es la plataforma principal de la demo con reproducción y persistencia SQLite. Desde una carpeta **local**, con Flutter y el SDK Android instalados:

```bash
flutter pub get
flutter devices
flutter run --profile -d "ID_DEL_TELEFONO"
flutter analyze
flutter test --coverage
flutter build apk --debug
```

La versión web permite revisar la interfaz y los videos, pero esta implementación de SQLite no guarda datos en el navegador. El reproductor declarado tampoco incluye una implementación nativa para Windows.

El feed sigue el dedo en ambos sentidos, prepara una ventana de hasta tres reproductores, limita a dos las cargas simultáneas para superar una precarga vecina lenta y conserva la posición al volver. Pausa durante el arrastre, al cambiar de sección, al abrir otra ruta o panel y al pasar a segundo plano. Incluye portadas de los clips, errores recuperables y controles de pausa/sonido.

- [Guía de commit y push desde Git Bash](GUIA_GIT_BASH.md).
- [Cambios, pruebas y límites de validación](INFORME_MEJORAS_Y_PRUEBAS.md).

La integración remota futura está separada en `PLAN_API_SYNC.md`. El backend
experimental de etapas anteriores no está conectado a esta versión de Flutter.
