import Foundation

struct SimulatedStandController: Sendable {
    func run(
        _ command: StandCommand,
        from state: StandState,
        update: @MainActor @escaping (StandState) -> Void
    ) async {
        print("[MathTutor Stand] Simulated command: \(command.rawValue)")

        var moving = state
        moving.currentMode = command == .stop ? .stopped : .moving
        moving.lastCommand = command
        moving.isMoving = command != .stop
        moving.lastError = nil
        await update(moving)

        guard command != .stop else { return }

        try? await Task.sleep(nanoseconds: 650_000_000)

        var completed = moving
        completed.currentMode = finalMode(for: command)
        completed.isMoving = false
        completed.simulatedAngleDegrees = angle(for: command)
        await update(completed)
    }

    private func finalMode(for command: StandCommand) -> StandMode {
        switch command {
        case .teachMode, .pitchUpToStudent:
            return .teach
        case .observeMode, .returnToObserve, .pitchDownToPaper:
            return .observe
        case .center:
            return .stopped
        case .stop:
            return .stopped
        }
    }

    private func angle(for command: StandCommand) -> Double {
        switch command {
        case .teachMode, .pitchUpToStudent:
            return 15
        case .observeMode, .returnToObserve, .pitchDownToPaper:
            return -35
        case .center:
            return 0
        case .stop:
            return 0
        }
    }
}
