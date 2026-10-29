import AVFoundation
import AudioToolbox
import GuitarPracticeCore

final class CaptureRecorder: @unchecked Sendable {
    private var driver: HALCaptureDriver?
    private let worker = DispatchQueue(label: "com.guitarjim.capture.writer", qos: .userInitiated)
    private var source: DispatchSourceUserDataAdd?
    private var overflow: DispatchSourceUserDataAdd?
    private var pool: AudioBufferPool?
    private var file: AVAudioFile?
    private var session: CaptureSession
    private let directory: URL
    private var chunkFrames: Int64 = 0
    private var totalFrames: Int64 = 0
    private var format: AVAudioFormat?
    private var chunkIndex = 0
    private var chunkHostTime: Double?
    private var stopping = false
    private let analyzer = LiveAudioAnalyzer()
    private var firstHost: Double?
    private var lastObservation: Double = 0
    private var lastBufferEnd: Double?
    private let onObservation: @Sendable (AudioObservation) -> Void
    private let onFault: @Sendable (String) -> Void

    init(session: CaptureSession, directory: URL, onObservation: @escaping @Sendable (AudioObservation) -> Void, onFault: @escaping @Sendable (String) -> Void) {
        self.session = session; self.directory = directory; self.onObservation = onObservation; self.onFault = onFault
    }

