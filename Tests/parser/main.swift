import Foundation

var passed = 0, failed = 0
func ok(_ n: String, _ c: Bool) {
    if c { passed += 1; print("  ✅ \(n)") } else { failed += 1; print("  ❌ \(n)") }
}

// A composite of the layouts Indian and Australian labs actually print.
let report = """
Dr Lal PathLabs
Patient: ANONYMOUS                    Age/Sex: 34 Y / M
Collected: 14/01/2025                 Reported: 15/01/2025

TEST NAME                    RESULT     UNITS        BIO. REF. INTERVAL
COMPLETE BLOOD COUNT
Haemoglobin                  14.2       g/dL         13.0 - 17.0
Total Leucocyte Count        7800       /cumm        4000 - 10000
Platelet Count               245        10^3/uL      150 - 410
PCV                          42.1       %            40.0 - 50.0

LIPID PROFILE
Cholesterol - Total (CHOD-PAP)   195    mg/dL        < 200
HDL Cholesterol              48         mg/dL        > 40
LDL Cholesterol              118        mg/dL        < 100
Triglycerides                142        mg/dL        < 150

LIVER FUNCTION
SGPT (ALT)                   32         U/L          < 50
SGOT (AST)                   28         U/L          < 50
Total Bilirubin              0.8        mg/dL        0.3 - 1.2

OTHERS
HbA1c                        5.6        %            4.0 - 5.6
TSH (Ultrasensitive)         2.45       uIU/mL       0.35 - 5.50
25 OH Vitamin D              32         ng/mL        30 - 100
Vitamin B12                  450        pg/mL        211 - 911
S. Creatinine                0.9        mg/dL        0.7 - 1.3

Page 1 of 2
"""

print("\n▸ Whole-report extraction")
let readings = LabTextParser.parse(report)
ok("extracted a plausible number of results (got \(readings.count))",
   readings.count >= 15 && readings.count <= 20)

func find(_ id: String) -> Reading? { readings.first { $0.biomarkerID == id } }

ok("haemoglobin recognised",      find("hgb")?.value == 14.2)
ok("its unit captured",           find("hgb")?.unit == "g/dL")
ok("its printed range captured",  find("hgb")?.range.low == 13 && find("hgb")?.range.high == 17)
ok("haemoglobin reads within range", find("hgb")?.status == .within)

ok("'Cholesterol - Total (CHOD-PAP)' → total cholesterol", find("chol")?.value == 195)
ok("'< 200' parsed as an upper bound", find("chol")?.range.high == 200)
ok("cholesterol within range",     find("chol")?.status == .within)
ok("LDL 118 against '< 100' reads above", find("ldl")?.status == .above)
ok("HDL 48 against '> 40' reads within",  find("hdl")?.status == .within)

ok("'SGPT (ALT)' → ALT",           find("alt")?.value == 32)
ok("'SGOT (AST)' → AST",           find("ast")?.value == 28)
ok("'TSH (Ultrasensitive)' → TSH", find("tsh")?.value == 2.45)
ok("'S. Creatinine' → creatinine", find("creat")?.value == 0.9)
ok("'Total Leucocyte Count' → WBC", find("wbc")?.value == 7800)
ok("'PCV' → haematocrit",          find("hct")?.value == 42.1)

print("\n▸ The case that breaks naive parsers")
ok("'25 OH Vitamin D' takes 32 as the value, not the 25 in its name",
   find("vitd")?.value == 32)
ok("'Vitamin B12' takes 450, not the 12 in B12",
   find("b12")?.value == 450)
ok("'HbA1c' takes 5.6", find("hba1c")?.value == 5.6)

print("\n▸ Page furniture rejected")
ok("no reading called 'Page'",
   !readings.contains { $0.rawName.lowercased().contains("page") })
ok("no reading from the patient line",
   !readings.contains { $0.rawName.lowercased().contains("patient") })
ok("section headers produced no readings",
   !readings.contains { $0.rawName.uppercased() == $0.rawName && $0.unit.isEmpty })

