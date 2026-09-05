import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ImportView: View {
    @EnvironmentObject var store: LabStore
    @Environment(\.dismiss) private var dismiss

    @State private var stage: Stage = .choose
    @State private var text = ""
    @State private var readings: [Reading] = []
    @State private var reportDate = Date()
    @State private var labName = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var showingFileImporter = false
    @State private var busy = false
    @State private var problem: String?
    @State private var editing: Reading?
    @State private var addingByHand = false

    enum Stage { case choose, paste, review }

    var body: some View {
        // Split deliberately. Chaining every modifier onto one expression puts
        // the whole screen in front of the type-checker at once, and it gives
        // up — this file has hit that limit before.
        NavigationStack {
            staged
                .navigationTitle(stage == .review ? "Check the results" : "Add a report")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .modifier(ImportSources(showingFileImporter: $showingFileImporter,
                                        photoItem: $photoItem,
                                        onPDF: handlePDF,
                                        onPhoto: handlePhoto))
                .overlay { if busy { reading } }
                .sheet(item: $editing) { reading in
                    ReadingEditor(existing: reading, onSave: replace)
                }
                .sheet(isPresented: $addingByHand) {
                    ReadingEditor(existing: nil, onSave: append)
                }
                .alert("Couldn't read that", isPresented: hasProblem) {
                    Button("OK", role: .cancel) { problem = nil }
                } message: {
                    Text(problem ?? "")
                }
        }
    }

    @ViewBuilder
    private var staged: some View {
        switch stage {
        case .choose: chooser
        case .paste:  paster
        case .review: reviewer
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        if stage == .review {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save).disabled(readings.isEmpty)
            }
        }
    }

    private var reading: some View {
        ProgressView("Reading…").padding()
            .background(.regularMaterial, in: .rect(cornerRadius: 12))
    }

    private var hasProblem: Binding<Bool> {
        .init(get: { problem != nil }, set: { if !$0 { problem = nil } })
    }

    /// An edit updates the row in place; it never adds a second one.
    private func replace(_ updated: Reading) {
        guard let i = readings.firstIndex(where: { $0.id == updated.id }) else { return }
        readings[i] = updated
    }

    /// A hand-entered result belongs to the report being built, so it carries
    /// that report's date rather than today's.
    private func append(_ new: Reading) {
        var dated = new
        dated.date = reportDate
        readings.append(dated)
    }

    private var chooser: some View {
        List {
            Section {
                Button { showingFileImporter = true } label: {
                    Label("Choose a PDF", systemImage: "doc.fill")
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Photograph or pick an image", systemImage: "camera.fill")
                }
                Button { stage = .paste } label: {
                    Label("Paste the text", systemImage: "doc.on.clipboard")
                }
                Button {
                    readings = []
                    reportDate = Date()
                    stage = .review
                    addingByHand = true
                } label: {
                    Label("Enter results by hand", systemImage: "square.and.pencil")
                }
            } footer: {
                Text("Reports are read on this device. Nothing is uploaded, and there is no account.")
            }

            if let note = ModelExtractor.availability.explanation {
                Section {
                    Label(note, systemImage: "info.circle").font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var paster: some View {
        VStack {
            TextEditor(text: $text)
                .font(.system(.footnote, design: .monospaced))
                .padding(8)
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 10))
                .padding()
            Button("Read results") { Task { await extract(from: text) } }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.bottom)
        }
    }

    private var reviewer: some View {
        List {
            Section("Report") {
                DatePicker("Date", selection: $reportDate, displayedComponents: .date)
                TextField("Lab name (optional)", text: $labName)
            }
            Section {
                ForEach(readings) { r in
                    Button { editing = r } label: { row(r) }
                        .buttonStyle(.plain)
                }
                .onDelete { readings.remove(atOffsets: $0) }
                Button { addingByHand = true } label: {
                    Label("Add a result", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("\(readings.count) result\(readings.count == 1 ? "" : "s")")
            } footer: {
                Text("Tap a result to correct anything that was misread. Swipe to "
                   + "remove what isn't a result. Check these against your report "
                   + "before saving.")
            }
        }
    }

    @ViewBuilder
    private func row(_ r: Reading) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.displayName).font(.subheadline)
                if r.biomarkerID == nil {
                    Text("Not recognised — kept as written")
                        .font(.caption2).foregroundStyle(.orange)
                } else if !r.range.printed.isEmpty {
                    Text("Range \(r.range.printed)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(fmt(r.value)) \(r.unit)")
                .font(.subheadline.weight(.medium)).monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    // MARK: Actions

    private func handlePDF(_ url: URL) {
        busy = true
        Task { @MainActor in
            guard let extracted = TextExtraction.fromPDF(at: url) else {
                fail("That PDF has no text in it — it's a scan or a picture of a "
                   + "page. Photograph the report instead and it will be read "
                   + "with text recognition.")
                return
            }
            await extract(from: extracted)
        }
    }

    private func handlePhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        busy = true
        Task { @MainActor in
            // Clear the selection as soon as it's taken. SwiftUI only fires
            // onChange when the value differs, so leaving the last photo in
            // place means choosing that same photo again does nothing at all —
            // the picker opens, closes, and the user is left staring at an
            // unchanged screen with no idea why.
            defer { photoItem = nil }

            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                fail("That image couldn't be opened. Try taking the photo again.")
                return
            }
            guard let extracted = await TextExtraction.fromImage(image) else {
                fail("No text could be read from that photo. Get the whole page "
                   + "in frame, in even light, with the text upright.")
                return
            }
            await extract(from: extracted)
        }
    }

    @MainActor
    private func fail(_ message: String) {
        busy = false
        problem = message
    }

    @MainActor
    private func extract(from raw: String) async {
        busy = true
        let id = UUID()
        let date = LabTextParser.findDate(in: raw) ?? Date()
        let found = await ImportPipeline.readings(from: raw, date: date, reportID: id)
        busy = false
        guard !found.isEmpty else {
            problem = "No results could be read from that. If the report is an "
                    + "unusual layout, use \"Paste the text\" and paste the "
                    + "results in directly."
            return
        }
        readings = found
        reportDate = date
        stage = .review
    }

    private func save() {
        store.add(report: LabReport(date: reportDate, labName: labName), readings: readings)
        dismiss()
    }
}

/// The file and photo importers, lifted out of `body` for the type-checker.
private struct ImportSources: ViewModifier {
    @Binding var showingFileImporter: Bool
    @Binding var photoItem: PhotosPickerItem?
    let onPDF: (URL) -> Void
    let onPhoto: (PhotosPickerItem?) -> Void

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $showingFileImporter,
                          allowedContentTypes: [.pdf]) { result in
                if case .success(let url) = result { onPDF(url) }
            }
            .onChange(of: photoItem) { _, item in onPhoto(item) }
    }
}