    func start(device: InputDevice) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let driver = try HALCaptureDriver(device: device)
        self.driver = driver
        let format = driver.format
        guard format.sampleRate > 0, format.channelCount > 0, format.commonFormat == .pcmFormatFloat32, !format.isInterleaved else {
            throw failure("The input format is unsupported. Choose a standard PCM microphone route.")
        }
        self.format = format
        // A writable chunk and manifest exist before capture starts.
        try openChunk(); try writeManifest()
        let pool = AudioBufferPool(format: format); self.pool = pool
        let source = DispatchSource.makeUserDataAddSource(queue: worker)
        let overflow = DispatchSource.makeUserDataAddSource(queue: worker)
        source.setEventHandler { [weak self] in self?.drain() }
        overflow.setEventHandler { [weak self] in self?.reportFault("Microphone input failed or the recording buffer could not keep up. Saved audio is preserved. Restart the microphone explicitly.") }
        source.resume(); overflow.resume(); self.source = source; self.overflow = overflow
        do { try driver.start(pool: pool, ready: source, fault: overflow) }
        catch { driver.stop(); file = nil; source.cancel(); overflow.cancel(); throw error }
    }

    func addMarker(_ marker: SessionMarker) {
        worker.async { [weak self] in
            guard let self, !self.stopping else { return }
            self.session.markers.append(marker)
            do { try self.writeManifest() } catch { self.reportFault("Could not save recording markers. \(error.localizedDescription)") }
        }
    }
    func addAttempt(_ attempt: PracticeAttempt) {
        worker.async { [weak self] in
            guard let self, !self.stopping else { return }
            self.session.attempts.append(attempt)
            do { try self.writeManifest() } catch { self.reportFault("Could not save practice feedback. \(error.localizedDescription)") }
        }
    }

    /// Called off the audio callback. Stop input before draining and finalizing files.
    func stop(reason: String? = nil) async -> CaptureSession {
        driver?.stop()
        return await withCheckedContinuation { continuation in
            worker.async { [self] in
                drain(); stopping = true
                do { try finishChunk() } catch { session.fault = error.localizedDescription }
                session.state = reason == nil && session.fault == nil ? "saved" : "interrupted"
                if let reason { session.fault = reason; session.markers.append(.init(time: session.duration, label: "Gap / stopped: \(reason)")) }
                do { try writeManifest() } catch { session.fault = "Manifest save failed: \(error.localizedDescription). Audio chunks remain on disk." }
                source?.cancel(); overflow?.cancel()
                continuation.resume(returning: session)
            }
        }
    }

    private func drain() {
        guard !stopping, let pool, let format else { return }
        while let (index, buffer, rawHost) = pool.pop() {
            defer { pool.release(index) }
            do {
                let host = AVAudioTime.seconds(forHostTime: rawHost)
                if let previous = lastBufferEnd, abs(host - previous) > 0.1 {
                    throw failure("An input timestamp gap was detected. Capture stopped; restart explicitly.")
                }
                lastBufferEnd = host + Double(buffer.frameLength) / format.sampleRate
                if firstHost == nil { firstHost = host }
                if file == nil { try openChunk() }
                if chunkFrames == 0 { chunkHostTime = host }
                try file?.write(from: buffer)
                chunkFrames += Int64(buffer.frameLength); totalFrames += Int64(buffer.frameLength)
                analyze(buffer, host: host, rate: format.sampleRate)
                if Double(chunkFrames) / format.sampleRate >= 2 { try finishChunk(); try writeManifest() }
            } catch { reportFault("Recording stopped: \(error.localizedDescription)"); return }
        }
    }

    private func analyze(_ buffer: AVAudioPCMBuffer, host: Double, rate: Double) {
        guard let channels = buffer.floatChannelData else { return }
        var peak: Float = 0; var sum: Float = 0
        let count = Int(buffer.frameLength)
        var selected = 0
        for channel in 0..<Int(buffer.format.channelCount) {
            var energy: Float = 0
            for i in 0..<count { energy += channels[channel][i] * channels[channel][i] }
            if energy > sum { selected = channel; sum = energy }
        }
        let samples = channels[selected]
        var crossings = 0
        for i in 0..<count { peak = max(peak, abs(samples[i])) }
        if count > 1 { for i in 1..<count where (samples[i] >= 0) != (samples[i - 1] >= 0) { crossings += 1 } }
        let noisy = Float(crossings) / Float(max(1, count)) > 0.32 && sqrt(sum / Float(max(1, count))) > 0.003
        let analysis = analyzer.process(samples: UnsafeBufferPointer(start: samples, count: count), sampleRate: rate, hostTime: host)
        if host - lastObservation >= 0.04 || !analysis.onsets.isEmpty || !analysis.strums.isEmpty {
            let rms = sqrt(sum / Float(max(1, count)))
            session.waveform.append(peak)
            lastObservation = host
            onObservation(.init(hostTime: host, recordingTime: Double(totalFrames) / rate, level: rms, clipped: peak >= 0.99, attackHostTimes: analysis.onsets, analyzedStrums: analysis.strums, sampleRate: rate, channelCount: Int(buffer.format.channelCount), bufferDuration: Double(count) / rate, broadbandNoise: noisy))
        }
    }

    private func openChunk() throws {
        guard let format else { return }
        let filename = String(format: "audio-%05d.caf", chunkIndex)
        file = try AVAudioFile(forWriting: directory.appendingPathComponent(filename), settings: format.settings)
        chunkFrames = 0
    }
    private func finishChunk() throws {
        guard file != nil, let format else { return }
        file = nil // AVAudioFile finalizes its header before publishing the segment.
        if chunkFrames > 0 {
            let duration = Double(chunkFrames) / format.sampleRate
            session.segments.append(.init(filename: String(format: "audio-%05d.caf", chunkIndex), start: Double(totalFrames - chunkFrames) / format.sampleRate, duration: duration, sampleRate: format.sampleRate, sampleCount: chunkFrames, firstSampleHostTime: chunkHostTime))
            chunkIndex += 1
        }
        chunkFrames = 0; chunkHostTime = nil
    }
    private func writeManifest() throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(session).write(to: directory.appendingPathComponent("session.json"), options: .atomic)
    }
    private func reportFault(_ message: String) {
        guard session.fault == nil else { return }
        session.fault = message
        onFault(message)
    }
    private func failure(_ message: String) -> NSError { NSError(domain: "GuitarJim.Audio", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}
