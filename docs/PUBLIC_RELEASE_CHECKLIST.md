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
- [ ] Exact v0.2.1 public release candidate passes a final secret / PII / local-path scan

## v0.2.1 product acceptance

- [x] Owner-Mac source candidate passed 7/7 core checks
- [x] Owner-Mac source candidate passed strict concurrency with warnings as errors
- [x] Owner-Mac fault injection proved a hung first probe is terminated and the same Codex Wick process automatically recovers on the next poll
- [x] Owner visually accepted Dark-by-default appearance, 1-MIN BURN placement/dynamics, and freshness / STALE presentation
- [ ] Exact public release-candidate SHA passes `zsh scripts/verify.sh`
- [ ] Exact public release-candidate SHA passes `zsh scripts/verify-recovery.sh`
- [ ] Fresh public clone passes the source build/install smoke test

## Distribution

- [x] Source-first build/install path documented
- [x] v0.2.1 remains source-first
- [ ] If a prebuilt binary is added later, complete Developer ID signing and notarization first

## Release

- [ ] Merge the accepted public v0.2.1 release candidate to `main`
- [ ] Tag the exact accepted source as `v0.2.1`
- [ ] Create the GitHub release with source-only assets
- [ ] Re-test the tagged public clone/build path
