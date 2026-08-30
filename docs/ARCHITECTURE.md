# Architecture

Local Dictation is a native macOS menu-bar application with one bounded flow:

```text
global hotkey
  → capture focused application/field
  → record current macOS default input
  → finalize and decode app-owned temporary WAV
  → delete WAV
  → local WhisperKit transcription (`ru`)
  → byte-identical pass-through
  → Accessibility insertion or guarded Command+V fallback
```

`LocalDictationCore` contains the state machine, component protocols, hotkey classification, insertion guards, and raw transcript policy. It imports neither AppKit nor WhisperKit.

`LocalDictation` contains AppKit UI and system adapters. It does not start child processes, load an LLM, persist dictated text, or expose an intentional runtime network path. WhisperKit model download is disabled, and the tokenizer path is local. A registered `URLProtocol` adds fail-closed handling for HTTP(S) routed through Foundation's shared/default loading system; custom session configurations are outside that guard's guarantee.

## Security invariants

- A normal run has no application downloader for model or tokenizer assets.
- WhisperKit receives explicit local model and tokenizer folders with model download disabled.
- The shared/default Foundation URL Loading System receives an additional fail-closed HTTP(S) guard before app startup; it is defense in depth rather than a general network sandbox.
- Missing or invalid local assets fail closed before transcription.
- Audio, transcript, clipboard, target metadata, hardware identifiers, and user paths are not logged.
- Only the guarded fallback may synthesize an event, and only Command+V.
- Enter/Return and form submission are structurally absent.
- A late result from a cancelled flow cannot reach insertion.
- Temporary audio cleanup runs on success, failure, cancellation, and startup.
