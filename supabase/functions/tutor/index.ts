import "@supabase/functions-js/edge-runtime.d.ts";
import { OPTIMIZED_TUTOR_INSTRUCTIONS } from "./optimized_instructions.ts";

type TutorObservation = {
  mistake_detected: boolean;
  confidence: "low" | "medium" | "high";
  misconception_type:
    | "sign_error"
    | "distribution"
    | "equation_balance"
    | "invalid_cancellation"
    | "slope_intercept"
    | "factoring"
    | "square_root"
    | "sat_strategy"
    | "unclear_work";
  hint_level: number;
  hint: string;
  teacher_note: string;
  work_summary: string;
  teach_steps?: string[];
  final_answer_blocked: true;
};

const JSON_HEADERS = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const OBSERVE_TIMEOUT_MS = 35_000;
const AUDIO_TIMEOUT_MS = 45_000;
const FORBIDDEN_MATH_WORDS = [
  "something",
  "unknown",
  "answer",
  "value",
  "placeholder",
  "undefined",
  "variable",
  "number",
  "term",
  "solution",
  "result",
];
const ALLOWED_LATEX_COMMANDS = new Set([
  "cdot",
  "div",
  "frac",
  "geq",
  "leq",
  "left",
  "neq",
  "pm",
  "right",
  "sqrt",
  "times",
]);

const OBSERVATION_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    mistake_detected: { type: "boolean" },
    confidence: { type: "string", enum: ["low", "medium", "high"] },
    misconception_type: {
      type: "string",
      enum: [
        "sign_error",
        "distribution",
        "equation_balance",
        "invalid_cancellation",
        "slope_intercept",
        "factoring",
        "square_root",
        "sat_strategy",
        "unclear_work",
      ],
    },
    hint_level: { type: "integer", enum: [1, 2, 3] },
    hint: { type: "string" },
    teacher_note: { type: "string" },
    work_summary: { type: "string" },
    teach_steps: {
      type: "array",
      items: { type: "string" },
    },
    final_answer_blocked: { type: "boolean", enum: [true] },
  },
  required: [
    "mistake_detected",
    "confidence",
    "misconception_type",
    "hint_level",
    "hint",
    "teacher_note",
    "work_summary",
    "teach_steps",
    "final_answer_blocked",
  ],
} as const;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

function stripCodeFences(input: string): string {
  return input
    .replace(/^\s*```(?:json)?\s*/i, "")
    .replace(/\s*```\s*$/i, "")
    .trim();
}

function parseResponsesText(responseJson: any): string {
  if (typeof responseJson?.output_text === "string") return responseJson.output_text;

  const output = responseJson?.output;
  if (!Array.isArray(output)) return "";

  return output
    .flatMap((item) => Array.isArray(item?.content) ? item.content : [])
    .map((part) => typeof part?.text === "string" ? part.text : "")
    .filter((text) => text.trim().length > 0)
    .join("\n");
}

async function generateSpeech(
  openaiKey: string,
  body: Record<string, unknown>,
): Promise<Response> {
  const input = typeof body.text === "string" ? body.text.trim().slice(0, 12_000) : "";
  if (!input) return jsonResponse({ error: "Speech text is required." }, 400);

  const response = await fetchWithTimeout(
    "https://api.openai.com/v1/audio/speech",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${openaiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: Deno.env.get("OPENAI_TTS_MODEL") ?? "gpt-4o-mini-tts",
        voice: Deno.env.get("OPENAI_TTS_VOICE") ?? "marin",
        input,
        instructions:
          "Speak like a patient math tutor. Use a calm pace and pause briefly between steps.",
        response_format: "mp3",
      }),
    },
    AUDIO_TIMEOUT_MS,
  );
  if (!response.ok) {
    return jsonResponse({
      error: "Speech generation failed.",
      details: (await response.text()).slice(0, 500),
    }, response.status);
  }
  return new Response(await response.arrayBuffer(), {
    status: 200,
    headers: {
      "Content-Type": "audio/mpeg",
      "Cache-Control": "no-store",
      "X-AI-Generated-Voice": "true",
      "Access-Control-Allow-Origin": "*",
    },
  });
}

