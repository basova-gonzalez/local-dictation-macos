# Multilingual promotion gate

`v0.1.0` is configured and verified for Russian with `language = ru`. Verified support for English, Spanish, and automatic language detection is not part of the release claim and must remain unavailable until this separate gate passes.

## Modes

- Russian
- English
- Spanish
- Auto, tested against all three language sets

## Fixtures

For each explicit language, use at least five fixed non-personal live recordings on the same pinned model assets, application build, wired input route, and Notes target. Include one quiet phrase and one phrase containing a technical term. Do not store the audio, transcript, clipboard, or field content; retain only fixture ID, aggregate PASS/FAIL, content-free failure stage, detected language, and latency.

## PASS

- Explicit mode: 5/5 recorder → transcription → exactly one insertion.
- Auto: correct language selection and exactly one insertion for every fixture in all three language sets.
- The expected fixed phrase is manually judged acceptable without publishing an accuracy percentage.
- No Enter/Return or automatic submission.
- One undo removes the insertion where the target supports it.
- Temporary audio is absent after every outcome.
- Offline runtime and privacy gates remain green.

If a mode fails, it remains unavailable rather than being advertised as best effort. Do not publish WER or accuracy claims without a separately versioned reference corpus and scoring method.
