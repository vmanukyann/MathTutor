import Foundation
import MathTutorCore

let policy = TutorPolicy(noAnswerMode: true)
let sanitized = policy.sanitizedHint("The answer is x = 4.")
assert(sanitized.contains("will not give the final answer"))

let observation = TutorObservation(
    mistakeDetected: true,
    confidence: .medium,
    misconceptionType: .signError,
    hintLevel: 2,
    hint: "Check the sign when you moved that term.",
    teacherNote: "Likely sign change mistake.",
    workSummary: "Student moved a term across the equals sign."
)
assert(policy.shouldInterrupt(for: observation))

let cappedObservation = TutorObservation(
    mistakeDetected: true,
    confidence: .high,
    misconceptionType: .distribution,
    hintLevel: 4,
    hint: "Compare the two visible terms.",
    teacherNote: "",
    workSummary: ""
)
assert(cappedObservation.hintLevel == 3)

let longSpokenHint = """
Step two changes the sign incorrectly when moving the term across the equals sign. \
Undo that move, keep both sides balanced, and try the line again.
"""
let shortenedSpokenHint = SpokenHintPolicy.shortened(longSpokenHint)
assert(shortenedSpokenHint == longSpokenHint)
assert(shortenedSpokenHint.hasSuffix("."))
let fullDisplayHint = """
Aarav, you kept the left side balanced. Step 2 changes the sign incorrectly when moving \
the term across the equals sign. Which inverse operation should you use instead?
"""
let dedicatedSpokenHint = "Step two changes the sign. Undo that move and try the line again."
assert(
    SpokenHintPolicy.forPlayback(
        spokenHint: dedicatedSpokenHint,
        fallback: fullDisplayHint
    ) == dedicatedSpokenHint
)
assert(fullDisplayHint.contains("kept the left side balanced"))
let compactHint = SpokenHintPolicy.presentation(
    explanation: "The outside factor must reach both terms.",
    action: "Recheck the second product.",
    legacyHint: fullDisplayHint
)
assert(compactHint.explanation == "The outside factor must reach both terms.")
assert(compactHint.action == "Recheck the second product.")
assert(compactHint.combinedText == """
The outside factor must reach both terms.
Try: Recheck the second product.
""")
let mathPresentation = SpokenHintPolicy.presentation(
    explanation: "The outside factor must reach both terms.",
    action: #"Recheck \(-2 \cdot 5\)."#,
    legacyHint: ""
)
let mathSpeech = SpokenHintPolicy.spokenText(for: mathPresentation)
assert(mathPresentation.action.contains(#"\(-2 \cdot 5\)"#))
assert(mathSpeech.contains("the marked expression"))
assert(!mathSpeech.contains("\\"))
assert(!mathSpeech.contains("-2"))
let generatedSummary = "The outside factor must reach both terms. Recheck the second product."
assert(
    SpokenHintPolicy.playbackText(
        spokenHint: generatedSummary,
        presentation: mathPresentation
    ) == generatedSummary
)

let richPresentation = SpokenHintPolicy.presentation(
    explanation: "The first product is correct, but the outside factor must also multiply the second term inside the parentheses.",
    action: "Recheck the second product before rewriting Step 2.",
    legacyHint: ""
)
assert(richPresentation.explanation.contains("first product is correct"))
assert(richPresentation.action == "Recheck the second product before rewriting Step 2.")
assert(!richPresentation.combinedText.contains("more careful explanation"))
let rejectedGenericSpeech = SpokenHintPolicy.playbackText(
    spokenHint: "This step needs a more careful explanation. Compare it with the previous line.",
    presentation: richPresentation
)
assert(rejectedGenericSpeech.contains("outside factor must also multiply"))
assert(!rejectedGenericSpeech.contains("more careful explanation"))

let legacyCompactHint = SpokenHintPolicy.presentation(
    explanation: nil,
    action: nil,
    legacyHint: """
    Your first product is correct. The negative factor must also reach the second term. \
    Recheck that second product before rewriting the line.
    """
)
assert(legacyCompactHint.explanation.contains("negative factor must also reach"))
assert(legacyCompactHint.action == "Recheck that second product before rewriting the line.")

var student = StudentProfile(name: "Aarav", mathLevel: .algebraTwo)
student.record(.distribution)
student.record(.distribution)
assert(student.misconceptionCounts[.distribution] == 2)
assert(student.topMisconceptions.first == .distribution)

let start = Date(timeIntervalSince1970: 0)
let next = Date(timeIntervalSince1970: 1)
let later = Date(timeIntervalSince1970: 2)

var display = ExternalDisplayState(updatedAt: start)
display.setConnected(true, now: next)
assert(display.isConnected)
assert(!display.isTeaching)
assert(display.statusNote == "Ready")
assert(display.updatedAt == next)

display.showTeachMode(studentName: "Aarav", lines: ["3(x + 2)", "= 3x + 3·2", "= 3x + 6"], now: later)
assert(display.isConnected)
assert(display.isTeaching)
assert(display.studentName == "Aarav")
assert(display.mathLines.count == 3)
assert(display.statusNote == "Teach Mode")

display.updateTeachMode(lines: ["3(x + 2)", "= (3·x) + (3·2)", "= 3x + 6"], now: later)
assert(display.isTeaching)
assert(display.mathLines[1] == "= (3·x) + (3·2)")

display.clearTeachMode(now: later)
assert(display.isConnected)
assert(!display.isTeaching)
assert(display.studentName == nil)
assert(display.mathLines.isEmpty)
assert(display.statusNote == "Ready")

display.showTeachMode(studentName: "Aarav", lines: ["2x = 8", "x = 4"], now: later)
display.setConnected(false, now: later)
assert(!display.isConnected)
assert(!display.isTeaching)
assert(display.studentName == nil)
assert(display.mathLines.isEmpty)
assert(display.statusNote == "No display")

print("MathTutorCoreChecks passed")
