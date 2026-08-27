# Contributing

Thanks for helping improve Dev Server Activity. Small, focused changes with clear evidence are easiest to review.

## Before opening a pull request

1. Search existing issues and pull requests.
2. Open an issue first for a new framework detector, a change to stop behavior, or a substantial interface change.
3. Keep the change limited to one problem.
4. Add or update tests for behavior changes.
5. Run the complete local checks.

```bash
swift test
swift build -c release
```

## Safety-critical changes

Code that selects or signals a process must fail closed. A pull request that changes termination behavior must prove that:

- An invalid or missing PID is never signaled.
- A changed command line is never signaled.
- A process that no longer owns an expected listening port is never signaled.
- A failed validation command is never treated as permission to continue.
- Normal Stop uses `SIGTERM` and Force Stop uses `SIGKILL`.

Use disposable processes in tests. Never use a contributor's real development server as an automated fixture.

## Detection changes

Include representative command lines and working directories in unit tests. Explain false-positive risks, especially for background system software that happens to use a recognized runtime.

## Pull requests

- Explain what changed and why.
- List the checks you ran and their real results.
- Include a screenshot for a visible interface change.
- Do not commit signing certificates, notarization credentials, Keychain exports, profiles, build products, or user-specific paths.

Maintainer signing and notarization are intentionally separate from contributor builds.
