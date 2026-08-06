# Fase 4: integración del almacenamiento con una API

Esta fase no está implementada todavía. SQLite seguirá siendo la fuente local
para que Carrota funcione incluso sin conexión.

## Arquitectura propuesta

```text
Interfaz Flutter
      ↓
AppStore
      ↓
SQLite local ── cola de cambios ── API de sincronización
                                     ↓
                              Base de datos remota
```

El backend actual de IA puede continuar separado inicialmente. Las claves de
OpenAI y DeepSeek permanecen únicamente en el servidor.

## Cambios de datos necesarios

Antes de sincronizar se migrará la instantánea SQLite a tablas por entidad:

- `businesses`
- `products`
- `sales`
- `sale_lines`
- `memories`
- `timeline_events`
- `shopping_entries`
- `settings`
- `sync_outbox`
- `sync_metadata`

Cada registro tendrá:

- UUID generado en el dispositivo.
- `updated_at` en UTC.
- `server_revision`.
- `deleted_at` para eliminaciones sincronizables.
- Estado `pending`, `syncing`, `synced` o `failed`.

## Contrato inicial de API

```text
POST /v1/sync/push
GET  /v1/sync/pull?cursor=...
GET  /v1/sync/status
```

`push` recibirá operaciones con una clave de idempotencia. `pull` devolverá
cambios posteriores al último cursor confirmado.

## Conflictos

- Ventas y movimientos de inventario: eventos inmutables; nunca se reemplazan.
- Perfil, productos y ajustes: gana la revisión más reciente del servidor.
- Eliminaciones: se conservan como tombstones hasta que todos los dispositivos
  hayan sincronizado.
- Un conflicto no resoluble se guarda localmente y se muestra al usuario.

## Seguridad

- Autenticación de usuario y negocio.
- HTTPS obligatorio.
- Tokens cortos en almacenamiento seguro del sistema, no en SQLite.
- Autorización validada en cada endpoint.
- Las claves de proveedores de IA nunca viajan al teléfono.

## Orden de implementación

1. Normalizar el esquema SQLite mediante una migración sin pérdida.
2. Añadir UUID, revisiones y cola `sync_outbox`.
3. Crear autenticación y endpoints `push/pull`.
4. Sincronizar manualmente desde ajustes.
5. Añadir reintentos automáticos y modo offline.
6. Probar conflictos, duplicados, reinstalación y dos dispositivos.
