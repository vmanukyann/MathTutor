import {
  buildCompactHint,
  hintToSpeech,
  isValidInlineMathExpression,
} from "./hint_utils.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("specific display hint and spoken summary remain substantive", () => {
  const spokenHint =
    "Your first product is correct, but the negative factor must reach both terms. Recheck the second product before rewriting the line.";
  const result = buildCompactHint({
    explanation:
      "Your first product is correct. The negative factor outside the parentheses must multiply every term inside, so the second product needs the same sign rule.",
    action:
      "Recheck \\(-2 \\cdot 5\\) before rewriting the complete expression.",
    spokenHint,
    mistakeDetected: true,
  });

  assert(
    result.hint.includes("negative factor outside the parentheses"),
    "specific mathematical explanation was lost",
  );
  assert(
    result.hint === `${result.explanation}\nTry: ${result.action}`,
    "hint did not compose",
  );
  assert(
    result.spokenHint === spokenHint,
    "the API-provided spoken summary was not preserved",
  );
  assert(
    !result.hint.includes("more careful explanation"),
    "generic fallback was used",
  );
});

Deno.test("malformed or empty LaTeX uses a readable fallback", () => {
  for (
    const expression of [
      "",
      String.raw`\frac{}{2}`,
      String.raw`\sqrt{}`,
      "x^{}",
    ]
  ) {
    assert(
      !isValidInlineMathExpression(expression),
      `${expression} should be invalid`,
    );
  }

  for (
    const action of [
      String.raw`Check \(\) again.`,
      String.raw`Check \(\frac{}{2}\) again.`,
      String.raw`Check \(\sqrt{}\) again.`,
      String.raw`Check \(x^{}\) again.`,
    ]
  ) {
    const result = buildCompactHint({
      explanation: "The operation changes on this line.",
      action,
      mistakeDetected: true,
    });
    assert(
      !result.hint.includes("\\"),
      "sanitized hint still contains invalid LaTeX",
    );
    assert(
      result.action.includes("the marked expression"),
      "invalid expression was not replaced readably",
    );
    assert(
      result.explanation === "The operation changes on this line.",
      "valid explanatory prose was discarded",
    );
  }
});

Deno.test("one valid inline expression stays visible but is not read aloud", () => {
  const result = buildCompactHint({
    explanation: "The outside factor must reach both terms.",
    action: String.raw`Recheck \(-2 \cdot 5\).`,
    spokenHint:
      "The outside factor must reach both terms. Recheck the second product.",
    mistakeDetected: true,
  });

  assert(
    result.action.includes(String.raw`\(-2 \cdot 5\)`),
    "valid math was removed",
  );
  assert(
    hintToSpeech(result.hint).includes("the marked expression"),
    "display math could not be converted to safe fallback speech",
  );
  assert(!result.spokenHint.includes("\\"), "spoken hint still contains LaTeX");
  assert(
    !result.spokenHint.includes("-2"),
    "spoken hint still reads the expression",
  );
});
