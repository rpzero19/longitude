import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// ─────────────────────────────────────────────────────────────────────────────
//  ModelExtractor.swift — on-device LLM assistance for lines the deterministic
//  parser couldn't resolve.
//
//  Strictly an enhancement. FoundationModels needs Apple Intelligence, which
//  needs an iPhone 15 Pro or newer, so the app must be fully usable without it.
//  Inference is local: report text never leaves the device.
// ─────────────────────────────────────────────────────────────────────────────

public enum ModelAvailability: Equatable, Sendable {
    case available
    case deviceNotEligible
    case notEnabled
    case modelNotReady
    case unsupportedOS

    public var explanation: String? {
        switch self {
        case .available:         return nil
        case .deviceNotEligible: return "This iPhone doesn't support Apple Intelligence, so results are read using the built-in parser."
        case .notEnabled:        return "Turn on Apple Intelligence in Settings for better reading of unusual report layouts."
        case .modelNotReady:     return "Apple Intelligence is still downloading. The built-in parser is being used meanwhile."
        case .unsupportedOS:     return "Requires iOS 26 or later for assisted reading. The built-in parser is being used."
        }
    }
}

#if canImport(FoundationModels)

/// One result row as the model should return it.
@available(iOS 26.0, *)
@Generable
struct ModelResult {
    @Guide(description: "The test or analyte name exactly as printed on the report")
    var name: String
    @Guide(description: "The numeric result value only, with no unit")
    var value: Double
    @Guide(description: "The unit of measurement, for example mg/dL or g/L. Empty string if none.")
    var unit: String
    @Guide(description: "The reference interval exactly as printed, for example '13.0 - 17.0' or '< 200'. Empty string if none.")
    var referenceRange: String
}

@available(iOS 26.0, *)
@Generable
struct ModelResultSet {
    @Guide(description: "Every laboratory test result found in the text. Exclude headers, patient details, page numbers and addresses.")
    var results: [ModelResult]
}

#endif

public enum ModelExtractor {

    public static var availability: ModelAvailability {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return .unsupportedOS }
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:      return .deviceNotEligible
            case .appleIntelligenceNotEnabled: return .notEnabled
            case .modelNotReady:          return .modelNotReady
            @unknown default:             return .modelNotReady
            }
        @unknown default:
            return .modelNotReady
        }
        #else
        return .unsupportedOS
        #endif
    }

    public static var isAvailable: Bool { availability == .available }

    private static let instructions = """
        You read laboratory report text and extract test results.

        Rules:
        - Return only actual test results: an analyte name with a numeric value.
        - Never invent a value. If a number is not clearly a result, omit the row.
        - Copy names, units and reference intervals exactly as printed. Do not \
        convert units, translate names, or normalise anything.
        - Ignore patient details, doctor names, addresses, page numbers, \
        section headings and dates.
        - If the text contains no results, return an empty list.
        """

    /// The on-device model has a modest context window, so long reports are
    /// sent in overlapping-free chunks of whole lines.
    static func chunk(_ text: String, linesPerChunk: Int = 25) -> [String] {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard !lines.isEmpty else { return [] }
        return stride(from: 0, to: lines.count, by: linesPerChunk).map { start in
            lines[start..<min(start + linesPerChunk, lines.count)].joined(separator: "\n")
        }
    }

    /// Asks the model to read the text. Returns [] when unavailable, so callers
    /// can treat this as a best-effort supplement.
    public static func extract(from text: String) async -> [ParsedLine] {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *), isAvailable else { return [] }

        var found: [ParsedLine] = []
        for piece in chunk(text) {
            do {
                let session = LanguageModelSession(instructions: instructions)
                let reply = try await session.respond(
                    to: "Extract the laboratory results from this text:\n\n\(piece)",
                    generating: ModelResultSet.self)
                found += reply.content.results.map {
                    ParsedLine(name: $0.name, value: $0.value,
                               unit: $0.unit, range: $0.referenceRange)
                }
            } catch {
                // A refusal, a context overflow or a guardrail trip on one chunk
                // must not lose the chunks that did work.
                print("Longitude: model chunk failed — \(error.localizedDescription)")
                continue
            }
        }
        return found
        #else
        return []
        #endif
    }
}

// MARK: - Import pipeline

public enum ImportPipeline {

    /// Deterministic parse first, then the model for anything it missed.
    ///
    /// The deterministic result always wins on conflict: it is reproducible and
    /// auditable, where a model output is neither.
    public static func readings(from text: String, date: Date,
                                reportID: UUID, useModel: Bool = true) async -> [Reading] {
        let deterministic = LabTextParser.parse(text, date: date, reportID: reportID)

        guard useModel, ModelExtractor.isAvailable else { return deterministic }

        let alreadyFound = Set(deterministic.compactMap { $0.biomarkerID })
        let modelLines = await ModelExtractor.extract(from: text)

        let extra: [Reading] = modelLines.compactMap { line in
            // Only accept analytes the registry recognises. An unrecognised name
            // from a model is more likely a hallucination than a discovery.
            guard let def = BiomarkerRegistry.match(line.name),
                  !alreadyFound.contains(def.id) else { return nil }
            return Reading(
                biomarkerID: def.id, rawName: line.name, value: line.value,
                unit: line.unit,
                canonicalValue: BiomarkerRegistry.toCanonical(
                    value: line.value, unit: line.unit, for: def),
                range: ReferenceRange.parse(line.range),
                date: date, reportID: reportID)
        }

        // De-duplicate anything the model repeated across chunks.
        var seen = alreadyFound
        let deduped = extra.filter { r in
            guard let id = r.biomarkerID, !seen.contains(id) else { return false }
            seen.insert(id)
            return true
        }
        return deterministic + deduped
    }
}
