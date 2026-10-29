import SwiftUI
import GuitarPracticeCore

struct ArrangementEditor: View {
    @ObservedObject var model: AppModel
    let original: SongArrangement
    var onSave: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SongArrangement
    @State private var storagePermission = false
    @State private var error: String?
    @State private var selectedPattern: StrummingPattern = .folk
    init(model: AppModel, original: SongArrangement, onSave: (() -> Void)? = nil) {
        self.model = model; self.original = original; self.onSave = onSave
        var reviewDraft = original
        if original.id == model.song.id { reviewDraft.practiceBPM = model.pendingBPM }
        _draft = State(initialValue: reviewDraft)
        _storagePermission = State(initialValue: original.sources.allSatisfy(\.permitsOfflineStorage))
        _selectedPattern = State(initialValue: original.bars.first.flatMap { StrummingPattern.matching($0) } ?? .folk)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Review arrangement").font(Theme.title(29))
                    Text(draft.readiness.rawValue).font(Theme.strong(12)).foregroundStyle(Theme.accent)
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save to library") { save() }.buttonStyle(PrimaryButtonStyle()).disabled(!storagePermission || model.isRecording || !draft.practiceBPM.isFinite)
            }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                        GridRow { Text("Title"); TextField("Song title", text: $draft.title) }
                        GridRow { Text("Artist"); TextField("Artist", text: $draft.artist) }
                        GridRow { Text("Version"); TextField("Arrangement version", text: $draft.version) }
                    }.textFieldStyle(.roundedBorder)
                    HStack(spacing: 24) {
                        Stepper("Practice \(Int(draft.practiceBPM)) BPM", value: $draft.practiceBPM, in: 50...140)
                        Stepper("Capo \(draft.capo)", value: $draft.capo, in: 0...12)
                        Text("4/4").foregroundStyle(Theme.muted)
                    }.font(Theme.strong(13))
                    if let bpm = draft.sourceBPM, bpm.isFinite { Text("Source tempo: \(Int(bpm)) BPM · kept separately from your practice tempo").font(Theme.body(11)).foregroundStyle(Theme.muted) }
                    HStack {
                        Toggle("Standard tuning confirmed", isOn: $draft.tuningConfirmed)
                        Toggle("Capo confirmed", isOn: $draft.capoConfirmed)
                    }.font(Theme.body(12))
                    Divider()
                    Text("Bars and beats").font(Theme.title(24))
                    Text("Set each chord change on the beat grid. Click a strum to cycle rest → down → up. Lyrics follow these anchors; sung words are not tracked.").font(Theme.body(12)).foregroundStyle(Theme.muted)
                    HStack(spacing: 14) {
                        Picker("Strumming preset", selection: $selectedPattern) {
                            ForEach(StrummingPattern.allCases) { pattern in Text(pattern.name).tag(pattern) }
                        }.frame(maxWidth: 330)
                        Button("Apply to all bars") { draft.applyStrummingPattern(selectedPattern, bars: 0..<draft.bars.count) }
                            .disabled(draft.bars.isEmpty)
                        Text(selectedPattern.events.map { $0.stroke.symbol }.joined(separator: " ")).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.accent)
                        Spacer()
                    }.font(Theme.body(12))
                    ForEach(draft.sections.indices, id: \.self) { sectionIndex in
                        VStack(alignment: .leading, spacing: 16) {
                            TextField("Section name", text: $draft.sections[sectionIndex].name).font(Theme.strong(16)).textFieldStyle(.roundedBorder)
                            ForEach(draft.sections[sectionIndex].bars.indices, id: \.self) { barIndex in
                                let global = draft.sections.prefix(sectionIndex).reduce(0) { $0 + $1.bars.count } + barIndex
                                BarEditor(bar: $draft.sections[sectionIndex].bars[barIndex], number: global + 1)
                                HStack {
                                    Spacer()
                                    Button("Remove bar") { draft.sections[sectionIndex].bars.remove(at: barIndex) }.font(Theme.body(10))
                                        .disabled(draft.sections[sectionIndex].bars.count <= 1)
                                }
                                Divider()
                            }
                            Button("Add bar") {
                                draft.sections[sectionIndex].bars.append(.init(chords: [.init(beat: 0, shape: "G")], strums: ChartImporter.quarterNotes))
                            }.disabled(draft.bars.count >= 512)
                        }
                    }
                    Button("Add section") { draft.sections.append(.init(name: "New section", bars: [.init(chords: [.init(beat: 0, shape: "G")], strums: ChartImporter.quarterNotes)])) }
                    Divider()
                    Text("Sources and permission").font(Theme.title(24))
                    ForEach(Array(draft.sources.enumerated()), id: \.offset) { _, source in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(source.field) · \(source.status.rawValue)").font(Theme.strong(12))
                            Text(source.attribution).font(Theme.body(12)).foregroundStyle(Theme.muted)
                            if let url = source.url { Link("View source", destination: url).font(Theme.body(12)) }
                        }
                    }
                    Toggle("I have permission to display and store this material locally", isOn: $storagePermission).font(Theme.body(12))
                    Toggle("I have reviewed the version, chords, timing and strumming", isOn: $draft.suggestionsConfirmed).font(Theme.body(12))
                    if !draft.unsupportedChords.isEmpty {
                        Text("Unsupported chord shapes: \(draft.unsupportedChords.joined(separator: ", ")). These remain unscored.").font(Theme.body(12)).foregroundStyle(Theme.accent)
                        Toggle("Practise with these events unscored", isOn: $draft.unsupportedChordsAcknowledged).font(Theme.body(12))
                    }
                    if !draft.validationIssues.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Still needs review").font(Theme.strong(13))
                            ForEach(Array(draft.validationIssues.prefix(12).enumerated()), id: \.offset) { _, issue in Text("• \(issue)").font(Theme.body(12)) }
                            Text("You can save an incomplete chart and finish it later.").font(Theme.body(11)).foregroundStyle(Theme.muted)
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Theme.sidebar, in: RoundedRectangle(cornerRadius: 6))
                    }
                    if let error { Text(error).font(Theme.body(12)).foregroundStyle(Theme.accent) }
                }.padding(26)
            }
        }.frame(width: 790, height: 760).background(Theme.paper).foregroundStyle(Theme.ink).tint(Theme.accent)
    }
    private func save() {
        draft.revision += 1
        for index in draft.sources.indices { draft.sources[index].permitsOfflineStorage = storagePermission }
        do {
            try model.store.saveSong(draft); model.selectSong(draft); dismiss(); onSave?()
        } catch { self.error = error.localizedDescription }
    }
}

