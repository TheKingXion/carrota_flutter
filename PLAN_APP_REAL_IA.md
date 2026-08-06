# Plan: convertir Carrota en una aplicación real con IA

## 1. Objetivo

Transformar el prototipo actual en una aplicación que:

- cree usuarios y negocios reales;
- guarde productos, ventas, inventario y conversaciones;
- haga preguntas cuando falte información;
- responda usando los datos reales del negocio;
- use OpenAI y DeepSeek detrás de un único sistema;
- permita elegir `Automático`, `OpenAI` o `DeepSeek`;
- proponga operaciones y pida confirmación antes de modificar datos;
- funcione en Android, web y posteriormente iOS.

## 2. Principio central

La IA no será la base de datos y no podrá inventar cifras.

Ejemplo:

```text
Usuario: ¿Cómo vamos hoy?

IA:
1. solicita get_business_summary;
2. el backend consulta ventas reales;
3. recibe ingresos, operaciones y productos;
4. explica esos datos al usuario.
```

Para una escritura:

```text
Usuario: Vendí dos tomates y una lechuga.

IA:
1. busca productos y precios reales;
2. crea un borrador de venta;
3. pregunta el método de pago;
4. muestra el total;
5. espera confirmación;
6. el backend registra la venta en una transacción;
7. devuelve el resultado confirmado.
```

La IA puede interpretar y conversar. Las reglas, cálculos y escrituras las
realiza código determinista.

## 3. Arquitectura recomendada

```text
Flutter
  │
  │ HTTPS + streaming
  ▼
Backend TypeScript
  ├── Autenticación y permisos
  ├── Reglas del negocio
  ├── Herramientas de Carrota
  ├── Router de IA
  │     ├── OpenAI Responses API
  │     └── DeepSeek Chat Completions
  └── PostgreSQL
        ├── usuarios y negocios
        ├── productos e inventario
        ├── ventas
        ├── conversaciones
        └── auditoría
```

### Tecnologías

- App: Flutter.
- Backend: Node.js + TypeScript + Fastify.
- Base de datos y autenticación: Supabase/PostgreSQL.
- OpenAI: Responses API.
- DeepSeek: API compatible con Chat Completions.
- Streaming: Server-Sent Events.
- Archivos de boletas o facturas: Supabase Storage.

El backend vivirá inicialmente dentro de este repositorio:

```text
carrota_flutter/
├── lib/         aplicación Flutter
├── backend/     API TypeScript
├── supabase/    migraciones y políticas de datos
└── test/        pruebas Flutter
```

## 4. Uso de OpenAI y DeepSeek

### Modos disponibles

#### Automático, recomendado

El servidor selecciona el proveedor según el trabajo:

- conversación cotidiana y herramientas: modelo balanceado;
- análisis complejo: modelo de mayor capacidad;
- extracción o clasificación simple: modelo rápido y económico;
- fallo temporal: proveedor alternativo cuando sea seguro reintentar.

#### OpenAI

- API: Responses.
- Modelo cotidiano inicial: `gpt-5.6-terra`.
- Análisis de mayor dificultad: `gpt-5.6-sol`.
- Conversation ID o `previous_response_id` para continuidad.
- Function calling para consultar y operar Carrota.

#### DeepSeek

- API: `/chat/completions`.
- Modelo rápido inicial: `deepseek-v4-flash`.
- Análisis más profundo: `deepseek-v4-pro`.
- El backend conserva y reenvía el historial porque la API es stateless.
- Function calling con las mismas herramientas lógicas de Carrota.

Los nombres de modelos estarán en configuración del servidor y no dispersos en
la app. Así podrán actualizarse sin publicar otro APK.

### Interfaz común

```ts
interface AiProvider {
  streamTurn(input: ProviderTurn): AsyncIterable<ProviderEvent>;
}
```

Ambos proveedores se normalizarán a eventos internos:

```text
text_delta
question
tool_call
tool_result
usage
completed
error
```

La app Flutter no necesitará saber qué formato utiliza cada proveedor.

## 5. Herramientas que podrá usar la IA

Primera versión:

### Solo lectura

- `search_products`
- `get_product`
- `get_inventory`
- `get_business_summary`
- `get_sales_report`
- `get_recent_activity`
- `search_business_memory`

### Propuestas

- `draft_sale`
- `draft_inventory_receipt`
- `draft_price_change`
- `draft_shopping_list`
- `draft_daily_close`

### Escrituras confirmadas

- `confirm_sale`
- `confirm_inventory_receipt`
- `confirm_price_change`
- `confirm_daily_close`

Reglas:

- toda herramienta valida tipos y permisos;
- la IA nunca envía precios finales sin consultar productos;
- una escritura requiere un `draft_id`;
- el usuario debe confirmar ese borrador;
- la confirmación usa una clave de idempotencia para impedir duplicados;
- toda operación queda en un registro de auditoría.

