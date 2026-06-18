import SwiftUI

struct LiveTutorSessionView: View {
    @EnvironmentObject private var appModel: AppModel

    let student: StudentProfile

    @StateObject private var camera = CameraObservationService()
    @StateObject private var voice = VoiceTutor()
    @ObservedObject private var standController: StandController

    @State private var session: TutoringSession
    @State private var status: SessionStatus = .watching
    @State private var latestHint = "Place the iPad above the page. I will watch quietly until you ask me to check."
    @State private var latestObservation: TutorObservation?
    @State private var errorMessage: String?
    @State private var studentConfused = false
    @State private var isTeachMode = false
    @State private var lastTeachModeRequest = Date.distantPast
    @State private var teachModeVariant = 0

    private let tutorClient = SupabaseTutorClient(configuration: AppSecrets.supabase)
    private let policy = TutorPolicy(noAnswerMode: true)
    private let teachModeCooldown: TimeInterval = 8

    init(student: StudentProfile, standController: StandController) {
        self.student = student
        _standController = ObservedObject(wrappedValue: standController)
        _session = State(initialValue: TutoringSession(student: student))
    }

    var body: some View {
        ZStack {
            if isTeachMode && !appModel.externalDisplay.isConnected {
                teachModeView
            } else {
                observeModeView
            }
        }
        .task {
            await camera.start()
            standController.send(.observeMode)
        }
        .onChange(of: appModel.voiceRecognizer.commandEventID) { _, _ in
            handleVoiceCommand()
        }
        .onChange(of: appModel.externalDisplay.isConnected) { _, isConnected in
            if isTeachMode, isConnected {
                appModel.showExternalTeachMode(student: student, lines: teachModeLines)
            } else if !isConnected {
                appModel.clearExternalTeachMode()
            }
        }
        .onDisappear {
            camera.stop()
            voice.stop()
            standController.returnToObserve()
            appModel.clearExternalTeachMode()
        }
    }

