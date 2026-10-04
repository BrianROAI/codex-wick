# Security Policy

## Supported version

Codex Wick is pre-1.0 software. Security fixes are applied to the current development line.

## Security model

Codex Wick is a local macOS utility. It invokes the locally installed `codex app-server`, relies on existing Codex authentication, does not ask for or persist OpenAI API keys or session credentials, stores monitoring history locally, and has no Codex Wick-operated remote backend.

The main security boundary is to avoid turning local authentication or private app-server output into repository content, logs, telemetry, or support artifacts.

## Reporting a vulnerability

Do not publish credentials, account identifiers, private Codex output, or exploit details in a public issue.

Use GitHub's private vulnerability-reporting / security-advisory flow when available. Otherwise, open a minimal public issue asking for a private reporting channel without sensitive details.

## Out of scope

Distinguish Codex Wick behavior from vulnerabilities in macOS, the Codex CLI, the Codex app-server, or OpenAI services.