## 6. Preguntas reales y manejo de ambigüedad

El prompt de Carrota indicará:

```text
Objetivo:
Ayudar al usuario a entender y operar su negocio usando datos verificables.

Cuando falte información:
- pregunta solamente por el dato mínimo necesario;
- no inventes productos, cantidades, precios ni métodos de pago;
- conserva los valores que el usuario ya entregó;
- muestra el borrador antes de cualquier escritura;
- explica claramente qué dato proviene del negocio y qué es una estimación.
```

Ejemplos:

```text
"Vendí tomates"
→ ¿Cuántos kilos de tomate vendiste?

"Vendí dos tomates"
→ Encontré “Tomate saladet”. ¿Te refieres a 2 kg?

"Fue con tarjeta"
→ ¿Cuál es el código de autorización?

"Cambia el precio de la lechuga"
→ ¿Cuál será el nuevo precio?
```

## 7. Base de datos

Tablas iniciales:

```text
profiles
businesses
business_members
products
inventory_movements
sales
sale_lines
conversations
messages
operation_drafts
business_memories
ai_runs
audit_logs
```

### Relaciones esenciales

- un usuario puede pertenecer a varios negocios;
- cada producto pertenece a un negocio;
- el stock se deriva de movimientos de inventario;
- una venta tiene varias líneas;
- cada conversación pertenece a un negocio y usuario;
- cada ejecución de IA registra proveedor, modelo, latencia y uso;
- todas las consultas se filtran por `business_id`.

### Decisión importante

No se guardará el stock solamente como un número editable. La fuente de verdad
será `inventory_movements`:

```text
entrada +20
venta -2
ajuste -1
devolución +1
```

Esto permite auditoría y correcciones reales.

## 8. Seguridad

### Nunca hacer

- incluir `OPENAI_API_KEY` en Flutter;
- incluir `DEEPSEEK_API_KEY` en el APK;
- permitir que Flutter escriba ventas sin autorización;
- confiar en argumentos de herramientas generados por la IA;
- usar una clave general de base de datos desde el teléfono.

### Implementar

- claves de IA solamente como secretos del backend;
- autenticación JWT;
- Row Level Security en PostgreSQL;
- validación con esquemas;
- rate limiting por usuario y negocio;
- límites de tokens, tiempo y herramientas por turno;
- confirmación explícita para acciones;
- claves de idempotencia;
- registros de auditoría;
- ocultamiento de información sensible en logs;
- posibilidad de borrar historial y memoria.

## 9. API de Carrota

Rutas iniciales:

```text
POST   /v1/auth/session
GET    /v1/businesses/current
GET    /v1/products
POST   /v1/products
GET    /v1/inventory
GET    /v1/sales
POST   /v1/chat/stream
POST   /v1/drafts/:id/confirm
POST   /v1/drafts/:id/cancel
GET    /v1/conversations/:id/messages
```

Solicitud de chat:

```json
{
  "conversation_id": "uuid",
  "message": "Vendí dos tomates",
  "provider": "auto"
}
```

El streaming permitirá mostrar la respuesta palabra por palabra y estados como:

```text
Consultando inventario…
Preparando venta…
Esperando confirmación…
```

## 10. Nueva organización de Flutter

```text
lib/
├── app/
│   ├── app.dart
│   └── router.dart
├── core/
│   ├── config/
│   ├── network/
│   ├── storage/
│   └── widgets/
├── features/
│   ├── auth/
│   ├── business/
│   ├── chat/
│   ├── inventory/
│   ├── sales/
│   ├── memory/
│   └── settings/
└── main.dart
```

Cada feature se divide en:

```text
data/          llamadas HTTP y modelos JSON
domain/        entidades y reglas visibles para Flutter
presentation/ pantallas, controladores y widgets
```

El `AppStore` actual se separará gradualmente. No se reescribirá todo de una
vez.

## 11. Fases de implementación

### Fase 1 — Base real

- crear Supabase;
- migraciones de usuarios, negocios, productos e inventario;
- registro e inicio de sesión;
- repositorios Flutter;
- reemplazar productos simulados por datos reales;
- estados de carga, vacío, error y sin conexión.

Resultado: la app guarda y recupera información, todavía sin IA.

### Fase 2 — Backend y conversación real

- crear backend TypeScript;
- autenticación del backend contra Supabase;
- endpoint de chat con streaming;
- adaptador OpenAI;
- adaptador DeepSeek;
- selector Automático/OpenAI/DeepSeek;
- almacenamiento de conversaciones y mensajes;
- respuestas basadas en contexto real del negocio.

Resultado: Lumo conversa de verdad y recuerda la conversación.

### Fase 3 — Herramientas de lectura

- inventario;
- resumen del día;
- reportes de ventas;
- búsqueda de productos;
- actividad y memoria;
- mostrar en la UI qué datos está consultando.

