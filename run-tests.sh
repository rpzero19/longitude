#!/bin/bash
# Logic tests, no Xcode required — the parsing and registry layers are pure Swift.
set -e
cd "$(dirname "$0")"
OUT=$(mktemp -d)
CORE="Sources/Longitude/Biomarkers.swift Sources/Longitude/Models.swift \
      Sources/Longitude/JSONCoding.swift Sources/Longitude/LabTextParser.swift \
      Sources/Longitude/ManualEntry.swift \
      Sources/Longitude/Store.swift"
for suite in "main:registry & units" "parsing:ranges & series" "parser:report extraction" "store:saved data"; do
  dir="${suite%%:*}"; label="${suite#*:}"
  src=$([ "$dir" = "main" ] && echo "Tests/main.swift" || echo "Tests/$dir/main.swift")
  echo "═══ $label ═══"
  swiftc -o "$OUT/$dir" $CORE "$src" && "$OUT/$dir" | tail -3
done
