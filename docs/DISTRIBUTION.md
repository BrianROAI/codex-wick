# Distribution

Codex Wick currently supports a source-first distribution path.

## Local source build

`scripts/verify.sh` runs core checks and builds the release app. `scripts/install.sh` builds and installs `~/Applications/Codex Wick.app`.

The build script may apply ad-hoc signing with `codesign -` when available.

## What ad-hoc signing is not

Ad-hoc signing is not Apple Developer ID distribution signing and is not notarization.

## Recommended first public release

Use a **source-first** release unless Apple Developer ID signing and notarization have been completed and independently verified.

## Binary-release gate

Before publishing a prebuilt app/archive, verify Developer ID Application signing, notarization, stapling when applicable, Gatekeeper assessment on a clean Mac, live Codex sampling, and absence of credentials/account identifiers in the artifact.
