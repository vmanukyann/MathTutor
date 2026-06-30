import "@supabase/functions-js/edge-runtime.d.ts";

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

function normalizeObservation(value: unknown): TutorObservation {
  if (!value || typeof value !== "object") {
    throw new Error("Observation response is not a JSON object.");
  }

  const row = value as Record<string, unknown>;
  const confidenceRaw = typeof row.confidence === "string"
    ? row.confidence.toLowerCase()
    : "medium";
  const confidence = ["low", "medium", "high"].includes(confidenceRaw)
    ? confidenceRaw as TutorObservation["confidence"]
    : "medium";

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
      .slice(0, 5)
    : undefined;

  return {
    mistake_detected: typeof row.mistake_detected === "boolean"
      ? row.mistake_detected
      : true,
    confidence,
    misconception_type: misconceptionType,
    hint_level: Math.min(4, Math.max(1, Number(row.hint_level ?? 1))),
    hint: typeof row.hint === "string" && row.hint.trim().length > 0
      ? row.hint.trim()
      : "Pause and compare this line to the one above it.",
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

  return `
You are MathTutor, a real-time guided math teacher watching ${name}'s handwritten paper.

Student context:
- Name: ${name}
- Current level: ${level}
- Past misconception counts: ${misconceptions}
- Session check number: ${checkNumber}
- No-answer mode: ${noAnswerMode ? "enabled" : "disabled"}

Analyze the newest visible step in the image. Detect likely reasoning mistakes, but do not over-interrupt if confidence is low. Use the student's past mistakes to personalize the hint when relevant.

Hard rules:
- Never reveal the final answer.
- Never solve the full problem.
- Give one short teacher-like hint or clarifying question.
- Provide 2 to 5 short math-only teach_steps that can be shown on a classroom display.
- teach_steps should match the student's visible work or misconception.
- teach_steps should not dump a full final answer unless the visible step already contains it.
- Write every mathematical expression in valid LaTeX.
- In hint prose, wrap each math expression in \\( and \\), for example: "Compare \\(2(x+3)\\) with \\(2x+3\\)."
- Each teach_steps item must contain only raw display LaTeX without dollar signs or prose.
- Prefer LaTeX commands such as \\frac{a}{b}, x^{2}, \\cdot, \\neq, and \\sqrt{x}; never use Unicode superscripts or slash fractions.
- Because the response is JSON, escape every LaTeX backslash as a JSON double backslash. For example, return "\\\\frac{1}{2}", never "\\frac{1}{2}".
- Every teach_steps line must be mathematically valid and arithmetically checked.
- Never use placeholder words such as "something", "unknown", "answer", "value", or "placeholder" in teach_steps.
- Never put prose or \\text{...} in teach_steps; use mathematical symbols and variables only.
- Preserve branches correctly. For square roots, use \\pm and never combine two solutions with a comma.
- In no-answer mode, stop at the most useful intermediate step before the final solved value.
- If the work is correct or too unclear, say so without inventing a mistake.

Return ONLY valid JSON with exactly these keys:
{
  "mistake_detected": boolean,
  "confidence": "low" | "medium" | "high",
  "misconception_type": "sign_error" | "distribution" | "equation_balance" | "invalid_cancellation" | "slope_intercept" | "factoring" | "sat_strategy" | "unclear_work",
  "hint_level": 1 | 2 | 3 | 4,
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

  if (body.mode !== "observe_work") {
    return jsonResponse({ error: 'Unsupported mode. Use "observe_work" or "log_session".' }, 400);
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
          text: { format: { type: "json_object" } },
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
