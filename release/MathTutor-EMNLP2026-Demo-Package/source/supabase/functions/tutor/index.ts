import "@supabase/functions-js/edge-runtime.d.ts";
import { OPTIMIZED_TUTOR_INSTRUCTIONS } from "./optimized_instructions.ts";
import { buildCompactHint } from "./hint_utils.ts";

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
  spoken_hint: string;
  hint_explanation: string;
  hint_action: string;
  display_hint: string;
  try_step: string;
  teacher_note: string;
  work_summary: string;
  teach_steps?: string[];
  final_answer_blocked: true;
  vision_detail?: "low" | "auto" | "high";
  observe_max_output_tokens?: number;
  prompt_characters?: number;
  response_bytes?: number;
};

const JSON_HEADERS = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-mathtutor-request-id",
};

const OBSERVE_TIMEOUT_MS = 35_000;
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
    display_hint: { type: "string" },
    try_step: { type: "string" },
    spoken_hint: { type: "string" },
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
    "display_hint",
    "try_step",
    "spoken_hint",
    "teacher_note",
    "work_summary",
    "teach_steps",
    "final_answer_blocked",
  ],
} as const;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

function latencyLogger(scope: string, requestId: string) {
  const startedAt = performance.now();
  return (event: string, fields: Record<string, unknown> = {}) => {
    console.log("mathtutor_elevenlabs_latency", {
      scope,
      request_id: requestId,
      event,
      elapsed_ms: Math.round(performance.now() - startedAt),
      ...fields,
    });
  };
}

function configuredVisionDetail(): "low" | "auto" | "high" {
  const configured = Deno.env.get("OPENAI_VISION_DETAIL")?.trim().toLowerCase();
  return configured === "low" || configured === "auto" || configured === "high"
    ? configured
    : "high";
}

function stripCodeFences(input: string): string {
  return input
    .replace(/^\s*```(?:json)?\s*/i, "")
    .replace(/\s*```\s*$/i, "")
    .trim();
}

function parseResponsesText(responseJson: any): string {
  if (typeof responseJson?.output_text === "string") {
    return responseJson.output_text;
  }

  const output = responseJson?.output;
  if (!Array.isArray(output)) return "";

  return output
    .flatMap((item) => Array.isArray(item?.content) ? item.content : [])
    .map((part) => typeof part?.text === "string" ? part.text : "")
    .filter((text) => text.trim().length > 0)
    .join("\n");
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

  const matchedTokens = normalized.match(/\d+(?:\.\d+)?|[()+\-*/]/g);
  if (!matchedTokens || matchedTokens.join("") !== normalized) return undefined;
  const tokens: string[] = matchedTokens;
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
      if (right === undefined || (operation === "/" && right === 0)) {
        return undefined;
      }
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
  return cursor === tokens.length && Number.isFinite(result)
    ? result
    : undefined;
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
  if (
    !normalized || normalized.length > 160 || !hasBalancedBraces(normalized)
  ) return false;
  if (/\{\s*\}/.test(normalized) || /\^\s*\{\s*\}/.test(normalized)) {
    return false;
  }
  if (
    normalized.includes("$") || normalized.includes("...") ||
    normalized.includes(",")
  ) return false;
  if (/^\s*[A-Za-z]\s*=\s*(?![A-Za-z](?:\s|$))/.test(normalized)) return false;

  const lowercased = normalized.toLowerCase();
  if (
    FORBIDDEN_MATH_WORDS.some((word) =>
      new RegExp(`\\b${word}\\b`, "i").test(lowercased)
    )
  ) {
    return false;
  }
  if (/\\text|\\mathrm|\\operatorname/i.test(normalized)) return false;
  if (
    /(^|[^\\])\b(?:frac|sqrt|cdot|times|div|neq|leq|geq)\b/i.test(normalized)
  ) return false;

  const commands = [...normalized.matchAll(/\\([A-Za-z]+)/g)].map((match) =>
    match[1]
  );
  if (commands.some((command) => !ALLOWED_LATEX_COMMANDS.has(command))) {
    return false;
  }

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
      .filter((step): step is string =>
        typeof step === "string" && step.trim().length > 0
      )
      .map((step) => step.trim())
      .filter(isValidMathOnlyStep)
      .slice(0, 3)
    : undefined;
  const mistakeDetected = typeof row.mistake_detected === "boolean"
    ? row.mistake_detected
    : true;
  const confidence: TutorObservation["confidence"] =
    misconceptionType === "unclear_work"
      ? "low"
      : mistakeDetected
      ? "high"
      : "medium";
  const squareRootFallback = {
    explanation:
      "Your setup is correct, but the square root of 16 is 4, not 8.",
    action: "Replace ±8 with ±4, then continue solving from there.",
  };
  const genericFallback = {
    explanation: "Check the first incorrect step carefully before continuing.",
    action: "Redo only that step, then try the next line again.",
  };
  const fallback = misconceptionType === "square_root"
    ? squareRootFallback
    : genericFallback;
  const displayHint = validStudentFacingText(row.display_hint)
    ? String(row.display_hint).trim()
    : fallback.explanation;
  const tryStep = validStudentFacingText(row.try_step)
    ? String(row.try_step).trim()
    : fallback.action;
  const spokenHint = validStudentFacingText(row.spoken_hint)
    ? row.spoken_hint
    : `${displayHint} ${tryStep}`;
  const compactHint = buildCompactHint({
    explanation: displayHint,
    action: tryStep,
    spokenHint,
    legacyHint: row.hint,
    mistakeDetected,
  });

  return {
    mistake_detected: mistakeDetected,
    confidence,
    misconception_type: misconceptionType,
    hint_level: Math.min(3, Math.max(1, Number(row.hint_level ?? 1))),
    hint: compactHint.hint,
    spoken_hint: compactHint.spokenHint,
    hint_explanation: compactHint.explanation,
    hint_action: compactHint.action,
    display_hint: compactHint.explanation,
    try_step: compactHint.action,
    teacher_note: typeof row.teacher_note === "string"
      ? row.teacher_note.trim()
      : "",
    work_summary: typeof row.work_summary === "string"
      ? row.work_summary.trim()
      : "",
    teach_steps: teachSteps && teachSteps.length > 0 ? teachSteps : undefined,
    final_answer_blocked: true,
    vision_detail: undefined,
    observe_max_output_tokens: undefined,
    prompt_characters: undefined,
    response_bytes: undefined,
  };
}

