import Foundation

// Raw pass-through helpers.
//
// The transcript is inserted verbatim: no LLM, HTTP, filler-word rules, or
// voice-command execution. `passThrough` is the byte-for-byte identity used
// by the raw cleanup stage; `isInsertable` rejects empty or meaningless output
// (e.g. a silence hallucination that is only punctuation) so nothing is inserted
// and the flow ends in a bounded failure instead.
public enum RawTranscriptPolicy {
    public static func passThrough(_ text: String) -> String { text }

    public static func isInsertable(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
    }
}
