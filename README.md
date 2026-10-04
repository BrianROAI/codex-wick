# Codex Wick

<p align="center">
  <img src="docs/assets/codex-wick-icon.svg" width="180" alt="Codex Wick: ink-wash oil lamp with two rush wicks, one lit and one extinguished">
</p>

<p align="center"><strong>One Wick Is Enough.</strong><br><em>两根灯草，Codex 版。</em></p>

Codex Wick is a local-first macOS monitor for Codex purchased credits and included usage allowance.

The metaphor is simple: if one wick gives enough light, the second wick is wasted oil. Codex Wick makes AI compute burn visible enough to conserve it.

## Why Codex Wick Exists

We keep hearing that AI is taking us toward an age of abundance. My day-to-day experience often feels like the opposite: not enough time, money, disk space, memory, tokens, or credits.

The breaking point came after I exhausted my weekly Codex allowance and began drawing down 62,500 one-time credits from OpenAI. I went to sleep with about 50,000 credits remaining and woke up a few hours later with roughly 30,000. Then I watched another 10,000-plus disappear over the next couple of hours.

I had enough.

I do not mind heavy compute usage. I mind not knowing what is consuming it, how fast it is burning, or whether I have enough runway to reach the next reset.

Codex Wick exists to make that resource pressure visible.

**Abundance still needs stewardship.**

## Current capabilities

- Live purchased-credit balance
- 1-minute drawdown and normalized 1-minute burn rate
- Hourly burn rate and runway estimate
- 24-hour balance history with a separately colored dC/dt overlay
- Weekly and short-window allowance tracking
- Freshness telemetry with Updated / STALE / RETRY states
- Self-recovering, deadline-bounded Codex app-server polling
- Adaptive anomaly detection
- macOS notifications
- Menu-bar status
- Compact always-on-top HUD with centered detail window
- Dark mode by default; Light mode remains available and is remembered
- Animated in-app Wick mark with two rush wicks: one lit, one extinguished and smoking
- Local-only 30-day history
- No remote Codex Wick backend

## Requirements

- macOS 14 or later
- Swift 5.10 or later
- A locally installed Codex CLI
- An existing authenticated Codex session usable by `codex app-server`

Codex Wick does not collect or ask for an OpenAI API key.

## Build and install from source

```bash
git clone https://github.com/BrianROAI/codex-wick.git
cd codex-wick
zsh scripts/verify.sh
zsh scripts/install.sh
```

The app installs to `~/Applications/Codex Wick.app`.

The current install script builds locally and uses ad-hoc signing when available. It is not a Developer ID-signed or notarized public binary installer. See [Distribution](docs/DISTRIBUTION.md).

## How it works

Codex Wick starts the locally installed `codex app-server` over stdio, performs initialization, and reads `account/rateLimits/read`. Each protocol phase has a bounded deadline; if a probe hangs or fails, Codex Wick tears it down and allows the next polling cycle to recover automatically. It normalizes only fields needed for local monitoring and stores observations as JSONL. It does not scrape the ChatGPT or Codex UI.

## Local data and privacy

History is stored at `~/Library/Application Support/Codex Wick/observations.jsonl`.

Codex Wick stores balances, allowance percentages, reset timing, plan metadata, and observation timestamps. It does **not** persist OpenAI access tokens, cookies, session credentials, or account IDs.

See [Privacy](docs/PRIVACY.md) for the complete local-data contract.

## Security

Read [Security](docs/SECURITY.md) before reporting a vulnerability. Do not paste credentials, account identifiers, or private Codex output into a public issue.

## Development

Run `zsh scripts/verify.sh` before every release candidate.

See [Contributing](docs/CONTRIBUTING.md), [Architecture](docs/ARCHITECTURE.md), [Changelog](docs/CHANGELOG.md), and the [Public release checklist](docs/PUBLIC_RELEASE_CHECKLIST.md).

## Release status

Codex Wick is pre-1.0 software. It depends on the locally installed Codex app-server contract, which may evolve. A public release should be treated as a small independent utility, not as an OpenAI-supported integration.

## Philosophy

**No Two Wicks on Codex.**

The visual contract is deliberate: two rush wicks are shown, one burning and one extinguished with smoke rising.

## Third-party notice

Codex Wick is an independent third-party utility and is not affiliated with, endorsed by, or sponsored by OpenAI.

OpenAI, ChatGPT, Codex, and related names and marks belong to their respective owners. Codex Wick uses its own lamp-and-wick visual identity rather than reproducing an OpenAI app icon.
