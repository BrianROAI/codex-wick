# Public Release Checklist

## Repository hygiene

- [x] Public repository bootstrap is a clean single-root snapshot and does not include private development history
- [x] Product-facing docs use the Codex Wick name
- [x] Current source was scanned for obvious API keys, bearer tokens, personal filesystem paths, personal email content, and persisted account IDs
- [x] Public privacy/security/contribution/distribution docs exist
- [x] OpenAI non-affiliation notice is present
- [x] Account IDs are excluded from newly persisted observations
- [x] MIT license selected
- [x] Root commit uses a GitHub noreply identity

## Product acceptance

- [x] Bootstrap snapshot passes `zsh scripts/verify.sh` before publication
- [ ] Exact remote main passes the Personal Runtime Codex Wick project gate after bootstrap
- [ ] Compact HUD launches in the intended upper-right position
- [ ] Opening details hides the HUD
- [ ] Detail window opens centered
- [ ] Closing the detail window with X restores the HUD
- [ ] Light/dark mode are coherent across HUD, detail, and Settings
- [ ] Credits is blue; dC/dt orange-red; Weekly green; Short purple
- [ ] In-app mark has exactly two wicks: one lit, one extinguished/smoking
- [ ] Reduce Motion disables the Wick animation
- [ ] Live authenticated `account/rateLimits/read` sample renders
- [ ] Local notification path is accepted

## Distribution

- [x] Source-first build/install path documented
- [x] First public release is source-first
- [ ] If a prebuilt binary is added later, complete Developer ID signing and notarization first

## Release

- [ ] Complete owner-Mac visual/live acceptance
- [ ] Change repository visibility from private to public
- [ ] Tag the approved `v0.2.0` source release
- [ ] Create the GitHub release
- [ ] Re-test the public clone/build path
