# Local model setup

Model weights and tokenizer assets are deliberately excluded from Git. Normal application runtime has no model downloader: WhisperKit receives `download: false` plus explicit local model and tokenizer folders. Before WhisperKit starts, a registered `URLProtocol` also fails HTTP(S) routed through Foundation's shared/default loading system; this additional guard is not a general network sandbox.

## Pinned runtime dependency

- WhisperKit `0.13.0`
- Resolved commit `b3c412aa7520069f6c71f7cc217fbcf850ba31a1`
- Source: <https://github.com/argmaxinc/WhisperKit/tree/b3c412aa7520069f6c71f7cc217fbcf850ba31a1>
- License: MIT

## Pinned Core ML artifact

- Runtime identifier: `openai_whisper-large-v3-v20240930_turbo_632MB`
- Immutable revision: `4e186b908e840f4a90bce4fe58d86894cc97bef4`
- Exact folder: <https://huggingface.co/argmaxinc/whisperkit-coreml/tree/4e186b908e840f4a90bce4fe58d86894cc97bef4/openai_whisper-large-v3-v20240930_turbo_632MB>
- Runtime task: `transcribe`
- Runtime language: `ru`
- Integrity inventory: `model-manifests/whisper-large-v3-turbo.integrity.tsv`

The inventory covers every file and exact byte size. Hugging Face LFS payloads use publisher-provided SHA-256 values; regular Git files use their publisher-provided Git blob SHA-1 identifiers. The repository does not redistribute these files.

**External-artifact boundary:** the upstream OpenAI `whisper-large-v3-turbo` model card declares MIT, but the pinned `argmaxinc/whisperkit-coreml` repository does not declare separate terms for its converted Core ML artifacts. Local Dictation does not include, redistribute, sublicense, or grant rights to those files. The pinned link and integrity inventory are provided for reproducibility only; users must review and accept any applicable publisher terms before obtaining the artifact.

## Pinned tokenizer

WhisperKit `0.13.0` maps this model family to `openai/whisper-large-v3` and requires exactly `config.json`, `tokenizer_config.json`, and `tokenizer.json`.

- Immutable revision: `06f233fe06e710322aca913c1bc4249a0d71fce1`
- Source: <https://huggingface.co/openai/whisper-large-v3/tree/06f233fe06e710322aca913c1bc4249a0d71fce1>
- License: Apache-2.0
- Integrity inventory: `model-manifests/whisper-large-v3-tokenizer.integrity.tsv`

## Expected offline bundle layout

If you choose to obtain the external assets after reviewing their applicable terms, place them outside this repository in this structure:

```text
asset-bundle/
├── Models/
│   └── openai_whisper-large-v3-v20240930_turbo_632MB/
│       └── (the 22 manifest-listed files)
└── Tokenizers/
    └── models/openai/whisper-large-v3/
        ├── config.json
        ├── tokenizer.json
        └── tokenizer_config.json
```

Then verify and provision explicitly:

```bash
./scripts/verify-model-assets.sh /path/to/asset-bundle
./scripts/provision-model.sh /path/to/asset-bundle
```

The verifier rejects missing, changed, extra, or symlinked files. Provisioning refuses to overwrite an existing model or tokenizer directory, copies no unlisted file, and verifies the installed bundle again. It never downloads anything.
