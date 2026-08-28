# Implementation Plan: Security Hardening v1.0.1

**Spec:** `specs/security-hardening-v1-0-1/spec.md`
**Spec status:** frozen
**Project root:** `.`
**Branch/worktree:** `security/remediation-v1.0.1`

## Summary

- Primary requirement: Remove public privacy metadata and make destructive process control exact, bounded, and independently verifiable.
- Technical approach: Add immutable process-birth identity and stop requests, run blocking services through an actor, bound command execution, sanitize media/packaging, and add pinned security workflows plus public readback checks.
- Smallest valuable implementation: Verified source and release candidate ready for the final public mutation gate.

## Current technical context

- Language/runtime: Swift 5.10, SwiftPM, macOS 14+.
- Frameworks: SwiftUI, Foundation, Network, Darwin/libproc.
- Storage/data: No app persistence; process data exists only in memory.
- APIs/integrations: `/usr/sbin/lsof`, `/bin/ps`, Darwin signals, `proc_pidinfo`, Apple notarization, GitHub Actions/API.
- Existing tests and commands: `swift test`, `swift build -c release`, `script/package_direct_release.sh`, ShellCheck, actionlint, plist checks.
- Deployment/activation path: Developer ID signed and notarized GitHub Release.
- Constraints: No App Sandbox, no new third-party runtime dependency, fail closed, no credentials in source, no public mutation before exact confirmation.

## Existing components to reuse

| Need | Existing definition/helper/pattern | Exact path | Decision |
| --- | --- | --- | --- |
| Process scan | `DevServerScanner` | `Sources/DevServerActivityCore/Services/DevServerScanner.swift` | extend |
| Signal validation | `DevServerTerminator` | `Sources/DevServerActivityCore/Services/DevServerTerminator.swift` | extend |
| Command execution | `CommandRunning` / `ShellCommandRunner` | `Sources/DevServerActivityCore/Services/ShellCommandRunner.swift` | harden |
| UI state | `ServerActivityStore` | `Sources/DevServerActivity/Stores/ServerActivityStore.swift` | make asynchronous and exact-target |
| Confirmation | `ServerDetailView` | `Sources/DevServerActivity/Views/ServerDetailView.swift` | freeze request |
| Release gate | direct-release script | `script/package_direct_release.sh` | harden |
| CI | current Swift workflow | `.github/workflows/ci.yml` | pin and extend |

## Project-doctrine check

- [x] Root task instructions and routed skills were read.
- [x] Current git state and exact public repository checkout were verified.
- [x] Source definitions, usages, tests, manifests, release scripts, and live GitHub evidence were inspected.
- [x] The plan preserves direct distribution, local-only privacy, and fail-closed termination.
- [x] No new runtime dependency, service, schema, hook, or unrelated behavior is introduced.

## Proposed design

### Interfaces and behavior

- Input: macOS process/listener snapshots and an exact user-confirmed `DevServer`.
- Output: bounded scan results or typed errors; one validated signal to the exact process birth.
- Errors/failure contract: missing identity, changed identity/command/port, command timeout/output overflow, or validation failure sends no signal.
- Permissions/authorization: current-user process access only; no elevation.
- Idempotency/retry behavior: one in-flight scan and one in-flight stop; safe refresh after success/failure.

### Data and migration

- Schema/state changes: in-memory `ProcessIdentity` added to `ProcessSnapshot` and `DevServer`; no persistence.
- Migration/backfill: none.
- Compatibility: source/API initializers gain an optional identity default only where needed for read-only probe records; stoppability requires identity.
- Data recovery/rollback: previous public objects are retained only in a non-pushed local backup ref while rewrite verification runs.

### Mutable surface

