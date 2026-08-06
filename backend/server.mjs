import { createServer } from "node:http";
import { readFileSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

loadLocalEnv();

const config = {
  host: process.env.HOST || "0.0.0.0",
  port: Number(process.env.PORT || 8787),
  openaiKey: process.env.OPENAI_API_KEY || "",
  openaiModel: process.env.OPENAI_MODEL || "gpt-5.6-terra",
  deepseekKey: process.env.DEEPSEEK_API_KEY || "",
  deepseekModel: process.env.DEEPSEEK_MODEL || "deepseek-v4-flash",
  defaultProvider: process.env.AI_DEFAULT_PROVIDER || "openai",
};

const server = createServer(async (request, response) => {
  setCors(response);

  if (request.method === "OPTIONS") {
    response.writeHead(204);
    response.end();
    return;
  }

  if (request.method === "GET" && request.url === "/health") {
    sendJson(response, 200, {
      ok: true,
      providers: {
        openai: Boolean(config.openaiKey),
        deepseek: Boolean(config.deepseekKey),
      },
      models: {
        openai: config.openaiModel,
        deepseek: config.deepseekModel,
      },
    });
    return;
  }

  if (request.method === "POST" && request.url === "/v1/chat") {
    try {
      const body = await readJson(request);
      const input = validateChatInput(body);
      const result = await routeChat(input);
      sendJson(response, 200, result);
    } catch (error) {
      const status = error instanceof HttpError ? error.status : 500;
      sendJson(response, status, {
        error: error instanceof Error ? error.message : "Error desconocido",
      });
    }
    return;
  }

  sendJson(response, 404, { error: "Ruta no encontrada" });
});

server.listen(config.port, config.host, () => {
  console.log(`Carrota AI backend: http://${config.host}:${config.port}`);
  console.log(
    `OpenAI ${config.openaiKey ? "configurado" : "sin clave"} · ` +
      `DeepSeek ${config.deepseekKey ? "configurado" : "sin clave"}`,
  );
});

async function routeChat(input) {
  if (input.provider === "openai") return callOpenAI(input);
  if (input.provider === "deepseek") return callDeepSeek(input);

  const order =
    config.defaultProvider === "deepseek"
      ? [callDeepSeek, callOpenAI]
      : [callOpenAI, callDeepSeek];
  const errors = [];

  for (const callProvider of order) {
    try {
      return await callProvider(input);
    } catch (error) {
      errors.push(error instanceof Error ? error.message : String(error));
    }
  }

  throw new HttpError(
    503,
    `Ningún proveedor de IA respondió. ${errors.join(" | ")}`,
  );
}

async function callOpenAI(input) {
  if (!config.openaiKey) {
    throw new HttpError(503, "OPENAI_API_KEY no está configurada");
  }

  const apiResponse = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${config.openaiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: config.openaiModel,
      instructions: buildSystemPrompt(input.business),
      input: [
        ...normalizeHistory(input.history),
        { role: "user", content: input.message },
      ],
      reasoning: { effort: "low" },
      text: { verbosity: "medium" },
      store: false,
      max_output_tokens: 700,
    }),
    signal: AbortSignal.timeout(45_000),
  });

  const payload = await readApiResponse(apiResponse, "OpenAI");
  const text = extractOpenAIText(payload);
  if (!text) throw new Error("OpenAI devolvió una respuesta vacía");

  return {
    text,
    provider: "openai",
    model: payload.model || config.openaiModel,
    usage: payload.usage || null,
  };
}

async function callDeepSeek(input) {
  if (!config.deepseekKey) {
    throw new HttpError(503, "DEEPSEEK_API_KEY no está configurada");
  }

  const apiResponse = await fetch(
    "https://api.deepseek.com/chat/completions",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${config.deepseekKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: config.deepseekModel,
        messages: [
          { role: "system", content: buildSystemPrompt(input.business) },
          ...normalizeHistory(input.history),
          { role: "user", content: input.message },
        ],
        thinking: { type: "disabled" },
        max_tokens: 700,
      }),
      signal: AbortSignal.timeout(45_000),
    },
  );

  const payload = await readApiResponse(apiResponse, "DeepSeek");
  const text = payload.choices?.[0]?.message?.content?.trim();
  if (!text) throw new Error("DeepSeek devolvió una respuesta vacía");

  return {
    text,
    provider: "deepseek",
    model: payload.model || config.deepseekModel,
    usage: payload.usage || null,
  };
}

