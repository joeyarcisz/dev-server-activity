# Changelog

All notable changes to Dev Server Activity are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases use [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/joeyarcisz/dev-server-activity/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/joeyarcisz/dev-server-activity/releases/tag/v1.0.0
