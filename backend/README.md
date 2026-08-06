# Backend de IA para Carrota

Este servidor mantiene las claves fuera del APK y normaliza OpenAI y DeepSeek.

## Configuración

1. Copia `.env.example` como `.env`.
2. Completa `OPENAI_API_KEY` y `DEEPSEEK_API_KEY`.
3. Ejecuta:

```powershell
cd backend
node server.mjs
```

El servidor escucha en `0.0.0.0:8787`, por lo que un teléfono en la misma red
puede conectarse usando la IP local del PC.

## Rutas

- `GET /health`
- `POST /v1/chat`

Las claves nunca deben copiarse a Dart, `pubspec.yaml` ni Android.
