import Foundation

// ─────────────────────────────────────────────────────────────────────────────
//  Biomarkers.swift — the canonical registry.
//
//  This file is the reason the app works. Labs name the same analyte a dozen
//  ways ("SGPT", "ALT", "Alanine Aminotransferase") and report it in different
//  units in different countries. Without normalisation a user's history is a
//  pile of disconnected readings instead of a trend line.
//
//  Bundled, not fetched: the app must work offline, and reference data that
//  arrives over a network would mean the data left the device.
// ─────────────────────────────────────────────────────────────────────────────

public enum Panel: String, Codable, CaseIterable, Sendable, Identifiable {
    case haematology, lipids, metabolic, liver, kidney, thyroid
    case vitamins, electrolytes, inflammation, hormones

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .haematology:  return "Blood count"
        case .lipids:       return "Lipids"
        case .metabolic:    return "Metabolic"
        case .liver:        return "Liver"
        case .kidney:       return "Kidney"
        case .thyroid:      return "Thyroid"
        case .vitamins:     return "Vitamins & iron"
        case .electrolytes: return "Electrolytes"
        case .inflammation: return "Inflammation"
        case .hormones:     return "Hormones"
        }
    }

    public var systemImage: String {
        switch self {
        case .haematology:  return "drop.fill"
        case .lipids:       return "circle.hexagongrid.fill"
        case .metabolic:    return "flame.fill"
        case .liver:        return "leaf.fill"
        case .kidney:       return "aqi.medium"
        case .thyroid:      return "bolt.fill"
        case .vitamins:     return "pills.fill"
        case .electrolytes: return "atom"
        case .inflammation: return "waveform.path.ecg"
        case .hormones:     return "chart.xyaxis.line"
        }
    }
}

/// A single analyte: how to recognise it, and how to bring every lab's units
/// onto one scale.
public struct BiomarkerDef: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let panel: Panel
    /// Every spelling seen in the wild, including regional ones.
    public let aliases: [String]
    public let canonicalUnit: String
    /// unit (normalised) → multiplier that converts a value INTO canonicalUnit.
    public let conversions: [String: Double]
    /// Higher is generally better (HDL, eGFR). Drives chart direction only —
    /// never a judgement about the reading.
    public let higherIsBetter: Bool

    public init(id: String, name: String, panel: Panel, aliases: [String],
                canonicalUnit: String, conversions: [String: Double] = [:],
                higherIsBetter: Bool = false) {
        self.id = id
        self.name = name
        self.panel = panel
        self.aliases = aliases
        self.canonicalUnit = canonicalUnit
        self.conversions = conversions
        self.higherIsBetter = higherIsBetter
    }
}

public enum BiomarkerRegistry {

