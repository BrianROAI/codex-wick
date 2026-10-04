#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

swift run CodexPulseCoreChecks
zsh scripts/build-app.sh

print "Verification passed: core checks GREEN and Codex Wick app bundle builds with icon."
