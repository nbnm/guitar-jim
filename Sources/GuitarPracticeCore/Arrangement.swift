import Foundation

public struct Meter: Codable, Equatable, Sendable {
    public var beats: Int = 4
    public var unit: Int = 4
    public init(beats: Int = 4, unit: Int = 4) { self.beats = beats; self.unit = unit }
}

public enum Stroke: String, Codable, CaseIterable, Sendable {
    case down, up, rest
    public var symbol: String { self == .down ? "↓" : self == .up ? "↑" : "·" }
}

public struct StrumEvent: Codable, Equatable, Sendable {
    public var beat: Double
    public var stroke: Stroke
    public init(beat: Double, stroke: Stroke) { self.beat = beat; self.stroke = stroke }
}

public struct ChordEvent: Codable, Equatable, Sendable {
    public var beat: Double
    public var shape: String
    public init(beat: Double, shape: String) { self.beat = beat; self.shape = shape }
}

public struct LyricLine: Codable, Equatable, Sendable {
    public var beat: Double
    public var text: String
    public init(beat: Double, text: String) { self.beat = beat; self.text = text }
}

public struct PracticeBar: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var chords: [ChordEvent]
    public var strums: [StrumEvent]
    public var lyrics: [LyricLine]
    public init(id: UUID = UUID(), chords: [ChordEvent], strums: [StrumEvent], lyrics: [LyricLine] = []) {
        self.id = id; self.chords = chords; self.strums = strums; self.lyrics = lyrics
    }
    public func canMoveChord(at index: Int, to beat: Double) -> Bool {
        guard chords.indices.contains(index), beat.isFinite, beat >= 0, beat < 4,
              (beat * 2).rounded() == beat * 2, index != 0 || beat == 0 else { return false }
        return !chords.enumerated().contains { $0.offset != index && $0.element.beat == beat }
    }
    @discardableResult
    public mutating func moveChord(at index: Int, to beat: Double) -> Bool {
        guard canMoveChord(at: index, to: beat) else { return false }
        chords[index].beat = beat
        chords.sort { $0.beat < $1.beat }
        return true
    }
}

public struct PracticeSection: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var bars: [PracticeBar]
    public init(id: UUID = UUID(), name: String, bars: [PracticeBar]) {
        self.id = id; self.name = name; self.bars = bars
    }
}

public struct FieldSource: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable { case original, userSupplied, suggested, confirmed, unavailable }
    public var field: String
    public var status: Status
    public var attribution: String
    public var url: URL?
    public var permitsOfflineStorage: Bool
    public init(field: String, status: Status, attribution: String, url: URL? = nil, permitsOfflineStorage: Bool = false) {
        self.field = field; self.status = status; self.attribution = attribution
        self.url = url; self.permitsOfflineStorage = permitsOfflineStorage
    }
}

public enum Readiness: String, Sendable { case found = "Found", needsReview = "Needs review", ready = "Ready to practise" }

public struct StrummingDifficulty: Codable, Equatable, Sendable {
    public var level: Int
    public var name: String
    public var technique: String
    public init(level: Int, name: String, technique: String) { self.level = level; self.name = name; self.technique = technique }
}

