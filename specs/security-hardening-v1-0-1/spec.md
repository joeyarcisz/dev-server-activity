# Feature Specification: Security Hardening v1.0.1

**Status:** frozen
**Owner:** Joey Arcisz
**Project root:** `.`
**Feature slug:** `security-hardening-v1-0-1`

## Outcome and value

- User/customer outcome: Dev Server Activity stops only the exact process the user confirmed, remains responsive when macOS inspection tools misbehave, and ships without local-device metadata.
- Business/operational value: Protect the public project's trust, Joey's privacy, and the safety of the app's destructive action before further promotion.
- Why now: The first public security audit found a display identifier in tracked images, local archive metadata, a confirmation-target race, a pipe deadlock, incomplete process identity, and repository hardening gaps.
- Smallest valuable release: A verified `v1.0.1` direct release plus sanitized reachable Git history and enforced GitHub controls.

## Sources inspected

- Root instructions supplied to this Codex task.
- `README.md`, `SECURITY.md`, `PRIVACY.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, and `Package.swift`.
- `Sources/DevServerActivity/Stores/ServerActivityStore.swift` and `Sources/DevServerActivity/Views/ServerDetailView.swift`.
- `Sources/DevServerActivityCore/Models/DevServer.swift`, `ProcessSnapshot.swift`, and services under `Sources/DevServerActivityCore/Services/`.
- Tests under `Tests/DevServerActivityCoreTests/`.
- `.github/workflows/ci.yml`, `script/package_direct_release.sh`, `Config/app.env`, and the public GitHub repository/release configuration.
- Public branch `main` at `30933837e933043cc10ed39f764c52ef32972077` and `v1.0.0` at `203a52c38ab025c84478ae7511cb038d91ecc757`.

## Scope

### In scope

- Remove device-specific ICC, screenshot, username, quarantine, provenance, and AppleDouble metadata from published source and release artifacts.
- Bind each confirmation to an immutable `DevServer` snapshot.
- Drain subprocess output without pipe backpressure, enforce finite timeout/output limits, and keep blocking process inspection off the main actor.
- Capture and revalidate process birth identity before signaling.
- Add regression tests and repository-native privacy/release checks.
- Pin GitHub Actions, add Dependabot and CodeQL coverage, add release attestation, require signed Git history, and protect `main` after the rewrite.
- Produce, notarize, staple, publish, and verify `v1.0.1` after the final irreversible-action confirmation.

### Non-goals

- New server frameworks, automatic termination, telemetry, accounts, cloud services, privileged helpers, App Store distribution, Intel support, or unrelated visual redesign.
- Publishing credentials, signing keys, Keychain data, local paths, or internal receipts containing secrets.
- Claiming that history rewriting can erase copies already fetched by third parties.

## User journeys

### US1 — Confirm and stop the exact server

**Journey:** A user opens Stop or Force Stop for one server. Refreshes or selection changes cannot redirect that confirmation to another server.

**Independent test:** A frozen server snapshot is passed to termination; changed or unavailable process birth identity causes a fail-closed result with no signal.

**Acceptance scenarios:**

1. **Given** server A is confirmed and selection later points to server B, **when** the user accepts, **then** only server A's frozen identity is validated and B is never signaled.
2. **Given** the PID now represents another process birth, **when** Stop is accepted, **then** no signal is sent and the list refreshes.

### US2 — Keep scans responsive and bounded

**Journey:** A user refreshes while `lsof` emits large output or a child command stalls.

**Independent test:** A command producing more than pipe capacity completes without deadlock; a stalled command terminates within the configured timeout; scan work does not run on the main actor.

**Acceptance scenarios:**

1. **Given** output exceeds 65,536 bytes, **when** it is read, **then** the complete bounded output returns without deadlock.
2. **Given** a child exceeds the timeout or output limit, **when** it runs, **then** it is terminated and a typed error returns.

### US3 — Publish without local metadata

**Journey:** A developer clones or downloads the project and receives no device-specific display identity or embedded local packaging xattrs.

**Independent test:** Source-image checks, all-reachable-object scans, and expanded-release checks find no prohibited metadata while signature, staple, and Gatekeeper validation still pass.

**Acceptance scenarios:**

1. **Given** every tracked PNG and reachable public Git blob, **when** privacy checks run, **then** no device-specific ICC make/model serial or personal test username is found.
2. **Given** the public ZIP, **when** its stored entries and bytes are inspected, **then** no embedded AppleDouble, quarantine, or provenance metadata is present; the expanded app still passes Apple trust checks.

### US4 — Verify public supply-chain controls

**Journey:** A contributor or downloader can trace source, CI, tag, artifact digest, Apple signature, and GitHub attestation.

**Independent test:** Public API readback confirms protected `main`, required checks, signed commits/tags, restricted pinned Actions, enabled security analysis, and a verifiable attestation for the downloadable ZIP.

## Edge and failure states

- Empty state: Port-only records remain visible but cannot be stopped.
- Invalid input: Invalid PID, missing birth identity, empty command, missing expected port, malformed port, timeout, or oversized output fails closed.
- Permission/authorization failure: Process inspection failure falls back to read-only port probes; release/GitHub mutation stops without partial publication.
- Dependency/network failure: Notarization, GitHub publication, attestation, or public-download verification failure leaves the previous public release available and blocks promotion.
- Duplicate/retry/idempotency behavior: Refresh and Stop cannot run duplicate destructive operations; release paths refuse overwrite; GitHub controls are read back after mutation.
- Partial completion or rollback behavior: No public history or release is replaced until code, tests, metadata checks, signing, notarization, and the exact mutation packet pass locally.
- Accessibility/non-happy path: Stop controls disable while a stop is in flight and explain when a process cannot be safely identified.

## Requirements

- **FR-001:** All published PNGs must use a generic sRGB representation and contain no device-specific ICC make/model serial, XMP, or screenshot user comment.
- **FR-002:** Reachable public Git history must not contain the identified display profile or the local username fixture.
- **FR-003:** Release ZIPs must contain no `__MACOSX`/AppleDouble entries or embedded quarantine/provenance xattr records and must continue to pass Apple signature, staple, and Gatekeeper checks.
- **FR-004:** A Stop confirmation must carry the exact immutable server snapshot shown when the dialog opened.
- **FR-005:** A stoppable server must include a process birth identity, and the terminator must compare it again immediately before signaling.
- **FR-006:** Command execution must concurrently drain output, enforce timeout and output bounds, and return typed failures without indefinite blocking.
- **FR-007:** Scan and termination work must execute outside the main actor while UI state updates remain main-actor isolated.
- **FR-008:** Tests must cover large output, timeout, output limit, missing/mismatched birth identity, exact signal behavior, and existing fail-closed cases.
- **FR-009:** GitHub Actions must use full commit SHAs; Dependabot and CodeQL must cover Actions/Swift; release attestation must bind the ZIP digest to the release ref.
- **FR-010:** Public `main` and release tags must be protected after the rewrite; force pushes/deletions must be blocked; commits and tags must be verifiably signed.
- **FR-011:** Version, changelog, security/privacy documentation, and release instructions must accurately describe `v1.0.1` behavior and proof.

## Data and interface entities

- `ProcessIdentity`: PID birth timestamp used only for local equality checks; never persisted or transmitted.
- `DevServer`: immutable scan snapshot including optional identity; stoppable only when identity is present.
- `StopRequest`: UI-held exact server snapshot and mode.
- `CommandRunnerError`: source-compatible legacy nonzero-exit failure; `CommandExecutionError`: typed launch, timeout, output-limit, read, and UTF-8 failures.
- Release proof: ZIP, SHA-256, verification receipt, Apple notarization result, signed tag, and GitHub artifact attestation.

## Clarifications and assumptions

| ID | Question or assumption | Why it matters | Resolution/source | Status |
| --- | --- | --- | --- | --- |
| C-001 | What identifies a process birth? | PID alone can be reused. | Use macOS `proc_pidinfo(PROC_PIDTBSDINFO)` start seconds/microseconds. Verified available on the supported macOS floor. | resolved |
| C-002 | What happens when birth identity is unavailable? | Continuing would weaken the safety contract. | Display the process but disable Stop/Force Stop and explain that identity is unverified. | resolved |
| C-003 | Can public history be rewritten automatically? | It is destructive and changes commit/tag identities. | Prepare and verify locally; require exact final confirmation before force-push/tag/release mutation. | resolved |
| C-004 | Can signing credentials enter the repository? | Credential exposure would defeat the remediation. | No. Apple credentials remain in Keychain; Git signing uses a dedicated key registered only at the final external gate. | resolved |

## Measurable success

- **SC-001:** `swift test`, warning-as-error Release build, ShellCheck, actionlint, plist checks, and privacy audit all pass.
- **SC-002:** A greater-than-64-KiB subprocess output regression test completes and a stalled process returns within the configured bound.
- **SC-003:** No signal recorder call occurs for missing/mismatched process identity or changed target data.
- **SC-004:** Every reachable public Git object and downloaded release artifact passes the privacy/secret scan.
- **SC-005:** Downloaded `v1.0.1` passes checksum, `codesign`, `stapler`, `spctl`, and GitHub attestation verification.
- **SC-006:** GitHub API readback confirms the intended branch, Action, security-analysis, and tag protections.

## Authority and approval boundaries

- Decisions the agent may make: focused local implementation, tests, docs, privacy-preserving media conversion, build validation, and preparation of a replacement history/release packet.
- Decisions requiring the owner: the exact force-push/history replacement, tag deletion/move, release deletion/replacement, signing-key registration, and public GitHub security-setting mutations.
- External, destructive, financial, legal, or public actions excluded from implementation: publication before the final exact-target confirmation; unrelated account/repository changes.

## Freeze record

- Frozen by: Codex for Joey Arcisz
- Frozen at: 2026-08-27T21:38:50Z
- Git branch/commit/worktree: `security/remediation-v1.0.1` at `30933837e933043cc10ed39f764c52ef32972077`, clean checkout of `joeyarcisz/dev-server-activity`
- Changes after freeze require: source-backed contradiction or Joey's explicit direction.
