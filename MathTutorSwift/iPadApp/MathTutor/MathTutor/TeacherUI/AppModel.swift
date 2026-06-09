import Foundation
import Combine
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    enum Route {
        case studentPicker
        case consent(StudentProfile)
        case liveSession(StudentProfile)
        case reflection(TutoringSession)
        case admin
    }

    @Published var route: Route = .studentPicker
    @Published var students: [StudentProfile] = []
    @Published var sessions: [TutoringSession] = []

    private let store: FileStudentMemoryStore
    private let tutorClient = SupabaseTutorClient(configuration: AppSecrets.supabase)

    init() {
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        store = FileStudentMemoryStore(
            directory: documents.appendingPathComponent("MathTutor")
        )
        load()
    }

    func load() {
        students = (try? store.loadStudents()) ?? []
        sessions = (try? store.loadSessions()) ?? []
    }

    func select(_ student: StudentProfile) {
        if student.consentAccepted {
            route = .liveSession(student)
        } else {
            route = .consent(student)
        }
    }

    func saveStudent(_ student: StudentProfile) {
        if let index = students.firstIndex(where: { $0.id == student.id }) {
            students[index] = student
        } else {
            students.append(student)
        }
        try? store.saveStudents(students)
    }

    func acceptConsent(for student: StudentProfile) {
        var updated = student
        updated.consentAccepted = true
        saveStudent(updated)
        route = .liveSession(updated)
    }

    func finishSession(_ session: TutoringSession) {
        try? store.saveSession(session)
        Task {
            try? await tutorClient.logSession(session)
        }
        load()
        route = .reflection(session)
    }

    func returnHome() {
        load()
        route = .studentPicker
    }
}
