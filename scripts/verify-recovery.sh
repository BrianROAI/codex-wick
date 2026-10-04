#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/dist/Codex Wick.app"
FAULT_ROOT="/tmp/codex-wick-fault"
SHIM="$FAULT_ROOT/codex"
STATE="$FAULT_ROOT/state"
LOG="$FAULT_ROOT/fault.log"
HIST="$HOME/Library/Application Support/Codex Wick/observations.jsonl"
INSTALLED_APP="$HOME/Applications/Codex Wick.app"

if [[ ! -d "$APP" ]]; then
  print "Building candidate app..."
  zsh "$ROOT/scripts/build-app.sh"
fi

BUNDLE_ID=$(/usr/libexec/PlistBuddy   -c 'Print :CFBundleIdentifier'   "$APP/Contents/Info.plist")

VERSION=$(/usr/libexec/PlistBuddy   -c 'Print :CFBundleShortVersionString'   "$APP/Contents/Info.plist")

[[ "$BUNDLE_ID" == "io.github.BrianROAI.codexwick" ]]
[[ "$VERSION" == "0.2.1" ]]
[[ -f "$HIST" ]]

REAL_CODEX="$(whence -p codex 2>/dev/null || true)"

if [[ -z "$REAL_CODEX" || ! -x "$REAL_CODEX" ]]; then
  for candidate in     /opt/homebrew/bin/codex     /usr/local/bin/codex     "$HOME/.local/bin/codex"     "$HOME/.npm-global/bin/codex"     "$HOME/.volta/bin/codex"     "$HOME/.bun/bin/codex"     "$HOME/.cargo/bin/codex"     "$HOME/.codex/bin/codex"
  do
    if [[ -x "$candidate" ]]; then
      REAL_CODEX="$candidate"
      break
    fi
  done
fi

if [[ -z "$REAL_CODEX" || ! -x "$REAL_CODEX" ]]; then
  print -u2 "FAIL: could not resolve an executable Codex binary."
  exit 1
fi

mkdir -p "$FAULT_ROOT"

cat > "$SHIM" <<EOF
#!/bin/zsh
set -eu
STATE="$STATE"
LOG="$LOG"
REAL="$REAL_CODEX"

if [[ "\${1:-}" == "app-server" && ! -e "\$STATE" ]]; then
  print -r -- "HANG_ONCE" >> "\$LOG"
  : > "\$STATE"
  exec /bin/sleep 60
fi

print -r -- "DELEGATE" >> "\$LOG"
exec "\$REAL" "\$@"
EOF

chmod +x "$SHIM"
zsh -n "$SHIM"

RECOVERY_SUCCEEDED=0

cleanup() {
  defaults delete "$BUNDLE_ID" codexPathOverride >/dev/null 2>&1 || true
  defaults write "$BUNDLE_ID" pollIntervalSeconds -float 30

  pkill -x CodexWick >/dev/null 2>&1 || true
  sleep 1

  if [[ "$RECOVERY_SUCCEEDED" == "1" ]]; then
    open -na "$APP"
  elif [[ -d "$INSTALLED_APP" ]]; then
    open -na "$INSTALLED_APP"
  fi
}

trap cleanup EXIT INT TERM

pkill -x CodexWick >/dev/null 2>&1 || true
sleep 1

print "Candidate: $APP"
print "Bundle:    $BUNDLE_ID"
print "Version:   $VERSION"
print "Codex:     $REAL_CODEX"
print

print "== baseline: prove candidate samples the real Codex app-server =="
defaults delete "$BUNDLE_ID" codexPathOverride >/dev/null 2>&1 || true
defaults write "$BUNDLE_ID" pollIntervalSeconds -float 15

BASELINE_BEFORE="$(tail -n 1 "$HIST")"
open -na "$APP"

BASELINE_OK=0
for _ in {1..8}; do
  sleep 5
  BASELINE_AFTER="$(tail -n 1 "$HIST")"

  if [[ "$BASELINE_AFTER" != "$BASELINE_BEFORE" ]]; then
    BASELINE_OK=1
    break
  fi
done

if [[ "$BASELINE_OK" != "1" ]]; then
  print -u2 "FAIL: candidate did not produce a normal baseline observation."
  pgrep -x CodexWick -af . >&2 || true
  exit 1
fi

print "GREEN: normal baseline observation arrived"

pkill -x CodexWick >/dev/null 2>&1 || true
sleep 1

BEFORE="$(tail -n 1 "$HIST")"

defaults write "$BUNDLE_ID" codexPathOverride "$SHIM"
defaults write "$BUNDLE_ID" pollIntervalSeconds -float 15

rm -f "$STATE" "$LOG"

print
print "== inject one hung probe, then require automatic recovery =="

open -na "$APP"
sleep 2

APP_PID="$(pgrep -x CodexWick | head -1 || true)"
if [[ -z "$APP_PID" ]]; then
  print -u2 "FAIL: candidate Codex Wick did not launch."
  exit 1
fi

print "CodexWick PID=$APP_PID"
print
print "== 5s: verify deliberately hung first probe =="
sleep 5

CHILD="$(pgrep -P "$APP_PID" | head -1 || true)"
if [[ -z "$CHILD" ]]; then
  print -u2 "FAIL: expected deliberately hung child was not present."
  [[ -f "$LOG" ]] && cat "$LOG"
  exit 1
fi

ps -p "$CHILD" -o pid=,ppid=,etime=,command=
grep -q HANG_ONCE "$LOG"

print
print "== 15s: verify hard timeout removed hung probe =="
sleep 10

if pgrep -P "$APP_PID" >/dev/null; then
  print -u2 "FAIL: hung probe survived the deadline."
  pgrep -P "$APP_PID" -af . || true
  exit 1
fi

print "GREEN: hung probe removed"

print
print "== watch automatic recovery for up to 75s =="

RECOVERED=0

for _ in {1..15}; do
  sleep 5

  CURRENT="$(tail -n 1 "$HIST")"

  if [[ "$CURRENT" != "$BEFORE" ]]       && [[ -f "$LOG" ]]       && grep -q DELEGATE "$LOG"; then
    RECOVERED=1
    break
  fi
done

if [[ "$RECOVERED" != "1" ]]; then
  print -u2 "FAIL: no successful observation arrived after automatic retry."
  print -u2 ""
  print -u2 "fault log:"
  [[ -f "$LOG" ]] && cat "$LOG" >&2 || true
  print -u2 ""
  print -u2 "latest observation:"
  tail -n 1 "$HIST" >&2
  print -u2 ""
  print -u2 "remaining children:"
  pgrep -P "$APP_PID" -af . >&2 || true
  exit 1
fi

kill -0 "$APP_PID"

AFTER="$(tail -n 1 "$HIST")"

print
print "== fault log =="
cat "$LOG"

print
print "== before =="
print -r -- "$BEFORE"

print
print "== after =="
print -r -- "$AFTER"

print
print "========================================================"
print "GREEN: hung probe timed out"
print "GREEN: automatic retry delegated to real Codex"
print "GREEN: new observation arrived"
print "GREEN: same Codex Wick process survived"
print "========================================================"

RECOVERY_SUCCEEDED=1
print
print "Candidate will relaunch normally at 30-second polling for visual acceptance."