print("\n▸ Collection date")
let date = LabTextParser.findDate(in: report)
let cal = Calendar(identifier: .gregorian)
ok("found a date", date != nil)
if let d = date {
    ok("prefers 'Collected' (14 Jan 2025) over 'Reported'",
       cal.component(.day, from: d) == 14 && cal.component(.month, from: d) == 1
         && cal.component(.year, from: d) == 2025)
}

print("\n▸ Other date layouts")
func dateOf(_ s: String) -> Date? { LabTextParser.findDate(in: s) }
ok("ISO 'Collected: 2025-01-14'",
   dateOf("Collected: 2025-01-14").map { cal.component(.year, from: $0) == 2025 } == true)
ok("'Sample date: 14-Jan-2025'",
   dateOf("Sample date: 14-Jan-2025").map { cal.component(.day, from: $0) == 14 } == true)
ok("'Collected 14 Jan 2025'",
   dateOf("Collected 14 Jan 2025").map { cal.component(.day, from: $0) == 14 } == true)
ok("rejects an implausible year",
   dateOf("Ref 12/34/1850") == nil)

print("\n▸ Single-line robustness")
func line(_ s: String) -> ParsedLine? { LabTextParser.parseLine(s) }
ok("tight spacing 'Haemoglobin 14.2 g/dL 13.0-17.0'",
   line("Haemoglobin 14.2 g/dL 13.0-17.0")?.value == 14.2)
ok("that range still splits",
   line("Haemoglobin 14.2 g/dL 13.0-17.0")?.range == "13.0-17.0")
ok("no range column at all",
   line("Haemoglobin 14.2 g/dL")?.unit == "g/dL")
ok("empty line yields nothing", line("") == nil)
ok("prose line with no number yields nothing", line("COMPLETE BLOOD COUNT") == nil)
ok("a lone number yields nothing", line("42") == nil)

print("\n▸ Unit reconciliation through the pipeline")
let mmol = LabTextParser.parse("Total Cholesterol 5.2 mmol/L 3.0 - 5.5")
ok("mmol/L cholesterol converted to mg/dL for plotting",
   abs((mmol.first?.plottedValue ?? 0) - 201.08) < 0.5)
ok("but the original value is preserved", mmol.first?.value == 5.2)
ok("and the original unit is preserved",  mmol.first?.unit == "mmol/L")

print("\n▸ Column order the lab chose, not the one we assumed")
// A real Indian pathology report prints the interval before the unit. The
// unit then lands inside the range, the unit comes back empty, and every
// result on the page is discarded as "not a result".
ok("'Gamma GT. 42 10-71 U/L' keeps its unit",
   line("Gamma GT. 42 10-71 U/L")?.unit == "U/L")
ok("and its interval",
   line("Gamma GT. 42 10-71 U/L")?.range == "10-71")
ok("open-ended interval before the unit: '48 <45 U/L'",
   line("Alanine Aminotransferase (ALT/SGPT) 48 <45 U/L")?.unit == "U/L")
ok("unit-after-value order still works",
   line("Haemoglobin 14.2 g/dL 13.0-17.0")?.unit == "g/dL")

print("\n▸ One panel printed twice is still one reading")
let twice = LabTextParser.parse("""
Albumin. 5.0 3.5-5.2 g/dL
Blood Urea Nitrogen. 15 6-20 mg/dL
Albumin. 5.0 3.5-5.2 g/dL
""")
ok("the repeat is dropped", twice.filter { $0.biomarkerID == "alb" }.count == 1)
ok("the other analyte survives", twice.count == 2)
let differing = LabTextParser.parse("""
Albumin. 5.0 3.5-5.2 g/dL
Albumin. 4.2 3.5-5.2 g/dL
""")
ok("a genuinely different value is never merged away", differing.count == 2)

print("\n▸ Captions in the interval column are not units")
ok("'Normal :' is dropped",
   line("MDRD, GFR 88.7 Normal : > 90 ml/min/1.73m2")?.unit == "ml/min/1.73m2")
ok("leaving the interval readable",
   line("MDRD, GFR 88.7 Normal : > 90 ml/min/1.73m2")?.range == "> 90")
