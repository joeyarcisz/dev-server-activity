# Direct distribution

Dev Server Activity ships through GitHub Releases as a Developer ID-signed and Apple-notarized direct download. It is intentionally not sandboxed: the full app must inspect current-user listening processes and send `SIGTERM` or `SIGKILL` to the exact server the user confirms.

## Supported release

- Bundle ID: `com.joeyarcisz.DevServerActivity`
- Version: `1.0.0` (`1`)
- Minimum macOS: 14.0
- Current binary architecture: Apple silicon (`arm64`)
- Distribution: [GitHub Releases](https://github.com/joeyarcisz/dev-server-activity/releases)

## Contributor builds

Contributors do not need release credentials.

```bash
swift test
./script/build_and_run.sh --verify
```

## Maintainer credential setup

The release command reads notarization credentials only from a named macOS Keychain profile. Create it interactively so no password appears in a command, file, log, or repository:

```bash
xcrun notarytool store-credentials "DevServerActivityNotary" \
  --apple-id "YOUR_APPLE_DEVELOPER_EMAIL" \
  --team-id "34M828S6C8"
```

Enter the Apple app-specific password only at the secure prompt.

## Build and notarize

The source tree must be clean and committed.

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Geared Like A Machine LLC (34M828S6C8)" \
NOTARY_PROFILE="DevServerActivityNotary" \
./script/package_direct_release.sh
```

The script has no unsigned or skip-notarization release mode. It must pass:

1. The complete Swift test suite.
2. An isolated Release build.
3. Developer ID signing with Hardened Runtime and a secure timestamp.
4. Exact team, entitlement, bundle, icon, privacy-manifest, version, architecture, and macOS-floor checks.
5. Apple notarization with status `Accepted`.
6. Stapling and stapler validation.
7. Gatekeeper acceptance.
8. ZIP expansion followed by repeated signature, staple, and Gatekeeper checks.
9. SHA-256 generation and a verification receipt.

Packaging does not prove behavior. Before publication, launch the expanded notarized app against disposable recognized servers and verify scan, Open, Stop, and Force Stop.

## Publish and verify

1. Create a version tag from the reviewed source commit.
2. Upload only the verified versioned ZIP and its `.sha256` file.
3. Download both assets from the public release URL without an authenticated GitHub session.
4. Compare the downloaded ZIP against the local canonical SHA-256.
5. Expand the downloaded ZIP and rerun `codesign`, `stapler`, and `spctl` checks.
6. Confirm that the release page, source tag, architecture, macOS requirement, and safety notes are accurate.

Do not call a local artifact, draft release, successful upload, or authenticated download a public release. The signed-out download and expanded artifact must pass the final checks.
