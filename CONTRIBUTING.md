# Contributing

Local Dictation is a source-only experimental alpha under the MIT License. Contributions are welcome when they preserve its narrow, local-only scope. External model artifacts remain outside this repository and outside the license granted here.

- Keep normal runtime fully local and offline.
- Never add cloud speech services, analytics, telemetry, external endpoints, CORS, or arbitrary process execution.
- Never log audio, transcripts, prompts, clipboard data, user paths, or target content.
- Never synthesize Enter/Return or submit a form.
- Do not commit model files, tokenizer assets, audio, databases, settings, logs, credentials, or signing material.
- Add tests for both required behavior and the absence of forbidden behavior.
- Use only fixed non-personal fixtures in tests and issue reports.
