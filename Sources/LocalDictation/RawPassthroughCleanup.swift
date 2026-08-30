import Foundation
import LocalDictationCore

// Raw pass-through. Returns the Whisper transcript byte-for-byte with no
// LLM, HTTP request, filler-word rule, or voice-command execution.
// The coordinator hides the "cleaning" overlay for it so the
// user is never told a cleanup happened.
struct RawPassthroughCleanup: CleanupComponent {
    func cleanup(_ transcript: Transcript) async throws -> CleanedText {
        CleanedText(text: RawTranscriptPolicy.passThrough(transcript.text))
    }
}
