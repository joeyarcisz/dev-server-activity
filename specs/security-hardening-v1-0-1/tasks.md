# Implementation Tasks: Security Hardening v1.0.1

**Spec:** `specs/security-hardening-v1-0-1/spec.md`
**Plan:** `specs/security-hardening-v1-0-1/plan.md`
**Frozen git fingerprint:** `security/remediation-v1.0.1` at `30933837e933043cc10ed39f764c52ef32972077`, initially clean

## Phase 1 — Reproduction and test contract

- [x] T001 [US1] Add failing process-birth identity tests in `Tests/DevServerActivityCoreTests/DevServerTerminatorTests.swift` — Proof: focused tests fail before implementation because identity is absent.
- [x] T002 [US2] Add failing large-output, timeout, and output-limit tests in `Tests/DevServerActivityCoreTests/ShellCommandRunnerTests.swift` — Proof: old runner hangs/fails the bounded contract under a test timeout.
- [x] T003 [P] [US3] Add `script/audit_public_artifacts.sh` to reject device profiles, personal fixture text, AppleDouble, quarantine, and provenance metadata — Proof: current source/release fails for the identified reasons.

**Checkpoint:** Each original finding has a reproducible failing or missing gate.

## Phase 2 — Blocking foundations

- [x] T004 [US1] Add `ProcessIdentity` and its macOS provider under `Sources/DevServerActivityCore/` — Proof: provider returns a stable identity for the current process.
- [x] T005 [US1] Carry identity through `ProcessSnapshot`, `DevServerScanner`, and `DevServer` — Proof: detector/scanner tests retain identity and port-only records cannot stop.
- [x] T006 [US2] Implement bounded concurrent output draining and typed timeout/output-limit errors in `ShellCommandRunner.swift` — Proof: T002 passes.

**Checkpoint:** Core identity and command foundations compile and pass focused tests.

## Phase 3 — P1 process-safety journey

- [x] T007 [US1] Revalidate birth identity immediately before signaling in `DevServerTerminator.swift` — Proof: changed/missing identity produces no signal.
- [x] T008 [US1] Replace selection-time termination with an immutable confirmation request in `ServerDetailView.swift` and exact-target store API — Proof: source passes the frozen server to termination.
- [x] T009 [US1/US2] Run scan/stop services through a non-main actor and prevent duplicate in-flight operations in `ServerActivityStore.swift` — Proof: build passes strict concurrency checks and UI state remains main-actor isolated.

**Checkpoint:** Stop/Force Stop can only target the confirmed process birth and cannot indefinitely block the UI.

## Phase 4 — Privacy, packaging, and repository controls

- [x] T010 [P] [US3] Convert every tracked PNG to generic sRGB, strip XMP/comments, regenerate `Assets/AppIcon.icns`, and replace the personal fixture username — Proof: source privacy audit passes with unchanged dimensions and inspected appearance.
- [ ] T011 [US3] Package final ZIPs without `__MACOSX`/AppleDouble entries and reject prohibited embedded xattr records in `script/package_direct_release.sh` — Proof: clean-archive dry run and Apple trust checks pass.
- [x] T012 [P] [US4] Pin every Action to a full SHA; add Dependabot, CodeQL, and exact-digest release-attestation workflows — Proof: actionlint passes and no mutable `uses:` remains.
- [x] T013 [P] Update version/changelog/security/privacy/contribution/distribution documentation for `v1.0.1` — Proof: documented claims match implementation and release gates.

**Checkpoint:** Source, workflows, docs, and release packaging are privacy-clean and reproducible.

## Phase 5 — Integration and release proof

- [x] T014 Run focused and complete Swift tests — Proof: all tests pass.
- [x] T015 Run warning-as-error Release build, ShellCheck, actionlint, plist, metadata, and secret scans — Proof: zero blocking findings.
- [ ] T016 Build Developer ID signed `v1.0.1`, notarize, staple, package, expand, and rerun trust checks — Proof: Accepted notarization, valid staple, Gatekeeper acceptance, clean ZIP.
- [ ] T017 Prepare a sanitized two-commit history, hardening commit, dedicated Git signing key plan, signed `v1.0.0`/`v1.0.1` tags, and public mutation manifest without pushing — Proof: fresh local clone contains no prohibited history and all signatures verify.
- [ ] T018 Independently inspect the complete diff, artifacts, and mutation manifest — Proof: checker returns PASS with exact hashes and no scope drift.

## Phase 6 — Final external gate

- [x] T019 Obtain exact confirmation for force-pushing `joeyarcisz/dev-server-activity/main`, moving/replacing `v1.0.0`, publishing `v1.0.1`, registering the signing key, and changing only that repository's security settings.
- [ ] T020 Execute the confirmed public mutations and read back branch/tag/release/settings state — Proof: public APIs and signed-out clone/download match the manifest.
- [ ] T021 Run public checksum, Apple trust, privacy, CI, CodeQL, and attestation verification — Proof: every public gate passes before promotion resumes.

## Dependencies and parallel lanes

| Task | Depends on | Parallel-safe with | Conflict risk |
| --- | --- | --- | --- |
| T004/T005/T007 | T001 | T003, T010, T012 | Shared core models/tests |
| T006/T009 | T002 | T010, T012 | Store consumes command behavior |
| T010/T011 | T003 | T004-T009, T012 | Packaging consumes sanitized assets |
| T012 | source inspection | T001-T011 | Workflow-only |
| T016 | T004-T015 | none | Release consumes committed clean tree |
| T017 | T010-T016 | none | History/tag identities depend on final tree |
| T020/T021 | T018/T019 | none | Public irreversible state |

## Stop and escalation conditions

Stop and report when:

- the spec, plan, and tasks conflict;
- source is no longer based on exact public HEAD;
- a required test cannot fail before or pass after the fix;
- process identity cannot be captured reliably on macOS 14;
- Apple signing/notarization or GitHub verification cannot be completed without exposing credentials;
- any proposed public mutation expands beyond `joeyarcisz/dev-server-activity`;
- a release or history scan still exposes prohibited metadata.
