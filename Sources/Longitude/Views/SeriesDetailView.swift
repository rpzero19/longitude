import SwiftUI
import Charts

struct SeriesDetailView: View {
    @EnvironmentObject var store: LabStore
    let series: Series
    @State private var editing: Reading?

    /// The interval from the most recent report, drawn as a band behind the line.
    private var band: (low: Double, high: Double)? {
        guard let range = series.readings.last?.range, range.isUsable else { return nil }

        // Open-ended intervals ("< 200") still need two bounds to draw a band,
        // so the missing side is taken from the data's own extent.
        let values: [Double] = series.readings.map { $0.plottedValue }
        let dataMin: Double = values.min() ?? 0
        let dataMax: Double = values.max() ?? 0

        // An open-ended interval must be drawn open-ended. "< 100" means every
        // value below 100 is inside the range, so the band has to reach the
        // bottom of the chart — stopping it short would imply a lower bound the
        // lab never set, and make an in-range result look abnormal.
        let low: Double
        if let l = range.low {
            low = l
        } else {
            low = Swift.min(0, dataMin)
        }

        let high: Double
        if let h = range.high {
            high = h
        } else {
            let top: Double = Swift.max(dataMax, range.low ?? dataMin)
            high = top * 1.25
        }

        guard high > low else { return nil }
        return (low, high)
    }

    var body: some View {
        List {
            chartSection
            readingsSection
            disclaimerSection
        }
        .navigationTitle(series.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { reading in
            ReadingEditor(existing: reading) { store.update($0) }
        }
    }

    // Each section is its own property: SwiftUI view builders nest generic
    // types deeply enough that one large body exceeds the type checker's budget.
    private var chartSection: some View {
        Section {
            chart
                .frame(height: 240)
                .padding(.vertical, 8)
        } footer: {
            chartFooter
        }
    }

    @ViewBuilder private var chartFooter: some View {
        if series.hasUnreconciledUnits {
            Label("Some readings use units that couldn't be reconciled, so points may not be directly comparable.",
                  systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if band != nil {
            Text("Shaded band is the reference interval printed on your most recent report.")
        }
    }

    private var readingsSection: some View {
        Section {
            ForEach(series.readings.reversed()) { reading in
                Button { editing = reading } label: { readingRow(reading) }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) { store.delete(reading) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        } header: {
            Text("Readings")
        } footer: {
            // A misread value that has already been saved was, until now,
            // permanent. It shouldn't be.
            Text("Tap a reading to correct what the report says. Swipe to delete one.")
        }
    }

    private func readingRow(_ r: Reading) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                if !r.range.printed.isEmpty {
                    Text("Lab range \(r.range.printed)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(fmt(r.value)) \(r.unit)")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                if r.status != .unknown {
                    Text(r.status.label)
                        .font(.caption2)
                        .foregroundStyle(r.status == .within ? Color.secondary : Color.orange)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    private var disclaimerSection: some View {
        Section {
            Text("Longitude shows your results and how they've changed. It does not interpret them or offer medical advice. Discuss any result with your doctor.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var chart: some View {
        Chart {
            if let b = band {
                RectangleMark(
                    yStart: .value("Low", b.low),
                    yEnd: .value("High", b.high)
                )
                .foregroundStyle(.green.opacity(0.10))
            }
            ForEach(series.readings) { r in
                LineMark(x: .value("Date", r.date), y: .value(series.unit, r.plottedValue))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                PointMark(x: .value("Date", r.date), y: .value(series.unit, r.plottedValue))
                    .foregroundStyle(r.status == .within || r.status == .unknown
                                     ? Color.accentColor : Color.orange)
                    .symbolSize(70)
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
    }
}
