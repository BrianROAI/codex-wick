#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

if grep -q 'availableData' Sources/CodexPulse/CodexAppServerProbe.swift; then
  print -u2 "FAIL: blocking availableData reader reintroduced"
  exit 1
fi

if grep -q 'read(upToCount:' Sources/CodexPulse/CodexAppServerProbe.swift; then
  print -u2 "FAIL: blocking Foundation pipe read reintroduced"
  exit 1
fi

if grep -Eq 'Reason ONE|reasonone' Resources/Info.plist; then
  print -u2 "FAIL: private company identifier present in release metadata"
  exit 1
fi

grep -q '<string>io.github.BrianROAI.codexwick</string>' Resources/Info.plist
grep -q '<string>0.2.1</string>' Resources/Info.plist
grep -q '"version": "0.2.1"' Sources/CodexPulse/CodexAppServerProbe.swift
grep -q 'darkMode = UserDefaults.standard.object(forKey: "darkMode") as? Bool ?? true' Sources/CodexPulse/MonitorModel.swift

swift run CodexPulseCoreChecks

swift build -c release --product CodexWick \
  -Xswiftc -strict-concurrency=complete \
  -Xswiftc -warnings-as-errors

zsh scripts/build-app.sh

print "Verification passed: reliability guards GREEN, core checks GREEN, and Codex Wick app bundle builds with icon."
