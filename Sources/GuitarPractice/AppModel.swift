import AppKit
import AVFoundation
import GuitarPracticeCore

@MainActor
final class AppModel: ObservableObject {
    enum Page: String, CaseIterable { case practice = "Practice", library = "Song library", recordings = "Recordings" }
    enum Transport { case stopped, counting, playing, paused }
    @Published var page: Page = .practice
    @Published var song: SongArrangement
    @Published var transport: Transport = .stopped
    @Published var isRecording = false
    @Published var isStartingMic = false
    @Published var recordingSeconds: Double = 0
    @Published var level: Float = 0
    @Published var clipped = false
    @Published var devices = InputDevice.all()
    @Published var selectedDeviceID: UInt32 = 0
    @Published var calibrationMS: Double = 0
    @Published var calibrationConfirmed = false
    @Published var loop = true
    @Published var startBar = 0
    @Published var endBar = 4
    @Published var currentBar = 0
    @Published var beat: Double = 0
    @Published var countIn = 4
    @Published var countdownPulse: Double = 0
    @Published var showGoCue = false
    @Published var metronomeEnabled = UserDefaults.standard.object(forKey: "metronome.enabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(metronomeEnabled, forKey: "metronome.enabled"); clickTrack.setVolume(clickVolume) }
    }
    @Published var metronomeVolume = UserDefaults.standard.object(forKey: "metronome.volume") as? Double ?? 0.65 {
        didSet { UserDefaults.standard.set(metronomeVolume, forKey: "metronome.volume"); clickTrack.setVolume(clickVolume) }
    }
    @Published var pendingBPM: Double
    @Published var activeBPM: Double
    @Published var summary = RhythmSummary(results: [], expectedDuringUsableAudio: 0)
    @Published var lastHeard = "Listening"
    @Published var harmonicEstimate: HarmonicEstimate?
    @Published var chordFeedback: [ChordFeedback] = []
    @Published var timingLabel = "Waiting for a strum"
    @Published var inputSampleRate: Double = 0
    @Published var inputChannels = 0
    @Published var receivedAudio = false
    @Published var noisyInput = false
    @Published var attemptsCompleted = 0
    @Published var error: String?
    @Published var showImporter = false
    @Published var showEditor = false
    @Published var largeText = false
    @Published var showChordTable = UserDefaults.standard.object(forKey: "practice.chordTable") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showChordTable, forKey: "practice.chordTable") }
    }
    let store: LocalStore
    let replay = ReplayPlayer()
    private let clickTrack = MetronomePlayer()
    private var recorder: CaptureRecorder?
    private var startHost: Double = 0
    private var countInHost: Double = 0
    private var clickSchedule: MetronomeSchedule?
    private var recordingEpoch: Double?
    private var attemptRecordingStart: Double = 0
    private var detected: [DetectedAttack] = []
    private var expected: [ExpectedAttack] = []
    private var usable: [TimeRange] = []
    private var lastUsableObservation: Double?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var lastHealthCheck: Double = 0
    private var healthStart: Double = 0
    private var lastAudioHost: Double = 0
    private var stoppingMic = false
    private var lastFeedbackID: String?
    var clickVolume: Float { metronomeEnabled && metronomeVolume.isFinite ? Float(min(1, max(0, metronomeVolume))) : 0 }
    var metronomeAudible: Bool { clickVolume > 0.001 }
    var outputLatencyMS: Int { Int(clickTrack.outputLatency * 1000) }

    init() {
        let store = LocalStore(); self.store = store
        let song = store.songs.first ?? .demo
        self.song = song; pendingBPM = song.practiceBPM; activeBPM = song.practiceBPM
        endBar = min(song.sections.first?.bars.count ?? 4, song.bars.count)
        selectedDeviceID = devices.contains(where: { $0.id == InputDevice.defaultID }) ? InputDevice.defaultID : devices.first?.id ?? 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.stopMic(reason: "Mac went to sleep.") }
        })
    }
    var judgedChords: [ChordFeedback] {
        let assigned = Set(summary.results.filter { $0.expectedID != nil }.compactMap(\.detectedID))
        return chordFeedback.filter { ($0.verdict == .matches || $0.verdict == .different) && $0.detectedID.map(assigned.contains) == true }
    }
    var chordRate: Double? { judgedChords.isEmpty ? nil : Double(judgedChords.filter { $0.verdict == .matches }.count) / Double(judgedChords.count) }
    var chordCoverage: Double? {
        let eligible = expected.filter { $0.time <= max(0, AudioClock.now - startHost - 0.30) }.count
        return eligible > 0 ? Double(judgedChords.count) / Double(eligible) : nil
    }
    var micName: String { devices.first(where: { $0.id == selectedDeviceID })?.name ?? "Choose a microphone" }
    var inputDB: Double { 20 * log10(max(0.000001, Double(level))) }
    var signalLabel: String {
        if !isRecording { return "Microphone off" }
        if !receivedAudio { return "Opening audio stream…" }
        if clipped { return "Clipping · lower input gain" }
        if noisyInput { return "Noisy input · reduce background sound" }
        if inputDB < -57 { return "Mic connected · waiting for sound" }
        return "Receiving audio · \(Int(inputDB)) dBFS"
    }
    var lastChordLabel: String {
        guard isRecording else { return "Enable the microphone" }
        guard let last = chordFeedback.last else { return harmonicEstimate?.chord.map { "Heard \($0)" } ?? "Waiting for a clear strum" }
        switch last.verdict {
        case .matches: return "Matches \(last.expectedShape)"
        case .different: return "Heard \(last.heard ?? "another chord") · expected \(last.expectedShape)"
        case .unclear: return "Unclear audio"
        case .unsupported: return "Unscored chord"
        case .unassigned: return last.heard.map { "Extra strum · heard \($0)" } ?? "Extra strum · chord unclear"
        }
    }
    var currentChord: String {
        guard song.bars.indices.contains(currentBar) else { return "—" }
        return song.bars[currentBar].chords.last(where: { $0.beat <= beat.truncatingRemainder(dividingBy: 4) })?.shape ?? song.bars[currentBar].chords.first?.shape ?? "—"
    }
    var activeStrumSlot: Int? {
        guard transport == .playing else { return nil }
        return StrumSlot.activeIndex(at: beat - Double(currentBar * 4))
    }
    var nextChord: String {
        guard song.bars.indices.contains(currentBar) else { return "—" }
        let local = beat.truncatingRemainder(dividingBy: 4)
        if let next = song.bars[currentBar].chords.first(where: { $0.beat > local }) { return next.shape }
        let nextIndex = currentBar + 1 < min(endBar, song.bars.count) ? currentBar + 1 : loop ? startBar : -1
        return song.bars.indices.contains(nextIndex) ? song.bars[nextIndex].chords.first?.shape ?? "—" : "—"
    }
    var visibleLyrics: String {
        guard song.bars.indices.contains(currentBar) else { return "" }
        let lines = song.bars[currentBar].lyrics
        return lines.last(where: { $0.beat <= beat.truncatingRemainder(dividingBy: 4) })?.text ?? "Chord-only practice"
    }
    var transportLabel: String {
        switch transport {
        case .stopped: return "Ready when you are"
        case .counting: return "Count in · \(countIn)"
        case .playing: return "Bar \(currentBar + 1) of \(song.bars.count)"
        case .paused: return isRecording ? "Practice paused · Recording" : "Practice paused"
        }
    }
    func selectSong(_ song: SongArrangement) {
        guard !isRecording else { error = "Turn the mic off and save before changing the arrangement."; return }
        pause(); transport = .stopped; self.song = song; pendingBPM = song.practiceBPM; activeBPM = song.practiceBPM
        startBar = 0; currentBar = 0; endBar = min(song.sections.first?.bars.count ?? 4, song.bars.count); beat = 0
        summary = .init(results: [], expectedDuringUsableAudio: 0); attemptsCompleted = 0; page = .practice
        chordFeedback = []; harmonicEstimate = nil; timingLabel = "Waiting for a strum"
    }
    func selectPassage(_ range: Range<Int>) {
        guard transport != .playing && transport != .counting else { return }
        startBar = range.lowerBound; endBar = range.upperBound; currentBar = startBar; beat = Double(startBar) * 4
    }
    func start() {
        guard song.readiness == .ready, !song.bars.isEmpty else { showEditor = true; return }
        replay.stop()
        activeBPM = min(140, max(50, pendingBPM))
        startBar = min(max(0, startBar), song.bars.count - 1); endBar = min(max(startBar + 1, endBar), song.bars.count)
        currentBar = startBar; beat = Double(startBar) * 4
        expected = RhythmMatcher.expectedAttacks(song: song, bars: startBar..<endBar, bpm: activeBPM)
        detected = []; usable = []; lastUsableObservation = nil
        chordFeedback = []; lastFeedbackID = nil; timingLabel = "Waiting for a strum"
        summary = .init(results: [], expectedDuringUsableAudio: 0)
        let schedule = MetronomeSchedule(bpm: activeBPM, practiceBeats: (endBar - startBar) * 4)
        do { countInHost = try clickTrack.start(schedule: schedule, volume: clickVolume) }
        catch { self.error = error.localizedDescription; transport = .stopped; return }
        clickSchedule = schedule
        startHost = countInHost + schedule.songStart
        attemptRecordingStart = max(0, startHost - (recordingEpoch ?? AudioClock.now - recordingSeconds))
        transport = .counting; countIn = 4
        countdownPulse = 0; showGoCue = false
        recorder?.addMarker(.init(time: recordingSeconds, label: "Count-in · bars \(startBar + 1)–\(endBar) · \(Int(activeBPM)) BPM"))
    }
    func toggleTransport() { if transport == .playing || transport == .counting { pause() } else { start() } }
    func pause() {
        if transport == .playing { finishAttempt(through: max(0, AudioClock.now - startHost)) }
        if transport == .playing || transport == .counting { recorder?.addMarker(.init(time: recordingSeconds, label: "Practice paused · recording continues")) }
        transport = .paused
        clickTrack.stop(); countdownPulse = 0; showGoCue = false
    }
    func testCountdownSound() {
        guard transport != .playing && transport != .counting else { return }
        replay.stop()
        do { try clickTrack.preview(volume: Float(max(0, min(1, metronomeVolume)))) }
        catch { self.error = error.localizedDescription }
    }
    func enableMic() async {
        guard !isRecording, !isStartingMic, !stoppingMic else { return }
        isStartingMic = true; defer { isStartingMic = false }
        pause(); replay.stop()
        let permitted = await AVCaptureDevice.requestAccess(for: .audio)
        guard permitted else { error = "Microphone access was denied. Enable Guitar Jim in System Settings → Privacy & Security → Microphone."; return }
        guard let device = InputDevice.all().first(where: { $0.id == selectedDeviceID }) else { error = "Choose an available microphone first."; return }
        let session = CaptureSession(arrangement: song, deviceUID: device.uid, deviceName: device.name, calibrationOffset: calibrationConfirmed ? calibrationMS / 1000 : nil)
        let recorder = CaptureRecorder(session: session, directory: store.sessionDirectory(session.id), onObservation: { [weak self] observation in
            Task { @MainActor in self?.observe(observation) }
        }, onFault: { [weak self] reason in
            Task { @MainActor in await self?.stopMic(reason: reason) }
        })
        do {
            try recorder.start(device: device)
            self.recorder = recorder; isRecording = true; recordingSeconds = 0; level = 0
            receivedAudio = false; harmonicEstimate = nil
            recordingEpoch = nil
            healthStart = AudioClock.now; lastAudioHost = healthStart
            recorder.addMarker(.init(time: 0, label: "Setup · mic enabled"))
        } catch { self.error = error.localizedDescription; store.reloadSessions() }
    }
    func stopMic(reason: String? = nil) async {
        guard !stoppingMic else { return }
        stoppingMic = true; defer { stoppingMic = false }
        pause()
        guard let recorder else { return }
        self.recorder = nil; isRecording = false; level = 0
        let session = await recorder.stop(reason: reason)
        store.reloadSessions()
        if let fault = reason ?? session.fault { error = fault; calibrationConfirmed = false }
    }
    func loadReplay(_ session: CaptureSession) async {
        await stopMic()
        replay.load(session, directory: store.sessionDirectory(session.id)); page = .recordings
    }
    func deviceChanged() {
        calibrationConfirmed = false
        devices = InputDevice.all()
        if let device = devices.first(where: { $0.id == selectedDeviceID }) {
            calibrationMS = UserDefaults.standard.double(forKey: "offset.\(device.uid)")
        }
    }
    func saveCalibration() {
        if let device = devices.first(where: { $0.id == selectedDeviceID }) {
            UserDefaults.standard.set(calibrationMS, forKey: "offset.\(device.uid)")
        }
    }
    private func observe(_ observation: AudioObservation) {
        guard isRecording else { return }
        recordingSeconds = observation.recordingTime; level = observation.level; clipped = observation.clipped
        inputSampleRate = observation.sampleRate; inputChannels = observation.channelCount; receivedAudio = true
        noisyInput = observation.broadbandNoise
        if let strum = observation.analyzedStrums.last { harmonicEstimate = strum.estimate }
        lastAudioHost = AudioClock.now
        recordingEpoch = observation.hostTime + observation.bufferDuration - observation.recordingTime
        guard transport == .playing || transport == .counting else { return }
        let offset = calibrationConfirmed ? calibrationMS / 1000 : 0
        let time = observation.hostTime - startHost - offset
        if !observation.clipped && !observation.broadbandNoise {
            if let last = lastUsableObservation, time - last < 0.15, !usable.isEmpty { usable[usable.count - 1].end = time + observation.bufferDuration }
            else { usable.append(.init(start: time, end: time + observation.bufferDuration)) }
            lastUsableObservation = time
            let duration = Double((endBar - startBar) * 4) * 60 / activeBPM
            detected += observation.attackHostTimes.map { .init(time: $0 - startHost - offset) }.filter { $0.time >= -0.18 && $0.time <= duration }
            for strum in observation.analyzedStrums {
                let relativeTime = strum.onsetHostTime - startHost - offset
                guard relativeTime >= -0.18, relativeTime < duration,
                      let attack = detected.first(where: { abs($0.time - relativeTime) < 0.002 }) else { continue }
                let settled = RhythmMatcher.evaluate(expected: expected, detected: detected, usable: usable, through: AudioClock.now - startHost)
                chordFeedback.append(.forAttack(attack, estimate: strum.estimate, expected: expected, rhythm: settled, capo: song.capo))
            }
        } else { lastUsableObservation = nil; lastHeard = "Unclear audio · clipping" }
    }
    private func finishAttempt(through time: Double) {
        guard isRecording else { return }
        summary = RhythmMatcher.evaluate(expected: expected, detected: detected, usable: usable, through: time)
        recorder?.addAttempt(.init(startInRecording: attemptRecordingStart, startBar: startBar, endBar: endBar, bpm: activeBPM, expected: expected, detected: detected, summary: summary, chordFeedback: chordFeedback))
        attemptsCompleted += 1
    }
    private func tick() {
        replay.tick()
        let now = AudioClock.now
        if isRecording && now - lastHealthCheck > 1 {
            lastHealthCheck = now
            let reason: String?
            if AVCaptureDevice.authorizationStatus(for: .audio) != .authorized { reason = "Microphone permission was revoked. Saved audio is preserved." }
            else if !InputDevice.all().contains(where: { $0.id == selectedDeviceID }) { reason = "The selected microphone was disconnected. Choose the input explicitly before restarting." }
            else if now - lastAudioHost > 3 { reason = "No audio buffers arrived from \(micName). Check that this input is available and restart capture." }
            else { reason = nil }
            if let reason { Task { await stopMic(reason: reason) }; return }
        }
        guard transport == .playing || transport == .counting else { return }
        if clickTrack.outputFailed {
            pause(); clickTrack.reset(); calibrationConfirmed = false
            error = "The sound output changed or stopped. Check your speaker or headphones, then resume with a new count-in."
            return
        }
        let elapsed = now - startHost
        if let schedule = clickSchedule {
            let cue = schedule.countdown(at: now - countInHost)
            countIn = cue.number; countdownPulse = cue.pulse; showGoCue = cue.isGo
        }
        let relativeBeat = elapsed * activeBPM / 60
        if elapsed < 0 { countIn = min(4, max(1, Int(ceil(-relativeBeat)))) }
        else {
            transport = .playing
            beat = Double(startBar * 4) + relativeBeat
            currentBar = min(endBar - 1, max(startBar, Int(beat / 4)))
            if isRecording {
                summary = RhythmMatcher.evaluate(expected: expected, detected: detected, usable: usable, through: elapsed)
                if let latest = summary.results.last, latest.id != lastFeedbackID {
                    lastFeedbackID = latest.id
                    timingLabel = latest.verdict.rawValue + (latest.offset.map { String(format: " · %+.0f ms", $0 * 1000) } ?? "")
                }
            }
            if elapsed >= Double((endBar - startBar) * 4) * 60 / activeBPM + 0.18 {
                finishAttempt(through: elapsed)
                if loop { start() } else { transport = .stopped; clickTrack.stop(); showGoCue = false }
                return
            }
        }
    }
}
