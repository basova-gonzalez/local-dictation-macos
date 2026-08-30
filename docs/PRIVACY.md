# Privacy

Local Dictation is designed for local processing and human-controlled insertion.

## Data handling

- Microphone access begins only after an explicit dictation gesture.
- Audio is recorded to an app-owned temporary WAV, finalized, decoded to in-memory samples, and deleted before transcription continues.
- Transcription runs locally with pre-provisioned, integrity-checked WhisperKit model and tokenizer assets.
- Transcript text is kept only in memory for the active flow and is not stored in history.
- No analytics, telemetry, cloud transcription, or update service is present.
- Local Dictation source defines no intentional runtime network feature or external endpoint. WhisperKit model download is disabled explicitly, and tokenizer assets must come from the configured local folder.
- Before WhisperKit starts, a registered `URLProtocol` adds fail-closed handling for HTTP(S) routed through Foundation's shared/default loading system. This is defense in depth, not an OS firewall or a guarantee for arbitrary custom `URLSession` configurations.
- Diagnostic UI contains only bounded stage labels; it does not expose dictated content or user paths.

## Accessibility and clipboard

The application requires user-granted Accessibility permission to capture the focused field and deliver insertion reliably. It first attempts Accessibility insertion. When a captured field rejects that path, a guarded fallback temporarily snapshots the clipboard in memory, writes the transcript, synthesizes one Command+V, and restores the previous clipboard only if no external clipboard change occurred.

The fallback is not a substitute for granting Accessibility permission. Without that permission, macOS may reject event delivery even when the app records that it attempted the fallback path.

The application never synthesizes Enter/Return and never submits a form. Target-application behavior can vary, so users must verify inserted text and send it manually.

## Local files

Settings store only the selected hotkey and onboarding completion. Model assets live outside the repository in Application Support. The repository excludes audio, models, tokenizers, databases, logs, credentials, signing material, and local settings exports.
