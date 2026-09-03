# Longitude

Your lab results as a timeline, read and stored entirely on your iPhone.

Blood tests arrive as PDFs, get read once, and are never seen again — so nobody ever sees
their own trend. Longitude extracts results from reports, joins them across years and labs,
and charts them against the reference interval your own lab printed.

**No account. No server. No analytics. Nothing is uploaded.**

## The problem it actually solves

Labs name the same analyte differently and report it in different units. A 2019 report
saying `SGPT` and a 2025 one saying `ALT` are the same enzyme; `5.2 mmol/L` and
`201 mg/dL` are the same cholesterol. Without reconciling both, a decade of reports is a
pile of disconnected numbers rather than a trend.

`Biomarkers.swift` is the answer to that: 51 analytes, their aliases as seen in the wild,
and the unit conversions between them. It's the reason the app works.

## Design rules

- **It reports; it never interprets.** Values are compared against the interval printed on
  your own report. The app does not say what a result means, suggest a cause, or recommend
  an action. It is not a medical device.
- **Reference intervals are never substituted.** They're assay- and lab-specific; swapping
  in a generic range would silently change whether a result reads as normal.
- **It refuses to guess.** An unmatched analyte name returns nothing rather than a
  near-match, and an unrecognised unit is left unconverted. A wrong match silently corrupts
  a trend line, which is worse than showing nothing.
- **Deterministic first.** The parser runs on every device. The on-device model only
  supplements it, and only contributes analytes the registry recognises.

## Architecture

```
Sources/Longitude/
  Biomarkers.swift      ← canonical registry: 51 analytes, aliases, unit conversions
  LabTextParser.swift   ← deterministic extraction; registry confirms name boundaries
  ModelExtractor.swift  ← optional on-device LLM (iOS 26 FoundationModels)
  Models.swift          ← Codable value types, reference-range parsing, series building
  Store.swift           ← persistence + observable state
  TextExtraction.swift  ← PDFKit for PDFs, Vision OCR for photos
  Views/                ← SwiftUI + Swift Charts
Tests/                  ← 116 tests, runnable without Xcode
```

## Privacy

Report text is extracted with Apple's on-device PDF and text-recognition frameworks. On
devices supporting Apple Intelligence, an on-device language model assists with unusual
layouts — it runs locally and sends nothing anywhere. There is no network code in this app.

## Building

The Xcode project is generated, not committed:

```bash
brew install xcodegen
xcodegen generate
open Longitude.xcodeproj
```

Requires Xcode 26+. Deployment target is iOS 17; the on-device model is gated at iOS 26 and
degrades cleanly to the deterministic parser on older devices and on hardware without Apple
Intelligence.

## Tests

```bash
./run-tests.sh
```

116 tests covering registry integrity (no alias claimed by two analytes), cross-lab name
resolution, unit conversion, reference-range parsing in the forms labs actually print,
series grouping across years, and extraction from realistic report text.

They compile against the macOS SDK, so the whole logic layer is verifiable without Xcode.

## Not medical advice

Longitude records and displays results. It does not interpret them, diagnose anything, or
offer medical advice. Discuss your results with a qualified healthcare professional.
