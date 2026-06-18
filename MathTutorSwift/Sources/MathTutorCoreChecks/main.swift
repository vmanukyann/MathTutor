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
