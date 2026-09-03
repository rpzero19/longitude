import SwiftUI

struct ReportsView: View {
    @EnvironmentObject var store: LabStore

    var body: some View {
        NavigationStack {
            List {
                if store.reportsNewestFirst.isEmpty {
                    Text("No reports added yet").foregroundStyle(.secondary)
                }
                ForEach(store.reportsNewestFirst) { report in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(report.date.formatted(date: .long, time: .omitted))
                            .font(.subheadline.weight(.medium))
                        Text([report.labName.isEmpty ? nil : report.labName,
                              "\(store.data.readings.filter { $0.reportID == report.id }.count) results"]
                            .compactMap { $0 }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    offsets.map { store.reportsNewestFirst[$0] }.forEach(store.deleteReport)
                }
            }
            .navigationTitle("Reports")
            .toolbar { if !store.reportsNewestFirst.isEmpty { EditButton() } }
        }
    }
}
