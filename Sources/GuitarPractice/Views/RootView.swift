import SwiftUI
import GuitarPracticeCore

struct RootView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.line).frame(width: 1)
            VStack(spacing: 0) {
                HStack {
                    SectionLabel(text: model.page == .practice ? "Free play / Acoustic guitar" : "Your collection")
                    Spacer()
                    Label(model.metronomeAudible ? "METRONOME ON" : "METRONOME MUTED", systemImage: model.metronomeAudible ? "speaker.wave.2" : "speaker.slash").font(Theme.strong(10)).foregroundStyle(model.metronomeAudible ? Theme.accent : Theme.muted)
                    SettingsLink { Image(systemName: "slider.horizontal.3").padding(6) }.buttonStyle(.plain).help("Light Element settings")
                }.padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 14)
                Group {
                    switch model.page {
                    case .practice: PracticeView(model: model)
                    case .library: LibraryView(model: model, store: model.store)
                    case .recordings: RecordingsView(model: model, store: model.store, replay: model.replay)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                recordingStrip
            }.background(Theme.paper)
        }
        .font(Theme.body()).foregroundStyle(Theme.ink).tint(Theme.accent)
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: model.page)
        .sheet(isPresented: $model.showImporter) { ImportView(model: model) }
        .sheet(isPresented: $model.showEditor) { ArrangementEditor(model: model, original: model.song) }
        .alert("Guitar Jim", isPresented: Binding(get: { model.error != nil || model.store.error != nil }, set: { if !$0 { model.error = nil; model.store.error = nil } })) {
            Button("OK") { model.error = nil; model.store.error = nil }
        } message: { Text(model.error ?? model.store.error ?? "") }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(nsImage: AppResources.logo)
                    .resizable().interpolation(.high).scaledToFit().frame(width: 64, height: 64)
                    .accessibilityLabel("Cartoon portrait of Jimmy Page")
                VStack(alignment: .leading, spacing: -3) {
                    Text("GUITAR").lineLimit(1).minimumScaleFactor(0.85)
                    Text("JIM")
                }.font(Theme.title(20)).frame(width: 70, alignment: .leading)
                    .accessibilityElement(children: .combine).accessibilityLabel("Guitar Jim")
            }.padding(.top, 45).padding(.bottom, 36)
            ForEach(AppModel.Page.allCases, id: \.self) { page in
                Button { model.page = page } label: {
                    HStack(spacing: 13) {
                        Image(systemName: page == .practice ? "play.rectangle" : page == .library ? "music.note.list" : "waveform").frame(width: 20)
                        Text(page == .library ? "Songs" : page.rawValue).lineLimit(1).minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }.font(model.page == page ? Theme.strong(12) : Theme.body(12)).padding(.horizontal, 10).padding(.vertical, 12)
                        .foregroundStyle(model.page == page ? Theme.accent : Theme.muted)
                        .background(model.page == page ? Theme.accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain).padding(.bottom, 5)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 4) { ForEach(0..<5) { i in Circle().fill(Theme.lanes[i]).frame(width: 9, height: 9) } }
                Text("YOUR NEXT\nHIGH SCORE.").font(Theme.title(23))
                Text("\(model.store.songs.count) songs. Five levels.\nOne real guitar.").font(Theme.body(11)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            }.padding(.bottom, 30)
            Divider().overlay(Theme.line)
            Text("LOCAL AUDIO · BETA").font(Theme.strong(9)).tracking(1.2).foregroundStyle(Theme.muted).padding(.vertical, 20)
        }.padding(.horizontal, 16).frame(width: 174).background(Theme.sidebar)
    }
    private var recordingStrip: some View {
        HStack(spacing: 12) {
            Image(systemName: model.isRecording ? "record.circle.fill" : "mic.slash")
                .foregroundStyle(model.isRecording ? Theme.accent : Theme.muted)
            Text(model.isRecording ? (model.transport == .paused ? "Practice paused · Recording" : "Recording on your Mac") : "Microphone off")
                .font(Theme.strong(12))
            if model.isRecording {
                Text(formatTime(model.recordingSeconds)).monospacedDigit().font(Theme.body(12))
                LevelMeter(level: model.level, clipped: model.clipped).frame(width: 70, height: 12)
            }
            Spacer()
            if model.isRecording {
                Button("Turn mic off and save") { Task { await model.stopMic() } }.font(Theme.strong(12))
            } else {
                Text("Audio and practice history stay local").font(Theme.body(11)).foregroundStyle(Theme.muted)
            }
        }.padding(.horizontal, 28).padding(.vertical, 13)
            .background(Theme.sidebar.opacity(0.6)).overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }
}

struct LevelMeter: View {
    var level: Float
    var clipped: Bool
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<12) { i in
                RoundedRectangle(cornerRadius: 1).fill(Double(i) / 12 < min(1, Double(level) * 8) ? (clipped ? Theme.accent : Theme.green) : Theme.line)
            }
        }.accessibilityLabel(clipped ? "Input clipping" : "Input level \(Int(min(1, level * 8) * 100)) percent")
    }
}
