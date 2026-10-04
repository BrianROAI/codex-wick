# Changelog

## v0.2.1 - 2026-10-04

### Added

- Glanceable 1-minute burn rate beside the hourly burn metric
- Live "Updated ..." freshness text in the detail view and compact HUD
- Explicit STALE / RETRY telemetry state when sampling falls behind or fails
- Reproducible owner-Mac hung-probe recovery verification script

### Fixed

- Replaced the blocking app-server pipe reader with an event-driven, deadline-bounded session
- A failed or timed-out Codex app-server probe can no longer latch refresh state indefinitely
- Polling now remains recoverable after a probe timeout instead of requiring an app restart

### Changed

- App-server client identity updated to Codex Wick 0.2.1
- Bundle identifier standardized on io.github.BrianROAI.codexwick
- Copyright metadata standardized on Codex Wick contributors
- Dark mode is now the default for users without a saved appearance preference

## v0.2.0 - 2026-10-04

### Added

- Compact always-on-top Wick HUD and centered detail window
- Functional chart colors for Credits, dC/dt, Weekly, and Short
- Light/dark synchronization across SwiftUI and AppKit
- Animated in-app oil-lamp mark with two rush wicks: one lit/flickering, one extinguished/smoking
- Reduce Motion support
- Public-release privacy, security, contribution, distribution, and release-readiness documentation

### Changed

- Product-facing naming standardized on Codex Wick
- Normalized history no longer persists account IDs
