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

    enum Stage { case choose, paste, review }

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .choose: chooser
                case .paste:  paster
                case .review: reviewer
                }
            }
            .navigationTitle(stage == .review ? "Check the results" : "Add a report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                if stage == .review {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: save).disabled(readings.isEmpty)
                    }
                }
            }
            .photosPicker(isPresented: .constant(false), selection: $photoItem)
            .fileImporter(isPresented: $showingFileImporter,
                          allowedContentTypes: [.pdf]) { result in
                if case .success(let url) = result { handlePDF(url) }
            }
            .onChange(of: photoItem) { _, item in handlePhoto(item) }
            .overlay { if busy { ProgressView("Reading…").padding()
                .background(.regularMaterial, in: .rect(cornerRadius: 12)) } }
        }
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
                ForEach($readings) { $r in
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
                    }
                }
                .onDelete { readings.remove(atOffsets: $0) }
            } header: {
                Text("\(readings.count) result\(readings.count == 1 ? "" : "s") found")
            } footer: {
                Text("Swipe to remove anything that isn't a result. Check these against your report before saving.")
            }
        }
    }

    // MARK: Actions

    private func handlePDF(_ url: URL) {
        busy = true
        Task {
            let extracted = TextExtraction.fromPDF(at: url) ?? ""
            await extract(from: extracted)
        }
    }

    private func handlePhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        busy = true
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let extracted = await TextExtraction.fromImage(image) else {
                busy = false; return
            }
            await extract(from: extracted)
        }
    }

    private func extract(from raw: String) async {
        busy = true
        let id = UUID()
        let date = LabTextParser.findDate(in: raw) ?? Date()
        let found = await ImportPipeline.readings(from: raw, date: date, reportID: id)
        await MainActor.run {
            readings = found
            reportDate = date
            busy = false
            stage = .review
        }
    }

    private func save() {
        store.add(report: LabReport(date: reportDate, labName: labName), readings: readings)
        dismiss()
    }
}
