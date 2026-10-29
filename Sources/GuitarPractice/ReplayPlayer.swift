import AVFoundation
import GuitarPracticeCore

@MainActor
final class ReplayPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var sessionID: UUID?
    @Published var isPlaying = false
    @Published var position: Double = 0
    @Published var error: String?
    private var session: CaptureSession?
    private var directory: URL?
    private var player: AVAudioPlayer?
    private var index = 0
    var passageLoop: ClosedRange<Double>?
    func load(_ session: CaptureSession, directory: URL) {
        stop(); self.session = session; self.directory = directory; sessionID = session.id; position = 0
    }
    func play() {
        guard let session, !session.segments.isEmpty else { return }
        if position >= session.duration { position = 0 }
        seek(position, resume: true)
    }
    func pause() { player?.pause(); isPlaying = false }
    func stop() { player?.stop(); player = nil; isPlaying = false; passageLoop = nil }
    func seek(_ time: Double, resume: Bool? = nil) {
        guard let session, let directory, !session.segments.isEmpty else { return }
        let shouldPlay = resume ?? isPlaying
        let time = min(max(0, time), max(0, session.duration - 0.001))
        index = session.segments.lastIndex(where: { $0.start <= time }) ?? 0
        do {
            let segment = session.segments[index]
            player?.stop()
            let player = try AVAudioPlayer(contentsOf: directory.appendingPathComponent(segment.filename))
            player.delegate = self; player.currentTime = time - segment.start
            self.player = player; position = time
            if shouldPlay { isPlaying = player.play() } else { isPlaying = false }
        } catch { self.error = "This audio chunk could not be opened: \(error.localizedDescription)"; isPlaying = false }
    }
    func tick() {
        guard let session, let player else { return }
        position = session.segments[index].start + player.currentTime
        if let loop = passageLoop, isPlaying, position >= loop.upperBound { seek(loop.lowerBound, resume: true) }
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self, let session = self.session else { return }
            if self.index + 1 < session.segments.count { self.seek(session.segments[self.index + 1].start, resume: true) }
            else if let loop = self.passageLoop { self.seek(loop.lowerBound, resume: true) }
            else { self.position = session.duration; self.isPlaying = false }
        }
    }
    static func exportWAV(session: CaptureSession, directory: URL, destination: URL) async throws {
        try await Task.detached(priority: .utility) {
            guard let first = session.segments.first else { return }
            let firstFile = try AVAudioFile(forReading: directory.appendingPathComponent(first.filename))
            let format = firstFile.processingFormat
            let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: format.sampleRate, AVNumberOfChannelsKey: format.channelCount, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
            let output = try AVAudioFile(forWriting: destination, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192) else { return }
            for segment in session.segments {
                let input = try AVAudioFile(forReading: directory.appendingPathComponent(segment.filename))
                while input.framePosition < input.length {
                    try input.read(into: buffer)
                    try output.write(from: buffer)
                }
            }
        }.value
    }
}
