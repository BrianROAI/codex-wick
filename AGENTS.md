# AGENTS.md

## Product intent

Codex Wick is a standalone, local-first macOS dashboard for continuous monitoring of Codex purchased credits and included allowance windows.

## Product invariants

- Prefer the authenticated local Codex app-server over UI scraping or credential handling.
- Never persist OpenAI access tokens, cookies, session credentials, or account identifiers.
- Preserve only normalized timestamped observations needed for monitoring.
- Treat purchased credits and included plan allowance as separate quantities.
- Keep adaptive anomaly detection plus absolute safeguards for abrupt drawdowns.
- Keep the app useful without a remote backend or paid third-party service.
- Preserve exactly two rush wicks: one lit, one extinguished with smoke rising.
- Respect macOS Reduce Motion.
- Keep Light/Dark appearance consistent across HUD, detail, Settings, and AppKit windows.

## Public-release constraints

- Do not commit secrets, user-specific filesystem paths, email addresses, account IDs, or captured private Codex output.
- Keep the OpenAI non-affiliation notice visible.
- Do not describe ad-hoc signing as Developer ID signing or notarization.
- A license must be explicitly selected before public visibility.
- Keep the public repository history free of personal commit-metadata email exposure.

## Verification

Run `zsh scripts/verify.sh`. On macOS also launch the app and verify a live `account/rateLimits/read` sample before integration or public release.
