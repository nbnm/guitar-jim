import Foundation

public enum RhythmVerdict: String, Codable, Sendable {
    case onTime = "On time", early = "Early", late = "Late", missed = "Missed", extra = "Extra"
}

public struct ExpectedAttack: Codable, Equatable, Identifiable, Sendable {
    public var id: Int
    public var time: Double
    public var chord: String
    public init(id: Int, time: Double, chord: String) { self.id = id; self.time = time; self.chord = chord }
}

public struct DetectedAttack: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var time: Double
    public init(id: UUID = UUID(), time: Double) { self.id = id; self.time = time }
}

public struct TimeRange: Codable, Equatable, Sendable {
    public var start: Double
    public var end: Double
    public init(start: Double, end: Double) { self.start = start; self.end = end }
    public func contains(_ time: Double) -> Bool { time >= start && time <= end }
}

public struct RhythmResult: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var expectedID: Int?
    public var detectedID: UUID?
    public var verdict: RhythmVerdict
    public var offset: Double?
}

public struct RhythmSummary: Codable, Equatable, Sendable {
    public var results: [RhythmResult]
    public var expectedDuringUsableAudio: Int
    public init(results: [RhythmResult], expectedDuringUsableAudio: Int) {
        self.results = results; self.expectedDuringUsableAudio = expectedDuringUsableAudio
    }
    public var onTime: Int { results.filter { $0.verdict == .onTime }.count }
    public var onTimeRate: Double? { expectedDuringUsableAudio > 0 ? Double(onTime) / Double(expectedDuringUsableAudio) : nil }
    public func count(_ verdict: RhythmVerdict) -> Int { results.filter { $0.verdict == verdict }.count }
}

/// Audio-clock seconds, after subtracting the explicitly calibrated input offset.
/// Verdicts settle only when an attack's complete matching window has elapsed.
public enum RhythmMatcher {
    public static func windows(at index: Int, expected: [ExpectedAttack]) -> (onTime: Double, match: Double) {
        let before = index > 0 ? expected[index].time - expected[index - 1].time : .infinity
        let after = index + 1 < expected.count ? expected[index + 1].time - expected[index].time : .infinity
        let nearest = min(before, after)
        return (min(0.090, nearest * 0.25), min(0.180, nearest * 0.45))
    }

    public static func evaluate(expected input: [ExpectedAttack], detected: [DetectedAttack], usable: [TimeRange], through time: Double) -> RhythmSummary {
        let expected = input.filter { $0.time.isFinite }.sorted { $0.time < $1.time }
        let observed = detected.filter { attack in attack.time.isFinite && attack.time <= time && usable.contains(where: { $0.contains(attack.time) }) }
        var candidates: [(distance: Double, e: Int, d: Int)] = []
        for (e, attack) in expected.enumerated() {
            guard usable.contains(where: { $0.contains(attack.time) }) else { continue }
            let window = windows(at: e, expected: expected).match
            for (d, heard) in observed.enumerated() where abs(heard.time - attack.time) <= window {
                candidates.append((abs(heard.time - attack.time), e, d))
            }
        }
        candidates.sort { $0.distance == $1.distance ? ($0.e == $1.e ? $0.d < $1.d : $0.e < $1.e) : $0.distance < $1.distance }
        var matched: [Int: Int] = [:]
        var used = Set<Int>()
        for candidate in candidates where matched[candidate.e] == nil && !used.contains(candidate.d) {
            matched[candidate.e] = candidate.d; used.insert(candidate.d)
        }
        var results: [RhythmResult] = []
        var eligible = 0
        for (e, attack) in expected.enumerated() {
            let window = windows(at: e, expected: expected)
            guard time >= attack.time + window.match, usable.contains(where: { $0.contains(attack.time) }) else { continue }
            eligible += 1
            if let d = matched[e] {
                let offset = observed[d].time - attack.time
                let verdict: RhythmVerdict = abs(offset) <= window.onTime ? .onTime : offset < 0 ? .early : .late
                results.append(.init(id: "e\(attack.id)", expectedID: attack.id, detectedID: observed[d].id, verdict: verdict, offset: offset))
            } else {
                results.append(.init(id: "e\(attack.id)", expectedID: attack.id, detectedID: nil, verdict: .missed, offset: nil))
            }
        }
        for (d, attack) in observed.enumerated() where !used.contains(d) && time >= attack.time + 0.180 {
            results.append(.init(id: "d\(attack.id)", expectedID: nil, detectedID: attack.id, verdict: .extra, offset: nil))
        }
        return RhythmSummary(results: results, expectedDuringUsableAudio: eligible)
    }

    public static func expectedAttacks(song: SongArrangement, bars: Range<Int>, bpm: Double) -> [ExpectedAttack] {
        guard bpm.isFinite, bpm > 0 else { return [] }
        var events: [ExpectedAttack] = []
        for barIndex in bars where song.bars.indices.contains(barIndex) {
            let bar = song.bars[barIndex]
            for strum in bar.strums where strum.stroke != .rest {
                let chord = bar.chords.last(where: { $0.beat <= strum.beat })?.shape ?? "?"
                events.append(.init(id: events.count, time: (Double(barIndex - bars.lowerBound) * 4 + strum.beat) * 60 / bpm, chord: chord))
            }
        }
        return events
    }
}
