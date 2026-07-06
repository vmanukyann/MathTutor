import "@supabase/functions-js/edge-runtime.d.ts";

type VoiceSettings = {
  stability?: number;
  similarity_boost?: number;
  style?: number;
  use_speaker_boost?: boolean;
};

type TTSRequest = {
  text?: unknown;
  voice_id?: unknown;
  model_id?: unknown;
  voice_settings?: unknown;
};

const JSON_HEADERS = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-mathtutor-request-id",
};
const DEFAULT_MODEL_ID = "eleven_flash_v2_5";
const MAX_TEXT_LENGTH = 10_000;

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: JSON_HEADERS,
  });
}

function latencyLogger(requestId: string) {
  const startedAt = performance.now();
  return {
    requestId,
    log(event: string, fields: Record<string, unknown> = {}) {
      console.log("mathtutor_elevenlabs_latency", {
        request_id: requestId,
        event,
        elapsed_ms: Math.round(performance.now() - startedAt),
        ...fields,
      });
    },
  };
}

function optionalIdentifier(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function parseVoiceSettings(value: unknown): VoiceSettings | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "object" || Array.isArray(value)) {
    throw new Error("voice_settings must be an object");
  }

  const input = value as Record<string, unknown>;
  const settings: VoiceSettings = {};
  for (
    const key of ["stability", "similarity_boost", "style"] as const
  ) {
    const setting = input[key];
    if (setting === undefined) continue;
    if (typeof setting !== "number" || setting < 0 || setting > 1) {
      throw new Error(`${key} must be a number between 0 and 1`);
    }
    settings[key] = setting;
  }

  const speakerBoost = input.use_speaker_boost;
  if (speakerBoost !== undefined) {
    if (typeof speakerBoost !== "boolean") {
      throw new Error("use_speaker_boost must be a boolean");
    }
    settings.use_speaker_boost = speakerBoost;
  }
  return settings;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: JSON_HEADERS });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const trace = latencyLogger(
    request.headers.get("x-mathtutor-request-id") ?? crypto.randomUUID(),
  );
  trace.log("supabase_tts_function_request_received");

  try {
    const apiKey = Deno.env.get("ELEVENLABS_API_KEY");
    if (!apiKey) {
      trace.log("configuration_error", {
        missing: "ELEVENLABS_API_KEY",
      });
      return jsonResponse({
        error: "Missing ELEVENLABS_API_KEY secret",
      }, 500);
    }

    const body = await request.json() as TTSRequest;
    if (typeof body.text !== "string" || body.text.trim().length === 0) {
      return jsonResponse({ error: "text is required" }, 400);
    }
    const text = body.text.trim();
    if (text.length > MAX_TEXT_LENGTH) {
      return jsonResponse({
        error: `text must be at most ${MAX_TEXT_LENGTH} characters`,
      }, 400);
    }

    const voiceId = optionalIdentifier(body.voice_id) ??
      optionalIdentifier(Deno.env.get("ELEVENLABS_VOICE_ID"));
    if (!voiceId) {
      trace.log("configuration_error", {
        missing: "ELEVENLABS_VOICE_ID",
      });
      return jsonResponse({
        error: "Missing ELEVENLABS_VOICE_ID secret or voice_id request field",
      }, 500);
    }
    const modelId = optionalIdentifier(body.model_id) ??
      optionalIdentifier(Deno.env.get("ELEVENLABS_MODEL_ID")) ??
      DEFAULT_MODEL_ID;
    const voiceSettings = parseVoiceSettings(body.voice_settings);

    const elevenLabsURL = new URL(
      `https://api.elevenlabs.io/v1/text-to-speech/${
        encodeURIComponent(voiceId)
      }`,
    );
    elevenLabsURL.searchParams.set("output_format", "mp3_44100_128");

    trace.log("elevenlabs_request_started", {
      model_id: modelId,
      text_characters: text.length,
    });
    const elevenLabsResponse = await fetch(elevenLabsURL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "xi-api-key": apiKey,
      },
      body: JSON.stringify({
        text,
        model_id: modelId,
        ...(voiceSettings ? { voice_settings: voiceSettings } : {}),
      }),
    });
    trace.log("elevenlabs_response_headers_received", {
      status: elevenLabsResponse.status,
    });

    if (!elevenLabsResponse.ok) {
      trace.log("elevenlabs_request_failed", {
        status: elevenLabsResponse.status,
      });
      return jsonResponse({
        error: "ElevenLabs could not synthesize this request",
        upstream_status: elevenLabsResponse.status,
      }, 502);
    }

    const audio = await elevenLabsResponse.arrayBuffer();
    trace.log("elevenlabs_response_fully_read", {
      bytes: audio.byteLength,
    });
    trace.log("supabase_tts_response_returned", {
      bytes: audio.byteLength,
    });
    return new Response(audio, {
      status: 200,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Cache-Control": "no-store",
        "Content-Length": String(audio.byteLength),
        "Content-Type": "audio/mpeg",
        "X-TTS-Model-ID": modelId,
        "X-Request-ID": trace.requestId,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Invalid request";
    trace.log("request_failed", { error: message });
    return jsonResponse({ error: message }, 400);
  }
});
