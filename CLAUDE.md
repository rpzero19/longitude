# Longitude — working notes

An iOS app that turns lab reports into a timeline. Read and stored entirely on device.

**Status:** v1.0 (build 1) submitted to App Store review, 4 Sep 2026.
Bundle ID `io.github.rpzero19.longitude` · Apple ID `6808665314` · Team `U5J9JN6V59`

## Design rules — do not quietly relax these

1. **The app reports; it never interprets.** It shows values and compares them to the
   interval printed on the user's own report. It must never say what a result means,
   suggest a cause, or recommend an action. This keeps it clear of medical-device
   territory and is the honest position for software with no clinical picture.
   Users will ask for interpretation. It is the obvious next feature and the obvious
   way to monetise. Hold the line.
2. **Reference intervals come from the report, never substituted.** They are assay- and
   lab-specific; a generic range would silently change whether a result reads as normal.
3. **Refuse to guess.** An unmatched analyte name returns nil rather than a near-match;
   an unrecognised unit is left unconverted. A wrong match silently corrupts a trend
   line, which is worse than showing nothing.
4. **Deterministic parsing is the primary path.** `FoundationModels` needs Apple
   Intelligence (iPhone 15 Pro+), so it can only ever supplement. The model contributes
   only analytes the registry already recognises — an unrecognised name from an LLM is
   more likely a hallucination than a discovery.
5. **No network code.** There is none in the source today, and that fact backs the
   "Data Not Collected" App Store declaration and the privacy policy. Adding any would
   break both.

## Where the value is

`Sources/Longitude/Biomarkers.swift` — 51 analytes with their real-world aliases and unit
conversions. This is the moat, and it grows every time a report names something a way the
registry doesn't know. Adding an alias is cheap; getting one wrong is expensive.

## Gotchas

- **`Longitude.xcodeproj` is generated and git-ignored.** Edit `project.yml`, then run
  `xcodegen generate`. Settings changed only in Xcode's UI are wiped on the next run —
  this already bit us once with `DEVELOPMENT_TEAM`.
- **App Store Connect has a separate screenshot slot per display size**, each rejecting
  anything not matching its exact pixels. Both sets live in `screenshots/`.
- **Copyright is a version-level field**, on the "Prepare for Submission" page, not on
  App Information.
- The App ID must be **explicit** in the Developer portal. Xcode's wildcard profile
  (`TEAM.*`) signs development builds fine but cannot be used for App Store distribution,
  and the bundle ID won't appear in App Store Connect's dropdown until it's registered.

## Commands

```bash
./run-tests.sh          # 116 logic tests, no Xcode needed
xcodegen generate       # regenerate the project after editing project.yml
```

Screenshots are scriptable — see `screenshots/README.md`. The app takes `-openSeries <id>`
and `-initialTab <n>` launch arguments so the set can be regenerated after any UI change.

## Known gaps

- The parser has only met synthetic reports plus one manual paste test. Real PDFs from
  actual labs are the honest test and the most likely source of bugs.
- Reference intervals vary by sex and age. Using whatever the report printed is correct,
  but worth being deliberate about if per-analyte defaults are ever added.
- Import UI was verified manually once; there are no UI tests.
