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
    @State private var showingPhotoPicker = false
    @State private var editor: EditorTarget?

    /// One sheet, two jobs. Two `.sheet` modifiers on the same view is a
    /// standing SwiftUI hazard — one of them quietly wins — and this screen
    /// already presents a file importer and a photo picker on top of being a
    /// sheet itself.
    enum EditorTarget: Identifiable {
        case new
        case existing(Reading)
        var id: String {
            switch self {
            case .new: return "new"
            case .existing(let r): return r.id.uuidString
            }
        }
        var reading: Reading? {
            if case .existing(let r) = self { return r }
            return nil
        }
    }

    enum Stage { case choose, paste, review }

    var body: some View {
        // Split deliberately. Chaining every modifier onto one expression puts
        // the whole screen in front of the type-checker at once, and it gives
        // up — this file has hit that limit before.
        NavigationStack {
            VStack(spacing: 0) {
                if let problem { banner(problem) }
                staged
            }
                .navigationTitle(stage == .review ? "Check the results" : "Add a report")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .modifier(ImportSources(showingFileImporter: $showingFileImporter,
                                        showingPhotoPicker: $showingPhotoPicker,
                                        photoItem: $photoItem,
                                        onPDF: handlePDF,
                                        onPhoto: handlePhoto))
                .overlay { if busy { reading } }
                .sheet(item: $editor) { target in
                    ReadingEditor(existing: target.reading) { saved in
                        target.reading == nil ? append(saved) : replace(saved)
                    }
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

    /// Shown in the view rather than presented.
    ///
    /// This screen is already a sheet that presents a file importer, a photo
    /// picker and an editor. An alert competing with all of that is one more
    /// thing that can quietly fail to appear — and a failure the user cannot
    /// see is exactly what made the photo path look like it did nothing.
    private func banner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text).font(.footnote)
            Spacer(minLength: 0)
            Button { problem = nil } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
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
                Button { showingPhotoPicker = true } label: {
                    Label("Photograph or pick an image", systemImage: "camera.fill")
                }
                Button { stage = .paste } label: {
                    Label("Paste the text", systemImage: "doc.on.clipboard")
                }
                Button {
                    readings = []
                    reportDate = Date()
                    stage = .review
                    editor = .new
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
                    Button { editor = .existing(r) } label: { row(r) }
                        .buttonStyle(.plain)
                }
                .onDelete { readings.remove(atOffsets: $0) }
                Button { editor = .new } label: {
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

            // Report which step failed, and what the system said. A photo can
            // fail to load for reasons the app can't see — an image still in
            // iCloud, an unsupported format — and "nothing happened" leaves
            // nobody, including the developer, able to tell which.
            let data: Data
            do {
                guard let loaded = try await item.loadTransferable(type: Data.self) else {
                    fail("That photo couldn't be loaded. If it's stored in iCloud, "
                       + "open it in Photos first so it downloads, then try again.")
                    return
                }
                data = loaded
            } catch {
                fail("That photo couldn't be loaded — \(error.localizedDescription)")
                return
            }
            guard let image = UIImage(data: data) else {
                fail("That file didn't open as an image (\(data.count) bytes).")
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
            // Character count included deliberately: it separates "the text was
            // never read" from "the text was read but nothing in it parsed",
            // which are different bugs with different fixes.
            problem = "Read \(raw.count) characters, but no results in them. "
                    + "If the layout is unusual, use \"Paste the text\", or "
                    + "\"Enter results by hand\"."
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
    @Binding var showingPhotoPicker: Bool
    @Binding var photoItem: PhotosPickerItem?
    let onPDF: (URL) -> Void
    let onPhoto: (PhotosPickerItem?) -> Void

    /// Both pickers are presented from here, not from inside the stage they are
    /// launched from.
    ///
    /// A `PhotosPicker` placed in the chooser is destroyed the moment reading
    /// succeeds and the stage becomes .review — while it is still unwinding its
    /// own presentation. That tears down the sheet this whole screen lives in,
    /// so the import vanishes and nothing is saved. Presented from the stable
    /// parent it outlives the stage change, exactly as the file importer does.
    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $showingFileImporter,
                          allowedContentTypes: [.pdf]) { result in
                if case .success(let url) = result { onPDF(url) }
            }
            .photosPicker(isPresented: $showingPhotoPicker,
                          selection: $photoItem, matching: .images)
            .onChange(of: photoItem) { _, item in onPhoto(item) }
    }
}
