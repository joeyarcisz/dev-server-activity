# Architecture

Dev Server Activity is a Swift Package with a SwiftUI executable and a separately testable core library. It has no third-party runtime dependencies.

## Scan flow

```text
lsof: current-user TCP listeners
            |
            v
     unique process IDs
            |
            +--> proc_pidinfo: launch identity
            +--> ps: command and arguments
            +--> lsof: working directory
            |
            v
   classify likely dev servers
            |
            v
   SwiftUI list and detail view
```

`DevServerScanner` asks `lsof` for current-user TCP listeners. It builds a `ProcessSnapshot` for each PID, then `DevServerDetector` classifies likely development runtimes and excludes known system or unrelated background paths.

If `lsof` cannot provide process information, `LocalPortProbeScanner` tests a fixed list of common ports on `127.0.0.1`. A fallback result has no PID or command identity, so it is read-only and the stop controls remain disabled.

## Stop flow

```text
user confirms frozen server target
            |
            v
same PID launch identity?
            |
            v
re-read exact PID command line
            |
            v
re-read listening ports for PID
            |
            v
same launch identity, command, and expected port?
       |                 |
      no                yes
       |                 |
refresh; no signal    SIGTERM or SIGKILL
```

`DevServerTerminator` does not trust a stale scan. It requires a positive PID, a recorded launch identity, a recorded command line, and at least one expected port. It checks launch identity before validation, requires the same command line and an expected listening port, then checks launch identity again immediately before signaling. A failed command, a missing process, or any identity mismatch stops the operation.

System-command output is drained while each command runs. Every command has a time limit and output-size limit, and scanning and termination run outside the main actor so a stalled system tool cannot freeze the interface.

Normal Stop sends `SIGTERM`. Force Stop sends `SIGKILL`.

## Targets

- `DevServerActivity`: SwiftUI app and presentation state.
- `DevServerActivityCore`: process scanning, parsing, classification, and termination.
- `DevServerActivityCoreTests`: deterministic detection and fail-closed termination tests.

## Distribution boundary

GitHub-hosted CI builds and tests unsigned source. Official binaries are produced separately by the maintainer because Developer ID signing and Apple notarization require private Keychain credentials. The release script refuses ad hoc signing or skipped notarization.
