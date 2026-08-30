# Source-only alpha v0.1.0 release checklist

## Repository

- [x] Fresh repository with no inherited private history.
- [x] Repository root is exactly this curated tree; the history gate inspects at least one commit and reports the count.
- [ ] Public repository URL and visibility verified.
- [x] MIT `LICENSE` selected by the owner and present.
- [x] Source-dependency licenses recorded; external model artifact explicitly excluded from distribution and license grant.
- [x] No internal prompts, incident history, private names, dashboard/runtime files, or user paths.

## Model boundary

- [x] Immutable Core ML artifact revision recorded.
- [x] Immutable tokenizer revision recorded.
- [x] Available model-card terms recorded; undeclared converted-artifact terms disclosed without asserting rights or redistributing files.
- [x] Exact file lists, sizes, LFS SHA-256 values, and Git blob identifiers present.
- [x] Provisioning verifies before and after copying.
- [x] Local Dictation source defines no intentional runtime network feature; model download is disabled and model/tokenizer folders are explicit and local.

## Automated gates

- [x] Apple Swift 6.2 minimum and package-manifest compatibility; hosted CI selects Xcode 26.2 explicitly.
- [x] Core `70/70`, release app build, and headless app self-check of forced language/model constants plus URLProtocol request classification (not live interception).
- [x] Clean-room build from an exact allowlist-only temporary export; Git checkout replay remains part of the history gate.
- [x] Privacy, secrets, network/process, event-synthesis, and artifact scans.
- [x] macOS 14 is disclosed as an unverified deployment target; current automated build evidence is from macOS 15.
- [x] Full Git history privacy scan.
- [ ] CI passes from a private remote rehearsal before repository visibility changes to public.
- [x] License gate.

## Manual Russian alpha gate

- [x] Microphone/Accessibility prerequisites and the missing-Accessibility false-positive boundary are documented.
- [x] Fresh locally signed source build.
- [x] Five fixed non-personal wired-microphone hold flows in Notes.
- [x] Every flow produces one insertion, no submission, and one undo.
- [x] Restart preserves expected permissions for the same local signature.
- [x] Temporary app audio is absent after success/failure observations; cancellation cleanup is structurally enforced and covered by the coordinator gate.
- [x] Bluetooth, WhatsApp, hands-free, verified multilingual support, binary, and production-support claims remain excluded.

## External actions

- [ ] Owner authorizes repository creation and publication.
- [ ] Private vulnerability reporting / GitHub Security Advisories is enabled and verified before public visibility.
- [ ] Owner authorizes profile/About updates.
- [ ] `CHANGELOG.md` replaces the `v0.1.0` `TBD` date with the actual release date.
- [ ] Tag and release notes say source-only experimental Russian alpha.
- [ ] No `.app`, Developer ID, notarization, or updater claim.
