# Privacy

Dev Server Activity is a local macOS utility. It does not collect or transmit personal data.

## Data the app reads

To identify local development servers owned by the current user, the app invokes the macOS `lsof` and `ps` tools and reads:

- Process IDs.
- Process names, launch times, and command lines.
- Current working directories.
- TCP listening hosts and ports.

This information is displayed in the app and is not persisted by Dev Server Activity.

If process inspection is unavailable, the app can test a fixed list of common ports on `127.0.0.1`. Opening a server sends its `http://localhost:<port>` address to the user's default browser.

## Data the app does not send

The app contains no accounts, analytics, advertising, crash-reporting service, telemetry, cloud sync, or remote API. It does not upload process information or usage data.

## Process control

After user confirmation, Stop and Force Stop can send a local signal to the exact process shown in the confirmation. The app revalidates its launch identity, command line, and an expected listening port immediately before signaling.

## Contact

Questions about this policy can be sent to `intake@gearedlikeamachine.com`.
