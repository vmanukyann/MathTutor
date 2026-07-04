import SwiftUI
import UIKit

struct LiveTutorSessionView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.scenePhase) private var scenePhase

    let student: StudentProfile

    @StateObject private var camera = CameraObservationService()
    @ObservedObject private var voice: VoiceTutor
    @ObservedObject private var standController: StandController
    @ObservedObject private var voiceRecognizer: VoiceCommandRecognizer

    @State private var session: TutoringSession
    @State private var status: SessionStatus = .watching
    @State private var latestHint = "Place the iPad above the page. I will watch quietly until you ask me to check."
    @State private var latestHintPresentation: HintPresentation?
    @State private var latestSpokenHint: String?
    @State private var latestObservation: TutorObservation?
    @State private var errorMessage: String?
    @State private var checkFailure: CheckFailure?
    @State private var airPlayMessage: String?
    @State private var showingScreenMirroringHelp = false
    @State private var studentConfused = false
    @State private var isTeachMode = false
    @State private var lastTeachModeRequest = Date.distantPast
    @State private var lastCheckRequest = Date.distantPast
    @State private var teachModeVariant = 0
    @State private var microphoneEnabled = true
    @State private var activeCheckID: UUID?

    private let tutorClient = SupabaseTutorClient(configuration: AppSecrets.supabase)
    private let policy = TutorPolicy(noAnswerMode: true)
    private let teachModeCooldown: TimeInterval = 8
    private let checkWorkCooldown: TimeInterval = 1.5

    init(
        student: StudentProfile,
        standController: StandController,
        voiceRecognizer: VoiceCommandRecognizer,
        voice: VoiceTutor
    ) {
        self.student = student
        _standController = ObservedObject(wrappedValue: standController)
        _voiceRecognizer = ObservedObject(wrappedValue: voiceRecognizer)
        _voice = ObservedObject(wrappedValue: voice)
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
            UIApplication.shared.isIdleTimerDisabled = true
            voice.onSpeechStarted = {
                voiceRecognizer.setTutorSpeaking(true)
            }
            voice.onSpeechFinished = {
                voiceRecognizer.setTutorSpeaking(false)
            }
            await camera.start()
            await voiceRecognizer.ensureListening()
            microphoneEnabled = voiceRecognizer.snapshot.permissionStatus == .authorized
                && voiceRecognizer.snapshot.isMicrophoneAuthorized
            standController.send(.observeMode)
        }
        .onChange(of: voiceRecognizer.commandEventID) { _, _ in
            handleVoiceCommand()
        }
        .onChange(of: appModel.externalDisplay.isConnected) { _, isConnected in
            if isConnected, latestObservation != nil {
                appModel.showExternalTeachMode(student: student, lines: teachModeLines)
            } else if !isConnected {
                appModel.clearExternalTeachMode()
            }
            airPlayMessage = isConnected
                ? "AirPlay connected. Show Step will use the TV."
                : "AirPlay disconnected. Tap AirPlay and choose your TV."
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, microphoneEnabled else { return }
            Task {
                await voiceRecognizer.ensureListening()
                microphoneEnabled = voiceRecognizer.snapshot.permissionStatus == .authorized
                    && voiceRecognizer.snapshot.isMicrophoneAuthorized
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            activeCheckID = nil
            camera.stop()
            voice.stop()
            voiceRecognizer.stopListening()
            standController.returnToObserve()
            appModel.clearExternalTeachMode()
        }
        .alert("Connect TV Display", isPresented: $showingScreenMirroringHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Open Control Center, tap Screen Mirroring, then choose your TV. Return to MathTutor when the TV shows the notebook background.")
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
                    .overlay(alignment: .top) {
                        topControlBar
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
        VStack(spacing: 12) {
            Text("Put your work inside the frame.")
                .font(.callout.weight(.semibold))
                .foregroundStyle(MTTheme.deepBlackGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(MTTheme.notebookPaper.opacity(0.96), in: RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous)
                        .stroke(MTTheme.gridLine, lineWidth: 1)
                }

            ScanFrameGuide()
                .aspectRatio(1.42, contentMode: .fit)
                .frame(maxWidth: 720)
        }
        .padding(.horizontal, 44)
        .padding(.bottom, 88)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var topControlBar: some View {
        HStack {
            scanStatusBadge
            Spacer()
            endButton
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }

    private var endButton: some View {
        Button {
            endSession()
        } label: {
            Label("End", systemImage: "xmark")
        }
        .buttonStyle(MTLabeledControlButton(tint: MTTheme.errorRust))
        .accessibilityLabel("End session")
    }

    private var tutorDock: some View {
        VStack(spacing: 8) {
            if !voice.isReady {
                Text(voice.voiceStatus)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MTTheme.deepBlackGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(MTTheme.notebookPaper.opacity(0.96), in: Capsule())
            }

            if shouldShowHintNote {
                minimalHintNote
            } else if !isTeachMode {
                scanCoachNote
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
        return errorMessage != nil
            || standController.state.lastError != nil
            || latestObservation != nil
            || studentConfused
            || airPlayMessage != nil
    }

    private var scanStatusBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: scanStatusSymbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(scanStatusTint)

            Text(scanStatusTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MTTheme.deepBlackGreen)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(MTTheme.notebookPaper.opacity(0.96), in: RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous)
                .stroke(scanStatusTint.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scan status: \(scanStatusTitle)")
    }

    private var scanCoachNote: some View {
        HStack(spacing: 9) {
            Image(systemName: "doc.viewfinder")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MTTheme.labGreen)
                .accessibilityHidden(true)

            Text(scanCoachText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MTTheme.deepBlackGreen)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(MTTheme.notebookPaper.opacity(0.96), in: RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous)
                .stroke(MTTheme.gridLine, lineWidth: 1)
        }
        .frame(maxWidth: 520)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(scanCoachText)
    }

    private var liveControlStrip: some View {
        MTControlStrip {
            VStack(spacing: 10) {
                Button {
                    Task { _ = await checkWork() }
                } label: {
                    Label(status == .thinking ? "Checking..." : "Check Work", systemImage: status == .thinking ? "hourglass" : "viewfinder")
                        .frame(minWidth: 220)
                }
                .buttonStyle(MTLabeledControlButton(fill: MTTheme.chalkboardGreen, isFilled: true))
                .disabled(status == .thinking)
                .accessibilityLabel(status == .thinking ? "Checking work" : "Check work")

                HStack(spacing: 8) {
                    Button {
                        requestTeachMode()
                    } label: {
                        Label("Show Step", systemImage: appModel.externalDisplay.isConnected ? "airplayvideo" : "rectangle.inset.filled.and.person.filled")
                    }
                    .buttonStyle(MTLabeledControlButton(tint: MTTheme.labGreen))
                    .disabled(status == .thinking || !canRequestTeachMode)
                    .accessibilityLabel(appModel.externalDisplay.isConnected ? "Show step on external display" : "Show step")

                    Button {
                        markSelfCorrected()
                    } label: {
                        Label("Mark Fixed", systemImage: "checkmark")
                    }
                    .buttonStyle(MTLabeledControlButton(tint: latestObservation == nil ? MTTheme.disabledGray : MTTheme.labGreen))
                    .disabled(latestObservation == nil)
                    .accessibilityLabel("Mark corrected")

                    Button {
                        toggleMicrophone()
                    } label: {
                        Label(
                            isMicrophoneActive ? "Mic On" : "Mic Off",
                            systemImage: isMicrophoneActive ? "mic.fill" : "mic.slash"
                        )
                    }
                    .buttonStyle(MTLabeledControlButton(tint: isMicrophoneActive ? MTTheme.labGreen : MTTheme.graphiteInk))
                    .accessibilityLabel(isMicrophoneActive ? "Turn microphone off" : "Turn microphone on")
                }

                HStack(spacing: 8) {
                    ExternalDisplayRouteButton(
                        isConnected: appModel.externalDisplay.isConnected,
                        onShowInstructions: showScreenMirroringInstructions
                    )

                    #if targetEnvironment(simulator)
                    ExternalDisplaySimulatorPreviewButton(previewLines: teachModeLines)
                    #endif

                    Button {
                        speakCurrentHint()
                    } label: {
                        Label("Repeat", systemImage: "speaker.wave.2")
                    }
                    .buttonStyle(MTLabeledControlButton(tint: MTTheme.graphiteInk))
                    .accessibilityLabel("Repeat hint")
                }
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
        ScrollView {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: hintIcon)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(hintTint)

                if let presentation = visibleHintPresentation {
                    CompactTutorHintView(
                        explanation: presentation.explanation,
                        action: presentation.action
                    )
                } else {
                    TutorHintView(content: visibleHint)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: 720, maxHeight: 240)
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

            if shouldShowScanAgain {
                Text("SCAN AGAIN")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(MTTheme.deepBlackGreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        returnToObserveMode()
                    }
                    .accessibilityLabel("Scan again. Tap to return to the camera.")
            } else {
                VStack {
                    Spacer()

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(Array(teachModeLines.enumerated()), id: \.offset) { index, line in
                                MathStepCard(
                                    number: index + 1,
                                    latex: line,
                                    fontSize: 32
                                )
                            }
                        }
                        .padding(18)
                    }
                    .padding(.horizontal, 34)
                    .frame(maxWidth: 960, maxHeight: 560)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Math steps")

                    Spacer()

                    teachControlStrip
                        .padding(.bottom, 24)
                }
                .padding(MTTheme.pagePadding)
            }
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
        if let airPlayMessage {
            return airPlayMessage
        }
        return latestHint
    }

    private var visibleHintPresentation: HintPresentation? {
        guard errorMessage == nil,
              standController.state.lastError == nil,
              airPlayMessage == nil,
              let latestHintPresentation,
              latestHint == latestHintPresentation.combinedText else {
            return nil
        }
        return latestHintPresentation
    }

    private var hintIcon: String {
        if errorMessage != nil || standController.state.lastError != nil {
            return "exclamationmark.triangle"
        }
        if airPlayMessage != nil {
            return appModel.externalDisplay.isConnected ? "airplayvideo.circle.fill" : "airplayvideo"
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
        if airPlayMessage != nil {
            return appModel.externalDisplay.isConnected ? MTTheme.labGreen : MTTheme.chemicalGold
        }
        if studentConfused {
            return MTTheme.chemicalGold
        }
        return MTTheme.chalkboardGreen
    }

    private var scanStatusTitle: String {
        if let checkFailure {
            switch checkFailure {
            case .couldNotRead:
                return "Could not read"
            case .backend:
                return "Backend error"
            }
        }

        switch status {
        case .watching:
            return "Listening"
        case .thinking:
            return "Checking"
        case .hintReady:
            return "Hint ready"
        }
    }

    private var scanStatusSymbol: String {
        if checkFailure != nil {
            return "exclamationmark.triangle"
        }

        switch status {
        case .watching:
            return "viewfinder"
        case .thinking:
            return "hourglass"
        case .hintReady:
            return "lightbulb"
        }
    }

    private var scanStatusTint: Color {
        if checkFailure != nil {
            return MTTheme.errorRust
        }

        switch status {
        case .watching:
            return MTTheme.labGreen
        case .thinking:
            return MTTheme.chemicalGold
        case .hintReady:
            return MTTheme.chalkboardGreen
        }
    }

    private var scanCoachText: String {
        if let checkFailure {
            switch checkFailure {
            case .couldNotRead:
                return "Line up the paper and try Check Work again."
            case .backend:
                return "MathTutor could not connect. Try again in a moment."
            }
        }

        switch status {
        case .watching:
            return "Put your work inside the frame, then tap Check Work."
        case .thinking:
            return "Hold still while MathTutor checks this step."
        case .hintReady:
            return "Read the hint, then tap Show Step or Mark Fixed."
        }
    }

    private var canRequestTeachMode: Bool {
        Date().timeIntervalSince(lastTeachModeRequest) >= teachModeCooldown
    }

    private var voiceRouteContext: VoiceRouteContext {
        VoiceRouteContext(
            location: isTeachMode ? .teachMode : .liveSession,
            canEnterTeachMode: canRequestTeachMode,
            holderControlsActive: true
        )
    }

    private var teachModeLines: [String] {
        if shouldShowScanAgain {
            return ["SCAN AGAIN"]
        }

        let sets = teachModeLineSets
        guard !sets.isEmpty else { return [] }
        return sets[teachModeVariant % sets.count]
    }

    private var shouldShowScanAgain: Bool {
        checkFailure == .couldNotRead
            || latestObservation?.misconceptionType == .unclearWork
    }

    private var teachModeLineSets: [[String]] {
        guard let latestObservation else { return [] }

        if let backendSteps = latestObservation.teachSteps?
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter({ !$0.isEmpty }),
            areValidTeachSteps(backendSteps) {
            return [backendSteps]
        }

        return []
    }

    private func areValidTeachSteps(_ steps: [String]) -> Bool {
        guard (1...3).contains(steps.count) else { return false }
        return steps.allSatisfy(LaTeXNormalizer.isMathOnlyExpression)
    }

    private func checkWork(studentQuestion: String? = nil) async -> Bool {
        guard status != .thinking else { return false }
        guard Date().timeIntervalSince(lastCheckRequest) >= checkWorkCooldown else { return false }

        let checkID = UUID()
        activeCheckID = checkID
        lastCheckRequest = Date()
        status = .thinking
        errorMessage = nil
        checkFailure = nil
        airPlayMessage = nil
        studentConfused = false
        latestHintPresentation = nil
        latestSpokenHint = nil
        latestHint = "Checking."
        voice.speak(latestHint)

        do {
            let imageData = try await camera.captureFrame()
            guard activeCheckID == checkID else { return false }
            let request = TutorObservationRequest(
                imageBase64: imageData.base64EncodedString(),
                student: student,
                checkNumber: session.events.count + 1,
                noAnswerMode: true,
                studentQuestion: studentQuestion
            )
            var observation = try await tutorClient.observeWork(request)
            guard activeCheckID == checkID else { return false }
            let sanitizedHint = policy.sanitizedHint(observation.hint)
            if sanitizedHint != observation.hint {
                observation.hintExplanation = nil
                observation.hintAction = nil
                observation.spokenHint = ""
            }
            observation.hint = sanitizedHint

            latestObservation = observation
            status = .hintReady

            if observation.misconceptionType == .unclearWork {
                latestHint = "I could not read a clear step yet. Try lining up the paper."
                checkFailure = .couldNotRead
            } else if observation.mistakeDetected {
                let presentation = SpokenHintPolicy.presentation(
                    explanation: observation.hintExplanation,
                    action: observation.hintAction,
                    legacyHint: observation.hint
                )
                latestHintPresentation = presentation
                latestSpokenHint = SpokenHintPolicy.playbackText(
                    spokenHint: observation.spokenHint,
                    presentation: presentation
                )
                latestHint = presentation.combinedText
            } else {
                latestSpokenHint = nil
                latestHint = "I do not see a clear issue yet."
            }

            session.events.append(
                TutorEvent(
                    observation: observation,
                    tutorMessage: latestHint
                )
            )
            if appModel.externalDisplay.isConnected {
                appModel.showExternalTeachMode(student: student, lines: teachModeLines)
            }

            speakHintWithDisplayGuidance()
            activeCheckID = nil
            return true
        } catch {
            guard activeCheckID == checkID else { return false }
            if error is CameraError {
                checkFailure = .couldNotRead
                latestHint = "I could not check it yet. Try lining up the paper."
            } else {
                checkFailure = .backend
                latestHint = "I could not check it yet. Try again in a moment."
            }
            latestHintPresentation = nil
            latestSpokenHint = nil
            errorMessage = latestHint
            status = .watching
            voice.speak(latestHint)
            activeCheckID = nil
            return false
        }
    }

    private func handleVoiceCommand() {
        guard let command = voiceRecognizer.lastRecognizedCommand else { return }
        let action = appModel.voiceRouter.route(command, in: voiceRouteContext)
        voiceRecognizer.recordRoutedAction(action.displayName)

        switch action {
        case .enterTeachMode:
            Task { await showHowToDoThis() }
        case .returnToWork, .confirmUnderstood:
            returnToObserveMode()
        case .nextStep, .differentWay:
            advanceTeachModeStep()
        case .repeatHint:
            speakCurrentHint()
        case .askQuestion:
            handleVoiceQuestion()
        case .checkWork:
            Task { _ = await checkWork() }
        case .confirmHearing:
            latestHint = "Yes, I can hear you."
            voice.speak(latestHint)
        case .connectAirPlay:
            handleVoiceAirPlayRequest()
        case .displayOnScreen:
            displayCurrentTeaching()
        case .markCorrected:
            markSelfCorrected()
        case .endSession:
            endSession()
        case .emergencyStop:
            latestHint = "Holder stopped."
        case .startSession, .ignore(_):
            break
        }
    }

    private func handleVoiceAirPlayRequest() {
        if appModel.externalDisplay.isConnected {
            airPlayMessage = "Screen connected. Say display this on the screen."
        } else {
            airPlayMessage = "Open Control Center, tap Screen Mirroring, and choose your TV."
        }
        latestHint = airPlayMessage ?? latestHint
        voice.speak(latestHint)
    }

    private func showScreenMirroringInstructions() {
        if appModel.externalDisplay.isConnected {
            airPlayMessage = "TV display connected."
        } else {
            showingScreenMirroringHelp = true
            airPlayMessage = "Use Screen Mirroring in Control Center to connect the TV."
        }
    }

    private func displayCurrentTeaching() {
        guard latestObservation != nil, !teachModeLineSets.isEmpty else {
            Task { await showHowToDoThis() }
            return
        }

        teachModeVariant = 0
        if appModel.externalDisplay.isConnected {
            appModel.showExternalTeachMode(student: student, lines: teachModeLines)
            latestHint = "Displayed on the screen."
            voice.speak(latestHint)
        } else {
            isTeachMode = true
            latestHint = "No TV screen is connected. Showing it on the iPad."
            voice.speak(latestHint)
            standController.send(.teachMode)
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

    private func handleVoiceQuestion() {
        voiceRecognizer.setQuestionMode(true)
        studentConfused = true

        if isTeachMode {
            askTeachModeQuestion()
            voiceRecognizer.setQuestionMode(false)
            return
        }

        Task {
            let question = voiceRecognizer.snapshot.lastTranscript
                .trimmingCharacters(in: .whitespacesAndNewlines)
            await showHowToDoThis(question: question.isEmpty ? nil : question)
            voiceRecognizer.setQuestionMode(false)
        }
    }

    private func requestTeachMode() {
        guard !teachModeLineSets.isEmpty else {
            latestHint = "I do not have a reliable step to show yet. Keep the mistaken line in view and check again."
            voice.speak(latestHint)
            return
        }
        guard canRequestTeachMode else {
            latestHint = "Try the current hint first."
            voice.speak(latestHint)
            return
        }

        lastTeachModeRequest = Date()
        teachModeVariant = 0
        isTeachMode = true
        if appModel.externalDisplay.isConnected {
            latestHint = "Teach Mode is on the display."
            appModel.showExternalTeachMode(student: student, lines: teachModeLines)
        } else {
            latestHint = "AirPlay is not connected. Look at the iPad screen for the math hint."
            voice.speak(latestHint)
        }
        standController.send(.teachMode)
    }

    private func showHowToDoThis(question: String? = nil) async {
        guard status != .thinking else { return }
        latestHint = "Let me look at this step."
        voice.speak(latestHint)

        let completed = await checkWork(studentQuestion: question)
        guard completed, latestObservation != nil, checkFailure == nil else { return }
        requestTeachMode()
    }

    private func speakHintWithDisplayGuidance() {
        speakCurrentHint()
    }

    private func speakCurrentHint() {
        if status == .hintReady,
           checkFailure == nil,
           let presentation = latestHintPresentation,
           latestHint == presentation.combinedText {
            voice.speak(
                latestSpokenHint ?? SpokenHintPolicy.playbackText(
                    spokenHint: nil,
                    presentation: presentation
                )
            )
            return
        }
        voice.speak(latestHint)
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

    private func endSession() {
        session.endedAt = Date()
        appModel.clearExternalTeachMode()
        appModel.finishSession(session)
    }

    private func toggleMicrophone() {
        if microphoneEnabled && voiceRecognizer.snapshot.isListening {
            microphoneEnabled = false
            voiceRecognizer.stopListening()
            return
        }

        if voiceRecognizer.snapshot.permissionStatus == .denied {
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
            return
        }

        microphoneEnabled = true
        Task {
            await voiceRecognizer.startListening()
            microphoneEnabled = voiceRecognizer.snapshot.permissionStatus == .authorized
                && voiceRecognizer.snapshot.isMicrophoneAuthorized
        }
    }

    private var isMicrophoneActive: Bool {
        microphoneEnabled && voiceRecognizer.snapshot.isListening
    }
}

private enum CheckFailure {
    case couldNotRead
    case backend
}

private struct ScanFrameGuide: View {
    private let cornerLength: CGFloat = 54
    private let cornerWidth: CGFloat = 4

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Rectangle()
                    .strokeBorder(MTTheme.notebookPaper.opacity(0.58), style: StrokeStyle(lineWidth: 1.4, dash: [10, 12]))

                corner(horizontal: .right, vertical: .down)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                corner(horizontal: .left, vertical: .down)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                corner(horizontal: .right, vertical: .up)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

                corner(horizontal: .left, vertical: .up)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }

    private func corner(horizontal: HorizontalDirection, vertical: VerticalDirection) -> some View {
        ZStack(alignment: .topLeading) {
            Capsule(style: .continuous)
                .fill(MTTheme.paleYellowNote.opacity(0.96))
                .frame(width: cornerLength, height: cornerWidth)
                .position(
                    x: horizontal == .right ? cornerLength / 2 : cornerLength / -2,
                    y: 0
                )

            Capsule(style: .continuous)
                .fill(MTTheme.paleYellowNote.opacity(0.96))
                .frame(width: cornerWidth, height: cornerLength)
                .position(
                    x: 0,
                    y: vertical == .down ? cornerLength / 2 : cornerLength / -2
                )
        }
        .frame(width: 1, height: 1)
        .shadow(color: .black.opacity(0.14), radius: 2, x: 0, y: 1)
    }

    private enum HorizontalDirection {
        case left
        case right
    }

    private enum VerticalDirection {
        case up
        case down
    }
}
