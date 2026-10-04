#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
zsh "$ROOT/scripts/build-app.sh"

DEST="$HOME/Applications/Codex Wick.app"
LEGACY="$HOME/Applications/Codex Pulse.app"

/usr/bin/pkill -x CodexWick >/dev/null 2>&1 || true
/usr/bin/pkill -f "Codex Pulse.app" >/dev/null 2>&1 || true
sleep 1

mkdir -p "$HOME/Applications"
rm -rf "$DEST"
ditto "$ROOT/dist/Codex Wick.app" "$DEST"

if [[ -d "$LEGACY" ]]; then
  rm -rf "$LEGACY"
fi

/usr/bin/open -na "$DEST"
print "Installed and relaunched fresh: $DEST"
