import AppKit
import Darwin

OfflineNetworkGuard.install()

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments == ["--self-check"] {
    var blockedEndpoint = URLComponents()
    blockedEndpoint.scheme = "https"
    blockedEndpoint.host = "invalid.local"
    blockedEndpoint.path = "/"
    guard
        WhisperModelConfig.language == "ru",
        WhisperModelConfig.modelIdentifier == "openai_whisper-large-v3-v20240930_turbo_632MB",
        let blockedURL = blockedEndpoint.url,
        OfflineNetworkGuard.canInit(with: URLRequest(url: blockedURL)),
        !OfflineNetworkGuard.canInit(
            with: URLRequest(url: URL(fileURLWithPath: "/dev/null"))
        )
    else {
        exit(EXIT_FAILURE)
    }
    exit(EXIT_SUCCESS)
}

guard arguments.isEmpty else {
    exit(EXIT_FAILURE)
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