    private var observeModeView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.authorizationDenied {
                cameraDeniedState
            } else {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                    .overlay(alignment: .center) {
                        paperGuide
                    }
                    .overlay(alignment: .topTrailing) {
                        endButton
                    }
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 8) {
                            VoiceControlIndicator(snapshot: appModel.voiceRecognizer.snapshot)
                            ExternalDisplayStatusIcon(isConnected: appModel.externalDisplay.isConnected)
                        }
                        .padding(18)
                    }
                    .overlay(alignment: .bottom) {
                        tutorDock
                    }
            }
        }
    }

    private var cameraDeniedState: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 46, weight: .semibold))
            Text("Camera")
                .font(.title2.weight(.semibold))
            Text("Allow camera access to observe handwritten work.")
                .font(.callout)
                .foregroundStyle(MTTheme.secondaryInk)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(MTTheme.ink)
        .padding(28)
        .background(MTTheme.notebookPaper, in: RoundedRectangle(cornerRadius: MTTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MTTheme.cardRadius, style: .continuous)
                .stroke(MTTheme.gridLine, lineWidth: 1)
        }
        .padding()
    }

    private var paperGuide: some View {
        Rectangle()
            .strokeBorder(MTTheme.notebookPaper.opacity(0.78), style: StrokeStyle(lineWidth: 2, dash: [12, 12]))
            .frame(maxWidth: 720, maxHeight: 500)
            .padding(.horizontal, 44)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var endButton: some View {
        Button {
            endSession()
        } label: {
            Image(systemName: "xmark")
        }
        .buttonStyle(MTIconButton(tint: MTTheme.errorRust))
        .accessibilityLabel("End session")
        .padding(18)
    }

    private var tutorDock: some View {
        VStack(spacing: 8) {
            if shouldShowHintNote {
                minimalHintNote
            }

            if isTeachMode && appModel.externalDisplay.isConnected {
                teachControlStrip
                    .padding(.bottom, 16)
            } else {
                liveControlStrip
                    .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 18)
    }

    private var shouldShowHintNote: Bool {
        if isTeachMode && appModel.externalDisplay.isConnected {
            return false
        }
        return errorMessage != nil || standController.state.lastError != nil || latestObservation != nil || studentConfused
    }

    private var liveControlStrip: some View {
        MTControlStrip {
            HStack(spacing: 8) {
                Button {
                    Task { await checkWork() }
                } label: {
                    Image(systemName: status == .thinking ? "hourglass" : "viewfinder")
                }
                .buttonStyle(MTIconButton(tint: MTTheme.chalkboardGreen))
                .disabled(status == .thinking || status == .paused)
                .accessibilityLabel(status == .thinking ? "Checking work" : "Check work")

                Button {
                    togglePause()
                } label: {
                    Image(systemName: status == .paused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(MTIconButton(tint: MTTheme.graphiteInk))
                .accessibilityLabel(status == .paused ? "Resume watching" : "Pause watching")

                Button {
                    markConfused()
                } label: {
                    Image(systemName: "questionmark")
                }
                .buttonStyle(MTIconButton(tint: MTTheme.chemicalGold))
                .disabled(status == .thinking)
                .accessibilityLabel("Ask a question")

                ExternalDisplayRouteButton(isConnected: appModel.externalDisplay.isConnected)

                #if targetEnvironment(simulator)
                ExternalDisplaySimulatorPreviewButton()
                #endif

                Button {
                    requestTeachMode()
                } label: {
                    Image(systemName: appModel.externalDisplay.isConnected ? "airplayvideo" : "rectangle.inset.filled.and.person.filled")
                }
                .buttonStyle(MTIconButton(tint: MTTheme.labGreen))
                .disabled(status == .thinking || !canRequestTeachMode)
                .accessibilityLabel(appModel.externalDisplay.isConnected ? "Show teach mode on external display" : "Enter teach mode")

                Button {
                    markSelfCorrected()
                } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(MTIconButton(tint: latestObservation == nil ? MTTheme.disabledGray : MTTheme.labGreen))
                .disabled(latestObservation == nil)
                .accessibilityLabel("Mark corrected")

                Button {
                    voice.speak(latestHint)
                } label: {
                    Image(systemName: "speaker.wave.2")
                }
                .buttonStyle(MTIconButton(tint: MTTheme.graphiteInk))
                .accessibilityLabel("Repeat hint")
            }
        }
    }

    private var teachControlStrip: some View {
        MTControlStrip {
            HStack(spacing: 8) {
                Button {
                    askTeachModeQuestion()
                } label: {
                    Image(systemName: "questionmark")
                }
                .buttonStyle(MTIconButton(tint: MTTheme.chemicalGold))
                .accessibilityLabel("Ask a question")

                Button {
                    returnToObserveMode()
                } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(MTIconButton(tint: MTTheme.labGreen))
                .accessibilityLabel("Understood")

                Button {
                    returnToObserveMode()
                } label: {
                    Image(systemName: "return")
                }
                .buttonStyle(MTIconButton(tint: MTTheme.graphiteInk))
                .accessibilityLabel("Return to work")

                if standController.state.currentMode == .teach {
                    Button {
                        standController.send(.stop)
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(MTIconButton(tint: MTTheme.errorRust))
                    .accessibilityLabel("Emergency stop holder")
                }
            }
        }
    }

    private var minimalHintNote: some View {
        HStack(spacing: 10) {
            Image(systemName: hintIcon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(hintTint)

            Text(visibleHint)
                .font(.callout.weight(.medium))
                .foregroundStyle(MTTheme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(MTTheme.paleYellowNote.opacity(0.96), in: RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous)
                .stroke(MTTheme.chemicalGold.opacity(0.55), lineWidth: 1)
        }
        .frame(maxWidth: 560)
    }

    private var teachModeView: some View {
        ZStack {
            MTBackground()

            VStack {
                HStack {
                    VoiceControlIndicator(snapshot: appModel.voiceRecognizer.snapshot)
                    Spacer()
                }

                Spacer()

                VStack(spacing: 26) {
                    ForEach(Array(teachModeLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 68, weight: .semibold, design: .serif))
                            .foregroundStyle(MTTheme.deepBlackGreen)
                            .lineLimit(1)
                            .minimumScaleFactor(0.42)
                            .accessibilityLabel(line)
                    }
                }
                .padding(.horizontal, 34)
                .frame(maxWidth: 960)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Math steps")

                Spacer()

                teachControlStrip
                    .padding(.bottom, 24)
            }
            .padding(MTTheme.pagePadding)
        }
        .onAppear {
            teachModeVariant = 0
        }
    }

    private var visibleHint: String {
        if let errorMessage {
            return errorMessage
        }
        if let standError = standController.state.lastError {
            return standError
        }
        return latestHint
    }

    private var hintIcon: String {
        if errorMessage != nil || standController.state.lastError != nil {
            return "exclamationmark.triangle"
        }
        if studentConfused {
            return "questionmark"
        }
        return "lightbulb"
    }

    private var hintTint: Color {
        if errorMessage != nil || standController.state.lastError != nil {
            return MTTheme.errorRust
        }
        if studentConfused {
            return MTTheme.chemicalGold
        }
        return MTTheme.chalkboardGreen
    }

    private var canRequestTeachMode: Bool {
        Date().timeIntervalSince(lastTeachModeRequest) >= teachModeCooldown
    }

    private var voiceRouteContext: VoiceRouteContext {
        VoiceRouteContext(
            location: isTeachMode ? .teachMode : .liveSession,
            sessionStatus: status,
            canEnterTeachMode: canRequestTeachMode,
            holderControlsActive: true
        )
    }

    private var teachModeLines: [String] {
        if teachModeVariant == 1 {
            return alternateTeachModeLines
        }

        switch latestObservation?.misconceptionType {
        case .signError:
            return ["-2x + 5 = 11", "-2x = 6", "x = -3"]
        case .equationBalance:
            return ["2x + 7 = 15", "2x = 15 - 7", "2x = 8", "x = 4"]
        case .invalidCancellation:
            return ["(x + 3) / x", "≠ 1 + 3", "= 1 + 3/x"]
        case .slopeIntercept:
            return ["y = mx + b", "y = 2x + 3", "m = 2", "b = 3"]
        case .factoring:
            return ["x² + 5x + 6", "= (x + 2)(x + 3)"]
        case .satStrategy:
            return ["2x + 6 = 18", "2(x + 3) = 18", "x + 3 = 9"]
        case .distribution, .unclearWork, .none:
            return ["3(x + 2)", "= 3x + 3·2", "= 3x + 6"]
        }
    }

    private var alternateTeachModeLines: [String] {
        switch latestObservation?.misconceptionType {
        case .signError:
            return ["-2x = 6", "x = 6 / -2", "x = -3"]
        case .equationBalance:
            return ["2x + 7 = 15", "-7        -7", "2x = 8"]
        case .invalidCancellation:
            return ["(x + 3) / x", "= x/x + 3/x", "= 1 + 3/x"]
        case .slopeIntercept:
            return ["y = 2x + 3", "rise / run = 2", "start = 3"]
        case .factoring:
            return ["2 · 3 = 6", "2 + 3 = 5", "(x + 2)(x + 3)"]
        case .satStrategy:
            return ["2x + 6 = 18", "2x = 12", "x = 6"]
        case .distribution, .unclearWork, .none:
            return ["3(x + 2)", "= (3·x) + (3·2)", "= 3x + 6"]
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
            latestHint = "Try steadying the iPad and checking again."
            status = .watching
        }
    }

    private func handleVoiceCommand() {
        guard let command = appModel.voiceRecognizer.lastRecognizedCommand else { return }
        let action = appModel.voiceRouter.route(command, in: voiceRouteContext)
        appModel.voiceRecognizer.recordRoutedAction(action.displayName)

        switch action {
        case .enterTeachMode:
            requestTeachMode()
        case .returnToWork, .confirmUnderstood:
            returnToObserveMode()
        case .nextStep, .differentWay:
            advanceTeachModeStep()
        case .repeatHint:
            voice.speak(latestHint)
        case .askQuestion:
            handleVoiceQuestion()
        case .pauseSession:
            if status != .paused {
                togglePause()
            }
        case .resumeSession:
            if status == .paused {
                togglePause()
            }
            Task {
                await appModel.voiceRecognizer.startListening()
            }
        case .emergencyStop:
            latestHint = "Holder stopped."
        case .startSession, .ignore(_):
            break
        }
    }

    private func markSelfCorrected() {
        guard var last = session.events.popLast() else { return }
        last.studentSelfCorrected = true
        session.events.append(last)
        studentConfused = false
        latestHint = "Keep the fixed line visible."
        voice.speak(latestHint)
    }

    private func markConfused() {
        studentConfused = true
        if let latestObservation {
            latestHint = "Compare this line with the previous line near \(latestObservation.misconceptionType.displayName.lowercased())."
        } else {
            latestHint = "Point to the line that feels uncertain."
        }
        voice.speak(latestHint)
    }

    private func handleVoiceQuestion() {
        appModel.voiceRecognizer.setQuestionMode(true)
        studentConfused = true

        if isTeachMode {
            askTeachModeQuestion()
            appModel.voiceRecognizer.setQuestionMode(false)
            return
        }

        latestHint = "I heard you. Checking this step."
        voice.speak(latestHint)

        Task {
            await checkWork()
            if errorMessage != nil {
                latestHint = "I can still help locally: compare this line with the one just above it."
                voice.speak(latestHint)
            }
            appModel.voiceRecognizer.setQuestionMode(false)
        }
    }

    private func requestTeachMode() {
        guard canRequestTeachMode else {
            latestHint = "Try the current hint first."
            voice.speak(latestHint)
            return
        }

        lastTeachModeRequest = Date()
        teachModeVariant = 0
        isTeachMode = true
        status = .paused
        if appModel.externalDisplay.isConnected {
            latestHint = "Teach Mode is on the display."
            appModel.showExternalTeachMode(student: student, lines: teachModeLines)
        }
        standController.send(.teachMode)
    }

    private func askTeachModeQuestion() {
        advanceTeachModeStep()
        latestHint = "Look at the changed line."
        voice.speak(latestHint)
    }

    private func advanceTeachModeStep() {
        teachModeVariant = (teachModeVariant + 1) % 2
        if appModel.externalDisplay.isConnected {
            appModel.updateExternalTeachMode(lines: teachModeLines)
        }
    }

    private func returnToObserveMode() {
        isTeachMode = false
        status = .watching
        standController.returnToObserve()
        appModel.clearExternalTeachMode()
        latestHint = "Continue from the corrected step."
        voice.speak(latestHint)
    }

    private func togglePause() {
        switch status {
        case .paused:
            status = .watching
            latestHint = "Watching again."
        case .watching, .hintReady:
            status = .paused
            latestHint = "Paused."
        case .thinking:
            return
        }
        voice.speak(latestHint)
    }

    private func endSession() {
        session.endedAt = Date()
        appModel.clearExternalTeachMode()
        appModel.finishSession(session)
    }
}
