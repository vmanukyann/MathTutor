import Foundation

public struct ExternalDisplayState: Equatable, Sendable {
    public private(set) var isConnected: Bool
    public private(set) var isTeaching: Bool
    public private(set) var studentName: String?
    public private(set) var mathLines: [String]
    public private(set) var statusNote: String
    public private(set) var updatedAt: Date

    public init(
        isConnected: Bool = false,
        isTeaching: Bool = false,
        studentName: String? = nil,
        mathLines: [String] = [],
        statusNote: String = "No display",
        updatedAt: Date = Date()
    ) {
        self.isConnected = isConnected
        self.isTeaching = isTeaching
        self.studentName = studentName
        self.mathLines = mathLines
        self.statusNote = statusNote
        self.updatedAt = updatedAt
    }

    public mutating func setConnected(_ connected: Bool, now: Date = Date()) {
        isConnected = connected
        if connected {
            if !isTeaching {
                statusNote = "Ready"
            }
        } else {
            clearTeachMode(now: now)
            return
        }
        updatedAt = now
    }

    public mutating func showTeachMode(studentName: String, lines: [String], now: Date = Date()) {
        self.studentName = studentName
        mathLines = lines
        isTeaching = true
        statusNote = "Teach Mode"
        updatedAt = now
    }

    public mutating func updateTeachMode(lines: [String], now: Date = Date()) {
        mathLines = lines
        isTeaching = true
        statusNote = "Teach Mode"
        updatedAt = now
    }

    public mutating func clearTeachMode(now: Date = Date()) {
        isTeaching = false
        studentName = nil
        mathLines = []
        statusNote = isConnected ? "Ready" : "No display"
        updatedAt = now
    }
}
