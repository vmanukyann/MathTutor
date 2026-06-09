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
    @State private var studentConfused = false

    private let tutorClient = SupabaseTutorClient(configuration: AppSecrets.supabase)
    private let policy = TutorPolicy(noAnswerMode: true)

    init(student: StudentProfile) {
        self.student = student
        _session = State(initialValue: TutoringSession(student: student))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.authorizationDenied {
                cameraDeniedState
            } else {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .overlay {
                        cameraVignette
                    }
                    .overlay(alignment: .center) {
                        paperGuide
                    }
                    .overlay(alignment: .top) {
                        sessionHeader
                    }
                    .overlay(alignment: .bottom) {
                        tutorDock
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

    private var cameraDeniedState: some View {
        ContentUnavailableView(
            "Camera Access Needed",
            systemImage: "camera.fill",
            description: Text("Allow camera access so MathTutor can observe handwritten work.")
        )
        .padding(40)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MTTheme.cardRadius, style: .continuous))
        .padding()
    }

    private var cameraVignette: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.38),
                .black.opacity(0.04),
                .black.opacity(0.52)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var sessionHeader: some View {
        HStack(spacing: 12) {
            MTStatusPill(title: student.name, symbol: "person.crop.circle.fill", tint: .white)
            MTStatusPill(title: statusLabel, symbol: statusIcon, tint: statusTint)

            Spacer()

            Button {
                endSession()
            } label: {
                Label("End", systemImage: "xmark.circle.fill")
            }
            .buttonStyle(MTSecondaryButton())
            .tint(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var paperGuide: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .strokeBorder(.white.opacity(0.72), style: StrokeStyle(lineWidth: 3, dash: [16, 12]))
            .frame(maxWidth: 720, maxHeight: 500)
            .padding(.horizontal, 44)
            .overlay(alignment: .top) {
                Label("Paper area", systemImage: "doc.viewfinder")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.42), in: Capsule())
                    .offset(y: -18)
            }
    }

    private var tutorDock: some View {
        VStack(spacing: 12) {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
            }

            MTFloatingGlass {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 14) {
                        hintPanel
                        tutorControls
                    }

                    VStack(spacing: 14) {
                        hintPanel
                        tutorControls
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
    }

    private var tutorControls: some View {
        VStack(spacing: 12) {
            Button {
                Task { await checkWork() }
            } label: {
                Label(status == .thinking ? "Checking" : "Check Work", systemImage: "viewfinder")
                    .frame(width: 170)
            }
            .buttonStyle(MTPrimaryButton())
            .disabled(status == .thinking || status == .paused)

            Button {
                togglePause()
            } label: {
                Label(status == .paused ? "Resume" : "Pause", systemImage: status == .paused ? "play.circle.fill" : "pause.circle.fill")
                    .frame(width: 170)
            }
            .buttonStyle(MTSecondaryButton())

            Button {
                markConfused()
            } label: {
                Label("Confused", systemImage: "questionmark.bubble.fill")
                    .frame(width: 170)
            }
            .buttonStyle(MTSecondaryButton())
            .disabled(status == .thinking)

            Button {
                markSelfCorrected()
            } label: {
                Label("I fixed it", systemImage: "checkmark.circle.fill")
                    .frame(width: 170)
            }
            .buttonStyle(MTSecondaryButton())
            .disabled(latestObservation == nil)

            Button {
                voice.speak(latestHint)
            } label: {
                Label("Repeat", systemImage: "speaker.wave.2.fill")
                    .frame(width: 170)
            }
            .buttonStyle(MTSecondaryButton())
        }
    }

    private var hintPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Tutor Hint", systemImage: "lightbulb.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Spacer()

                if let latestObservation {
                    Text("Level \(latestObservation.hintLevel)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(MTTheme.accent.opacity(0.12), in: Capsule())
                }
            }

            Text(latestHint)
                .font(.title3.weight(.semibold))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if studentConfused {
                Label("Student marked this step as confusing", systemImage: "questionmark.bubble.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MTTheme.warning)
                    .padding(.top, 2)
            }

            if let latestObservation {
                HStack(spacing: 8) {
                    MTStatusPill(
                        title: latestObservation.misconceptionType.displayName,
                        symbol: "brain.head.profile",
                        tint: MTTheme.warning
                    )
                    MTStatusPill(
                        title: latestObservation.confidence.rawValue.capitalized,
                        symbol: "gauge.with.dots.needle.bottom.50percent",
                        tint: MTTheme.accent
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .mtLiquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        case .watching: "eye.fill"
        case .thinking: "brain.head.profile"
        case .hintReady: "lightbulb.fill"
        case .paused: "pause.circle.fill"
        }
    }

    private var statusTint: Color {
        switch status {
        case .watching: .white
        case .thinking: MTTheme.warning
        case .hintReady: MTTheme.success
        case .paused: .white
        }
    }

    private func checkWork() async {
        guard status != .paused else { return }
        status = .thinking
        errorMessage = nil
        studentConfused = false

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
        studentConfused = false
        latestHint = "Nice correction. Keep the fixed line visible so I can follow the next step."
        voice.speak(latestHint)
    }

    private func markConfused() {
        studentConfused = true
        if let latestObservation {
            latestHint = "Pause on this step. What changed from the previous line in the \(latestObservation.misconceptionType.displayName.lowercased()) part?"
        } else {
            latestHint = "Pause here. Point to the line that feels uncertain, then compare it with the line right before it."
        }
        voice.speak(latestHint)
    }

    private func togglePause() {
        switch status {
        case .paused:
            status = .watching
            latestHint = "I am watching again. Keep the current line visible as you continue."
        case .watching, .hintReady:
            status = .paused
            latestHint = "Paused. I will stay quiet until you resume or ask me to repeat the hint."
        case .thinking:
            return
        }
        voice.speak(latestHint)
    }

    private func endSession() {
        session.endedAt = Date()
        appModel.finishSession(session)
    }
}
