import "@supabase/functions-js/edge-runtime.d.ts";

type SolutionBlock = { type: string; text: string };

const JSON_HEADERS = { "Content-Type": "application/json" };

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

function stripCodeFences(input: string): string {
  return input
    .replace(/^\s*```(?:json)?\s*/i, "")
    .replace(/\s*```\s*$/i, "")
    .trim();
}

function parseVisionContent(content: unknown): string {
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .map((part) =>
        part && typeof part === "object" && "text" in part ? (part as any).text ?? "" : ""
      )
      .join("\n");
  }
  return "";
}

function normalizeSolution(value: unknown): SolutionBlock[] {
  if (!Array.isArray(value)) return [];
  const allowedTypes = new Set(["header", "paragraph", "equation", "question"]);

  return value
    .filter((item) => item && typeof item === "object")
    .map((item) => {
      const row = item as Record<string, unknown>;
      const rawType = typeof row.type === "string" ? row.type.toLowerCase().trim() : "paragraph";
      const type = allowedTypes.has(rawType) ? rawType : "paragraph";
      const text = typeof row.text === "string" ? row.text.trim() : "";
      return { type, text };
    })
    .filter((row) => row.text.length > 0);
}

function parseTutorPayload(raw: string): {
  skill_category: string;
  skill_name: string;
  solution: SolutionBlock[];
} {
  const cleaned = stripCodeFences(raw);
  let parsed: unknown;

  try {
    parsed = JSON.parse(cleaned);
  } catch {
    const start = cleaned.indexOf("{");
    const end = cleaned.lastIndexOf("}");
    if (start < 0 || end <= start) throw new Error("Model returned invalid JSON.");
    parsed = JSON.parse(cleaned.slice(start, end + 1));
  }

  if (!parsed || typeof parsed !== "object") {
    throw new Error("Parsed response is not a JSON object.");
  }

  const map = parsed as Record<string, unknown>;
  const solution = normalizeSolution(map.solution);
  if (solution.length === 0) throw new Error("No solution blocks returned from model.");

  return {
    skill_category:
      typeof map.skill_category === "string" && map.skill_category.trim().length > 0
        ? map.skill_category.trim()
        : "Other",
    skill_name:
      typeof map.skill_name === "string" && map.skill_name.trim().length > 0
        ? map.skill_name.trim()
        : "General Problem Solving",
    solution,
  };
}

function convertLatexToSpeech(latex: string): string {
  let spoken = latex;

  spoken = spoken.replaceAll("\\", "");
  spoken = spoken.replaceAll("leq", " is less than or equal to ");
  spoken = spoken.replaceAll("geq", " is greater than or equal to ");
  spoken = spoken.replaceAll("times", " times ");
  spoken = spoken.replaceAll("div", " divided by ");
  spoken = spoken.replaceAll("cdot", " times ");
  spoken = spoken.replaceAll("pm", " plus or minus ");

  spoken = spoken.replaceAll("<=", " is less than or equal to ");
  spoken = spoken.replaceAll(">=", " is greater than or equal to ");
  spoken = spoken.replaceAll("!=", " is not equal to ");
  spoken = spoken.replaceAll("=", " equals ");
  spoken = spoken.replaceAll("<", " is less than ");
  spoken = spoken.replaceAll(">", " is greater than ");
  spoken = spoken.replaceAll("+", " plus ");
  spoken = spoken.replaceAll("*", " times ");
  spoken = spoken.replaceAll("/", " divided by ");

  return spoken.replace(/\s+/g, " ").trim();
}

function solutionToSpeech(blocks: SolutionBlock[]): string {
  const out: string[] = [];
  out.push("Hi there! Let me walk you through this problem step by step.");
  out.push("");

  for (const block of blocks) {
    if (block.type === "header") {
      if (!block.text.toLowerCase().includes("solution")) {
        out.push(block.text);
        out.push("");
      }
      continue;
    }

    if (block.type === "equation") {
      out.push(convertLatexToSpeech(block.text));
      continue;
    }

    out.push(block.text);
    if (block.type === "question") out.push("");
  }

  out.push("And that's how we solve it! Do you have any questions?");
  return out.join("\n");
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

async function fetchWithTimeout(url: string, init: RequestInit, timeoutMs: number): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timeoutId);
  }
}

