import Foundation

public enum ClickVoice: String, CaseIterable, Sendable { case countIn, beat, downbeat, go }

public struct ClickEvent: Equatable, Sendable {
    public var index: Int
    public var time: Double
    public var voice: ClickVoice
    public func sampleTime(at sampleRate: Double) -> Int64 { Int64((time * sampleRate).rounded()) }
}

/// Count-in and practice share one absolute timeline. Each event is rounded from
/// its exact beat position, so fractional samples never accumulate tempo drift.
public struct MetronomeSchedule: Sendable {
    public let bpm: Double
    public let practiceBeats: Int
    public let countInBeats = 4
    public var secondsPerBeat: Double { 60 / bpm }
    public var songStart: Double { Double(countInBeats) * secondsPerBeat }
    public var duration: Double { Double(countInBeats + practiceBeats) * secondsPerBeat }
    public init(bpm: Double, practiceBeats: Int) {
        self.bpm = bpm.isFinite ? min(140, max(50, bpm)) : 80
        self.practiceBeats = max(0, min(2048, practiceBeats))
    }
    public var events: [ClickEvent] {
        (0..<(countInBeats + practiceBeats)).map { index in
            let voice: ClickVoice = index < countInBeats ? .countIn : index == countInBeats ? .go : (index - countInBeats) % 4 == 0 ? .downbeat : .beat
            return .init(index: index, time: Double(index) * secondsPerBeat, voice: voice)
        }
    }
    public func countdown(at elapsed: Double) -> (number: Int, pulse: Double, isGo: Bool) {
        guard elapsed.isFinite, elapsed >= 0 else { return (4, 0, false) }
        if elapsed < songStart {
            let position = elapsed / secondsPerBeat
            let phase = position - floor(position)
            return (4 - min(3, Int(position)), max(0, 1 - phase * 2.4), false)
        }
        let sinceGo = elapsed - songStart
        return (1, max(0, 1 - sinceGo / 0.4), sinceGo < min(0.4, secondsPerBeat))
    }
}

public enum ClickSynthesizer {
    /// Original short, band-limited tonal clicks. No audio asset or network needed.
    public static func samples(voice: ClickVoice, sampleRate: Double) -> [Float] {
        guard sampleRate.isFinite, sampleRate >= 8_000, sampleRate <= 192_000 else { return [] }
        let duration = voice == .go ? 0.15 : voice == .countIn ? 0.075 : 0.045
        let frequency: Double = voice == .go ? 1320 : voice == .countIn ? 880 : voice == .downbeat ? 1200 : 800
        return (0..<Int(sampleRate * duration)).map { index in
            let time = Double(index) / sampleRate
            let attack = min(1, time / 0.0015)
            let release = min(1, (duration - time) / 0.006)
            let decay = exp(-time * (voice == .go ? 24 : voice == .countIn ? 48 : 90))
            let fundamental = sin(2 * .pi * frequency * time)
            let overtone = sin(2 * .pi * frequency * (voice == .go ? 1.5 : 2.0) * time) * 0.22
            return Float((fundamental + overtone) * 0.48 * attack * release * decay)
        }
    }
}
