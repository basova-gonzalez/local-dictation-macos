import AVFoundation
import AppKit
import ApplicationServices
import LocalDictationCore

// Reads the live Microphone and Accessibility permission status and performs
// explicit, user-initiated permission requests. It never resets existing TCC
// grants and only prompts on an explicit user action.
final class SystemPermissionProvider: PermissionStatusProviding, @unchecked Sendable {
    func snapshot() -> PermissionsSnapshot {
        let microphone: PermissionState
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: microphone = .granted
        case .denied, .restricted: microphone = .denied
        case .notDetermined: microphone = .notDetermined
        @unknown default: microphone = .notDetermined
        }
        let accessibility: PermissionState = AXIsProcessTrusted() ? .granted : .notDetermined
        return PermissionsSnapshot(microphone: microphone, accessibility: accessibility)
    }

    // Explicit user action only. Shows the system microphone prompt on first use.
    @MainActor
    func requestMicrophone(_ completion: @escaping @MainActor (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            Task { @MainActor in completion(granted) }
        }
    }

    // Explicit user action only. Shows the system Accessibility prompt.
    @MainActor
    func requestAccessibilityPrompt() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

extension PermissionState {
    var russianLabel: String {
        switch self {
        case .granted: return "разрешено"
        case .denied: return "запрещено"
        case .notDetermined: return "не запрошено"
        }
    }
}
