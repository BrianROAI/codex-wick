# Contributing

Thanks for helping improve Codex Wick.

## Development environment

- macOS 14 or later
- Swift 5.10 or later
- a locally installed Codex CLI for live acceptance

## Verify before proposing a change

Run `zsh scripts/verify.sh`.

For UI or transport changes, also verify the compact HUD, centered detail window, HUD restoration on close, light/dark consistency, functional chart colors, the two-wick visual invariant, a live authenticated sample, and absence of account IDs or credentials in newly persisted history.

## Product constraints

Preserve [AGENTS.md](../AGENTS.md). Do not add UI scraping when the local app-server is available, persist credentials/account identifiers, add remote telemetry without explicit product review, replace the independent lamp identity with OpenAI artwork, or describe ad-hoc signing as notarization.

## Pull requests

Explain user-facing behavior, privacy/security impact, verification performed, and app-server compatibility assumptions.
