# App Store listing copy

Paste these into App Store Connect. Character limits noted — Apple enforces them.

---

## Name (30 max)
```
Longitude
```
If taken, in order of preference: `Longitude Labs` · `Longitude Health` · `Lab Longitude`

## Subtitle (30 max)
```
Your lab results over time
```
*(26 characters)*

## Promotional text (170 max — editable any time without a new build)
```
Blood tests arrive as PDFs and are never seen again. Longitude turns years of reports into one clear timeline, read and kept entirely on your iPhone.
```
*(148 characters)*

## Keywords (100 max, comma-separated, no spaces after commas)
```
blood test,lab results,bloodwork,pathology,cholesterol,biomarker,health record,offline,private
```
*(94 characters. Don't repeat words already in your name or subtitle — Apple indexes those separately, so repeating them wastes the budget.)*

## Description (4000 max)
```
Your blood test results arrive as a PDF, get read once, and are never seen again. So the one thing that actually matters — how your numbers are changing — is the one thing you never get to see.

Longitude fixes that. Add your lab reports and it builds a continuous timeline for every result, so you can see the direction of travel instead of a single number in isolation.

EVERYTHING STAYS ON YOUR IPHONE

There is no account, no server, and no analytics. Your reports are read on the device itself, and nothing is ever uploaded — not to us, not to anyone. Your health data is yours.

IT JOINS UP YOUR HISTORY

Labs name the same test differently and report it in different units. A report from 2019 saying "SGPT" and one from 2025 saying "ALT" are the same enzyme. 5.2 mmol/L and 201 mg/dL are the same cholesterol.

Longitude knows 51 common analytes, the many names labs use for them, and the conversions between units — so results from different labs, different countries and different years line up on one chart instead of sitting in disconnected fragments.

IT USES YOUR LAB'S OWN REFERENCE RANGE

Reference intervals differ between laboratories and between assays. Longitude never substitutes a generic range: it shows the interval printed on your own report, and tells you where your result sits against it.

WHAT YOU CAN DO

• Add reports as a PDF, a photo, or pasted text
• See every result as a timeline, with the reference range drawn behind it
• Spot immediately which results sit outside your lab's range
• Keep the original report alongside the numbers
• Export everything as a spreadsheet for yourself or your doctor

IT DOES NOT INTERPRET YOUR RESULTS

This is deliberate. Longitude shows you your numbers and how they have changed. It does not tell you what they mean, suggest a cause, or recommend anything. Interpreting a result needs your full clinical picture, which an app does not have.

Longitude is not a medical device and does not provide medical advice. Always discuss your results with a qualified healthcare professional.
```

## What's New (first release)
```
First release.
```

## Review notes (for App Review — not shown to users)
```
Longitude is a personal record-keeping app for laboratory results.

It does not interpret results, diagnose, or offer medical advice. It displays values
the user has entered or imported from their own reports, and compares them only to the
reference interval printed on that same report. Disclaimers appear on the results
screen, on every chart, and on the app's website.

The app collects no data. There is no account, no server, no analytics and no
third-party SDK. All processing — PDF text extraction, OCR, and optional on-device
language model assistance on Apple Intelligence hardware — happens on the device.
The app contains no networking code.

To test: open the app, tap the menu at the top right, choose "Add a report", then
"Paste the text", and paste the sample below. It will extract the results and build
the timeline.

Haemoglobin        14.2   g/dL    13.0 - 17.0
Cholesterol Total  195    mg/dL   < 200
LDL Cholesterol    118    mg/dL   < 100
SGPT (ALT)         32     U/L     < 50
HbA1c              5.6    %       4.0 - 5.6
25 OH Vitamin D    32     ng/mL   30 - 100
```

## App Privacy questionnaire
Answer **"No, we do not collect data from this app"** — every category, no exceptions.
This must match the privacy policy exactly; a mismatch is a common rejection cause.

## Other fields
| Field | Value |
|---|---|
| Category | Medical (primary). Health & Fitness is the alternative. |
| Age rating | 4+ |
| Privacy policy URL | https://rpzero19.github.io/longitude/privacy.html |
| Support URL | https://rpzero19.github.io/longitude/support.html |
| Marketing URL | https://rpzero19.github.io/longitude/ |
| Price | Free |
| Bundle ID | io.github.rpzero19.longitude |

**A note on category:** Medical is the honest fit and matches what users search for, but
apps in that category get read more carefully by App Review. That's an argument for
being scrupulous about the no-interpretation line, not for miscategorising to dodge
scrutiny — which reviewers notice.
