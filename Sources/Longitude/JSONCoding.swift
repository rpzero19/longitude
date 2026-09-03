import Foundation

/// One place where the encoder and decoder are defined together.
///
/// The stock `.iso8601` strategy drops fractional seconds, so a value written
/// and read back is not the value you started with. Configuring the pair here
/// means they can't drift apart at separate call sites.
public enum JSONCoding {

    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    public static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .custom { date, enc in
            var c = enc.singleValueContainer()
            try c.encode(formatter.string(from: date))
        }
        return e
    }

    public static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            if let date = formatter.date(from: s) { return date }
            // Tolerate whole-second timestamps from any earlier build.
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            if let date = fallback.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(
                in: try dec.singleValueContainer(),
                debugDescription: "Unrecognised date: \(s)")
        }
        return d
    }
}

public extension Date {
    /// Truncated to the millisecond precision the stored ISO-8601 form holds.
    ///
    /// Applied as values enter the model so the in-memory object is exactly
    /// what will be written — otherwise a freshly created record and the same
    /// record loaded back compare as different.
    var storagePrecision: Date {
        Date(timeIntervalSince1970: (timeIntervalSince1970 * 1000).rounded() / 1000)
    }
}