function hasBalancedBraces(input: string): boolean {
  let depth = 0;
  for (const character of input) {
    if (character === "{") depth += 1;
    if (character === "}") depth -= 1;
    if (depth < 0) return false;
  }
  return depth === 0;
}

function evaluateNumericExpression(source: string): number | undefined {
  const normalized = source
    .replace(/\\cdot|\\times/g, "*")
    .replace(/\\div/g, "/")
    .replace(/[{}]/g, (token) => token === "{" ? "(" : ")")
    .replace(/\s+/g, "");

  if (!/^[0-9+\-*/().]+$/.test(normalized)) return undefined;

  const tokens = normalized.match(/\d+(?:\.\d+)?|[()+\-*/]/g);
  if (!tokens || tokens.join("") !== normalized) return undefined;
  let cursor = 0;

  function parsePrimary(): number | undefined {
    const token = tokens[cursor];
    if (token === "+" || token === "-") {
      cursor += 1;
      const value = parsePrimary();
      return value === undefined ? undefined : token === "-" ? -value : value;
    }
    if (token === "(") {
      cursor += 1;
      const value = parseExpression();
      if (tokens[cursor] !== ")") return undefined;
      cursor += 1;
      return value;
    }
    if (token && /^\d/.test(token)) {
      cursor += 1;
      return Number(token);
    }
    return undefined;
  }

  function parseTerm(): number | undefined {
    let value = parsePrimary();
    if (value === undefined) return undefined;
    while (tokens[cursor] === "*" || tokens[cursor] === "/") {
      const operation = tokens[cursor++];
      const right = parsePrimary();
      if (right === undefined || (operation === "/" && right === 0)) return undefined;
      value = operation === "*" ? value * right : value / right;
    }
    return value;
  }

  function parseExpression(): number | undefined {
    let value = parseTerm();
    if (value === undefined) return undefined;
    while (tokens[cursor] === "+" || tokens[cursor] === "-") {
      const operation = tokens[cursor++];
      const right = parseTerm();
      if (right === undefined) return undefined;
      value = operation === "+" ? value + right : value - right;
    }
    return value;
  }

  const result = parseExpression();
  return cursor === tokens.length && Number.isFinite(result) ? result : undefined;
}

function hasFalseNumericEquality(step: string): boolean {
  const sides = step.split("=");
  if (sides.length !== 2) return false;
  const left = evaluateNumericExpression(sides[0]);
  const right = evaluateNumericExpression(sides[1]);
  if (left === undefined || right === undefined) return false;
  return Math.abs(left - right) > 1e-9;
}

function isValidMathOnlyStep(step: string): boolean {
  // Keep accidental prose off the external math board.
  const normalized = step.trim();
  if (!normalized || normalized.length > 160 || !hasBalancedBraces(normalized)) return false;
  if (normalized.includes("$") || normalized.includes("...") || normalized.includes(",")) return false;
  if (/^\s*[A-Za-z]\s*=\s*(?![A-Za-z](?:\s|$))/.test(normalized)) return false;

  const lowercased = normalized.toLowerCase();
  if (FORBIDDEN_MATH_WORDS.some((word) => new RegExp(`\\b${word}\\b`, "i").test(lowercased))) {
    return false;
  }
  if (/\\text|\\mathrm|\\operatorname/i.test(normalized)) return false;
  if (/(^|[^\\])\b(?:frac|sqrt|cdot|times|div|neq|leq|geq)\b/i.test(normalized)) return false;

  const commands = [...normalized.matchAll(/\\([A-Za-z]+)/g)].map((match) => match[1]);
  if (commands.some((command) => !ALLOWED_LATEX_COMMANDS.has(command))) return false;

  const withoutCommands = normalized.replace(/\\[A-Za-z]+/g, "");
  if (/[A-Za-z]{2,}/.test(withoutCommands)) return false;

  return !hasFalseNumericEquality(normalized);
}

