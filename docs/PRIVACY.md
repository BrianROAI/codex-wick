# Privacy

Codex Wick is designed as a local-first utility.

## What Codex Wick reads

Codex Wick starts the locally installed `codex app-server` and calls `account/rateLimits/read` using the user's existing Codex authentication.

The response can include purchased-credit balance and state, allowance usage and reset timing, plan metadata, ordinary-usage state, and an account identifier supplied by the transport. Codex Wick discards the account identifier before creating the persisted observation record.

## What Codex Wick stores

Codex Wick writes normalized observations to `~/Library/Application Support/Codex Wick/observations.jsonl`.

The file can contain observation UUID/timestamp, credit balance and state flags, allowance percentages/reset timing, plan type, and ordinary-usage-allowed state. History is retained for up to 30 days in normal operation.

Codex Wick does **not** intentionally persist OpenAI access tokens, API keys, cookies, session credentials, account IDs, conversation content, prompts, or responses.

Older local data created by Codex Pulse may contain an `accountId` field. Current Codex Wick builds ignore that legacy field and do not write it into new observations.

## Network behavior

Codex Wick has no Codex Wick-operated remote backend and does not send its history to a Codex Wick service. The locally installed Codex CLI/app-server may communicate with OpenAI as part of its normal authenticated operation.

## Notifications

If enabled, Codex Wick can create local macOS notifications containing anomaly summaries. Notification permission is controlled by macOS.

## Deleting local data

Quit Codex Wick, then remove `~/Library/Application Support/Codex Wick/`. Removing the app from `~/Applications` does not automatically delete this local history.

## Public issue hygiene

Do not paste credentials, private account identifiers, raw authenticated app-server output, or private local history into a public GitHub issue.