public struct SongArrangement: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var revision: Int = 1
    public var title: String
    public var artist: String
    public var version: String
    public var tuning: String = "E A D G B E"
    public var tuningConfirmed: Bool = false
    public var capo: Int = 0
    public var capoConfirmed: Bool = false
    public var sourceBPM: Double?
    public var practiceBPM: Double = 80
    public var meter: Meter = Meter()
    public var sections: [PracticeSection] = []
    public var sources: [FieldSource] = []
    public var suggestionsConfirmed: Bool = false
    public var unsupportedChordsAcknowledged: Bool = false
    public var difficulty: StrummingDifficulty?

    public init(title: String, artist: String, version: String) {
        self.title = title; self.artist = artist; self.version = version
    }
    public static let supportedChords = ["A", "Am", "C", "D", "Dm", "E", "Em", "G"]
    public var bars: [PracticeBar] { sections.flatMap(\.bars) }
    /// Chord-only charts describe the current setup, rather than a catalog
    /// subtitle that may refer to a capo or key changed in the editor.
    public var practiceDescription: String {
        let chart = bars
        guard !chart.isEmpty, chart.allSatisfy({ $0.lyrics.isEmpty }) else { return difficulty?.technique ?? version }
        var shapes: [String] = []
        for chord in chart.flatMap(\.chords) where !shapes.contains(chord.shape) { shapes.append(chord.shape) }
        let visible = Array(shapes.prefix(8))
        let sequence = visible.joined(separator: "–") + (shapes.count > visible.count ? "…" : "")
        if capo == 0 { return "\(sequence) · no capo" }
        let sounding = visible.compactMap { ChordVocabulary.concertName(shape: $0, capo: capo) }
        let concert = sounding.count == visible.count ? " · sounds \(sounding.joined(separator: "–"))" : ""
        return "\(sequence) shapes · capo \(capo)\(concert)"
    }
    public var unsupportedChords: [String] {
        Array(Set(bars.flatMap(\.chords).map(\.shape)).subtracting(Self.supportedChords)).sorted()
    }
    public var readiness: Readiness {
        sections.isEmpty ? .found : validationIssues.isEmpty ? .ready : .needsReview
    }
    public var validationIssues: [String] {
        var issues: [String] = []
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("Add a song title.") }
        if version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("Choose an arrangement version.") }
        if !tuningConfirmed || tuning != "E A D G B E" { issues.append("Confirm standard tuning.") }
        if !capoConfirmed || !(0...12).contains(capo) { issues.append("Confirm a capo between 0 and 12.") }
        if !practiceBPM.isFinite || !(50...140).contains(practiceBPM) { issues.append("Set a fixed tempo from 50 to 140 BPM.") }
        if meter != Meter() { issues.append("This prototype supports 4/4 time.") }
        if sections.isEmpty || sections.contains(where: { $0.bars.isEmpty }) { issues.append("Add bars to every section.") }
        if !suggestionsConfirmed { issues.append("Review and confirm the arrangement and timing.") }
        if !unsupportedChords.isEmpty && !unsupportedChordsAcknowledged {
            issues.append("Acknowledge unscored chords: \(unsupportedChords.joined(separator: ", ")).")
        }
        if bars.count > 512 { issues.append("Use at most 512 bars in this prototype.") }
        for (index, bar) in bars.enumerated() {
            let beats = bar.chords.map(\.beat) + bar.strums.map(\.beat) + bar.lyrics.map(\.beat)
            if beats.contains(where: { !$0.isFinite || $0 < 0 || $0 >= 4 || ($0 * 2).rounded() != $0 * 2 }) {
                issues.append("Bar \(index + 1): place events on the quarter or eighth note grid.")
            }
            if bar.chords.isEmpty || bar.chords.first?.beat != 0 || !isOrdered(bar.chords.map(\.beat)) || bar.chords.contains(where: { $0.shape.isEmpty }) {
                issues.append("Bar \(index + 1): set ordered chord changes, starting on beat one.")
            }
            if bar.strums.isEmpty || !isOrdered(bar.strums.map(\.beat)) {
                issues.append("Bar \(index + 1): set an ordered strumming pattern, including rests.")
            }
            if !isOrdered(bar.lyrics.map(\.beat)) || bar.lyrics.contains(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                issues.append("Bar \(index + 1): check lyric anchors and text.")
            }
        }
        return issues
    }
    private func isOrdered(_ beats: [Double]) -> Bool {
        zip(beats, beats.dropFirst()).allSatisfy { $0 < $1 }
    }

    public static var demo: SongArrangement {
        var song = SongArrangement(title: "A little closer", artist: "Guitar Jim", version: "Original practice study · 8 bars")
        song.tuningConfirmed = true; song.capoConfirmed = true; song.suggestionsConfirmed = true
        song.sourceBPM = 80
        let shapes = ["G", "Em", "C", "D", "G", "Em", "C", "G"]
        let words = ["Let the morning find its way", "Through the window, soft and slow", "Take a breath and let it ring", "There is nowhere else to go", "Every day a little closer", "Every chord a place to start", "Keep a little room for wonder", "Keep a little time for heart"]
        let pattern = [StrumEvent(beat: 0, stroke: .down), .init(beat: 1, stroke: .down), .init(beat: 1.5, stroke: .up), .init(beat: 2, stroke: .rest), .init(beat: 2.5, stroke: .up), .init(beat: 3, stroke: .down), .init(beat: 3.5, stroke: .up)]
        let allBars = zip(shapes, words).map { shape, text in
            PracticeBar(chords: [.init(beat: 0, shape: shape)], strums: pattern, lyrics: [.init(beat: 0, text: text)])
        }
        song.sections = [PracticeSection(name: "Verse", bars: Array(allBars.prefix(4))), PracticeSection(name: "Refrain", bars: Array(allBars.suffix(4)))]
        song.sources = [.init(field: "lyrics, chords, tempo, timing", status: .original, attribution: "Original practice material created for this prototype", permitsOfflineStorage: true)]
        return song
    }
}

public enum ChordVocabulary {
    public static func concertName(shape: String, capo: Int) -> String? {
        let roots = ["C": 0, "D": 2, "E": 4, "G": 7, "A": 9]
        let minor = shape.hasSuffix("m")
        let root = minor ? String(shape.dropLast()) : shape
        guard let pitch = roots[root], SongArrangement.supportedChords.contains(shape), (0...12).contains(capo) else { return nil }
        return ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"][(pitch + capo) % 12] + (minor ? "m" : "")
    }
}