- `Sources/DevServerActivityCore/Models/ProcessIdentity.swift`: birth identity model/provider.
- `Sources/DevServerActivityCore/Models/ProcessSnapshot.swift` and `DevServer.swift`: carry identity.
- `Sources/DevServerActivityCore/Services/DevServerScanner.swift`, `DevServerTerminator.swift`, and `ShellCommandRunner.swift`: capture/revalidate identity and bound commands.
- `Sources/DevServerActivity/Stores/ServerActivityStore.swift` and `Views/ServerDetailView.swift`: asynchronous exact-target behavior.
- `Tests/DevServerActivityCoreTests/`: regression coverage.
- `Assets/AppIcon.iconset/*.png`, `Assets/AppIcon.icns`, `docs/images/dev-server-activity.png`, and fixture text: privacy cleanup.
- `script/package_direct_release.sh` and a repository audit script: clean archives and enforce proof.
- `.github/workflows/*.yml` and `.github/dependabot.yml`: pinned CI, CodeQL, and attestation.
- `Config/app.env`, `CHANGELOG.md`, `README.md`, `PRIVACY.md`, `SECURITY.md`, `CONTRIBUTING.md`, and distribution docs: v1.0.1 truth.
- Local rewritten refs/tags and public GitHub configuration only after final confirmation.

### Explicitly out of scope

- Detector feature expansion, automatic killing, telemetry, account systems, App Store variant, Intel build, and unrelated refactors.

## Test and verification plan

| Spec item | Test/proof | Command or inspection | Expected evidence |
| --- | --- | --- | --- |
| FR-004/005 | Terminator identity and exact-target tests | `swift test --filter DevServerTerminatorTests` | No signal on changed/missing identity; correct signal on match |
| FR-006/007 | Command runner large-output/timeout tests and source inspection | `swift test --filter ShellCommandRunnerTests`; actor isolation compile | No deadlock; bounded timeout; UI service off main actor |
| FR-001/002 | Source and reachable-object privacy audit | `./script/audit_public_artifacts.sh --source`; rewritten-clone scan | Generic sRGB only; prohibited bytes absent |
| FR-003 | Archive-entry inspection and Apple trust checks | release script plus decompressed ZIP-entry/path/metadata validation, `codesign`, `stapler`, `spctl` | Clean ZIP and trusted app |
| FR-008 | Complete suite | `swift test`; Release warnings-as-errors build | All tests/checks pass |
| FR-009/010 | Workflow validation and GitHub API readback | actionlint; GitHub API; `gh attestation verify` | Pinned Actions, protected refs, enabled analysis, valid attestation |

## Rollout and rollback

- Local verification: Complete all code, media, history, build, and release-candidate checks in the dedicated checkout.
- CI/merge path: Push rewritten sanitized history and hardening commit only after exact approval; require pinned CI and CodeQL.
- Deployment/activation: Publish signed/notarized `v1.0.1`, checksum, verification receipt, and attestation.
- Post-deploy verification: Fresh anonymous clone and download; rescan all objects/assets; rerun Apple/GitHub trust checks.
- Rollback trigger: Any privacy finding, wrong-process signal, failing trust check, failed attestation, or mismatched public digest.
- Rollback procedure: Do not restore privacy-leaking refs. Remove only the failed new release, keep the last verified binary temporarily if safe, repair locally, and repeat the gate.

## Complexity exceptions

| Exception | Why required | Simpler alternative rejected because | Owner/source |
| --- | --- | --- | --- |
| Rewrite two public commits | The device identifier exists in both reachable commits. | A normal cleanup commit leaves the identifier public in history. | Security audit and Joey approval gate |
| Process birth identity | PID/command/port cannot fully distinguish PID reuse. | Extra command/port checks still allow a replacement process with matching values. | Security audit |

## Handoff packet

- Objective: Produce a privacy-clean, fail-closed, bounded, notarized `v1.0.1` and exact public hardening packet.
- Allowed files: Mutable surface listed above plus these spec artifacts.
- Interfaces: `ProcessIdentity`, `DevServer`, `CommandRunning`, `DevServerScanner`, `DevServerTerminator`, `ServerActivityStore`, release scripts/workflows.
- Constraints and non-goals: No unrelated features, dependencies, credentials, or public mutation before confirmation.
- Verification commands: Commands listed in the test matrix plus anonymous public readback after publication.
