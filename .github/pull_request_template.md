## Summary

Describe the source change without including dictated text, recordings, clipboard contents, user paths, credentials, or private screenshots.

## Verification

- [ ] `./scripts/check-dependencies.sh`
- [ ] `./scripts/check-manifests.sh`
- [ ] `./scripts/privacy-scan.sh`
- [ ] `./scripts/run-tests.sh`
- [ ] The change adds no model/tokenizer assets, telemetry, external endpoint, arbitrary process launch, sensitive logging, Enter/Return synthesis, or auto-submit behavior.
- [ ] Any new language or target-app claim has its own documented gate and evidence.

## Scope

- [ ] Documentation only
- [ ] Core behavior
- [ ] macOS adapter/UI
- [ ] Build/CI/security
