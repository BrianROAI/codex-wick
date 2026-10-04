# Public Release Checklist

This checklist is the source-first release gate for Codex Wick.

## Repository hygiene

- [x] Public repository history is independent of private development history
- [x] Product-facing docs use the Codex Wick name
- [x] Public bundle metadata uses `io.github.BrianROAI.codexwick` and `Codex Wick contributors`
- [x] Public privacy, security, contribution, architecture, distribution, and release-readiness docs exist
- [x] OpenAI non-affiliation notice is present
- [x] Account IDs are excluded from newly persisted observations
- [x] MIT license selected
- [x] Public commits use the repository's GitHub identity rather than personal email metadata
- [x] Exact v0.2.1 public release candidate passed the final secret / PII / local-path scan

The final scan found no personal name/email, private development repository name, employer/location strings, absolute user paths, private IPs, API keys, GitHub tokens, private keys, or bearer tokens. The only `Reason ONE|reasonone` match was the intentional negative guard in `scripts/verify.sh`; release metadata itself remained sanitized.

## v0.2.1 product acceptance

- [x] Owner-Mac source candidate passed 7/7 core checks
- [x] Owner-Mac source candidate passed strict concurrency with warnings as errors
- [x] Owner-Mac fault injection proved a hung first probe is terminated and the same Codex Wick process automatically recovers on the next poll
- [x] Owner visually accepted Dark-by-default appearance, 1-MIN BURN placement/dynamics, and freshness / STALE presentation
- [x] Exact public release-candidate SHA passed `zsh scripts/verify.sh`
- [x] Exact public release-candidate SHA passed `zsh scripts/verify-recovery.sh`
- [x] Fresh public clone passed the source build/install smoke test

Exact tested public RC:

- RC commit: `853ad9d8f1e5d139d75badac09030e08af6538fd`
- RC tree: `59090ea8be5886ce6097aa7c49d045814b6fd586`
- Public RC branch: `release/v0.2.1-rc1-20261004` (deleted after release)

## Distribution

- [x] Source-first build/install path documented
- [x] v0.2.1 remains source-first
- [ ] If a prebuilt binary is added later, complete Developer ID signing and notarization first

## Release

- [x] Merge the accepted public v0.2.1 release candidate to `main`
- [x] Tag the exact accepted source as `v0.2.1`
- [x] Create the GitHub release with source-only assets
- [x] Re-test the tagged public clone/build path

Authoritative public release state:

- Public `main`: `8a39e209369da662ae6bf10816c5e4c3b468e07c`
- Tag `v0.2.1`: `8a39e209369da662ae6bf10816c5e4c3b468e07c`
- Release: `Codex Wick v0.2.1`
- Draft: false
- Prerelease: false
- Attached binary assets: 0
- Release mode: source-only
- Published: 2026-10-04T23:37:09Z
- Tested RC tree and merged `main` tree were bit-for-bit identical

## Post-release cleanup

- [x] Delete public RC branch `release/v0.2.1-rc1-20261004`
- [x] Remove temporary release clones and fault-injection files from the owner Mac
- [x] Restore normal polling interval to 30 seconds
- [x] Remove the temporary `codexPathOverride`
- [x] Confirm installed app reports version `0.2.1`
- [x] Confirm installed app reports bundle ID `io.github.BrianROAI.codexwick`
- [x] Confirm no `/tmp/codex-wick*` paths remain
- [x] Preserve `~/Library/Application Support/Codex Wick/observations.jsonl`

The v0.2.1 public release and owner-Mac release cleanup are complete.
