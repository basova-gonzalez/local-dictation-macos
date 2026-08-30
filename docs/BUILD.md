# Build from source

## Requirements

- A Mac targeting macOS 14 or later. The current automated build runs on macOS 15; macOS 14 runtime compatibility has not yet been exercised separately.
- Xcode or Apple Command Line Tools with Apple Swift 6.2 or later and a macOS SDK that pass `scripts/check-toolchain.sh`.
- Exact Swift package resolution from `Package.resolved`.
- Locally provisioned model assets described in `MODEL_SETUP.md` for real dictation.

Hosted CI selects Xcode 26.2 explicitly instead of relying on the mutable default Xcode in the `macos-15` runner image.

## Headless build and tests

```bash
./scripts/check-toolchain.sh
./scripts/check-dependencies.sh
./scripts/run-core-tests-offline.sh
./scripts/run-tests.sh
./scripts/privacy-scan.sh
```

`run-core-tests-offline.sh` validates the dependency-free state machine without package resolution or network access. `run-tests.sh` performs the full pinned Swift Package build; on a clean machine SwiftPM must first fetch the source dependencies listed in `Package.resolved`. Neither command downloads model assets. The self-test executable does not open the microphone, Accessibility prompts, a GUI, or a model runtime.

## Local `.app` bundle

This source alpha does not distribute a signed or notarized binary. To build a local bundle, select one existing signing identity explicitly:

```bash
LOCAL_DICTATION_SIGN_IDENTITY="Your Existing Identity" ./scripts/build-app.sh
./scripts/smoke-launch.sh
```

The script does not create or trust a certificate and does not fall back to ad-hoc signing. Local signing is not Developer ID distribution. A downloadable application requires a separate Developer ID, hardened-runtime, notarization, and release review.

## First launch permissions

Before evaluating dictation, open the menu-bar app and grant both permissions:

- **Microphone** allows recording only during an explicit dictation gesture.
- **Accessibility** allows the app to capture the focused field and deliver insertion without submitting it.

The first gesture may only trigger the Microphone prompt and intentionally does not begin recording. After responding to a system prompt, focus the target field again before retrying.

Do not evaluate insertion while Accessibility is unavailable. The app can reach the guarded Command+V path, but macOS may reject event delivery; the bounded menu diagnostic can then describe the attempted path even though no text arrived. That outcome is not a successful smoke test. Grant Accessibility, refocus the target field, and retry.
