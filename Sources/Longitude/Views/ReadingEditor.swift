import SwiftUI

/// Adds or corrects one result by hand.
///
/// The same screen does both, because they are the same job: saying what the
/// report actually reads. Typing an analyte resolves it against the registry
/// exactly as an import does, so a hand-entered result lands on the same
/// timeline instead of starting a parallel one.
struct ReadingEditor: View {
    @Environment(\.dismiss) private var dismiss

    let existing: Reading?
    let onSave: (Reading) -> Void

    @State private var name: String
    @State private var valueText: String
    @State private var unit: String
    @State private var rangeText: String

    init(existing: Reading?, onSave: @escaping (Reading) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing?.rawName ?? "")
        _valueText = State(initialValue: existing.map { trimZeros($0.value) } ?? "")
        _unit = State(initialValue: existing?.unit ?? "")
        _rangeText = State(initialValue: existing?.range.printed ?? "")
    }

    private var resolved: BiomarkerDef? { BiomarkerRegistry.match(name) }
    private var value: Double? { ManualEntry.number(valueText) }
    private var canSave: Bool {
        value != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Only suggest while the name is still ambiguous. Once it resolves, the
    /// list is noise.
    private var suggestions: [BiomarkerDef] {
        guard resolved == nil, name.count >= 2 else { return [] }
        return Array(BiomarkerRegistry.search(name, limit: 6))
    }

    var body: some View {
        NavigationStack {
            Form {
                analyteSection
                measurementSection
                intervalSection
            }
            .navigationTitle(existing == nil ? "Add a result" : "Correct this result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save).disabled(!canSave)
                }
            }
        }
    }

    private var analyteSection: some View {
        Section {
            TextField("Test name, as the report prints it", text: $name)
                .autocorrectionDisabled()
            ForEach(suggestions) { def in
                Button {
                    name = def.name
                    if unit.isEmpty { unit = def.canonicalUnit }
                } label: {
                    HStack {
                        Text(def.name)
                        Spacer()
                        Text(def.panel.label).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Test")
        } footer: {
            if let resolved {
                Label("Recognised as \(resolved.name)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if !name.isEmpty {
                // Not an error. An unrecognised analyte is still recorded and
                // still charted — it simply can't be unit-converted.
                Text("Not a name Longitude knows. It will still be saved and "
                   + "charted under this name.")
            }
        }
    }

    private var measurementSection: some View {
        Section {
            HStack {
                Text("Result")
                Spacer()
                TextField("0.0", text: $valueText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
            }
            HStack {
                Text("Unit")
                Spacer()
                TextField(resolved?.canonicalUnit ?? "mg/dL", text: $unit)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
            }
        } footer: {
            if let def = resolved, !unit.isEmpty,
               BiomarkerRegistry.toCanonical(value: 1, unit: unit, for: def) == nil {
                Text("Longitude can't convert \(unit) to \(def.canonicalUnit), so this "
                   + "reading is charted on its own scale.")
            }
        }
    }

    private var intervalSection: some View {
        Section {
            TextField("13.0 - 17.0", text: $rangeText)
                .autocorrectionDisabled()
        } header: {
            Text("Reference interval")
        } footer: {
            intervalFooter
        }
    }

    @ViewBuilder
    private var intervalFooter: some View {
        let parsed = ReferenceRange.parse(rangeText)
        if rangeText.isEmpty {
            Text("Copy this from your report. Without it, the result is charted "
               + "but never marked high or low.")
        } else if parsed.isUsable {
            Label(parsed.describedBounds, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Text("Not understood as an interval. It will be shown as you typed "
               + "it, but won't mark the result high or low.")
        }
    }

    private func save() {
        guard let value else { return }
        let made = existing.map {
            ManualEntry.edited($0, name: name, value: value,
                               unit: unit, rangeText: rangeText)
        } ?? ManualEntry.reading(name: name, value: value, unit: unit,
                                 rangeText: rangeText, date: Date())
        guard let reading = made else { return }
        onSave(reading)
        dismiss()
    }
}

/// "1.20" reads as a stored artefact; "1.2" is what the report says.
private func trimZeros(_ d: Double) -> String {
    d == d.rounded() && abs(d) < 1e15
        ? String(Int(d))
        : String(d)
}