function validStudentFacingText(value: unknown): value is string {
  if (typeof value !== "string" || value.trim().length === 0) return false;
  const normalized = value.toLowerCase();
  return !value.includes("\\") &&
    !normalized.includes("that value") &&
    !normalized.includes("marked expression") &&
    !normalized.includes("marked value") &&
    !normalized.includes("placeholder") &&
    !normalized.includes("sqrt(");
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

function _verboseObserveWorkPrompt(student: any, session: any): string {
  const name =
    typeof student?.name === "string" && student.name.trim().length > 0
      ? student.name.trim()
      : "Student";
  const level = typeof student?.level === "string"
    ? student.level
    : "Algebra II";
  const misconceptions =
    student?.misconceptions && typeof student.misconceptions === "object"
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
${
    studentQuestion
      ? `- Student's spoken question: ${JSON.stringify(studentQuestion)}`
      : ""
  }

Analyze the visible work as one problem. Find the first incorrect transition, but do not over-interrupt if confidence is low. Use the student's past mistakes only when they match evidence in this image.
${
    studentQuestion
      ? "Answer the student's spoken question about the visible work with one concise guided hint. Do not ignore the question."
      : ""
  }

${OPTIMIZED_TUTOR_INSTRUCTIONS}

Hard rules:
- Never reveal the final answer.
- Never solve the full problem.
- Return a specific hint_explanation and one focused hint_action about the first incorrect transition.
- hint_explanation must use 2 to 4 complete sentences. Acknowledge what is correct, identify the exact mistake, and explain the mathematical rule that applies.
- hint_action must be one complete sentence that asks for exactly one useful next step.
- Do not shorten a useful explanation merely to save words. Never return generic advice such as "check this step carefully" or "compare it with the previous line" without naming the actual operation or misconception.
- spoken_hint must be a complete plain-English version of the same substantive guidance.
- spoken_hint must summarize the same explanation and next step without LaTeX, equations, arithmetic expressions, or raw mathematical notation.
- Make the hint concrete enough that the student understands the rule, but leave the calculation or correction for the student.
- Name the exact visible numbers, symbols, or operation involved; do not give a generic topic reminder.
- Refer to the displayed derivation as Step 1, Step 2, or Step 3 whenever that is less confusing than reading a dense expression aloud.
- Do not repeat a full algebraic expression in prose merely to identify a line; say "Step 2" and explain the operation or misconception.
- Provide at most 3 short math-only teach_steps that can be shown on a classroom display.
- Start teach_steps at the mistaken line (or the line immediately before it), not at the beginning of the problem.
- Copy the variables and numbers visible in the student's work. Never substitute a canned example or generic variables.
- teach_steps must directly correct the visible mistake.
- teach_steps should not dump a full final answer unless the visible step already contains it.
- Write every mathematical expression in valid LaTeX.
- In hint prose, wrap every math expression inline in \\( and \\), including equations, fractions, powers, variables with coefficients, and arithmetic products.
- Never leave raw math such as x^2, 3(x-4), 2x=10, or 1/2 unwrapped in hint prose.
- Keep prose and inline math in the same sentence. Do not place an expression on its own line and do not use display wrappers \\[...\\], $$...$$, Markdown code, or Markdown bullets in the hint.
- Example fields: hint_explanation is "Your first product is correct, but the outside factor must multiply both terms inside the parentheses." and hint_action is "Recheck \\(3 \\cdot (-4)\\) before rewriting Step 2."
- For that example, spoken_hint could be "The outside factor must reach both terms. Recheck the second product before rewriting Step 2."
- Never emit empty LaTeX wrappers or empty groups such as \\(\\), \\frac{}{2}, \\sqrt{}, or x^{}.
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
- If a candidate final answer is visible, explain how to verify it without confirming whether it is correct.
- Do not set up the final operation when only trivial arithmetic remains, and do not state a categorical final result such as an undefined slope.
- If the work is correct or too unclear, say so without inventing a mistake.

Return only the requested structured object. When the image is unclear, use misconception_type "unclear_work" and an empty teach_steps array.
{
  "mistake_detected": boolean,
  "confidence": "low" | "medium" | "high",
  "misconception_type": "sign_error" | "distribution" | "equation_balance" | "invalid_cancellation" | "slope_intercept" | "factoring" | "square_root" | "sat_strategy" | "unclear_work",
  "hint_level": 1 | 2 | 3,
  "hint_explanation": "one or two specific sentences explaining the visible mistake",
  "hint_action": "one focused next-step sentence with at most one inline LaTeX expression",
  "spoken_hint": "a short complete spoken summary with no mathematical notation",
  "teacher_note": "brief private note for admin/research review",
  "work_summary": "brief summary of what the student appears to be doing",
  "teach_steps": ["short math-only display line", "next short math-only display line"],
  "final_answer_blocked": true
}
`.trim();
}

function observeWorkPrompt(student: any, session: any): string {
  const name = typeof student?.name === "string" && student.name.trim()
    ? student.name.trim()
    : "Student";
  const level = typeof student?.level === "string"
    ? student.level
    : "Algebra II";
  const misconceptions =
    student?.misconceptions && typeof student.misconceptions === "object"
      ? JSON.stringify(student.misconceptions)
      : "{}";
  const checkNumber = Number(session?.check_number ?? 1);
  const noAnswerMode = session?.no_answer_mode !== false;
  const studentQuestion = typeof session?.student_question === "string"
    ? session.student_question.trim().slice(0, 300)
    : "";
  const previousTutorContext =
    typeof session?.previous_tutor_context === "string"
      ? session.previous_tutor_context.trim().slice(0, 900)
      : "";

  return `
You are MathTutor analyzing ${name}'s handwritten math.
Context: level=${level}; prior_misconceptions=${misconceptions};
check=${checkNumber}; no_answer=${noAnswerMode}.
${studentQuestion ? `Student question: ${JSON.stringify(studentQuestion)}` : ""}
${previousTutorContext ? `Previous tutor context: ${previousTutorContext}` : ""}

${OPTIMIZED_TUTOR_INSTRUCTIONS}

Output constraints:
- Return only the requested schema object.
- If this is a follow-up question, answer it using the previous tutor context
  and visible work. Do not restart as a fresh scan unless the context is empty.
- display_hint: one concise, specific plain-text sentence.
- try_step: exactly one short, actionable plain-text sentence.
- spoken_hint: one plain-English sentence, 15–30 words, no notation.
- teacher_note and work_summary: at most one short sentence each.
- teach_steps: 0–2 valid math-only LaTeX lines using visible symbols.
- Student-facing fields use plain text only. Use √, ±, ×, ÷, and ≤ rather
  than LaTeX or backslash commands.
- teach_steps contain no prose, dollar signs, \\text, or empty groups.
- Never name a misconception unsupported by visible work.
- Never use "that value", "marked expression", "marked value", "placeholder",
  raw LaTeX, backslash commands, or incomplete math fragments.
- For a square-root error like ±8 from 16, write naturally: display_hint
  "Your setup is correct, but the square root of 16 is 4, not 8." and try_step
  "Replace ±8 with ±4, then continue solving from there."
- Keep final_answer_blocked true. If unreadable, use unclear_work and [].
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
    throw new Error(
      "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY secret.",
    );
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
  const events = Array.isArray(body.events)
    ? body.events as Record<string, unknown>[]
    : [];

  if (!student || !session) {
    return jsonResponse({
      error: 'Missing required "student" or "session" object.',
    }, 400);
  }

  const studentId = String(student.id ?? "");
  const sessionId = String(session.id ?? "");
  if (!studentId || !sessionId) {
    return jsonResponse(
      { error: "Student and session IDs are required." },
      400,
    );
  }

  const studentRes = await supabaseRest("teacher_students?on_conflict=id", {
    id: studentId,
    name: String(student.name ?? "Student"),
    math_level: String(student.math_level ?? student.level ?? "Algebra II"),
    consent_accepted: Boolean(student.consent_accepted ?? true),
    misconception_counts: student.misconception_counts ??
      student.misconceptions ?? {},
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

    const eventsRes = await supabaseRest(
      "teacher_events?on_conflict=id",
      eventRows,
      {
        prefer: "resolution=merge-duplicates,return=minimal",
      },
    );

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
  const logLatency = latencyLogger(
    "observe_work",
    req.headers.get("x-mathtutor-request-id") ?? crypto.randomUUID(),
  );
  logLatency("supabase_tutor_request_received", { method: req.method });
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: JSON_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed. Use POST." }, 405);
  }

  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  if (!openaiKey) {
    return jsonResponse({ error: "Missing OPENAI_API_KEY secret." }, 500);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
    logLatency("request_json_parsed");
  } catch {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  if (body.mode === "log_session") {
    return await logSession(body);
  }

  if (body.mode !== "observe_work") {
    return jsonResponse({
      error: 'Unsupported mode. Use "observe_work" or "log_session".',
    }, 400);
  }

  const imageBase64 = typeof body.image_base64 === "string"
    ? body.image_base64.trim()
    : "";
  if (!imageBase64) {
    return jsonResponse(
      { error: 'Missing required field "image_base64".' },
      400,
    );
  }
  logLatency("image_payload_received", {
    base64_bytes: new TextEncoder().encode(imageBase64).byteLength,
    estimated_image_bytes: Math.floor(imageBase64.length * 0.75),
  });

  try {
    const student = body.student && typeof body.student === "object"
      ? body.student
      : {};
    const session = body.session && typeof body.session === "object"
      ? body.session
      : {};

    const model = Deno.env.get("OPENAI_OBSERVE_MODEL") ?? "gpt-5.4";
    const visionDetail = configuredVisionDetail();
    const prompt = observeWorkPrompt(student, session);
    const maxOutputTokens = 350;
    const openAIRequestBody = JSON.stringify({
      model,
      reasoning: { effort: "low" },
      input: [
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: prompt,
            },
            {
              type: "input_image",
              image_url: `data:image/jpeg;base64,${imageBase64}`,
              detail: visionDetail,
            },
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
      max_output_tokens: maxOutputTokens,
    });
    logLatency("openai_request_body_constructed", {
      image_detail: visionDetail,
      max_output_tokens: maxOutputTokens,
      model,
      prompt_characters: prompt.length,
      request_bytes: new TextEncoder().encode(openAIRequestBody).byteLength,
    });
    logLatency("openai_request_started", {
      model,
    });
    const observeRes = await fetchWithTimeout(
      "https://api.openai.com/v1/responses",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${openaiKey}`,
          "Content-Type": "application/json",
        },
        body: openAIRequestBody,
      },
      OBSERVE_TIMEOUT_MS,
    );

    logLatency("openai_response_received", {
      status: observeRes.status,
    });
    const observeText = await observeRes.text();
    const responseBytes = new TextEncoder().encode(observeText).byteLength;
    logLatency("openai_response_body_fully_read", {
      bytes: responseBytes,
    });
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
    logLatency("openai_response_text_extracted", { chars: rawText.length });
    if (!rawText.trim()) {
      return jsonResponse(
        { error: "Observation response content was empty." },
        500,
      );
    }

    const observation = normalizeObservation(
      JSON.parse(stripCodeFences(rawText)),
    );
    observation.vision_detail = visionDetail;
    observation.observe_max_output_tokens = maxOutputTokens;
    observation.prompt_characters = prompt.length;
    observation.response_bytes = responseBytes;
    logLatency("response_parsed", {
      spoken_words: observation.spoken_hint.split(/\s+/).filter(Boolean).length,
    });
    logLatency("response_returned");
    return jsonResponse(observation);
  } catch (err) {
    if (err instanceof DOMException && err.name === "AbortError") {
      return jsonResponse(
        { error: "OpenAI observation request timed out." },
        504,
      );
    }
    console.log("tutor:crash", String(err));
    return jsonResponse({
      error: "Tutor function failed.",
      details: String(err),
    }, 500);
  }
});