function buildSystemPrompt(business) {
  return [
    "Rol: eres Lumo, asistente de operación para un pequeño negocio.",
    "Idioma: responde en español claro, cálido y directo.",
    "Objetivo: responder usando exclusivamente los datos del negocio incluidos abajo.",
    "Reglas:",
    "- No inventes ventas, stock, precios, proveedores ni fechas.",
    "- Cuando falte un dato necesario, formula una sola pregunta concreta.",
    "- Distingue entre hechos de los datos mock y recomendaciones.",
    "- No afirmes haber registrado o modificado algo; las escrituras las ejecuta la app.",
    "- Para ventas, inventario, precios o cierre, explica el siguiente paso que debe confirmar el usuario.",
    "- Mantén la respuesta entre 1 y 5 párrafos breves.",
    "",
    "DATOS ACTUALES DEL NEGOCIO (JSON):",
    JSON.stringify(business ?? {}, null, 2),
  ].join("\n");
}

function normalizeHistory(history) {
  if (!Array.isArray(history)) return [];
  return history
    .filter(
      (item) =>
        item &&
        (item.role === "user" || item.role === "assistant") &&
        typeof item.content === "string",
    )
    .slice(-12)
    .map((item) => ({ role: item.role, content: item.content.slice(0, 3000) }));
}

function validateChatInput(body) {
  if (!body || typeof body !== "object") {
    throw new HttpError(400, "El cuerpo debe ser JSON");
  }
  const message = typeof body.message === "string" ? body.message.trim() : "";
  if (!message) throw new HttpError(400, "message es obligatorio");
  if (message.length > 4000) {
    throw new HttpError(400, "message supera el máximo de 4000 caracteres");
  }
  const provider = ["auto", "openai", "deepseek"].includes(body.provider)
    ? body.provider
    : "auto";
  return {
    message,
    provider,
    history: Array.isArray(body.history) ? body.history : [],
    business:
      body.business && typeof body.business === "object" ? body.business : {},
  };
}

function extractOpenAIText(payload) {
  const chunks = [];
  for (const item of payload.output || []) {
    if (item.type !== "message") continue;
    for (const content of item.content || []) {
      if (content.type === "output_text" && content.text) {
        chunks.push(content.text);
      }
    }
  }
  return chunks.join("\n").trim();
}

async function readApiResponse(response, provider) {
  const text = await response.text();
  let payload;
  try {
    payload = text ? JSON.parse(text) : {};
  } catch {
    throw new Error(`${provider} devolvió una respuesta no válida`);
  }
  if (!response.ok) {
    const message =
      payload?.error?.message || payload?.message || `${response.status}`;
    throw new Error(`${provider}: ${message}`);
  }
  return payload;
}

async function readJson(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 1_000_000) {
      throw new HttpError(413, "Solicitud demasiado grande");
    }
    chunks.push(chunk);
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}");
  } catch {
    throw new HttpError(400, "JSON inválido");
  }
}

function sendJson(response, status, body) {
  response.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(body));
}

function setCors(response) {
  response.setHeader("Access-Control-Allow-Origin", "*");
  response.setHeader("Access-Control-Allow-Headers", "Content-Type");
  response.setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS");
}

function loadLocalEnv() {
  const backendDirectory = dirname(fileURLToPath(import.meta.url));
  const path = resolve(backendDirectory, ".env");
  if (!existsSync(path)) return;
  for (const rawLine of readFileSync(path, "utf8").split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const separator = line.indexOf("=");
    if (separator < 1) continue;
    const key = line.slice(0, separator).trim();
    const value = line.slice(separator + 1).trim().replace(/^["']|["']$/g, "");
    if (!(key in process.env)) process.env[key] = value;
  }
}

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}
