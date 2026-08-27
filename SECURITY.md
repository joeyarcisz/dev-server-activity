# Security policy

Dev Server Activity inspects and can terminate local processes. Reports involving target selection, PID reuse, command validation, listening-port validation, signing, release integrity, or unexpected data transfer are treated as security-sensitive.

## Supported versions

Security fixes are provided for the current release. Older releases may not receive fixes.

## Report privately

Do not open a public issue for a vulnerability.

Use GitHub's [private vulnerability reporting form](https://github.com/joeyarcisz/dev-server-activity/security/advisories/new). If that form is unavailable, email `intake@gearedlikeamachine.com` with the subject `Dev Server Activity security report`.

Include:

- The app version and macOS version.
- Whether you used the official release or built from source.
- Clear reproduction steps using disposable processes.
- The expected and actual result.
- Relevant logs with personal paths, client names, tokens, and other secrets removed.

You should receive an acknowledgment within seven days. Please allow time to investigate and prepare a signed release before public disclosure.

This project does not currently operate a paid bug-bounty program.
