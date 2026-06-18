import Foundation
import Combine
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    private(set) static weak var shared: AppModel?

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
    @Published var standController = StandController()
    @Published var voiceRecognizer = VoiceCommandRecognizer()
    @Published var externalDisplay = ExternalDisplayState()

    let voiceRouter = VoiceCommandRouter()
    let externalDisplayController = ExternalDisplayController()

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
        Self.shared = self
    }

    func startExternalDisplaySupport() {
        externalDisplayController.start(appModel: self)
        ExternalDisplaySceneDelegate.bindExistingWindows(to: self)
    }

    func refreshExternalDisplaySupport() {
        externalDisplayController.refreshExternalDisplay()
        ExternalDisplaySceneDelegate.bindExistingWindows(to: self)
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
        clearExternalTeachMode()
    }

    func setExternalDisplayConnected(_ isConnected: Bool) {
        externalDisplay.setConnected(isConnected)
    }

    func showExternalTeachMode(student: StudentProfile, lines: [String]) {
        externalDisplay.showTeachMode(studentName: student.name, lines: lines)
    }

    func updateExternalTeachMode(lines: [String]) {
        externalDisplay.updateTeachMode(lines: lines)
    }

    func clearExternalTeachMode() {
        externalDisplay.clearTeachMode()
    }
}