private struct BarEditor: View {
    @Binding var bar: PracticeBar
    var number: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(String(format: "%02d", number)).font(Theme.title(24)).foregroundStyle(Theme.accent).frame(width: 38, alignment: .leading)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(bar.chords.indices, id: \.self) { index in
                        HStack {
                            Picker("Chord", selection: $bar.chords[index].shape) {
                                ForEach(Array(Set(SongArrangement.supportedChords + bar.chords.map(\.shape))).sorted(), id: \.self) { Text($0).tag($0) }
                            }.frame(width: 140)
                            Picker("At beat", selection: Binding(get: { bar.chords[index].beat }, set: { _ = bar.moveChord(at: index, to: $0) })) {
                                ForEach(0..<8) { beat in
                                    if bar.canMoveChord(at: index, to: Double(beat) / 2) {
                                        Text(beatLabel(beat)).tag(Double(beat) / 2)
                                    }
                                }
                            }.frame(width: 140).disabled(index == 0)
                            if index > 0 { Button { bar.chords.remove(at: index) } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).accessibilityLabel("Remove chord change") }
                        }
                    }
                    Button("Add chord change") {
                        let available = (1..<8).map { Double($0) / 2 }.first { beat in !bar.chords.contains(where: { $0.beat == beat }) }
                        if let available { bar.chords.append(.init(beat: available, shape: "G")); bar.chords.sort { $0.beat < $1.beat } }
                    }.font(Theme.body(11)).disabled(bar.chords.count >= 8)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Text("Strum").font(Theme.body(11)).foregroundStyle(Theme.muted).frame(width: 38)
                ForEach(0..<8) { i in
                    let beat = Double(i) / 2
                    let current = bar.strums.first(where: { $0.beat == beat })?.stroke ?? .rest
                    Button {
                        let next: Stroke = current == .rest ? .down : current == .down ? .up : .rest
                        bar.strums.removeAll { $0.beat == beat }; bar.strums.append(.init(beat: beat, stroke: next)); bar.strums.sort { $0.beat < $1.beat }
                    } label: {
                        VStack(spacing: 3) { Text(current.symbol).font(.system(size: 20)); Text(beatLabel(i)).font(Theme.body(9)) }.frame(width: 35)
                    }.accessibilityLabel("Beat \(beatLabel(i)): \(current.rawValue). Cycle stroke.")
                }
            }
            HStack {
                Text(StrummingPattern.matching(bar)?.name ?? "Custom pattern").font(Theme.body(11)).foregroundStyle(Theme.muted)
                Spacer()
                Menu("Use a pattern") {
                    ForEach(StrummingPattern.allCases) { pattern in
                        Button(pattern.name) { bar.strums = pattern.events }
                    }
                }.menuStyle(.borderlessButton).font(Theme.strong(11)).foregroundStyle(Theme.accent).fixedSize()
            }
            if bar.lyrics.isEmpty {
                Button("Add lyric line") { bar.lyrics.append(.init(beat: 0, text: "")) }.font(Theme.body(11))
            } else {
                ForEach(bar.lyrics.indices, id: \.self) { index in
                    HStack {
                        TextField("Lyric line", text: $bar.lyrics[index].text).textFieldStyle(.roundedBorder)
                        Picker("Beat", selection: $bar.lyrics[index].beat) { ForEach(0..<8) { Text(beatLabel($0)).tag(Double($0) / 2) } }.frame(width: 115)
                        Button { bar.lyrics.remove(at: index) } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).accessibilityLabel("Remove lyric line")
                    }
                }
            }
        }.font(Theme.body(12))
    }
    private func beatLabel(_ i: Int) -> String { i % 2 == 0 ? "\(i / 2 + 1)" : "\(i / 2 + 1) &" }
}