Resultado: preguntas como “¿cómo vamos?” tienen respuestas verificables.

### Fase 4 — Operaciones con confirmación

- borradores persistentes;
- registrar ventas;
- recibir inventario;
- cambiar precios;
- cierre diario;
- confirmación, cancelación e idempotencia;
- auditoría y posibilidad de corrección.

Resultado: conversar realmente opera el negocio.

### Fase 5 — Voz y cámara reales

- grabación de audio;
- transcripción;
- respuestas de voz opcionales;
- captura de boletas/facturas;
- OCR y extracción estructurada;
- revisión visual antes de importar.

Resultado: micrófono y cámara dejan de ser simulaciones.

### Fase 6 — Calidad y producción

- métricas de latencia, errores, tokens y costo;
- límites mensuales por negocio;
- pruebas con conversaciones reales anonimizadas;
- evaluación comparativa OpenAI/DeepSeek;
- reintentos y circuit breaker;
- política de privacidad;
- builds firmados;
- despliegue del backend y publicación.

## 12. Estrategia de fallback

No se cambiará de proveedor ciegamente.

- Si falla antes de una herramienta o escritura, se puede intentar el alternativo.
- Si una escritura ya comenzó, no se repite automáticamente.
- Los borradores y confirmaciones usan idempotencia.
- Cada turno guarda proveedor y modelo reales.
- Una conversación puede continuar con otro proveedor usando historial
  normalizado, pero se avisará si cambia el comportamiento.
- Si ambos fallan, la app conserva el mensaje para reintentar y muestra un error
  claro.

## 13. Pruebas necesarias

### Backend

- permisos entre negocios;
- validación de herramientas;
- cálculos de venta;
- movimientos de inventario;
- confirmación duplicada;
- streaming interrumpido;
- fallback de proveedor;
- límites y timeouts.

### IA

Casos de evaluación:

- entiende cantidades y unidades;
- pregunta por información faltante;
- no inventa precios;
- no mezcla datos de negocios;
- selecciona la herramienta correcta;
- no escribe sin confirmación;
- explica resultados reales;
- maneja productos ambiguos;
- responde correctamente cuando no hay datos.

### Flutter

- autenticación;
- reconexión;
- mensajes parciales;
- estados de herramienta;
- confirmación de borradores;
- errores recuperables;
- Android físico y tamaños de pantalla.

## 14. Criterios para considerar la app “real”

- un usuario puede registrarse e iniciar sesión;
- los datos permanecen después de cerrar la app;
- dos negocios no pueden acceder a información mutua;
- Lumo responde usando ventas e inventario guardados;
- Lumo hace preguntas cuando faltan datos;
- las acciones importantes requieren confirmación;
- las ventas actualizan inventario mediante transacciones;
- OpenAI y DeepSeek funcionan mediante adaptadores intercambiables;
- ninguna clave de IA está dentro del APK;
- existen logs, límites, pruebas y manejo de errores;
- una conversación interrumpida puede recuperarse.

## 15. Primer corte recomendado

Para evitar construir demasiadas cosas juntas, la primera versión real incluirá:

1. login;
2. un negocio por usuario;
3. productos reales;
4. ventas e inventario persistentes;
5. chat de texto con streaming;
6. OpenAI y DeepSeek seleccionables;
7. herramientas de consulta;
8. borrador y confirmación de ventas;
9. historial de conversación;
10. métricas básicas de costo y errores.

Voz, cámara, OCR, colaboradores, notificaciones y memoria semántica quedan para
las fases siguientes.

## 16. Decisiones antes de implementar

Se asumirá lo siguiente salvo que el producto requiera otra cosa:

- Supabase para autenticación y PostgreSQL;
- backend TypeScript + Fastify;
- región cercana a los usuarios;
- español como idioma inicial;
- moneda configurable, inicialmente MXN;
- modo `Automático` como predeterminado;
- confirmación obligatoria para toda escritura;
- una sola empresa por usuario en la primera entrega, conservando un modelo de
  datos que permita varias.

También serán necesarias:

- una cuenta/proyecto de OpenAI API;
- una cuenta y saldo de DeepSeek API;
- un proyecto de Supabase;
- decisiones de retención de conversaciones y privacidad.

## Referencias técnicas consultadas

- OpenAI Responses y estado:
  https://developers.openai.com/api/docs/guides/migrate-to-responses
- OpenAI GPT-5.6:
  https://developers.openai.com/api/docs/guides/upgrading-to-gpt-5p6-sol
- DeepSeek Chat Completions:
  https://api-docs.deepseek.com/api/create-chat-completion
- DeepSeek conversaciones:
  https://api-docs.deepseek.com/guides/multi_round_chat
- DeepSeek herramientas:
  https://api-docs.deepseek.com/guides/tool_calls
