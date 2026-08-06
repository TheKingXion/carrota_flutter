# Carrota Flutter

Demo móvil interactiva de Carrota/Lumo. Los datos iniciales de ventas e
inventario son mock, pero los cambios se aplican realmente, quedan guardados
en SQLite y las consultas generales reciben respuestas reales de OpenAI o
DeepSeek.

## Lo que funciona

- Onboarding validado: responsable, negocio, tipo y moneda.
- Registro y confirmación de ventas escritas.
- Pagos en efectivo, tarjeta, transferencia o combinado.
- Inventario, llegadas manuales, cambio de precios y lista de compra.
- Métricas, actividad, memoria editable y cierre de caja.
- Selector Automático, OpenAI o DeepSeek.
- Persistencia SQLite local y versionada.
- Cámara y micrófono siguen visibles, marcados como funciones futuras.

Los datos sobreviven al cierre, reinicio y actualización de la app. Android los
elimina si se desinstala Carrota o se usa “Borrar datos” desde los ajustes del
sistema. Esta sigue siendo una demo local, no una base de datos remota.

## Persistencia local

La base se crea automáticamente como `carrota_local.db` dentro del directorio
privado de la aplicación. Guarda:

- Perfil y onboarding.
- Productos, precios y stock.
- Ventas y formas de pago.
- Conversación e identificación del proveedor de IA.
- Memoria y actividad.
- Lista de compra, ajustes y cierre de caja.

El esquema actual usa una instantánea JSON transaccional en SQLite con versión
de migración. La implementación está en `lib/local_database.dart`.

## 1. Configurar la IA

Las claves viven en el backend y nunca dentro del APK:

```powershell
cd "C:\Users\Xion\Desktop\folders\Juan Proyectos\carrota_flutter\backend"
Copy-Item .env.example .env
notepad .env
```

Completa en `.env`:

```text
OPENAI_API_KEY=tu_clave_de_openai
DEEPSEEK_API_KEY=tu_clave_de_deepseek
```

No compartas ese archivo ni lo subas a Git. Luego enciende el servidor:

```powershell
node server.mjs
```

Debe mostrar `Carrota AI backend: http://0.0.0.0:8787`. Puedes comprobarlo
desde otro PowerShell:

```powershell
Invoke-RestMethod http://127.0.0.1:8787/health
```

## 2. Ejecutar en el teléfono por Wi-Fi

El PC y el teléfono deben estar en la misma red. Averigua la IPv4 del PC:

```powershell
ipconfig
```

Usa la IPv4 del adaptador Wi-Fi, no la IP del teléfono. Por ejemplo, si el PC
es `192.168.100.20`:

```powershell
cd "C:\Users\Xion\Desktop\folders\Juan Proyectos\carrota_flutter"
flutter devices
flutter run -d "adb-ARGKUT3A10006196-Uz6WNY._adb-tls-connect._tcp" --dart-define=CARROTA_API_URL=http://192.168.100.20:8787
```

Si Android abre la app pero la prueba de IA dice que no hay conexión, permite
Node.js en el Firewall de Windows para redes privadas y confirma desde el
navegador del teléfono que abre `http://IP_DEL_PC:8787/health`.

## 3. Construir un APK de demo

Con el backend encendido y sustituyendo la IP:

```powershell
flutter build apk --debug --dart-define=CARROTA_API_URL=http://192.168.100.20:8787
```

El archivo queda en:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

La IP queda incorporada en ese APK. Para publicar una versión release se debe
desplegar el backend con HTTPS y usar su URL pública.

## 4. Instalarlo tú mismo cuando conectes el teléfono

Estos comandos no se ejecutan automáticamente:

```powershell
flutter devices
flutter install -d "ID_DEL_TELEFONO"
```

También puedes copiar `app-debug.apk` al teléfono y abrirlo manualmente. Android
puede pedir permiso para instalar aplicaciones desde esa fuente.

La sincronización futura con una base remota está diseñada en
`PLAN_API_SYNC.md`; todavía no modifica la persistencia local.

## Verificación

```powershell
flutter analyze
flutter test
node --check backend\server.mjs
```
