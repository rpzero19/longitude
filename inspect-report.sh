#!/bin/bash
# Runs the real parser against a real lab report and reports what it understood.
# Diagnostics only — writes nothing, sends nothing anywhere. Values redacted
# unless you pass --values.
set -e
cd "$(dirname "$0")"
BIN=$(mktemp -d)/inspect
swiftc -o "$BIN" \
  Sources/Longitude/Biomarkers.swift Sources/Longitude/Models.swift \
  Sources/Longitude/JSONCoding.swift Sources/Longitude/LabTextParser.swift \
  Tools/inspect-report/main.swift 2>&1 | grep -v "^$" || true
"$BIN" "$@"
