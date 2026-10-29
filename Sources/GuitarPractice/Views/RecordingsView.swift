import SwiftUI
import UniformTypeIdentifiers
import GuitarPracticeCore

struct RecordingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: LocalStore
    @ObservedObject var replay: ReplayPlayer
    @State private var exporting = false
    @State private var deleteCandidate: CaptureSession?
    @State private var editedName = ""
    private var selected: CaptureSession? { store.sessions.first { $0.id == replay.sessionID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recordings").font(Theme.title(38))
                    Text("Every take has a place here.").font(Theme.body()).foregroundStyle(Theme.muted)
                }
                Spacer()
                Text("\(store.sessions.count) sessions · \(store.storageDescription)").font(Theme.body(12)).foregroundStyle(Theme.muted)
                Button { NSWorkspace.shared.open(store.root.appendingPathComponent("Sessions")) } label: { Image(systemName: "folder") }.help("Open local recordings")
            }
            Divider().overlay(Theme.line)
            if store.sessions.isEmpty {
                EmptyMessage(icon: "waveform", title: "Your first take starts here", detail: "Enable the microphone in Practice, then turn it off and save. Setup, count-ins and pauses are kept in the recording.")
            } else {
                HStack(alignment: .top, spacing: 28) {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(store.sessions) { session in
                                Button { Task { await model.loadReplay(session); editedName = session.name } } label: {
                                    VStack(alignment: .leading, spacing: 7) {
                                        HStack {
                                            Text(session.name).font(Theme.strong(14)).lineLimit(2)
                                            Spacer()
                                            if session.id == replay.sessionID { Image(systemName: "speaker.wave.2").foregroundStyle(Theme.accent) }
                                        }
                                        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened)).font(Theme.body(11)).foregroundStyle(Theme.muted)
                                        Text("\(formatTime(session.duration)) · \(Int(session.arrangement.practiceBPM)) BPM · \(session.state)").font(Theme.body(11)).foregroundStyle(Theme.muted)
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
                                        .background(session.id == replay.sessionID ? Theme.sidebar : .clear, in: RoundedRectangle(cornerRadius: 6))
                                }.buttonStyle(.plain)
                                Divider().overlay(Theme.line)
                            }
                        }
                    }.frame(width: 250)
                    if let selected {
                        ScrollView { playerDetail(selected) }
                    } else {
                        EmptyMessage(icon: "play.circle", title: "Choose a recording", detail: "Replay a full session or compare attempts at the same passage and tempo.")
                    }
                }
            }
        }.padding(.horizontal, 36).padding(.bottom, 30)
            .alert("Delete recording?", isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } })) {
                Button("Cancel", role: .cancel) { deleteCandidate = nil }
                Button("Delete", role: .destructive) {
                    if let session = deleteCandidate {
                        do { replay.stop(); try store.deleteSession(session) } catch { model.error = error.localizedDescription }
                    }
                    deleteCandidate = nil
                }
            } message: { Text("The audio and feedback for this session will be removed from this Mac.") }
            .alert("Playback", isPresented: Binding(get: { replay.error != nil }, set: { if !$0 { replay.error = nil } })) {
                Button("OK") { replay.error = nil }
            } message: { Text(replay.error ?? "") }
    }
    private func playerDetail(_ session: CaptureSession) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            TextField("Recording name", text: $editedName).font(Theme.title(26))
                .onSubmit {
                    var updated = session; updated.name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if updated.name.isEmpty { updated.name = session.name; editedName = session.name }
                    do { try store.updateSession(updated) } catch { model.error = error.localizedDescription }
                }
            Text("\(session.deviceName) · arrangement revision \(session.arrangement.revision)").font(Theme.body(12)).foregroundStyle(Theme.muted)
            WaveformView(values: session.waveform, progress: session.duration > 0 ? replay.position / session.duration : 0)
                .frame(height: 100)
            Slider(value: Binding(get: { replay.position }, set: { replay.seek($0) }), in: 0...max(0.01, session.duration)).accessibilityLabel("Recording position")
            HStack {
                Button {
                    if replay.isPlaying { replay.pause() }
                    else { Task { await model.stopMic(); replay.play() } }
                } label: {
                    Label(replay.isPlaying ? "Pause" : "Play recording", systemImage: replay.isPlaying ? "pause.fill" : "play.fill")
                }.buttonStyle(PrimaryButtonStyle())
                Text("\(formatTime(replay.position)) / \(formatTime(session.duration))").font(Theme.body(12)).monospacedDigit()
                Spacer()
                if replay.passageLoop != nil { Button("Stop loop") { replay.passageLoop = nil }.font(Theme.body(11)) }
            }
            if let fault = session.fault { Label(fault, systemImage: "exclamationmark.circle").font(Theme.body(12)).foregroundStyle(Theme.accent) }
            if !session.attempts.isEmpty {
                Divider()
                Text("Practice attempts").font(Theme.title(23))
                Text("Compare the same bars at the same tempo. Local chord estimates are beta; timing is uncalibrated unless a measured offset was saved.").font(Theme.body(12)).foregroundStyle(Theme.muted)
                ForEach(Array(session.attempts.enumerated()), id: \.element.id) { i, attempt in
                    Button {
                        let duration = attempt.replayDuration
                        let end = min(session.duration, attempt.startInRecording + duration)
                        if end > attempt.startInRecording {
                            Task {
                                await model.stopMic()
                                replay.passageLoop = attempt.startInRecording...end
                                replay.seek(attempt.startInRecording, resume: true)
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("Attempt \(i + 1) · bars \(attempt.startBar + 1)–\(attempt.endBar)").font(Theme.strong(12))
                                Spacer()
                                Text("\(Int(attempt.bpm)) BPM").font(Theme.body(11))
                            }
                            if let rate = attempt.summary.onTimeRate {
                                Text("\(Int(rate * 100))% on time · \(attempt.summary.expectedDuringUsableAudio) usable attacks").font(Theme.body(11)).foregroundStyle(Theme.muted)
                            } else { Text("Timing unscored · calibration or usable input required").font(Theme.body(11)).foregroundStyle(Theme.muted) }
                            if let feedback = attempt.chordFeedback, !feedback.isEmpty {
                                let assigned = Set(attempt.summary.results.filter { $0.expectedID != nil }.compactMap(\.detectedID))
                                let judged = feedback.filter { ($0.verdict == .matches || $0.verdict == .different) && $0.detectedID.map(assigned.contains) == true }
                                let matches = judged.filter { $0.verdict == .matches }.count
                                Text("Chords: \(matches)/\(judged.count) judged · \(feedback.filter { $0.verdict == .unclear }.count) unclear").font(Theme.body(11)).foregroundStyle(Theme.muted)
                            }
                        }.padding(.vertical, 9).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Divider()
                }
            }
            DisclosureGroup("Session markers") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(session.markers) { marker in
                        Button { replay.seek(marker.time) } label: { Text("\(formatTime(marker.time))  \(marker.label)").font(Theme.body(11)) }.buttonStyle(.plain)
                    }
                }.padding(.top, 10).frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Button(exporting ? "Exporting…" : "Export WAV…") { export(session) }.disabled(exporting || session.segments.isEmpty)
                Spacer()
                Button("Delete…", role: .destructive) { deleteCandidate = session }
            }
        }.padding(.bottom, 20)
    }
    private func export(_ session: CaptureSession) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.wav]; panel.nameFieldStringValue = "Guitar Jim recording.wav"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        exporting = true
        Task {
            defer { exporting = false }
            do { try await ReplayPlayer.exportWAV(session: session, directory: store.sessionDirectory(session.id), destination: url) }
            catch { model.error = "Export failed: \(error.localizedDescription)" }
        }
    }
}

private struct WaveformView: View {
    var values: [Float]
    var progress: Double
    var body: some View {
        Canvas { context, size in
            guard !values.isEmpty else { return }
            let count = max(1, Int(size.width / 4))
            for i in 0..<count {
                let start = i * values.count / count, end = max(start + 1, (i + 1) * values.count / count)
                let amplitude = values[min(start, values.count - 1)..<min(end, values.count)].max() ?? 0
                let height = max(2, CGFloat(amplitude) * size.height)
                let rect = CGRect(x: CGFloat(i) * 4, y: (size.height - height) / 2, width: 2, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(Double(i) / Double(count) <= progress ? Theme.accent : Theme.line))
            }
        }.accessibilityLabel("Recorded waveform. Use the position slider to seek.")
    }
}
