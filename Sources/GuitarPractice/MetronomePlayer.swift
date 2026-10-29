import AVFoundation
import GuitarPracticeCore

/// Output-only audio engine, separate from the input-only HAL recorder. Beats are
/// queued at sample positions; UI timer delays cannot move an audible click.
@MainActor
final class MetronomePlayer {
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var format: AVAudioFormat?
    private var buffers: [ClickVoice: AVAudioPCMBuffer] = [:]
    private var expectedToRun = false
    private var previewStop: Task<Void, Never>?
    private(set) var outputLatency: Double = 0
    var outputFailed: Bool { expectedToRun && engine?.isRunning != true }

    /// Returns the predicted audible epoch, including the device's reported
    /// presentation latency, so countdown animation uses the same audible clock.
    func start(schedule: MetronomeSchedule, volume: Float) throws -> Double {
        stop()
        try prepare()
        guard let engine, let player, let format else { throw failure("No sound output is available.") }
        player.volume = min(1, max(0, volume))
        for event in schedule.events {
            guard let buffer = buffers[event.voice] else { continue }
            player.scheduleBuffer(buffer, at: AVAudioTime(sampleTime: event.sampleTime(at: format.sampleRate), atRate: format.sampleRate))
        }
        engine.prepare()
        do { try engine.start() } catch { stop(); self.engine = nil; self.player = nil; throw failure("Could not start the metronome output: \(error.localizedDescription)") }
        outputLatency = max(0, min(3, player.outputPresentationLatency))
        let renderEpoch = AudioClock.now + 0.15
        player.play(at: AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: renderEpoch)))
        expectedToRun = true
        return renderEpoch + outputLatency
    }
    func setVolume(_ volume: Float) { player?.volume = min(1, max(0, volume)) }
    func stop() {
        previewStop?.cancel(); previewStop = nil
        expectedToRun = false
        player?.stop(); engine?.pause()
    }
    func reset() {
        stop(); engine?.stop(); engine = nil; player = nil; format = nil; buffers = [:]
    }
    func preview(volume: Float) throws {
        let schedule = MetronomeSchedule(bpm: 100, practiceBeats: 1)
        _ = try start(schedule: schedule, volume: volume)
        // A short real count-in and GO provides a useful output-route check.
        let delay = schedule.duration + outputLatency + 0.2
        previewStop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }
    private func prepare() throws {
        // Rebuild for the current output route, which may differ from the mic.
        if let engine, let format, engine.outputNode.inputFormat(forBus: 0).sampleRate == format.sampleRate { return }
        reset()
        let engine = AVAudioEngine()
        let rate = engine.outputNode.inputFormat(forBus: 0).sampleRate
        guard rate > 0, let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1) else { throw failure("Choose a connected sound output in macOS Sound settings.") }
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1
        self.engine = engine; self.player = player; self.format = format
        buffers = Dictionary(uniqueKeysWithValues: ClickVoice.allCases.map { voice in (voice, Self.makeBuffer(voice: voice, format: format)) })
    }
    static func makeBuffer(voice: ClickVoice, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let samples = ClickSynthesizer.samples(voice: voice, sampleRate: format.sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(samples.count))!
        buffer.frameLength = UInt32(samples.count)
        for channel in 0..<Int(format.channelCount) {
            samples.withUnsafeBufferPointer { source in buffer.floatChannelData![channel].update(from: source.baseAddress!, count: samples.count) }
        }
        return buffer
    }
    private func failure(_ message: String) -> NSError { NSError(domain: "GuitarJim.Metronome", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}
