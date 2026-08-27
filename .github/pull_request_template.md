## What changed

Describe the focused change and the problem it solves.

## Evidence

- [ ] `swift test`
- [ ] `swift build -c release`
- [ ] Added or updated tests for behavior changes
- [ ] Added a screenshot for a visible interface change

List the actual results and any checks that were not run.

## Process-safety review

Explain whether this change affects detection, PID identity, command validation, port validation, Stop, or Force Stop. If it does, describe the fail-closed evidence.

## Scope and privacy

- [ ] The change is limited to the stated problem.
- [ ] No credentials, signing material, personal paths, client data, or build products are included.
