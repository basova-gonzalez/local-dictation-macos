# Local Dictation

[English (canonical)](README.md) · [Español](README.es.md) · [Русский](README.ru.md)

Local dictation for macOS, configured and verified for Russian. Hold a
hotkey, speak, and the raw Whisper transcript goes straight into the
focused text field — no cloud, no post-processing, no Enter key.

Audio and transcription stay on your Mac: the app runs WhisperKit
locally. The decoder is set to `language = ru`. Other languages have not
passed the project's acceptance gate and are not part of the v0.1.0
claim. Model weights and tokenizer files are not included in this
repository; you provision them yourself offline.

A local build needs both Microphone and Accessibility permission before
dictation. Grant them from the menu-bar app before evaluating insertion.

This experimental source-only alpha targets macOS 14 or later. Current
automated build evidence is from macOS 15; macOS 14 runtime compatibility
has not been exercised separately. There is no telemetry, no update
service, and no `.app` download. Read
[privacy](docs/PRIVACY.md), [build](docs/BUILD.md), and
[known limitations](docs/LIMITATIONS.md) before use.

English is the canonical version where translations differ.

## What it does

- Menu-bar app written in Swift and AppKit.
- Hold-to-talk with a configurable global hotkey.
- One local WhisperKit inference pass (`language = ru`).
- Byte-identical insertion of the raw transcript — no cleanup model,
  no dictionary, no history, no voice commands.
- Accessibility API insertion with a guarded Command+V fallback;
  Enter/Return is never synthesized.
- Temporary audio is deleted before transcription continues.

Double-press hands-free mode exists in the source but is experimental
and not a release claim.

## What's not included

- Model or tokenizer files — see [MODEL_SETUP.md](docs/MODEL_SETUP.md)
  for offline provisioning.
- A signed or notarized `.app` binary.
- Cloud transcription, analytics, telemetry, or an update service.
- Guaranteed Bluetooth, WhatsApp, or universal target-app compatibility.
- Verified support for English, Spanish, or automatic language detection.

## Status

`v0.1.0` is a source-only alpha under the [MIT License](LICENSE).
Model and tokenizer revisions are pinned to exact commit revisions
with complete integrity inventories, but the external files themselves
are neither included nor licensed by this project.

## Quick verification

```bash
./scripts/privacy-scan.sh
./scripts/check-dependencies.sh
./scripts/check-toolchain.sh
./scripts/run-core-tests-offline.sh
./scripts/run-tests.sh
```

The app never downloads a model at runtime. See
[MODEL_SETUP.md](docs/MODEL_SETUP.md) for the offline provisioning
boundary.

## License

Source code is available under the [MIT License](LICENSE). External
dependencies and model assets have their own terms; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
