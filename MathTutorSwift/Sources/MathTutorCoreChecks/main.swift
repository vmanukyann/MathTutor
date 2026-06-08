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

print("MathTutorCoreChecks passed")