function normalizeObservation(value: unknown): TutorObservation {
  if (!value || typeof value !== "object") {
    throw new Error("Observation response is not a JSON object.");
  }

  const row = value as Record<string, unknown>;
  const mistakeRaw = typeof row.misconception_type === "string"
    ? row.misconception_type.toLowerCase()
    : "unclear_work";
  const allowedMistakes = [
    "sign_error",
    "distribution",
    "equation_balance",
    "invalid_cancellation",
    "slope_intercept",
    "factoring",
    "square_root",
    "sat_strategy",
    "unclear_work",
  ];
  const misconceptionType = allowedMistakes.includes(mistakeRaw)
    ? mistakeRaw as TutorObservation["misconception_type"]
    : "unclear_work";

  const teachSteps = Array.isArray(row.teach_steps)
    ? row.teach_steps
      .filter((step): step is string => typeof step === "string" && step.trim().length > 0)
      .map((step) => step.trim())
      .filter(isValidMathOnlyStep)
      .slice(0, 3)
    : undefined;
  const mistakeDetected = typeof row.mistake_detected === "boolean"
    ? row.mistake_detected
    : true;
  const confidence: TutorObservation["confidence"] = misconceptionType === "unclear_work"
    ? "low"
    : mistakeDetected
    ? "high"
    : "medium";

  return {
    mistake_detected: mistakeDetected,
    confidence,
    misconception_type: misconceptionType,
    hint_level: Math.min(3, Math.max(1, Number(row.hint_level ?? 1))),
    hint: typeof row.hint === "string" && row.hint.trim().length > 0
      ? row.hint.trim()
      : mistakeDetected
      ? "Compare the first incorrect line with the line immediately before it."
      : "The newest visible step looks consistent. Continue from there.",
    teacher_note: typeof row.teacher_note === "string" ? row.teacher_note.trim() : "",
    work_summary: typeof row.work_summary === "string" ? row.work_summary.trim() : "",
    teach_steps: teachSteps && teachSteps.length > 0 ? teachSteps : undefined,
    final_answer_blocked: true,
  };
}

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  timeoutMs: number,
): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timeoutId);
  }
}

