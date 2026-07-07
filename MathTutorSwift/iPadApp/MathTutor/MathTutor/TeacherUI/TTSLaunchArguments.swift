import Foundation

struct TTSLaunchArguments {
    let rawArguments: [String]

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.rawArguments = arguments
    }

    static var arguments: [String] {
        ProcessInfo.processInfo.arguments
    }

    var pocketDiagnosticRequested: Bool {
        rawArguments.contains("--run-pocket-tts-diagnostic")
    }

    var requestedProvider: String? {
        Self.launchArgumentValue(named: "--tts-provider", arguments: rawArguments)?.lowercased()
    }

    var requestsPocketProvider: Bool {
        pocketDiagnosticRequested || requestedProvider == "pocket"
    }

    static var pocketWasRequested: Bool {
        TTSLaunchArguments().requestsPocketProvider
    }

    static func launchArgumentValue(
        named name: String,
        arguments: [String] = TTSLaunchArguments.arguments
    ) -> String? {
        if let inline = arguments.first(where: { $0.hasPrefix("\(name)=") }) {
            return String(inline.dropFirst(name.count + 1))
        }
        guard let index = arguments.firstIndex(of: name),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}
