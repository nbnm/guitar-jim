import SwiftUI
import UniformTypeIdentifiers
import GuitarPracticeCore

struct ImportView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var mode = 0
    @State private var chart = ""
    @State private var query = ""
    @State private var error: String?
    @State private var task: Task<Void, Never>?
    @State private var busy = false
    @State private var draft: SongArrangement?
    @State private var editingDraft = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Add a song").font(Theme.title(30)); Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Picker("Import method", selection: $mode) {
                Text("Paste or import a chart").tag(0)
                Text("Light Element").tag(1)
            }.pickerStyle(.segmented).disabled(busy)
            if mode == 0 {
                Text("Paste ChordPro text or a row such as G | Em | C | D. Word positions become draft timing for you to review.").font(Theme.body(13)).foregroundStyle(Theme.muted)
                TextEditor(text: $chart).font(.system(.body, design: .monospaced)).frame(minHeight: 220)
                    .padding(8).background(Theme.sidebar).overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.line))
                HStack {
                    Button("Choose text file…") { chooseFile() }
                    Spacer()
                    Button("Review chart") {
                        do { draft = try ChartImporter.parse(chart); editingDraft = true } catch { self.error = error.localizedDescription }
                    }.buttonStyle(PrimaryButtonStyle()).disabled(chart.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else {
                Text("Ask for a beginner arrangement").font(Theme.strong(16))
                Text("The endpoint, token and model can be added in Settings later. This first adapter proposes chord-only drafts; licensed song discovery is still to come.")
                    .font(Theme.body(13)).foregroundStyle(Theme.muted)
                TextField("For example: a gentle acoustic study using G, C, D and Em", text: $query, axis: .vertical).lineLimit(3...6).textFieldStyle(.roundedBorder)
                HStack {
                    SettingsLink { Label("Light Element settings", systemImage: "slider.horizontal.3") }
                    Spacer()
                    if busy { ProgressView().controlSize(.small); Button("Cancel") { task?.cancel(); busy = false } }
                    Button(busy ? "Creating draft…" : "Create draft") { createDraft() }.buttonStyle(PrimaryButtonStyle()).disabled(query.isEmpty || busy)
                }
                Text("Only your request text is sent. Microphone audio and practice history stay on your Mac.").font(Theme.body(11)).foregroundStyle(Theme.muted)
            }
            if let error { Label(error, systemImage: "exclamationmark.circle").font(Theme.body(12)).foregroundStyle(Theme.accent).textSelection(.enabled) }
        }.padding(30).frame(width: 660).foregroundStyle(Theme.ink).background(Theme.paper)
            .onDisappear { task?.cancel() }
            .sheet(isPresented: $editingDraft) {
                if let draft { ArrangementEditor(model: model, original: draft, onSave: { dismiss() }) }
            }
    }
    private func chooseFile() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.plainText, .text]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                guard (attributes[.size] as? NSNumber)?.intValue ?? 0 <= 100_000 else { throw ChartImportError.tooLarge }
                chart = try String(contentsOf: url, encoding: .utf8)
            } catch { self.error = error.localizedDescription }
        }
    }
    private func createDraft() {
        error = nil
        do {
            let config = LightElementConfiguration(endpoint: UserDefaults.standard.string(forKey: "lightElement.endpoint") ?? "", model: UserDefaults.standard.string(forKey: "lightElement.model") ?? "")
            let request = try LightElementAdapter.request(query: query, configuration: config, token: Credentials.token() ?? "")
            busy = true
            task = Task {
                defer { busy = false }
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    try Task.checkCancellation()
                    guard let response = response as? HTTPURLResponse else { throw LightElementError.malformed }
                    guard (200...299).contains(response.statusCode) else { throw LightElementError.response(response.statusCode) }
                    draft = try LightElementAdapter.decode(data); editingDraft = true
                } catch is CancellationError { }
                catch let network as URLError where network.code == .cancelled { }
                catch { self.error = error.localizedDescription }
            }
        } catch { self.error = error.localizedDescription }
    }
}
