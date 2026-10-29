import Foundation

public enum ChartImportError: LocalizedError {
    case tooLarge, noBars
    public var errorDescription: String? {
        switch self {
        case .tooLarge: return "Use a chart smaller than 100 KB and no more than 512 bars."
        case .noBars: return "No chords found. Use [G]lyrics or a chord row such as G | Em | C | D."
        }
    }
}

public enum ChartImporter {
    /// Only parses chart text. Directives never become executable instructions.
    public static func parse(_ text: String, title: String = "Imported chart") throws -> SongArrangement {
        guard text.utf8.count <= 100_000 else { throw ChartImportError.tooLarge }
        var song = SongArrangement(title: title, artist: "Your library", version: "User supplied chart")
        var bars: [PracticeBar] = []
        let chordPattern = try NSRegularExpression(pattern: #"\[([A-G](?:#|b)?(?:m|maj7|m7|7|sus2|sus4|dim|add9)?(?:/[A-G](?:#|b)?)?)\]"#)
        let plainChord = try NSRegularExpression(pattern: #"^[A-G](?:#|b)?(?:m|maj7|m7|7|sus2|sus4|dim|add9)?(?:/[A-G](?:#|b)?)?$"#)
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("{") && line.hasSuffix("}") {
                let pieces = line.dropFirst().dropLast().split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if pieces.count == 2 {
                    switch pieces[0].lowercased() {
                    case "title", "t": song.title = String(pieces[1].prefix(200))
                    case "artist": song.artist = String(pieces[1].prefix(200))
                    case "capo":
                        if let capo = Int(pieces[1]), (0...12).contains(capo) { song.capo = capo }
                    case "tempo":
                        if let bpm = Double(pieces[1]), bpm.isFinite, (1...400).contains(bpm) {
                            song.sourceBPM = bpm; song.practiceBPM = min(140, max(50, bpm))
                        }
                    default: break
                    }
                }
                continue
            }
            let range = NSRange(line.startIndex..., in: line)
            let matches = chordPattern.matches(in: line, range: range)
            if !matches.isEmpty {
                let chords = matches.enumerated().compactMap { index, match -> ChordEvent? in
                    guard let r = Range(match.range(at: 1), in: line) else { return nil }
                    // Words do not determine musical time. This is a visible, unconfirmed proposal.
                    return .init(beat: floor(Double(index) * 8 / Double(matches.count)) / 2, shape: String(line[r]))
                }
                let lyrics = chordPattern.stringByReplacingMatches(in: line, range: range, withTemplate: "").trimmingCharacters(in: .whitespaces)
                bars.append(.init(chords: chords, strums: quarterNotes, lyrics: lyrics.isEmpty ? [] : [.init(beat: 0, text: lyrics)]))
            } else {
                let tokens = line.replacingOccurrences(of: "|", with: " ").split(whereSeparator: \.isWhitespace).map(String.init)
                if !tokens.isEmpty && tokens.allSatisfy({ plainChord.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }) {
                    bars += tokens.map { .init(chords: [.init(beat: 0, shape: $0)], strums: quarterNotes) }
                } else if !bars.isEmpty {
                    bars[bars.count - 1].lyrics.append(.init(beat: 0, text: line))
                }
            }
            if bars.count > 512 { throw ChartImportError.tooLarge }
        }
        guard !bars.isEmpty else { throw ChartImportError.noBars }
        // Combine plain-text lyric continuations into one anchor.
        for i in bars.indices where bars[i].lyrics.count > 1 {
            bars[i].lyrics = [.init(beat: 0, text: bars[i].lyrics.map(\.text).joined(separator: " "))]
        }
        song.sections = [.init(name: "Imported passage", bars: bars)]
        song.sources = [.init(field: "chart", status: .userSupplied, attribution: "User supplied text; confirm permission to store and display", permitsOfflineStorage: false),
                        .init(field: "timing and strumming", status: .suggested, attribution: "Evenly spaced draft timing; review each bar before practice", permitsOfflineStorage: true)]
        return song
    }
    public static let quarterNotes = (0..<4).map { StrumEvent(beat: Double($0), stroke: .down) }
}
