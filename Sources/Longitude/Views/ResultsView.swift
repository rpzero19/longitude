import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var store: LabStore
    @State private var importing = false
    @State private var shareURL: URL?
    /// `-openSeries hgb` at launch pushes straight to one chart, so App Store
    /// screenshots can be captured without driving the UI by hand.
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.series.isEmpty { empty } else { list }
            }
            .navigationDestination(for: String.self) { id in
                if let s = store.series.first(where: { $0.id == id }) {
                    SeriesDetailView(series: s)
                } else {
                    // Deleting the last reading of an analyte removes the series
                    // out from under this screen. Say so, rather than leaving a
                    // blank page behind a back button.
                    ContentUnavailableView("No readings left",
                                           systemImage: "chart.xyaxis.line",
                                           description: Text("Every reading for this "
                                             + "test has been deleted."))
                }
            }
            .onAppear {
                guard path.isEmpty,
                      let wanted = UserDefaults.standard.string(forKey: "openSeries"),
                      store.series.contains(where: { $0.id == wanted }) else { return }
                path.append(wanted)
            }
            .navigationTitle("Results")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { importing = true } label: {
                            Label("Add a report", systemImage: "plus")
                        }
                        if !store.series.isEmpty {
                            Button { shareURL = try? store.exportCSV() } label: {
                                Label("Export CSV", systemImage: "square.and.arrow.up")
                            }
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $importing) { ImportView() }
            .sheet(item: $shareURL) { ShareSheet(url: $0) }
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No results yet", systemImage: "chart.xyaxis.line")
        } description: {
            Text("Add a lab report and Longitude builds a timeline from it. Everything stays on this device.")
        } actions: {
            Button("Add a report") { importing = true }.buttonStyle(.borderedProminent)
        }
    }

    private var list: some View {
        List {
            if let failure = store.loadFailure {
                Section {
                    Label(failure, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.red)
                    Button("OK") { store.dismissLoadFailure() }.font(.caption)
                }
            }

            if !store.outOfRange.isEmpty {
                Section {
                    ForEach(store.outOfRange) { r in
                        HStack {
                            Circle()
                                .fill(r.status == .above ? Color.orange : Color.blue)
                                .frame(width: 8, height: 8)
                            Text(r.displayName).font(.subheadline)
                            Spacer()
                            Text("\(fmt(r.value)) \(r.unit)")
                                .font(.subheadline.weight(.medium)).monospacedDigit()
                            Text(r.status == .above ? "above" : "below")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Outside the lab's range — most recent report")
                } footer: {
                    Text("Compared against the reference interval printed on your report. Longitude doesn't interpret results — talk to your doctor.")
                }
            }

            ForEach(store.panelsPresent) { panel in
                Section(panel.label) {
                    ForEach(store.series(in: panel)) { s in
                        NavigationLink(value: s.id) { row(s) }
                    }
                }
            }
        }
    }

    private func row(_ s: Series) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.name).font(.subheadline)
                Text("\(s.readings.count) reading\(s.readings.count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let latest = s.latest {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(fmt(latest.plottedValue)) \(s.unit)")
                        .font(.subheadline.weight(.medium)).monospacedDigit()
                    if let pct = s.percentChange, abs(pct) >= 0.5 {
                        HStack(spacing: 2) {
                            Image(systemName: pct > 0 ? "arrow.up.right" : "arrow.down.right")
                            Text(String(format: "%.0f%%", abs(pct)))
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

func fmt(_ v: Double) -> String {
    if v == v.rounded() && abs(v) < 100_000 { return String(format: "%.0f", v) }
    // Two decimals at most, with trailing zeros trimmed: 14.2, not 14.20.
    var s = String(format: "%.2f", v)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}

extension URL: @retroactive Identifiable { public var id: String { absoluteString } }

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
