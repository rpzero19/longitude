import Foundation

var passed = 0, failed = 0
func ok(_ n: String, _ c: Bool) {
    if c { passed += 1; print("  ✅ \(n)") } else { failed += 1; print("  ❌ \(n)") }
}
func eq(_ n: String, _ a: Double?, _ e: Double, tol: Double = 0.01) {
    guard let a else { failed += 1; print("  ❌ \(n) — got nil"); return }
    if abs(a - e) <= tol { passed += 1; print("  ✅ \(n)") }
    else { failed += 1; print("  ❌ \(n) — expected \(e), got \(a)") }
}
func matches(_ raw: String, _ id: String) -> Bool {
    BiomarkerRegistry.match(raw)?.id == id
}

// ── Registry integrity ───────────────────────────────────────────────────────
print("\n▸ Registry integrity")
var seen: [String: String] = [:]
var collisions: [String] = []
for def in BiomarkerRegistry.all {
    for alias in def.aliases {
        let key = BiomarkerRegistry.normalise(alias)
        if let owner = seen[key], owner != def.id {
            collisions.append("'\(alias)' claimed by both \(owner) and \(def.id)")
        }
        seen[key] = def.id
    }
}
ok("no alias is claimed by two analytes", collisions.isEmpty)
if !collisions.isEmpty { collisions.forEach { print("       ⚠️  \($0)") } }

let ids = BiomarkerRegistry.all.map(\.id)
ok("all ids unique", Set(ids).count == ids.count)
ok("every analyte has at least one alias",
   BiomarkerRegistry.all.allSatisfy { !$0.aliases.isEmpty })
ok("every analyte has a canonical unit",
   BiomarkerRegistry.all.allSatisfy { !$0.canonicalUnit.isEmpty })

// ── The core promise: same analyte, different decades, one line ───────────────
print("\n▸ Cross-lab name resolution")
ok("SGPT → ALT",              matches("SGPT", "alt"))
ok("ALT → ALT",               matches("ALT", "alt"))
ok("Alanine Aminotransferase → ALT", matches("Alanine Aminotransferase", "alt"))
ok("SGOT → AST",              matches("SGOT", "ast"))
ok("Hb → haemoglobin",        matches("Hb", "hgb"))
ok("Hemoglobin (US spelling)", matches("Hemoglobin", "hgb"))
ok("Haemoglobin (UK/AU/IN)",  matches("Haemoglobin", "hgb"))
ok("TLC → white cells",       matches("Total Leucocyte Count", "wbc"))
ok("PCV → haematocrit",       matches("PCV", "hct"))
ok("FBS → fasting glucose",   matches("FBS", "glucose_f"))
ok("Fasting Blood Sugar → fasting glucose", matches("Fasting Blood Sugar", "glucose_f"))
ok("A1C → HbA1c",             matches("A1C", "hba1c"))

print("\n▸ Lab formatting noise")
ok("specimen prefix 'S. Creatinine'",  matches("S. Creatinine", "creat"))
ok("specimen prefix 'Serum Uric Acid'", matches("Serum Uric Acid", "urate"))
ok("uppercase + spacing 'VITAMIN  B12'", matches("VITAMIN  B12", "b12"))
ok("method note 'Cholesterol - Total (CHOD-PAP)'",
   matches("Cholesterol - Total (CHOD-PAP)", "chol"))
ok("bracket note 'TSH (Ultrasensitive)'", matches("TSH (Ultrasensitive)", "tsh"))
ok("punctuation 'Vit. D'", matches("Vit. D", "vitd") || matches("Vit D", "vitd"))

print("\n▸ Refusing to guess")
ok("unknown analyte returns nil", BiomarkerRegistry.match("Zorblatt Factor") == nil)
ok("empty string returns nil", BiomarkerRegistry.match("") == nil)
ok("HDL and LDL never collapse together",
   BiomarkerRegistry.match("HDL")?.id != BiomarkerRegistry.match("LDL")?.id)
ok("T3 and Free T3 stay distinct",
   BiomarkerRegistry.match("T3")?.id != BiomarkerRegistry.match("Free T3")?.id)
ok("total vs direct bilirubin stay distinct",
   BiomarkerRegistry.match("Total Bilirubin")?.id
     != BiomarkerRegistry.match("Direct Bilirubin")?.id)

// ── Units: the other half of a continuous trend ──────────────────────────────
print("\n▸ Unit conversion to canonical")
let glucose = BiomarkerRegistry.match("FBS")!
eq("glucose 5.5 mmol/L → 99.1 mg/dL",
   BiomarkerRegistry.toCanonical(value: 5.5, unit: "mmol/L", for: glucose), 99.1, tol: 0.2)
eq("glucose 99 mg/dL stays 99",
   BiomarkerRegistry.toCanonical(value: 99, unit: "mg/dL", for: glucose), 99)

let chol = BiomarkerRegistry.match("Total Cholesterol")!
eq("cholesterol 5.2 mmol/L → 201 mg/dL",
   BiomarkerRegistry.toCanonical(value: 5.2, unit: "mmol/L", for: chol), 201.08, tol: 0.5)

let creat = BiomarkerRegistry.match("Creatinine")!
eq("creatinine 88.4 µmol/L → 1.0 mg/dL",
   BiomarkerRegistry.toCanonical(value: 88.4, unit: "µmol/L", for: creat), 0.999, tol: 0.02)
eq("Greek mu (μ) parsed same as micro sign (µ)",
   BiomarkerRegistry.toCanonical(value: 88.4, unit: "μmol/L", for: creat), 0.999, tol: 0.02)

let hgb = BiomarkerRegistry.match("Hb")!
eq("haemoglobin 140 g/L → 14 g/dL",
   BiomarkerRegistry.toCanonical(value: 140, unit: "g/L", for: hgb), 14)

let vitd = BiomarkerRegistry.match("Vitamin D")!
eq("vitamin D 75 nmol/L → 30 ng/mL",
   BiomarkerRegistry.toCanonical(value: 75, unit: "nmol/L", for: vitd), 30.05, tol: 0.1)

let alt = BiomarkerRegistry.match("SGPT")!
eq("ALT 40 IU/L → 40 U/L (synonymous units)",
   BiomarkerRegistry.toCanonical(value: 40, unit: "IU/L", for: alt), 40)

print("\n▸ Refusing to convert what it doesn't understand")
ok("unknown unit returns nil rather than a wrong number",
   BiomarkerRegistry.toCanonical(value: 5, unit: "furlongs", for: glucose) == nil)
ok("blank unit passes the value through unchanged",
   BiomarkerRegistry.toCanonical(value: 5, unit: "", for: glucose) == 5)

print("\n▸ Round-trip consistency across every analyte")
var badRoundTrip: [String] = []
for def in BiomarkerRegistry.all {
    for (unit, factor) in def.conversions {
        let converted = BiomarkerRegistry.toCanonical(value: 10, unit: unit, for: def)
        if converted == nil || abs(converted! - 10 * factor) > 0.0001 {
            badRoundTrip.append("\(def.id)/\(unit)")
        }
    }
}
ok("every declared conversion applies its own factor", badRoundTrip.isEmpty)
if !badRoundTrip.isEmpty { print("       ⚠️  \(badRoundTrip.joined(separator: ", "))") }

print("\n" + String(repeating: "─", count: 58))
print(failed == 0 ? "✅ ALL \(passed) TESTS PASSED" : "❌ \(failed) FAILED, \(passed) passed")
print(String(repeating: "─", count: 58) + "\n")
exit(failed == 0 ? 0 : 1)
