# Architecture

Codex Wick is intentionally local-first. It does not scrape the ChatGPT or Codex UI and does not store OpenAI credentials.

## Data source

The collector starts the locally installed `codex app-server` over stdio, performs initialization, then calls `account/rateLimits/read`.

The response can contain an account identifier. Codex Wick may decode that transport field, but deliberately drops it before creating or persisting a `CodexObservation`.

## Sampling and persistence

The default sampling interval is 30 seconds. Normalized observations are appended to:

`~/Library/Application Support/Codex Wick/observations.jsonl`

The app retains the latest 30 days. Older Codex Pulse history may be copied once for migration. Unknown legacy fields, including an old `accountId`, are ignored and not written into new observations.

Persisted history contains monitoring fields such as timestamps, balances, allowance usage/reset timing, plan type, and ordinary-usage state. It does not intentionally contain tokens, cookies, session credentials, or account IDs.

## Metrics

Codex Wick derives current balance, 1-minute/1-hour drawdown, hourly burn rate, runway, allowance state, and a dC/dt overlay.

## Anomaly detection

The detector uses recent drawdown rates with a median/MAD baseline plus absolute and proportional safety floors. It also watches abrupt weekly-allowance jumps.

## UI model

The app launches with a compact floating HUD. Opening details hides the HUD and centers the detail window. Closing the detail window restores the HUD.

The in-app Wick mark uses SwiftUI `TimelineView` and `Canvas`: exactly two rush wicks, one flickering flame and one extinguished wick emitting smoke. Reduce Motion pauses the animation.

## Alerting

macOS local notifications are emitted for warning-or-higher events with a ten-minute de-duplication window unless severity escalates.

## Theme

Light/Dark appearance is synchronized across SwiftUI and AppKit. Functional colors remain stable: Credits blue, dC/dt orange-red, Weekly green, Short purple.
