const ALLOWED_INLINE_COMMANDS = new Set([
  "cdot",
  "div",
  "frac",
  "geq",
  "leq",
  "neq",
  "pm",
  "sqrt",
  "times",
]);

export type CompactHint = {
  explanation: string;
  action: string;
  hint: string;
  spokenHint: string;
};

type CompactHintInput = {
  explanation?: unknown;
  action?: unknown;
  spokenHint?: unknown;
  legacyHint?: unknown;
  mistakeDetected: boolean;
};

function normalizeText(value: unknown): string {
  return typeof value === "string" ? value.trim().replace(/\s+/g, " ") : "";
}

function finishSentence(value: string): string {
  const cleaned = value.trim().replace(/[,:;—-]+$/, "");
  return /[.!?]$/.test(cleaned) ? cleaned : `${cleaned}.`;
}

function inlineMathExpressions(value: string): string[] | undefined {
  if (/\\\[|\\\]|\$\$?/.test(value)) return undefined;

  const expressions = [...value.matchAll(/\\\((.*?)\\\)/gs)].map((match) =>
    match[1]
  );
  const remainder = value.replace(/\\\((.*?)\\\)/gs, "");
  if (/\\[()]|\\[A-Za-z]+/.test(remainder)) return undefined;
  return expressions;
}

export function isValidInlineMathExpression(source: string): boolean {
  const expression = source.trim();
  if (!expression || !hasBalancedBraces(expression)) return false;
  if (/\{\s*\}/.test(expression) || /\^\s*\{\s*\}/.test(expression)) {
    return false;
  }
  if (/\\(?:frac|sqrt)\s*\{\s*\}/.test(expression)) return false;

  const commands = [...expression.matchAll(/\\([A-Za-z]+)/g)].map((match) =>
    match[1]
  );
  if (commands.some((command) => !ALLOWED_INLINE_COMMANDS.has(command))) {
    return false;
  }

  const visibleContent = expression
    .replace(/\\[A-Za-z]+/g, "")
    .replace(/[{}\s^_()+\-*/=.,]/g, "");
  return /[A-Za-z0-9]/.test(visibleContent);
}

function hasBalancedBraces(source: string): boolean {
  let depth = 0;
  for (const character of source) {
    if (character === "{") depth += 1;
    if (character === "}") depth -= 1;
    if (depth < 0) return false;
  }
  return depth === 0;
}

function hasValidMath(value: string, maximumExpressions: number): boolean {
  const expressions = inlineMathExpressions(value);
  return expressions !== undefined &&
    expressions.length <= maximumExpressions &&
    expressions.every(isValidInlineMathExpression);
}

function sanitizeHintPart(value: string): string {
  if (hasValidMath(value, Number.MAX_SAFE_INTEGER)) return value;
  return value
    .replace(/\\\((?:\s*|.*?\{\s*\}.*?)\\\)/gs, "that value")
    .replace(/\\\[(?:\s*|.*?\{\s*\}.*?)\\\]/gs, "that value")
    .replace(/\\\((.*?)\\\)/gs, "$1")
    .replace(/\\\[(.*?)\\\]/gs, "$1")
    .replace(/\$\$?(.*?)\$\$?/gs, "$1")
    .replace(/\\[()]/g, "")
    .replace(/\\[A-Za-z]+(?:\s*\{[^{}]*\})*/g, "that value")
    .replace(/[{}]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

export function hintToSpeech(value: string): string {
  return value
    .replace(/\\\((.*?)\\\)/gs, "that value")
    .replace(/\\\[(.*?)\\\]/gs, "that value")
    .replace(/\$\$?.*?\$\$?/gs, "that value")
    .replace(/\\[A-Za-z]+/g, "")
    .replace(/[{}]/g, "")
    .replace(/\s*\n\s*/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function fallbackHint(mistakeDetected: boolean): CompactHint {
  const explanation = mistakeDetected
    ? "The first incorrect line does not follow the same operation as the line before it."
    : "The newest visible step follows correctly from the line before it.";
  const action = mistakeDetected
    ? "Identify what changed in that transition, then redo only that step."
    : "Continue to the next step and keep the operations balanced.";
  const hint = `${explanation}\nTry: ${action}`;
  return { explanation, action, hint, spokenHint: hintToSpeech(hint) };
}

function validSpokenHint(value: unknown): string | undefined {
  const normalized = normalizeText(value);
  if (!normalized || /[\\${}]/.test(normalized)) {
    return undefined;
  }
  return finishSentence(normalized);
}

export function buildCompactHint(input: CompactHintInput): CompactHint {
  let explanation = normalizeText(input.explanation);
  let action = normalizeText(input.action).replace(/^try\s*:\s*/i, "");

  if (!explanation || !action) {
    const legacy = normalizeText(input.legacyHint);
    const sentences = legacy.match(/[^.!?]+[.!?]?/g)?.map((part) =>
      part.trim()
    ) ?? [];
    explanation ||= sentences[0] ?? "";
    action ||= sentences[1] ?? "";
  }

  if (!explanation || !action) {
    return fallbackHint(input.mistakeDetected);
  }

  explanation = finishSentence(sanitizeHintPart(explanation));
  action = finishSentence(sanitizeHintPart(action));
  const hint = `${explanation}\nTry: ${action}`;

  return {
    explanation,
    action,
    hint,
    spokenHint: validSpokenHint(input.spokenHint) ?? hintToSpeech(hint),
  };
}
