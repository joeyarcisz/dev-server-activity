# Changelog

All notable changes to Dev Server Activity are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases use [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-09-23

### Changed

- Redesigned the native window with adaptive light and dark appearances, clearer server identity, and readable project paths and commands.
- Moved search into the compact server sidebar and kept the selected server synchronized with visible search results.
- Kept Stop and Force Stop visible at the minimum window size, with distinct controls and the existing confirmation and process-identity safeguards.
- Improved Auto refresh toolbar spacing and control sizing.
- Updated the GitHub introduction with the zombie-server campaign and added development-only native UI previews with synthetic data.

### Fixed

- Omitted debug path metadata from release builds with newer SwiftPM build engines.
- Supported both native and Swift Build module layouts in the public API compatibility check.

## [1.0.1] - 2026-08-27

### Security

- Bound each destructive confirmation to the exact server displayed in the dialog.
- Added process launch-time identity checks before validation and immediately before signaling to fail closed across PID reuse.
- Moved process inspection and termination off the main actor.
- Drained command output concurrently and added bounded execution time and output size.
- Replaced device-specific image color profiles and removed screenshot metadata from public assets.
- Removed embedded AppleDouble, quarantine, provenance, and download-origin metadata from public release ZIPs.
- Pinned GitHub Actions to immutable commits and added CodeQL, Dependabot, source-artifact auditing, and release-verification attestations.

## [1.0.0] - 2026-08-26

### Added

- Native SwiftUI interface for inspecting current-user local dev servers.
- Recognition for Vite, Next.js, Node.js, Python, Ruby, PHP, Bun, and Deno processes.
- Project, process, command, PID, host, and listening-port details.
- Search, manual refresh, six-second auto-refresh, and localhost opening.
- Confirmed normal Stop (`SIGTERM`) and Force Stop (`SIGKILL`) actions.
- Pre-signal command-line and listening-port revalidation.
- Read-only common-port fallback when macOS does not expose process details.
- Developer ID signing, Apple notarization, stapling, and Gatekeeper verification for the Apple-silicon release.

[Unreleased]: https://github.com/joeyarcisz/dev-server-activity/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/joeyarcisz/dev-server-activity/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/joeyarcisz/dev-server-activity/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/joeyarcisz/dev-server-activity/releases/tag/v1.0.0