function observeWorkPrompt(student: any, session: any): string {
  const name = typeof student?.name === "string" && student.name.trim().length > 0
    ? student.name.trim()
    : "Student";
  const level = typeof student?.level === "string" ? student.level : "Algebra II";
  const misconceptions = student?.misconceptions && typeof student.misconceptions === "object"
    ? JSON.stringify(student.misconceptions)
    : "{}";
  const checkNumber = Number(session?.check_number ?? 1);
  const noAnswerMode = session?.no_answer_mode !== false;
  const studentQuestion = typeof session?.student_question === "string"
    ? session.student_question.trim().slice(0, 300)
    : "";

  return `
You are MathTutor, a real-time guided math teacher watching ${name}'s handwritten paper.

Student context:
- Name: ${name}
- Current level: ${level}
- Past misconception counts: ${misconceptions}
- Session check number: ${checkNumber}
- No-answer mode: ${noAnswerMode ? "enabled" : "disabled"}
${studentQuestion ? `- Student's spoken question: ${JSON.stringify(studentQuestion)}` : ""}

Analyze the visible work as one problem. Find the first incorrect transition, but do not over-interrupt if confidence is low. Use the student's past mistakes only when they match evidence in this image.
${studentQuestion ? "Answer the student's spoken question about the visible work with one concise guided hint. Do not ignore the question." : ""}

${OPTIMIZED_TUTOR_INSTRUCTIONS}

Hard rules:
- Never reveal the final answer.
- Never solve the full problem.
- Give one short, specific teacher-like hint or clarifying question about the first incorrect transition.
- Name the exact visible numbers, symbols, or operation involved; do not give a generic topic reminder.
- Provide at most 3 short math-only teach_steps that can be shown on a classroom display.
- Start teach_steps at the mistaken line (or the line immediately before it), not at the beginning of the problem.
- Copy the variables and numbers visible in the student's work. Never substitute a canned example or generic variables.
- teach_steps must directly correct the visible mistake.
- teach_steps should not dump a full final answer unless the visible step already contains it.
- Write every mathematical expression in valid LaTeX.
- In hint prose, wrap each math expression in \\( and \\), for example: "Compare \\(2(x+3)\\) with \\(2x+3\\)."
- Each teach_steps item must contain only raw display LaTeX without dollar signs or prose.
- Prefer LaTeX commands such as \\frac{a}{b}, x^{2}, \\cdot, \\neq, and \\sqrt{x}; never use Unicode superscripts or slash fractions.
- Because the response is JSON, escape every LaTeX backslash as a JSON double backslash. For example, return "\\\\frac{1}{2}", never "\\frac{1}{2}".
- Every teach_steps line must be mathematically valid and arithmetically checked.
- Never use any English word in teach_steps. Words such as "something", "unknown", "answer", "value", "variable", "term", "solution", and "result" are forbidden.
- Never put prose, labels, units, or \\text{...} in teach_steps; use mathematical symbols and single-letter variables only.
- Use one canonical derivation. Given the same visible work, return the same misconception, hint level, and teach_steps every time.
- Use consistent operator spacing and canonical forms: \\frac{a}{b}, \\sqrt{x}, x^{2}, a \\cdot b, and \\pm.
- Preserve branches correctly. For square roots, use \\pm and never combine two solutions with a comma.
- Use "square_root" only when a square, radical, root operation, or missing \\pm is actually visible.
- Never mention a square root, sign error, distribution, or any other topic unless that feature is visible in this image.
- In no-answer mode, stop at the most useful intermediate step before the final solved value.
- If the work is correct or too unclear, say so without inventing a mistake.

Return only the requested structured object. When the image is unclear, use misconception_type "unclear_work" and an empty teach_steps array.
{
  "mistake_detected": boolean,
  "confidence": "low" | "medium" | "high",
  "misconception_type": "sign_error" | "distribution" | "equation_balance" | "invalid_cancellation" | "slope_intercept" | "factoring" | "square_root" | "sat_strategy" | "unclear_work",
  "hint_level": 1 | 2 | 3,
  "hint": "one short guided hint without the final answer",
  "teacher_note": "brief private note for admin/research review",
  "work_summary": "brief summary of what the student appears to be doing",
  "teach_steps": ["short math-only display line", "next short math-only display line"],
  "final_answer_blocked": true
}
`.trim();
}

async function supabaseRest(
  table: string,
  body: unknown,
  options: { prefer?: string } = {},
): Promise<Response> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY secret.");
  }

  return await fetch(`${supabaseUrl}/rest/v1/${table}`, {
    method: "POST",
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
      Prefer: options.prefer ?? "return=minimal",
    },
    body: JSON.stringify(body),
  });
}

async function logSession(body: Record<string, unknown>): Promise<Response> {
  const student = body.student as Record<string, unknown> | undefined;
  const session = body.session as Record<string, unknown> | undefined;
  const events = Array.isArray(body.events) ? body.events as Record<string, unknown>[] : [];

  if (!student || !session) {
    return jsonResponse({ error: 'Missing required "student" or "session" object.' }, 400);
  }

  const studentId = String(student.id ?? "");
  const sessionId = String(session.id ?? "");
  if (!studentId || !sessionId) {
    return jsonResponse({ error: "Student and session IDs are required." }, 400);
  }

  const studentRes = await supabaseRest("teacher_students?on_conflict=id", {
    id: studentId,
    name: String(student.name ?? "Student"),
    math_level: String(student.math_level ?? student.level ?? "Algebra II"),
    consent_accepted: Boolean(student.consent_accepted ?? true),
    misconception_counts: student.misconception_counts ?? student.misconceptions ?? {},
    updated_at: new Date().toISOString(),
  }, { prefer: "resolution=merge-duplicates,return=minimal" });

  if (!studentRes.ok) {
    return jsonResponse({
      error: "Failed to upsert teacher student.",
      details: await studentRes.text(),
    }, 500);
  }

  const sessionRes = await supabaseRest("teacher_sessions?on_conflict=id", {
    id: sessionId,
    student_id: studentId,
    started_at: session.started_at ?? new Date().toISOString(),
    ended_at: session.ended_at ?? null,
    reflection: session.reflection ?? "",
  }, { prefer: "resolution=merge-duplicates,return=minimal" });

  if (!sessionRes.ok) {
    return jsonResponse({
      error: "Failed to upsert teacher session.",
      details: await sessionRes.text(),
    }, 500);
  }

  if (events.length > 0) {
    const eventRows = events.map((event) => ({
      id: event.id,
      session_id: sessionId,
      observed_at: event.observed_at ?? new Date().toISOString(),
      mistake_detected: Boolean(event.mistake_detected),
      confidence: event.confidence ?? "medium",
      misconception_type: event.misconception_type ?? "unclear_work",
      hint_level: event.hint_level ?? 1,
      hint: event.hint ?? "",
      teacher_note: event.teacher_note ?? "",
      work_summary: event.work_summary ?? "",
      student_self_corrected: Boolean(event.student_self_corrected),
      final_answer_blocked: event.final_answer_blocked !== false,
    }));

    const eventsRes = await supabaseRest("teacher_events?on_conflict=id", eventRows, {
      prefer: "resolution=merge-duplicates,return=minimal",
    });

    if (!eventsRes.ok) {
      return jsonResponse({
        error: "Failed to upsert teacher events.",
        details: await eventsRes.text(),
      }, 500);
    }
  }

  return jsonResponse({ ok: true });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: JSON_HEADERS });
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed. Use POST." }, 405);
  }

  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  if (!openaiKey) return jsonResponse({ error: "Missing OPENAI_API_KEY secret." }, 500);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  if (body.mode === "log_session") {
    return await logSession(body);
  }

  if (body.mode === "speech") {
    return await generateSpeech(openaiKey, body);
  }

  if (body.mode !== "observe_work") {
    return jsonResponse({
      error: 'Unsupported mode. Use "observe_work", "log_session", or "speech".',
    }, 400);
  }

  const imageBase64 = typeof body.image_base64 === "string" ? body.image_base64.trim() : "";
  if (!imageBase64) {
    return jsonResponse({ error: 'Missing required field "image_base64".' }, 400);
  }

  try {
    const student = body.student && typeof body.student === "object" ? body.student : {};
    const session = body.session && typeof body.session === "object" ? body.session : {};

    const observeRes = await fetchWithTimeout(
      "https://api.openai.com/v1/responses",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${openaiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: Deno.env.get("OPENAI_OBSERVE_MODEL") ?? "gpt-4o-mini",
          input: [
            {
              role: "user",
              content: [
                { type: "input_text", text: observeWorkPrompt(student, session) },
                { type: "input_image", image_url: `data:image/jpeg;base64,${imageBase64}` },
              ],
            },
          ],
          text: {
            format: {
              type: "json_schema",
              name: "tutor_observation",
              strict: true,
              schema: OBSERVATION_SCHEMA,
            },
          },
          temperature: 0,
          max_output_tokens: 700,
        }),
      },
      OBSERVE_TIMEOUT_MS,
    );

    const observeText = await observeRes.text();
    if (!observeRes.ok) {
      console.log("tutor:observe:error", {
        status: observeRes.status,
        body: observeText.slice(0, 500),
      });
      return jsonResponse({
        error: "Observation request failed.",
        status: observeRes.status,
        details: observeText,
      }, 500);
    }

    const responseJson = JSON.parse(observeText);
    const rawText = parseResponsesText(responseJson);
    if (!rawText.trim()) {
      return jsonResponse({ error: "Observation response content was empty." }, 500);
    }

    const observation = normalizeObservation(JSON.parse(stripCodeFences(rawText)));
    return jsonResponse(observation);
  } catch (err) {
    if (err instanceof DOMException && err.name === "AbortError") {
      return jsonResponse({ error: "OpenAI observation request timed out." }, 504);
    }
    console.log("tutor:crash", String(err));
    return jsonResponse({ error: "Tutor function failed.", details: String(err) }, 500);
  }
});
