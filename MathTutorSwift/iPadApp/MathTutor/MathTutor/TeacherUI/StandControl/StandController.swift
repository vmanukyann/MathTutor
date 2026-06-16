import Foundation
import Combine

@MainActor
final class StandController: ObservableObject {
    @Published var state = StandState()
    @Published var baseURLString = ""

    private let simulated = SimulatedStandController()

    var connectionMode: StandConnectionMode {
        configuredBaseURL == nil ? .simulated : .http
    }

    var configuredBaseURL: URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    func send(_ command: StandCommand) {
        Task { await perform(command) }
    }

    func returnToObserve() {
        send(.returnToObserve)
    }

    private func perform(_ command: StandCommand) async {
        if command == .stop {
            await runSimulatedStop()
            return
        }

        guard let baseURL = configuredBaseURL else {
            await simulated.run(command, from: state) { [weak self] newState in
                self?.state = newState
            }
            return
        }

        await runHTTP(command, baseURL: baseURL)
    }

    private func runHTTP(_ command: StandCommand, baseURL: URL) async {
        var moving = state
        moving.currentMode = .moving
        moving.lastCommand = command
        moving.isMoving = true
        moving.lastError = nil
        state = moving

        do {
            try await HTTPStandController(baseURL: baseURL).send(command)
            var completed = moving
            completed.currentMode = finalMode(for: command)
            completed.isMoving = false
            state = completed
        } catch {
            var failed = moving
            failed.currentMode = .error
            failed.isMoving = false
            failed.lastError = error.localizedDescription
            state = failed
        }
    }

    private func runSimulatedStop() async {
        await simulated.run(.stop, from: state) { [weak self] newState in
            self?.state = newState
        }
    }

    private func finalMode(for command: StandCommand) -> StandMode {
        switch command {
        case .teachMode, .pitchUpToStudent:
            return .teach
        case .observeMode, .returnToObserve, .pitchDownToPaper:
            return .observe
        case .center, .stop:
            return .stopped
        }
    }
}
