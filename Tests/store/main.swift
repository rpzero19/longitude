import Foundation

var passed = 0, failed = 0
func ok(_ n: String, _ c: Bool) {
    if c { passed += 1; print("  ✅ \(n)") } else { failed += 1; print("  ❌ \(n)") }
}

/// Each test gets its own container, so nothing touches a real document. The
/// directory is handed back rather than read off the store: reopening the same
/// container is the only honest way to test that a change was persisted, and
/// that shouldn't require production code to expose its internals.
func freshDirectory() -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("longitude-test-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}
func freshStore() -> LabStore { LabStore(directory: freshDirectory()) }

let day = Calendar(identifier: .gregorian)
    .date(from: DateComponents(year: 2025, month: 3, day: 12))!

print("\n▸ Correcting a saved reading")
let directory = freshDirectory()
let store = LabStore(directory: directory)
let report = LabReport(date: day, labName: "City Pathology")
let wrong = ManualEntry.reading(name: "Creatinine", value: 0.7, unit: "mg/dL",
                                rangeText: "0.7 - 1.2", date: day)!
store.add(report: report, readings: [wrong])
ok("the reading was saved", store.data.readings.count == 1)

let corrected = ManualEntry.edited(wrong, name: "Creatinine", value: 1.2,
                                   unit: "mg/dL", rangeText: "0.7 - 1.2")!
store.update(corrected)
ok("the value is corrected", store.data.readings.first?.value == 1.2)
ok("and it replaced the row rather than adding one", store.data.readings.count == 1)
ok("the series reflects it", store.series.first?.latest?.value == 1.2)
ok("it still belongs to its report", store.data.readings.first?.reportID == report.id)

print("\n▸ A correction cannot move a result to another date or report")
var smuggled = corrected
smuggled.date = day.addingTimeInterval(60 * 60 * 24 * 365)
smuggled.reportID = UUID()
store.update(smuggled)
ok("the stored date is kept", store.data.readings.first?.date == day.storagePrecision)
ok("the owning report is kept", store.data.readings.first?.reportID == report.id)

print("\n▸ An edit survives a reload")
let reloaded = LabStore(directory: directory)
ok("the corrected value persisted", reloaded.data.readings.first?.value == 1.2)

print("\n▸ Editing an analyte re-resolves its series")
let s2 = freshStore()
let mystery = ManualEntry.reading(name: "Zorbium", value: 5, unit: "g/dL",
                                  rangeText: "", date: day)!
s2.add(report: LabReport(date: day, labName: ""), readings: [mystery])
ok("an unrecognised analyte still forms a series", s2.series.count == 1)
ok("and is not given a false identity", s2.series.first?.readings.first?.biomarkerID == nil)
s2.update(ManualEntry.edited(mystery, name: "Haemoglobin", value: 14.2,
                             unit: "g/dL", rangeText: "13.0 - 17.0")!)
ok("renaming it resolves the analyte", s2.series.first?.readings.first?.biomarkerID == "hgb")
ok("and the series follows", s2.series.first?.name == "Haemoglobin")

print("\n▸ Deleting a saved reading")
let s3 = freshStore()
let r1 = ManualEntry.reading(name: "Haemoglobin", value: 14.2, unit: "g/dL",
                             rangeText: "13.0 - 17.0", date: day)!
let r2 = ManualEntry.reading(name: "HbA1c", value: 5.6, unit: "%",
                             rangeText: "4.0 - 5.7", date: day)!
let rep3 = LabReport(date: day, labName: "")
s3.add(report: rep3, readings: [r1, r2])
s3.delete(r1)
ok("the reading is gone", s3.data.readings.count == 1)
ok("the other one is untouched", s3.data.readings.first?.value == 5.6)
ok("its report is kept — deleting reports is a separate, explicit act",
   s3.data.reports.count == 1)
ok("deleting something already gone is harmless",
   { s3.delete(r1); return s3.data.readings.count == 1 }())

print("\n" + String(repeating: "─", count: 58))
print(failed == 0 ? "✅ ALL \(passed) TESTS PASSED" : "❌ \(failed) FAILED, \(passed) passed")
print(String(repeating: "─", count: 58) + "\n")
exit(failed == 0 ? 0 : 1)