const VISION_TIMEOUT_MS = 35_000;
const TTS_TIMEOUT_MS = 25_000;

function structuredPrompt(): string {
  return `
You are a friendly tutor for a middle school student.

You MUST solve the math problem in the image by explaining it in 3 to 5 steps.

CRITICAL OUTPUT RULES:
- Return ONLY valid JSON (no markdown, no code fences).
- Do NOT use markdown symbols (*, **, _, #).
- Do NOT include any text outside the JSON.

FORMAT REQUIREMENTS FOR THE "solution" ARRAY:
- Each step MUST start with a header block whose text starts with "Step 1", "Step 2", etc.
- After each step header, include 1-3 blocks of paragraph/equation/question.
- Equations MUST be LaTeX in the "equation" type.
- Keep the language engaging, and ask a short guiding question per step.

Return a JSON object with EXACTLY these keys:
- "skill_category": one of [Arithmetic, Algebra, Geometry, Statistics, Trigonometry, Calculus, Functions, Other]
- "skill_name": short label
- "solution": array of { "type": "header|paragraph|equation|question", "text": string }
`.trim();
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed. Use POST." }, 405);

  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  if (!openaiKey) return jsonResponse({ error: "Missing OPENAI_API_KEY secret." }, 500);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: 'Invalid JSON body. Expected {"image_base64":"..."}' }, 400);
  }

  const imageBase64 = typeof body.image_base64 === "string" ? body.image_base64.trim() : "";
  if (!imageBase64) return jsonResponse({ error: 'Missing required field "image_base64".' }, 400);

  try {
    console.log("tutor:start", { bytes: imageBase64.length });

    // --- Vision ---
    console.log("tutor:vision:request");
    const visionRes = await fetchWithTimeout(
      "https://api.openai.com/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${openaiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          response_format: { type: "json_object" },
          messages: [
            {
              role: "user",
              content: [
                { type: "text", text: structuredPrompt() },
                { type: "image_url", image_url: { url: `data:image/jpeg;base64,${imageBase64}` } },
              ],
            },
          ],
          max_tokens: 1400,
        }),
      },
      VISION_TIMEOUT_MS
    );

    const visionText = await visionRes.text();
    if (!visionRes.ok) {
      console.log("tutor:vision:error", { status: visionRes.status, body: visionText.slice(0, 500) });
      return jsonResponse({ error: "Vision request failed.", status: visionRes.status, details: visionText }, 500);
    }

    const visionJson = JSON.parse(visionText);
    const rawContent = parseVisionContent(visionJson?.choices?.[0]?.message?.content);
    if (!rawContent.trim()) return jsonResponse({ error: "Vision response content was empty." }, 500);

    const parsed = parseTutorPayload(rawContent);
    console.log("tutor:vision:ok", { blocks: parsed.solution.length });

    const speechText = solutionToSpeech(parsed.solution);

    // --- TTS ---
    console.log("tutor:tts:request");
    const ttsRes = await fetchWithTimeout(
      "https://api.openai.com/v1/audio/speech",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${openaiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "tts-1",
          voice: "alloy",
          input: speechText,
        }),
      },
      TTS_TIMEOUT_MS
    );

    if (!ttsRes.ok) {
      const details = await ttsRes.text();
      console.log("tutor:tts:error", { status: ttsRes.status, body: details.slice(0, 500) });
      return jsonResponse({ error: "TTS request failed.", status: ttsRes.status, details }, 500);
    }

    const audioBytes = new Uint8Array(await ttsRes.arrayBuffer());
    const audioBase64 = bytesToBase64(audioBytes);
    console.log("tutor:tts:ok", { audioBytes: audioBytes.length });

    return jsonResponse({
      skill_category: parsed.skill_category,
      skill_name: parsed.skill_name,
      solution: parsed.solution,
      audio_base64: audioBase64,
    });
  } catch (err) {
    if (err instanceof DOMException && err.name === "AbortError") {
      console.log("tutor:timeout");
      return jsonResponse({ error: "Upstream timeout (vision or TTS)." }, 504);
    }
    console.log("tutor:crash", String(err));
    return jsonResponse({ error: "Tutor function failed.", details: String(err) }, 500);
  }
});