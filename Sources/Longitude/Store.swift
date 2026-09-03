import Foundation
import Combine

/// Persistence and observable state. One JSON document plus the original
/// report files, all inside the app's container. Nothing is ever transmitted.
public final class LabStore: ObservableObject {

    @Published public private(set) var data: AppData
    @Published public private(set) var loadFailure: String?

    private let fileURL: URL
    private let directory: URL

    public init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.directory = dir
        self.fileURL = dir.appendingPathComponent("longitude.json")

        // A decode failure must never silently become an empty document: the
        // next save would overwrite years of results. Keep the original and say so.
        if let raw = try? Data(contentsOf: fileURL) {
            do {
                self.data = try JSONCoding.decoder.decode(AppData.self, from: raw)
            } catch {
                let stamp = Int(Date().timeIntervalSince1970)
                let backup = dir.appendingPathComponent("longitude-unreadable-\(stamp).json")
                try? FileManager.default.moveItem(at: fileURL, to: backup)
                self.data = AppData()
                self.loadFailure = "Your saved results couldn't be read. The original file "
                    + "was kept as \(backup.lastPathComponent), so nothing is lost."
                print("Longitude: decode failed — \(error)")
            }
        } else {
            self.data = AppData()
        }
    }

    // MARK: Derived

    public var series: [Series] { SeriesBuilder.build(from: data.readings) }

    public func series(in panel: Panel) -> [Series] {
        series.filter { $0.panel == panel }
    }

    public var panelsPresent: [Panel] {
        let present = Set(series.map(\.panel))
        return Panel.allCases.filter { present.contains($0) }
    }

    public var reportsNewestFirst: [LabReport] {
        data.reports.sorted { $0.date > $1.date }
    }

    /// Readings outside the interval the lab itself printed.
    public var outOfRange: [Reading] {
        guard let latest = reportsNewestFirst.first else { return [] }
        return data.readings
            .filter { $0.reportID == latest.id && ($0.status == .above || $0.status == .below) }
            .sorted { $0.displayName < $1.displayName }
    }

    // MARK: Mutations

    public func add(report: LabReport, readings: [Reading]) {
        var stamped = readings
        for i in stamped.indices {
            stamped[i].reportID = report.id
            stamped[i].date = report.date
        }
        data.reports.append(report)
        data.readings.append(contentsOf: stamped)
        save()
    }

    public func deleteReport(_ report: LabReport) {
        data.readings.removeAll { $0.reportID == report.id }
        data.reports.removeAll { $0.id == report.id }
        if let file = report.sourceFilename {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        }
        save()
    }

    public func dismissLoadFailure() { loadFailure = nil }

    public func save() {
        do {
            try JSONCoding.encoder.encode(data).write(to: fileURL, options: .atomic)
        } catch {
            print("Longitude: save failed — \(error.localizedDescription)")
        }
    }

    /// CSV of every reading, for the user's own records or their doctor.
    public func exportCSV() throws -> URL {
        var rows = ["Date,Analyte,Value,Unit,Reference range,Status,As printed by lab"]
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        for r in data.readings.sorted(by: { $0.date < $1.date }) {
            func q(_ s: String) -> String {
                "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            rows.append([df.string(from: r.date), q(r.displayName), "\(r.value)",
                         q(r.unit), q(r.range.printed), r.status.rawValue, q(r.rawName)]
                        .joined(separator: ","))
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Longitude-results.csv")
        try rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
