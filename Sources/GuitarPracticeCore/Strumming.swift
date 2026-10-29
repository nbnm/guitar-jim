import Foundation

public struct StrumSlot: Identifiable, Equatable, Sendable {
    public var id: Int
    public var stroke: Stroke
    public var chord: String
    public var beat: Double { Double(id) / 2 }
    public var count: String { id.isMultiple(of: 2) ? "\(id / 2 + 1)" : "&" }
    public var spokenCount: String { "\(id / 2 + 1)\(id.isMultiple(of: 2) ? "" : " and")" }
    public static func activeIndex(at beat: Double) -> Int? {
        guard beat.isFinite, beat >= 0, beat < 4 else { return nil }
        return Int(floor(beat * 2))
    }
}

public enum StrummingPattern: String, CaseIterable, Identifiable, Sendable {
    case halfTime, steady, pickups, country, folk, syncopated, allDown, alternating
    public var id: String { rawValue }
    public var name: String {
        switch self {
        case .halfTime: return "Half-time"
        case .steady: return "Steady downstrokes"
        case .pickups: return "Eighth-note pickups"
        case .country: return "Country pulse"
        case .folk: return "Folk groove"
        case .syncopated: return "Syncopated"
        case .allDown: return "Driving downstrokes"
        case .alternating: return "Alternating eighths"
        }
    }
    private var notation: String {
        switch self {
        case .halfTime: return "D...D..."
        case .steady: return "D.D.D.D."
        case .pickups: return "D.D.DUDU"
        case .country: return "D.DUD.DU"
        case .folk: return "D.DU.UDU"
        case .syncopated: return "DU.UDU.U"
        case .allDown: return "DDDDDDDD"
        case .alternating: return "DUDUDUDU"
        }
    }
    public var events: [StrumEvent] {
        notation.enumerated().map { index, character in
            .init(beat: Double(index) / 2, stroke: character == "D" ? .down : character == "U" ? .up : .rest)
        }
    }
    public static func matching(_ bar: PracticeBar) -> Self? {
        let strokes = bar.strumGrid.map(\.stroke)
        return allCases.first { $0.events.map(\.stroke) == strokes }
    }
}

extension PracticeBar {
    /// Missing events are rests; chord changes remain anchored to their beats.
    public var strumGrid: [StrumSlot] {
        (0..<8).map { index in
            let beat = Double(index) / 2
            return .init(id: index, stroke: strums.first(where: { abs($0.beat - beat) < 0.0001 })?.stroke ?? .rest,
                         chord: chords.last(where: { $0.beat <= beat })?.shape ?? "—")
        }
    }
}

extension SongArrangement {
    public mutating func applyStrummingPattern(_ pattern: StrummingPattern, bars range: Range<Int>) {
        var global = 0
        for section in sections.indices {
            for bar in sections[section].bars.indices {
                if range.contains(global) { sections[section].bars[bar].strums = pattern.events }
                global += 1
            }
        }
    }
}
