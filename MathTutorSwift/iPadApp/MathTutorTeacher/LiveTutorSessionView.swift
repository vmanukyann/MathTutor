import MathTutorCore
import SwiftUI

struct LiveTutorSessionView: View {
    @EnvironmentObject private var appModel: AppModel

    let student: StudentProfile

    @StateObject private var camera = CameraObservationService()
    @StateObject private var voice = VoiceTutor()

    @State private var session: TutoringSession
    @State private var status: SessionStatus = .watching
    @State private var latestHint = "Place the iPad above the page. I will watch quietly until you ask me to check."
    @State private var latestObservation: TutorObservation?
    @State private var errorMessage: String?

    private let tutorClient = SupabaseTutorClient(configuration: AppSecrets.supabase)
    private let policy = TutorPolicy(noAnswerMode: true)

    init(student: StudentProfile) {
        self.student = student
        _session = State(initialValue: TutoringSession(student: student))
    }

    var body: some View {
        ZStack {
            if camera.authorizationDenied {
                ContentUnavailableView(
                    "Camera Access Needed",
                    systemImage: "camera.fill",
                    description: Text("Allow camera access so MathTutor can watch the paper.")
                )
            } else {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .overlay(alignment: .top) {
                        statusStrip
                    }
                    .overlay(alignment: .center) {
                        paperGuide
                    }
                    .overlay(alignment: .bottom) {
                        controls
                    }
            }
        }
        .task {
            await camera.start()
        }
        .onDisappear {
            camera.stop()
            voice.stop()
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 14) {
            Label(student.name, systemImage: "person.crop.circle")
            Label(statusLabel, systemImage: statusIcon)
            Spacer()
            Button {
                endSession()
            } label: {
                Label("End", systemImage: "xmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.75))
        }
        .font(.headline)
        .padding(14)
        .background(.ultraThinMaterial)
    }

    private var paperGuide: some View {
        RoundedRectangle(cornerRadius: 20)
            .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [14, 10]))
            .foregroundStyle(.white.opacity(0.65))
            .frame(width: 620, height: 430)
            .overlay(alignment: .top) {
                Text("Paper area")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.45))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)
                    .offset(y: -18)
            }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            HStack(alignment: .bottom, spacing: 16) {
                hintPanel

                VStack(spacing: 12) {
                    Button {
                        Task { await checkWork() }
                    } label: {
                        Label("Check Work", systemImage: "viewfinder")
                            .frame(width: 170)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(status == .thinking)

                    Button {
                        markSelfCorrected()
                    } label: {
                        Label("I fixed it", systemImage: "checkmark.circle")
                            .frame(width: 170)
                    }
                    .buttonStyle(.bordered)
                    .disabled(latestObservation == nil)

                    Button {
                        voice.speak(latestHint)
                    } label: {
                        Label("Repeat", systemImage: "speaker.wave.2")
                            .frame(width: 170)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
    }

    private var hintPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tutor Hint")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(latestHint)
                .font(.title3.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            if let latestObservation {
                HStack {
                    Text(latestObservation.misconceptionType.displayName)
                    Text("Level \(latestObservation.hintLevel)")
                    Text(latestObservation.confidence.rawValue.capitalized)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 560, alignment: .leading)
        .padding(16)
        .background(.black.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusLabel: String {
        switch status {
        case .watching: "Watching"
        case .thinking: "Thinking"
        case .hintReady: "Hint ready"
        case .paused: "Paused"
        }
    }

    private var statusIcon: String {
        switch status {
        case .watching: "eye"
        case .thinking: "brain.head.profile"
        case .hintReady: "lightbulb"
        case .paused: "pause.circle"
        }
    }

    private func checkWork() async {
        status = .thinking
        errorMessage = nil

        do {
            let imageData = try await camera.captureFrame()
            let request = TutorObservationRequest(
                imageBase64: imageData.base64EncodedString(),
                student: student,
                checkNumber: session.events.count + 1,
                noAnswerMode: true
            )
            var observation = try await tutorClient.observeWork(request)
            observation.hint = policy.sanitizedHint(observation.hint)

            latestObservation = observation
            latestHint = observation.hint
            session.events.append(TutorEvent(observation: observation))
            status = .hintReady

            if policy.shouldInterrupt(for: observation) {
                let opening = policy.personalizedOpening(
                    student: student,
                    misconception: observation.misconceptionType
                )
                voice.speak("\(opening). \(observation.hint)")
            }
        } catch {
            errorMessage = error.localizedDescription
            latestHint = "I could not analyze that frame. Try steadying the iPad and checking again."
            status = .watching
        }
    }

    private func markSelfCorrected() {
        guard var last = session.events.popLast() else { return }
        last.studentSelfCorrected = true
        session.events.append(last)
        latestHint = "Nice. Keep the corrected line visible so I can follow the next step."
        voice.speak(latestHint)
    }

    private func endSession() {
        session.endedAt = Date()
        appModel.finishSession(session)
    }
}
