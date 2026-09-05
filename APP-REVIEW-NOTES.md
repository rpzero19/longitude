# App Review Notes — Longitude

Paste the **Reviewer Notes** section below into App Store Connect →
your app → the version → **App Review Information → Notes**, and send the
same text as a reply in **Resolution Center**, with the screen recording
attached.

---

## Reviewer Notes (paste this)

Longitude requires no account, no login, and no network connection. There
are no in-app purchases and no paid content. Everything below can be
completed offline.

**2. Purpose and target audience**

Longitude turns a person's own pathology reports into a timeline, so they
can see how a measurement has moved over the years instead of reading each
report in isolation.

The problem it solves: lab results arrive as separate PDFs, months or years
apart. A single result tells you little; the trend is what matters. Today
people either keep a manual spreadsheet or lose track entirely.

Target audience: adults who have blood tests periodically — anyone managing
cholesterol, thyroid function, vitamin D, HbA1c or similar over time, and
anyone who simply wants their own history in one place.

Longitude reports; it does not interpret. It shows the number the lab
printed and the reference range the lab printed alongside it. It offers no
diagnosis, no advice, no risk score, and no recommendation of any kind.

**3. Setting up and accessing the main features**

No login or credentials are needed. On first launch the app is empty and
shows an "Add a report" button.

The fastest way to review is the paste-text option — no file transfer
required:

1. Launch the app. Tap **Add a report**.
2. Tap **Paste the text**.
3. Paste SAMPLE REPORT A below into the text box. Tap **Read results**.
4. The app extracts ten results. Tap **Save**.
5. Tap **Add a report** again and repeat with SAMPLE REPORT B, which is an
   earlier collection date from the same fictional patient.
6. The results list now shows both. Tap any row — for example
   **Total cholesterol** or **HbA1c** — to see the timeline chart with the
   lab's reference range shaded behind it.
7. The other two import paths can be tested the same way: **Choose a PDF**
   opens the Files app, and **Photograph or pick an image** reads a
   photographed paper report using on-device text recognition.
8. The **Reports** tab lists the two saved reports and allows either to be
   deleted, which removes its results from the timelines.

Both sample reports are fictional. They contain no real patient data.

SAMPLE REPORT A — paste exactly as shown:

CITY PATHOLOGY LABORATORY
Patient: Sample Patient
Collected: 12/03/2025

Haemoglobin              14.2   g/dL      13.0 - 17.0
Total Cholesterol        212    mg/dL     < 200
HDL Cholesterol          48     mg/dL     > 40
Triglycerides            145    mg/dL     < 150
Fasting Glucose          98     mg/dL     70 - 100
HbA1c                    5.6    %         4.0 - 5.7
TSH                      2.10   uIU/mL    0.40 - 4.50
Vitamin D (25-OH)        24     ng/mL     30 - 100
Creatinine               0.9    mg/dL     0.7 - 1.3
SGPT (ALT)               32     U/L       < 50

SAMPLE REPORT B — paste exactly as shown:

CITY PATHOLOGY LABORATORY
Patient: Sample Patient
Collected: 08/09/2024

Haemoglobin              13.6   g/dL      13.0 - 17.0
Total Cholesterol        238    mg/dL     < 200
HDL Cholesterol          41     mg/dL     > 40
Triglycerides            180    mg/dL     < 150
Fasting Glucose          104    mg/dL     70 - 100
HbA1c                    6.0    %         4.0 - 5.7
TSH                      3.40   uIU/mL    0.40 - 4.50
Vitamin D (25-OH)        18     ng/mL     30 - 100
Creatinine               1.0    mg/dL     0.7 - 1.3
SGPT (ALT)               41     U/L       < 50

**4. External services, tools and platforms**

None. Longitude makes no network requests of any kind. The app contains no
networking code — no URLSession, no third-party SDK, no analytics, no
crash reporter, no advertising identifier, no authentication service, no
payment processor, and no data provider.

Everything runs on the device using Apple frameworks only:

- PDFKit — extracting the text layer from a PDF report.
- Vision (VNRecognizeTextRequest) — on-device text recognition for
  photographed or scanned reports.
- Swift Charts — drawing the timelines.
- FoundationModels — on iOS 26 and later, on Apple Intelligence-capable
  devices only, Apple's on-device language model helps interpret unusual
  report layouts that the built-in deterministic parser cannot resolve.
  This inference is entirely local; no report text is ever transmitted.
  It is an enhancement only: the app is fully functional without it, and
  on devices that do not support Apple Intelligence the built-in parser
  handles everything.

No external AI service is used. No data leaves the device. Reports are
stored in the app's own container as a local file and are included in the
user's encrypted device backup only.

**5. Regional differences**

There are none. The app behaves identically in every region. It has no
region-gated features, no region-specific content, and no server to vary
behaviour by locale. It reads whatever units and reference ranges the
user's own report contains — conventional (mg/dL) and SI (mmol/L) units
are both supported — so it works with reports from any country without
any regional configuration.

**6. Regulated industry and third-party material**

Longitude is not a medical device and does not require any licence,
credential or authorisation.

It does not diagnose, treat, cure, mitigate or prevent any disease. It
performs no analysis or interpretation of results, calculates no clinical
score, and gives no health advice, recommendation or warning. It is a
personal record-keeping and charting tool, functionally equivalent to the
user typing their own results into a spreadsheet and plotting them.

It contains no protected third-party material. Every number displayed —
including the reference range and the in-range or out-of-range indication —
is read from the user's own report as printed by their own laboratory.
Longitude publishes no reference intervals, clinical guidelines or
proprietary content of its own. The word "high" or "low" shown next to a
result reflects only the range the user's laboratory printed on that
same report.

All content is supplied by the user, is the user's own health record, and
remains on the user's device.