ok("m2 reconciles with the registry's m²",
   BiomarkerRegistry.normaliseUnit("ml/min/1.73m2")
     == BiomarkerRegistry.normaliseUnit("mL/min/1.73m²"))

print("\n▸ A value welded to its unit is still the value")
// "Creatinine : 1.2mg/dL 0.7 - 1.2". Without splitting, 1.2mg/dL is not
// numeric, the parser walks past it and records 0.7 — the interval's lower
// bound — as the result. A silently wrong number in a health record.
ok("the result is the result, not the interval bound",
   line("Creatinine : 1.2mg/dL 0.7 - 1.2")?.value == 1.2)
ok("the welded unit is recovered",
   line("Creatinine : 1.2mg/dL 0.7 - 1.2")?.unit == "mg/dL")
ok("the interval survives intact",
   line("Creatinine : 1.2mg/dL 0.7 - 1.2")?.range == "0.7 - 1.2")
ok("the colon is not part of the name",
   line("Creatinine : 1.2mg/dL 0.7 - 1.2")?.name == "Creatinine")
ok("a date is never split apart",
   LabTextParser.splitValueFromUnit("30-Jul-2026") == ["30-Jul-2026"])
ok("nor is an interval",
   LabTextParser.splitValueFromUnit("13.0-17.0") == ["13.0-17.0"])
ok("but a welded value is",
   LabTextParser.splitValueFromUnit("82.1mL/min") == ["82.1", "mL/min"])
ok("a typewritten ≥ parses",
   ReferenceRange.parse(">/= 90").low == 90)

print("\n▸ Urine and serum are different tests")
ok("spot urine creatinine resolves to its own analyte",
   BiomarkerRegistry.match("Creatinine Spot Urine")?.id == "creat_u")
ok("serum creatinine is unaffected",
   BiomarkerRegistry.match("Creatinine.")?.id == "creat")
ok("they never share a timeline",
   BiomarkerRegistry.match("Creatinine Spot Urine")?.id
     != BiomarkerRegistry.match("Creatinine.")?.id)
ok("microalbumin resolves through the comma",
   BiomarkerRegistry.match("Microalbumin,Spot Urine")?.id == "microalb_u")

print("\n▸ Vitamin D fractions stay separate from the total")
ok("total", BiomarkerRegistry.match("Vitamin D total (D2+D3)")?.id == "vitd")
ok("D2",    BiomarkerRegistry.match("25 (OH) VIT D2 Ergocalciferol")?.id == "vitd2")
ok("D3",    BiomarkerRegistry.match("25 (OH) VIT D3 Cholecalciferol")?.id == "vitd3")
ok("they never merge into one timeline",
   Set([BiomarkerRegistry.match("Vitamin D total (D2+D3)")?.id,
        BiomarkerRegistry.match("25 (OH) VIT D2 Ergocalciferol")?.id,
        BiomarkerRegistry.match("25 (OH) VIT D3 Cholecalciferol")?.id]).count == 3)
ok("'Not established' is not a unit",
   line("25 (OH) VIT D2 Ergocalciferol : 2.22ng/mL Not established")?.unit == "ng/mL")
ok("post-meal glucose is not fasting glucose",
   BiomarkerRegistry.match("Post Lunch Glucose")?.id == "glucose_pp")

print("\n▸ Analytes this lab reports that the registry once missed")
ok("indirect bilirubin", BiomarkerRegistry.match("Indirect Bilirubin.")?.id == "bili_i")
ok("globulin",           BiomarkerRegistry.match("Globulin.")?.id == "glob")
ok("A/G ratio run together as one word",
   BiomarkerRegistry.match("A/GRatio.")?.id == "ag_ratio")
ok("a unitless ratio still parses as a result",
   LabTextParser.parse("A/GRatio. 1.47 0.8-2.0").count == 1)

print("\n" + String(repeating: "─", count: 58))
print(failed == 0 ? "✅ ALL \(passed) TESTS PASSED" : "❌ \(failed) FAILED, \(passed) passed")
print(String(repeating: "─", count: 58) + "\n")
exit(failed == 0 ? 0 : 1)
