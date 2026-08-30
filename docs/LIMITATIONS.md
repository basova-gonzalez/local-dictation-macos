# Known limitations

- `v0.1.0` is configured and verified for Russian. The decoder forces `language = ru`.
- The package and bundle target macOS 14 or later, but current automated build evidence is from macOS 15 and macOS 14 runtime compatibility has not been exercised separately.
- Verified support for English, Spanish, and automatic language detection is not part of the release claim; those modes require the separate multilingual gate.
- The verified working baseline uses a wired external microphone. Bluetooth and multipoint route changes can leave macOS without a usable input endpoint; the app cannot create a missing system endpoint.
- WhatsApp insertion has a known unresolved target-specific failure and is not listed as supported.
- Compatibility is not guaranteed for every text field or application.
- Microphone and Accessibility permissions are prerequisites for the verified flow. Without Accessibility, the menu diagnostic may describe an attempted Command+V fallback even when macOS delivered no paste; this is not a successful insertion.
- Hold-to-talk is the public alpha claim. Double-press hands-free behavior exists but remains experimental until a separate manual gate is complete.
- A non-empty Whisper result proves only technical completion, not transcription correctness.
- No `.app` download, Developer ID signature, notarization, updater, or production support commitment is included.
