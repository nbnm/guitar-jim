import SwiftUI
import GuitarPracticeCore

struct PracticeView: View {
    @ObservedObject var model: AppModel
    @State private var showSetup = false
    @State private var showShape = false
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    HStack(alignment: .top, spacing: 26) {
                        NoteHighway(model: model)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        lyricSheet.frame(width: max(300, geometry.size.width * 0.38))
                    }.frame(height: max(320, geometry.size.height - (model.showChordTable ? 370 : 240)))
                    if model.showChordTable { ChordTableView(model: model).frame(height: 126) }
                    transport
                    feedback
                }.padding(.bottom, 2)
            }
        }.padding(.horizontal, 28).padding(.bottom, 18)
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text(model.song.title.uppercased()).font(Theme.title(34)).lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                if model.song.readiness != .ready {
                    Button("REVIEW SETUP") { model.showEditor = true }.font(Theme.strong(10)).foregroundStyle(Theme.accent)
                }
                if let level = model.song.difficulty {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { i in Image(systemName: i <= level.level ? "star.fill" : "star").font(.system(size: 11)).foregroundStyle(i <= level.level ? Theme.accent : Theme.line) }
                    }.accessibilityLabel("Difficulty \(level.level) of 5")
                    Text((model.song.version.localizedCaseInsensitiveContains("simplified") ? "Simplified study" : level.name).uppercased()).font(Theme.strong(10)).tracking(1).foregroundStyle(Theme.accent)
                }
                Button { model.pause(); model.showEditor = true } label: { Image(systemName: "pencil.line") }.help("Edit arrangement").disabled(model.isRecording)
            }
            HStack(spacing: 14) {
                Text(model.song.artist).foregroundStyle(Theme.ink)
                Text(model.song.practiceDescription).lineLimit(1)
                Spacer()
                Text("\(Int(model.pendingBPM)) BPM")
                Text("4/4")
                Text("CAPO \(model.song.capo)")
                Toggle(isOn: $model.showChordTable) { Label("Chord table", systemImage: "tablecells") }
                    .toggleStyle(.button).foregroundStyle(model.showChordTable ? Theme.accent : Theme.muted).accessibilityLabel("Show chord table")
            }.font(Theme.body(11)).foregroundStyle(Theme.muted)
        }
    }
    private var lyricSheet: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionLabel(text: model.song.bars.allSatisfy({ $0.lyrics.isEmpty }) ? "Chord chart" : "Lyrics + chords")
                Spacer()
                Toggle(isOn: $model.largeText) { Image(systemName: "textformat.size") }.toggleStyle(.button).help("Large lyric text").accessibilityLabel("Large lyrics")
                Button { showShape.toggle() } label: { Label("\(model.currentChord) shape", systemImage: "hand.raised.fingers.spread") }.font(Theme.body(11))
                    .popover(isPresented: $showShape) { ChordDiagram(chord: model.currentChord).frame(width: 150, height: 170).padding(24).background(Theme.paper) }
            }
            HStack(spacing: 8) {
                ForEach(Array(model.song.sections.enumerated()), id: \.element.id) { i, section in
                    let start = model.song.sections.prefix(i).reduce(0) { $0 + $1.bars.count }
                    Button { model.selectPassage(start..<(start + section.bars.count)) } label: {
                        Text(section.name).font(Theme.strong(11)).padding(.horizontal, 12).padding(.vertical, 7)
                            .foregroundStyle(model.startBar == start ? Theme.stage : Theme.muted)
                            .background(model.startBar == start ? Theme.accent : Theme.sidebar, in: RoundedRectangle(cornerRadius: 4))
                    }.buttonStyle(.plain).disabled(model.transport == .playing || model.transport == .counting)
                }
                Spacer()
                Toggle(isOn: $model.loop) { Image(systemName: "repeat") }.toggleStyle(.button).help("Loop selected passage").accessibilityLabel("Loop passage")
            }
            Group {
                ScrollView {
                    VStack(alignment: .leading, spacing: model.largeText ? 18 : model.showChordTable ? 8 : 12) {
                        ForEach(visibleRows) { row in
                            HStack(alignment: .top, spacing: 12) {
                                Text(String(format: "%02d", row.bar + 1)).font(Theme.strong(10)).monospacedDigit().foregroundStyle(row.active ? Theme.accent : Theme.muted).frame(width: 23).padding(.top, 4)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 14) {
                                        ForEach(Array(model.song.bars[row.bar].chords.enumerated()), id: \.offset) { _, event in
                                            Text(event.shape).font(Theme.strong(12)).foregroundStyle(row.active ? Theme.accent : Theme.muted)
                                        }
                                    }
                                    Text(row.text).font(row.active ? Theme.strong(model.largeText ? 25 : 20) : Theme.body(model.largeText ? 22 : 16))
                                        .foregroundStyle(row.active ? Theme.ink : Theme.muted).fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                if row.active { Image(systemName: "arrowtriangle.right.fill").font(.system(size: 9)).foregroundStyle(Theme.accent).padding(.top, 8) }
                            }.id(row.id).opacity(row.bar < model.currentBar ? 0.56 : 1)
                        }
                    }.padding(.vertical, 5)
                }
            }
            Divider().overlay(Theme.line)
            if model.song.bars.indices.contains(model.currentBar) {
                StrummingPatternView(bar: model.song.bars[model.currentBar], activeSlot: model.activeStrumSlot, canEdit: !model.isRecording) {
                    model.pause(); model.showEditor = true
                }
            }
        }.frame(maxHeight: .infinity)
    }
    private var transport: some View {
        HStack(spacing: 16) {
            Button { model.toggleTransport() } label: {
                Label(model.song.readiness != .ready ? "REVIEW & PLAY" : model.transport == .playing || model.transport == .counting ? "PAUSE" : model.transport == .paused ? "RESUME" : "LET’S PLAY", systemImage: model.transport == .playing || model.transport == .counting ? "pause.fill" : "play.fill")
            }.buttonStyle(PrimaryButtonStyle()).help("Space starts or pauses practice")
            VStack(alignment: .leading, spacing: 4) {
                Text(model.transportLabel).font(Theme.strong(12))
                Text(model.pendingBPM != model.activeBPM ? "New tempo at next count-in" : "SPACE to pause · \(model.metronomeAudible ? "audible count-in + click" : "sound muted")").font(Theme.body(10)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            Stepper(value: $model.pendingBPM, in: 50...140, step: 5) { Text("\(Int(model.pendingBPM)) BPM").font(Theme.strong(12)).monospacedDigit() }.fixedSize()
            Toggle(isOn: $model.metronomeEnabled) { Image(systemName: model.metronomeAudible ? "speaker.wave.2.fill" : "speaker.slash") }
                .toggleStyle(.button).accessibilityLabel("Metronome and countdown sound").help("Mute or enable metronome and countdown sound")
            Button { showSetup.toggle() } label: { Image(systemName: "slider.horizontal.3") }.help("Microphone and timing offset")
                .popover(isPresented: $showSetup) { AudioSetupView(model: model).padding(24).frame(width: 410).background(Theme.paper) }
            if !model.isRecording {
                Button { Task { await model.enableMic() } } label: { Label(model.isFinalizingRecording ? "Saving…" : model.isStartingMic ? "Opening…" : "Enable mic + record", systemImage: "mic.fill") }
                    .disabled(model.isStartingMic || model.isFinalizingRecording || model.selectedDeviceID == 0).font(Theme.strong(12))
            }
        }.padding(.top, 3)
    }
    private var feedback: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().overlay(Theme.line)
            HStack(alignment: .top, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    SectionLabel(text: "Chord agreement · beta")
                    Text(model.lastChordLabel).font(Theme.strong(13)).foregroundStyle(model.chordFeedback.last?.verdict == .matches ? Theme.green : model.chordFeedback.last?.verdict == .different ? Theme.coral : Theme.ink).lineLimit(1)
                    Text(chordDetail).font(Theme.body(10)).foregroundStyle(Theme.muted)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 5) {
                    SectionLabel(text: model.calibrationConfirmed ? "Timing · calibrated" : "Timing estimate · uncalibrated")
                    Text(model.isRecording ? model.timingLabel : "Play with the mic to assess").font(Theme.strong(13)).lineLimit(1)
                    Text(model.summary.onTimeRate.map { "\(Int($0 * 100))% on time · \(model.summary.expectedDuringUsableAudio) usable attacks" } ?? "Audio-clock timing · chord and rhythm scored separately").font(Theme.body(10)).foregroundStyle(Theme.muted)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 5) {
                    SectionLabel(text: "Microphone")
                    Text(model.signalLabel).font(Theme.strong(12)).lineLimit(1)
                    Text(model.isRecording && model.receivedAudio ? "\(Int(model.inputSampleRate)) Hz · \(model.inputChannels) ch · saved locally" : "Mic monitoring off · headphones reduce click bleed").font(Theme.body(10)).foregroundStyle(Theme.muted)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    private var chordDetail: String {
        guard model.isRecording else { return "Local harmonic analysis · no audio uploaded" }
        guard let rate = model.chordRate else { return model.harmonicEstimate?.reason ?? "Waiting for audio evidence" }
        return "\(Int(rate * 100))% · \(model.judgedChords.count) judged · \(Int(min(1, model.chordCoverage ?? 0) * 100))% coverage"
    }
    private struct LyricRow: Identifiable {
        var id: String
        var bar: Int
        var text: String
        var active: Bool
    }
    private var visibleRows: [LyricRow] {
        var all = model.song.bars.enumerated().flatMap { bar, value in
            let active = value.lyrics.lastIndex(where: { $0.beat <= model.beat.truncatingRemainder(dividingBy: 4) })
            return value.lyrics.enumerated().map { i, line in LyricRow(id: "\(bar)-\(i)", bar: bar, text: line.text, active: bar == model.currentBar && i == active) }
        }
        if all.isEmpty {
            all = model.song.bars.enumerated().map { bar, value in
                LyricRow(id: "chord-\(bar)", bar: bar, text: "4 beats · \(value.strums.filter { $0.stroke != .rest }.count) strums", active: bar == model.currentBar)
            }
        }
        guard !all.isEmpty else { return [] }
        let current = all.lastIndex(where: { $0.bar <= model.currentBar }) ?? 0
        let start = min(max(0, current - 1), max(0, all.count - 5))
        return Array(all[start..<min(all.count, start + 5)])
    }
}
