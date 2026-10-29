import Foundation

public struct AudioSegment: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var filename: String
    public var start: Double
    public var duration: Double
    public var sampleRate: Double
    public var sampleCount: Int64
    public var firstSampleHostTime: Double?
    public init(filename: String, start: Double, duration: Double, sampleRate: Double, sampleCount: Int64, firstSampleHostTime: Double? = nil) {
        self.filename = filename; self.start = start; self.duration = duration
        self.sampleRate = sampleRate; self.sampleCount = sampleCount
        self.firstSampleHostTime = firstSampleHostTime
    }
}

public struct SessionMarker: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var time: Double
    public var label: String
    public init(time: Double, label: String) { self.time = time; self.label = label }
}

public struct PracticeAttempt: Codable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var startInRecording: Double
    public var startBar: Int
    public var endBar: Int
    public var bpm: Double
    public var expected: [ExpectedAttack]
    public var detected: [DetectedAttack]
    public var summary: RhythmSummary
    public var chordFeedback: [ChordFeedback]?
    public init(startInRecording: Double, startBar: Int, endBar: Int, bpm: Double, expected: [ExpectedAttack], detected: [DetectedAttack], summary: RhythmSummary, chordFeedback: [ChordFeedback]? = nil) {
        self.startInRecording = startInRecording; self.startBar = startBar; self.endBar = endBar
        self.bpm = bpm; self.expected = expected; self.detected = detected; self.summary = summary
        self.chordFeedback = chordFeedback
    }
}

public struct CaptureSession: Codable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var name: String
    public var startedAt: Date = Date()
    public var arrangement: SongArrangement
    public var deviceUID: String
    public var deviceName: String
    public var calibrationOffset: Double?
    public var segments: [AudioSegment] = []
    public var markers: [SessionMarker] = []
    public var attempts: [PracticeAttempt] = []
    public var waveform: [Float] = []
    public var state: String = "recording"
    public var fault: String?
    public var duration: Double { segments.reduce(0) { $0 + $1.duration } }
    public init(arrangement: SongArrangement, deviceUID: String, deviceName: String, calibrationOffset: Double?) {
        self.name = arrangement.title; self.arrangement = arrangement; self.deviceUID = deviceUID
        self.deviceName = deviceName; self.calibrationOffset = calibrationOffset
    }
}