    /// Strips case, punctuation, spacing and common noise so that
    /// "S. Cholesterol (Total)" and "cholesterol total" collide.
    public static func normalise(_ raw: String) -> String {
        var s = raw.lowercased()
        // Drop specimen prefixes labs love: "S.", "P.", "B.", "Serum", "Plasma".
        for prefix in ["serum ", "plasma ", "blood ", "s. ", "p. ", "b. ", "s.", "p."] {
            if s.hasPrefix(prefix) { s = String(s.dropFirst(prefix.count)); break }
        }
        let keep = s.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == " "
        }
        s = String(String.UnicodeScalarView(keep))
        // Collapse runs of whitespace.
        return s.split(separator: " ").joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    public static func normaliseUnit(_ raw: String) -> String {
        var s = raw.lowercased()
            .replacingOccurrences(of: "μ", with: "u")   // Greek mu
            .replacingOccurrences(of: "µ", with: "u")   // micro sign
            // Labs type "m2" where the registry prints "m²"; same unit.
            .replacingOccurrences(of: "²", with: "2")
            .replacingOccurrences(of: "³", with: "3")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "%", with: "percent")
        // "mg/dl", "mg / dL", "mgdl" all mean the same thing.
        s = s.replacingOccurrences(of: ".", with: "")
        return s
    }

    public static let all: [BiomarkerDef] = [

        // ── Haematology ──────────────────────────────────────────────────────
        BiomarkerDef(id: "hgb", name: "Haemoglobin", panel: .haematology,
            aliases: ["haemoglobin", "hemoglobin", "hb", "hgb", "haemoglobin hb"],
            canonicalUnit: "g/dL", conversions: ["g/l": 0.1, "gdl": 1, "gl": 0.1],
            higherIsBetter: true),
        BiomarkerDef(id: "hct", name: "Haematocrit", panel: .haematology,
            aliases: ["haematocrit", "hematocrit", "hct", "pcv", "packed cell volume"],
            canonicalUnit: "%"),
        BiomarkerDef(id: "rbc", name: "Red blood cells", panel: .haematology,
            aliases: ["rbc", "red blood cell count", "red blood cells",
                      "total rbc count", "erythrocyte count"],
            canonicalUnit: "10^6/µL"),
        BiomarkerDef(id: "wbc", name: "White blood cells", panel: .haematology,
            aliases: ["wbc", "white blood cell count", "white blood cells",
                      "total wbc count", "total leucocyte count", "tlc", "leucocyte count"],
            canonicalUnit: "10^3/µL"),
        BiomarkerDef(id: "plt", name: "Platelets", panel: .haematology,
            aliases: ["platelet count", "platelets", "plt", "thrombocyte count"],
            canonicalUnit: "10^3/µL"),
        BiomarkerDef(id: "mcv", name: "MCV", panel: .haematology,
            aliases: ["mcv", "mean corpuscular volume"], canonicalUnit: "fL"),
        BiomarkerDef(id: "mch", name: "MCH", panel: .haematology,
            aliases: ["mch", "mean corpuscular haemoglobin", "mean corpuscular hemoglobin"],
            canonicalUnit: "pg"),
        BiomarkerDef(id: "mchc", name: "MCHC", panel: .haematology,
            aliases: ["mchc", "mean corpuscular haemoglobin concentration"],
            canonicalUnit: "g/dL"),
        BiomarkerDef(id: "rdw", name: "RDW", panel: .haematology,
            aliases: ["rdw", "rdwcv", "red cell distribution width"], canonicalUnit: "%"),
        BiomarkerDef(id: "neut", name: "Neutrophils", panel: .haematology,
            aliases: ["neutrophils", "neutrophil", "polymorphs", "segmented neutrophils"],
            canonicalUnit: "%"),
        BiomarkerDef(id: "lymph", name: "Lymphocytes", panel: .haematology,
            aliases: ["lymphocytes", "lymphocyte"], canonicalUnit: "%"),

        // ── Lipids ───────────────────────────────────────────────────────────
        BiomarkerDef(id: "chol", name: "Total cholesterol", panel: .lipids,
            aliases: ["total cholesterol", "cholesterol total", "cholesterol",
                      "chol", "cholesterol serum"],
            canonicalUnit: "mg/dL", conversions: ["mmol/l": 38.67, "mmoll": 38.67]),
        BiomarkerDef(id: "ldl", name: "LDL cholesterol", panel: .lipids,
            aliases: ["ldl", "ldl cholesterol", "cholesterol ldl", "ldl c",
                      "low density lipoprotein"],
            canonicalUnit: "mg/dL", conversions: ["mmol/l": 38.67, "mmoll": 38.67]),
        BiomarkerDef(id: "hdl", name: "HDL cholesterol", panel: .lipids,
            aliases: ["hdl", "hdl cholesterol", "cholesterol hdl", "hdl c",
                      "high density lipoprotein"],
            canonicalUnit: "mg/dL", conversions: ["mmol/l": 38.67, "mmoll": 38.67],
            higherIsBetter: true),
        BiomarkerDef(id: "trig", name: "Triglycerides", panel: .lipids,
            aliases: ["triglycerides", "triglyceride", "tg", "trig"],
            canonicalUnit: "mg/dL", conversions: ["mmol/l": 88.57, "mmoll": 88.57]),
        BiomarkerDef(id: "vldl", name: "VLDL cholesterol", panel: .lipids,
            aliases: ["vldl", "vldl cholesterol", "cholesterol vldl"],
            canonicalUnit: "mg/dL", conversions: ["mmol/l": 38.67, "mmoll": 38.67]),

        // ── Metabolic ────────────────────────────────────────────────────────
        BiomarkerDef(id: "glucose_f", name: "Fasting glucose", panel: .metabolic,
            aliases: ["fasting glucose", "glucose fasting", "fbs", "fasting blood sugar",
                      "glucose fasting fbs", "fasting plasma glucose", "fpg", "sugar fasting"],
            canonicalUnit: "mg/dL", conversions: ["mmol/l": 18.018, "mmoll": 18.018]),
        BiomarkerDef(id: "glucose_pp", name: "Post-meal glucose", panel: .metabolic,
            aliases: ["post lunch glucose", "postprandial glucose", "post prandial glucose",
                      "ppbs", "pp glucose", "post prandial blood sugar",
                      "post lunch blood sugar", "2 hour postprandial glucose",
                      "post prandial plasma glucose"],
            canonicalUnit: "mg/dL", conversions: ["mmol/l": 18.018, "mmoll": 18.018]),
        BiomarkerDef(id: "hba1c", name: "HbA1c", panel: .metabolic,
            aliases: ["hba1c", "hb a1c", "glycated haemoglobin", "glycosylated haemoglobin",
                      "glycated hemoglobin", "a1c", "haemoglobin a1c"],
            canonicalUnit: "%"),
        BiomarkerDef(id: "insulin", name: "Insulin (fasting)", panel: .metabolic,
            aliases: ["insulin", "fasting insulin", "insulin fasting"],
            canonicalUnit: "µIU/mL"),

        // ── Liver ────────────────────────────────────────────────────────────
        BiomarkerDef(id: "alt", name: "ALT (SGPT)", panel: .liver,
            aliases: ["alt", "sgpt", "alt sgpt", "sgpt alt", "alanine aminotransferase",
                      "alanine transaminase", "alt gpt"],
            canonicalUnit: "U/L", conversions: ["iu/l": 1, "iul": 1, "ul": 1]),
        BiomarkerDef(id: "ast", name: "AST (SGOT)", panel: .liver,
            aliases: ["ast", "sgot", "ast sgot", "sgot ast", "aspartate aminotransferase",
                      "aspartate transaminase", "ast got"],
            canonicalUnit: "U/L", conversions: ["iu/l": 1, "iul": 1, "ul": 1]),
        BiomarkerDef(id: "alp", name: "Alkaline phosphatase", panel: .liver,
            aliases: ["alp", "alkaline phosphatase", "alk phos", "s alkaline phosphatase"],
            canonicalUnit: "U/L", conversions: ["iu/l": 1, "iul": 1, "ul": 1]),
        BiomarkerDef(id: "ggt", name: "GGT", panel: .liver,
            aliases: ["ggt", "gamma gt", "gamma glutamyl transferase", "ggtp"],
            canonicalUnit: "U/L", conversions: ["iu/l": 1, "iul": 1, "ul": 1]),
        BiomarkerDef(id: "bili_t", name: "Bilirubin (total)", panel: .liver,
            aliases: ["total bilirubin", "bilirubin total", "bilirubin", "t bilirubin"],
            canonicalUnit: "mg/dL", conversions: ["umol/l": 0.0585, "umoll": 0.0585]),
        BiomarkerDef(id: "bili_d", name: "Bilirubin (direct)", panel: .liver,
            aliases: ["direct bilirubin", "bilirubin direct", "conjugated bilirubin"],
            canonicalUnit: "mg/dL", conversions: ["umol/l": 0.0585, "umoll": 0.0585]),
        BiomarkerDef(id: "alb", name: "Albumin", panel: .liver,
            aliases: ["albumin", "serum albumin"],
            canonicalUnit: "g/dL", conversions: ["g/l": 0.1, "gl": 0.1]),
        BiomarkerDef(id: "prot_t", name: "Total protein", panel: .liver,
            aliases: ["total protein", "protein total", "total proteins"],
            canonicalUnit: "g/dL", conversions: ["g/l": 0.1, "gl": 0.1]),
        BiomarkerDef(id: "bili_i", name: "Bilirubin (indirect)", panel: .liver,
            aliases: ["indirect bilirubin", "bilirubin indirect",
                      "unconjugated bilirubin"],
            canonicalUnit: "mg/dL", conversions: ["umol/l": 0.0585, "umoll": 0.0585]),
        BiomarkerDef(id: "glob", name: "Globulin", panel: .liver,
            aliases: ["globulin", "serum globulin", "total globulin"],
            canonicalUnit: "g/dL", conversions: ["g/l": 0.1, "gl": 0.1]),
        // A ratio has no unit. "A/GRatio." normalises to "agratio" — labs run
        // the words together — so both spacings have to be listed.
        BiomarkerDef(id: "ag_ratio", name: "A/G ratio", panel: .liver,
            aliases: ["a/g ratio", "agratio", "ag ratio",
                      "albumin globulin ratio", "albumin/globulin ratio"],
            canonicalUnit: "ratio"),
        // Urine analytes are distinct tests from their serum namesakes and
        // must never merge into the same timeline — different specimen,
        // different reference interval, different meaning.
        BiomarkerDef(id: "creat_u", name: "Creatinine (urine)", panel: .kidney,
            aliases: ["creatinine spot urine", "urine creatinine",
                      "creatinine urine", "spot urine creatinine"],
            canonicalUnit: "mg/dL"),
        BiomarkerDef(id: "prot_u", name: "Urinary protein", panel: .kidney,
            aliases: ["urinary protein", "urine protein", "protein urine"],
            canonicalUnit: "mg/dL"),
        BiomarkerDef(id: "prot_u24", name: "Urinary protein (24h)", panel: .kidney,
            aliases: ["24 hours urinary protein", "24 hour urinary protein",
                      "24 hour urine protein", "urine protein 24 hours"],
            canonicalUnit: "mg/day"),
        BiomarkerDef(id: "vol_u24", name: "Urine volume (24h)", panel: .kidney,
            aliases: ["24 hours urinary total volume", "24 hour urine volume",
                      "24 hours urine volume", "total urine volume", "urine volume"],
            canonicalUnit: "mL/day"),
        BiomarkerDef(id: "microalb_u", name: "Microalbumin (urine)", panel: .kidney,
            aliases: ["microalbumin", "urine microalbumin",
                      "microalbumin spot urine", "spot urine microalbumin",
                      "urinary microalbumin", "microalbuminuria"],
            canonicalUnit: "mg/L"),

        // ── Kidney ───────────────────────────────────────────────────────────
        BiomarkerDef(id: "creat", name: "Creatinine", panel: .kidney,
            aliases: ["creatinine", "serum creatinine", "creatinine serum", "s creatinine"],
            canonicalUnit: "mg/dL", conversions: ["umol/l": 0.0113, "umoll": 0.0113]),
        BiomarkerDef(id: "urea", name: "Urea", panel: .kidney,
            aliases: ["urea", "blood urea", "serum urea"],
            canonicalUnit: "mg/dL", conversions: ["mmol/l": 6.006, "mmoll": 6.006]),
        BiomarkerDef(id: "bun", name: "BUN", panel: .kidney,
            aliases: ["bun", "blood urea nitrogen", "urea nitrogen"],
            canonicalUnit: "mg/dL", conversions: ["mmol/l": 2.8, "mmoll": 2.8]),
        BiomarkerDef(id: "egfr", name: "eGFR", panel: .kidney,
            aliases: ["egfr", "estimated gfr", "gfr", "egfr ckd epi",
                      "mdrd gfr", "mdrd", "glomerular filtration rate",
                      "estimated glomerular filtration rate"],
            canonicalUnit: "mL/min/1.73m²", higherIsBetter: true),
        BiomarkerDef(id: "urate", name: "Uric acid", panel: .kidney,
            aliases: ["uric acid", "urate", "serum uric acid"],
            canonicalUnit: "mg/dL", conversions: ["umol/l": 0.0168, "umoll": 0.0168]),

        // ── Thyroid ──────────────────────────────────────────────────────────
        BiomarkerDef(id: "tsh", name: "TSH", panel: .thyroid,
            aliases: ["tsh", "thyroid stimulating hormone", "thyrotropin",
                      "tsh ultrasensitive", "s tsh"],
            canonicalUnit: "µIU/mL", conversions: ["miu/l": 1, "miul": 1, "uiu/ml": 1]),
        BiomarkerDef(id: "ft4", name: "Free T4", panel: .thyroid,
            aliases: ["free t4", "ft4", "free thyroxine", "t4 free"],
            canonicalUnit: "ng/dL", conversions: ["pmol/l": 0.0777, "pmoll": 0.0777]),
        BiomarkerDef(id: "ft3", name: "Free T3", panel: .thyroid,
            aliases: ["free t3", "ft3", "free triiodothyronine", "t3 free"],
            canonicalUnit: "pg/mL", conversions: ["pmol/l": 0.651, "pmoll": 0.651]),
        BiomarkerDef(id: "t4", name: "Total T4", panel: .thyroid,
            aliases: ["t4", "total t4", "thyroxine", "t4 total"],
            canonicalUnit: "µg/dL"),
        BiomarkerDef(id: "t3", name: "Total T3", panel: .thyroid,
            aliases: ["t3", "total t3", "triiodothyronine", "t3 total"],
            canonicalUnit: "ng/dL"),

        // ── Vitamins & iron ──────────────────────────────────────────────────
        // The D2 and D3 fractions are reported alongside the total. They are
        // separate measurements and must not fold into the total's timeline.
        BiomarkerDef(id: "vitd2", name: "Vitamin D2", panel: .vitamins,
            aliases: ["vitamin d2", "vit d2", "ergocalciferol",
                      "25 oh vit d2 ergocalciferol", "25 oh vitamin d2",
                      "25 oh vit d2"],
            canonicalUnit: "ng/mL", conversions: ["nmol/l": 0.4006, "nmoll": 0.4006]),
        BiomarkerDef(id: "vitd3", name: "Vitamin D3", panel: .vitamins,
            aliases: ["vitamin d3", "vit d3", "cholecalciferol",
                      "25 oh vit d3 cholecalciferol", "25 oh vitamin d3",
                      "25 oh vit d3"],
            canonicalUnit: "ng/mL", conversions: ["nmol/l": 0.4006, "nmoll": 0.4006]),
        BiomarkerDef(id: "vitd", name: "Vitamin D (25-OH)", panel: .vitamins,
            aliases: ["vitamin d", "25 oh vitamin d", "vitamin d 25 hydroxy",
                      "25 hydroxyvitamin d", "vit d", "vitamin d total"],
            canonicalUnit: "ng/mL", conversions: ["nmol/l": 0.4006, "nmoll": 0.4006],
            higherIsBetter: true),
        BiomarkerDef(id: "b12", name: "Vitamin B12", panel: .vitamins,
            aliases: ["vitamin b12", "b12", "cobalamin", "vit b12"],
            canonicalUnit: "pg/mL", conversions: ["pmol/l": 1.355, "pmoll": 1.355],
            higherIsBetter: true),
        BiomarkerDef(id: "folate", name: "Folate", panel: .vitamins,
            aliases: ["folate", "folic acid", "serum folate"],
            canonicalUnit: "ng/mL", higherIsBetter: true),
        BiomarkerDef(id: "ferritin", name: "Ferritin", panel: .vitamins,
            aliases: ["ferritin", "serum ferritin"],
            canonicalUnit: "ng/mL", conversions: ["ug/l": 1, "ugl": 1]),
        BiomarkerDef(id: "iron", name: "Iron", panel: .vitamins,
            aliases: ["iron", "serum iron"],
            canonicalUnit: "µg/dL", conversions: ["umol/l": 5.587, "umoll": 5.587]),

        // ── Electrolytes ─────────────────────────────────────────────────────
        BiomarkerDef(id: "na", name: "Sodium", panel: .electrolytes,
            aliases: ["sodium", "na", "serum sodium"], canonicalUnit: "mmol/L",
            conversions: ["meq/l": 1, "meql": 1]),
        BiomarkerDef(id: "k", name: "Potassium", panel: .electrolytes,
            aliases: ["potassium", "k", "serum potassium"], canonicalUnit: "mmol/L",
            conversions: ["meq/l": 1, "meql": 1]),
        BiomarkerDef(id: "cl", name: "Chloride", panel: .electrolytes,
            aliases: ["chloride", "cl", "serum chloride"], canonicalUnit: "mmol/L",
            conversions: ["meq/l": 1, "meql": 1]),
        BiomarkerDef(id: "ca", name: "Calcium", panel: .electrolytes,
            aliases: ["calcium", "total calcium", "serum calcium"],
            canonicalUnit: "mg/dL", conversions: ["mmol/l": 4.008, "mmoll": 4.008]),

        // ── Inflammation ─────────────────────────────────────────────────────
        BiomarkerDef(id: "crp", name: "CRP", panel: .inflammation,
            aliases: ["crp", "c reactive protein", "hs crp", "hscrp",
                      "high sensitivity crp"],
            canonicalUnit: "mg/L", conversions: ["mg/dl": 10, "mgdl": 10]),
        BiomarkerDef(id: "esr", name: "ESR", panel: .inflammation,
            aliases: ["esr", "erythrocyte sedimentation rate", "sed rate"],
            canonicalUnit: "mm/hr"),

        // ── Hormones ─────────────────────────────────────────────────────────
        BiomarkerDef(id: "testo", name: "Testosterone (total)", panel: .hormones,
            aliases: ["testosterone", "total testosterone", "testosterone total"],
            canonicalUnit: "ng/dL", conversions: ["nmol/l": 28.82, "nmoll": 28.82]),
        BiomarkerDef(id: "cortisol", name: "Cortisol", panel: .hormones,
            aliases: ["cortisol", "serum cortisol", "cortisol morning"],
            canonicalUnit: "µg/dL", conversions: ["nmol/l": 0.0363, "nmoll": 0.0363]),
        BiomarkerDef(id: "psa", name: "PSA", panel: .hormones,
            aliases: ["psa", "prostate specific antigen", "total psa"],
            canonicalUnit: "ng/mL"),
    ]

    /// Exact-alias lookup table, built once.
    private static let byAlias: [String: BiomarkerDef] = {
        var map: [String: BiomarkerDef] = [:]
        for def in all {
            for alias in def.aliases { map[normalise(alias)] = def }
            map[normalise(def.name)] = def
        }
        return map
    }()

    public static func definition(id: String) -> BiomarkerDef? {
        all.first { $0.id == id }
    }

    /// Resolves a lab's label to a known analyte. Exact alias match only —
    /// a wrong match silently corrupts a trend line, so ambiguity returns nil
    /// and the reading is kept as unrecognised rather than guessed at.
    public static func match(_ rawName: String) -> BiomarkerDef? {
        if let hit = byAlias[normalise(rawName)] { return hit }
        // Labs append method or specimen notes: "Cholesterol - Total (CHOD-PAP)".
        // Retry on the text before each separator — split the RAW string, since
        // normalising strips the very punctuation being searched for.
        for separator in ["(", "-", ",", ":", "/"] {
            guard let cut = rawName.range(of: separator) else { continue }
            let head = normalise(String(rawName[..<cut.lowerBound]))
            if !head.isEmpty, let hit = byAlias[head] { return hit }
        }
        return nil
    }

    /// Converts a reading into the analyte's canonical unit.
    /// Returns nil when the unit is unrecognised — better to show the original
    /// than to plot a silently wrong number.
    public static func toCanonical(value: Double, unit: String,
                                   for def: BiomarkerDef) -> Double? {
        let u = normaliseUnit(unit)
        if u == normaliseUnit(def.canonicalUnit) { return value }
        if u.isEmpty { return value }
        for (from, factor) in def.conversions where normaliseUnit(from) == u {
            return value * factor
        }
        return nil
    }
}
