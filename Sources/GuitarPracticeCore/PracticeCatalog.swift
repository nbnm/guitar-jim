import Foundation

public enum PracticeCatalog {
    public static var songs: [SongArrangement] {
        [make(id: 1, title: "First Light", bpm: 65, level: 1, name: "Easy", technique: "Steady quarter-note downstrokes",
              chords: ["Em", "G", "Em", "G", "Em", "G", "Em", "G"], pattern: "D.D.D.D.",
              lyrics: ["First light on the windowsill", "One more breath and the room is still", "Let each note find a place to land", "Easy now with a steady hand", "Four small steps to a brand new day", "Let the hurry drift away", "Hear the wood and the open string", "Take your time and let it ring"]),
         make(id: 2, title: "Open Road", bpm: 80, level: 2, name: "Getting going", technique: "Downstrokes with eighth-note pickups",
              chords: ["G", "C", "D", "G", "G", "C", "D", "G"], pattern: "D.D.DUDU",
              lyrics: ["Pack a little sunlight for the road", "Leave a little room inside the load", "Every corner opens to the sky", "Watch the quiet fields go rolling by", "Turn the wheel and follow where it bends", "Find a song to carry to your friends", "Nothing here to hurry us along", "Just an open road and one more song"]),
         folkSong,
         make(id: 4, title: "Paper Satellites", bpm: 100, level: 4, name: "Off the beat", technique: "Syncopated eighths and minor chord changes",
              chords: ["Am", "C", "Dm", "E", "Am", "C", "Dm", "E"], pattern: "DU.UDU.U",
              lyrics: ["Fold a little message into flight", "Send it past the rooftops into night", "Paper satellites above the street", "Dancing in the spaces of the beat", "Hold the silence, let the rhythm lean", "Find the little places in between", "Every folded wing can catch the air", "Let it go and trust it gets somewhere"]),
         make(id: 5, title: "Night Runner", bpm: 120, level: 5, name: "Challenge", technique: "Continuous eighths with mid-bar chord changes",
              chords: ["Em", "G", "D", "A", "Em", "G", "D", "Em"], pattern: "DUDUDUDU", splitChanges: true,
              lyrics: ["Streetlights running down the avenue", "Every passing shadow turns to blue", "Keep the wheels beneath a silver moon", "Chase the rhythm, change the chord too soon", "Find a spark and send it down the wire", "Every little downbeat climbing higher", "All the city humming in your hands", "Bring it home and let the last chord stand"])]
    }
    private static var folkSong: SongArrangement {
        var song = SongArrangement.demo
        song.id = UUID(uuidString: "A1100000-0000-4000-8000-000000000003")!
        song.difficulty = .init(level: 3, name: "Folk groove", technique: "Down, down-up, up-down-up with a rest")
        return song
    }
    private static func make(id: Int, title: String, bpm: Double, level: Int, name: String, technique: String, chords: [String], pattern: String, splitChanges: Bool = false, lyrics: [String]) -> SongArrangement {
        var song = SongArrangement(title: title, artist: "Guitar Jim Originals", version: "Original song · level \(level)")
        song.id = UUID(uuidString: String(format: "A1100000-0000-4000-8000-%012d", id))!
        song.practiceBPM = bpm; song.sourceBPM = bpm
        song.tuningConfirmed = true; song.capoConfirmed = true; song.suggestionsConfirmed = true
        song.difficulty = .init(level: level, name: name, technique: technique)
        let patternEvents = pattern.enumerated().map { i, c in StrumEvent(beat: Double(i) / 2, stroke: c == "D" ? .down : c == "U" ? .up : .rest) }
        let bars = chords.enumerated().map { index, chord -> PracticeBar in
            var changes = [ChordEvent(beat: 0, shape: chord)]
            if splitChanges { changes.append(.init(beat: 2, shape: chords[(index + 1) % chords.count])) }
            return .init(chords: changes, strums: patternEvents, lyrics: [.init(beat: 0, text: lyrics[index])])
        }
        song.sections = [.init(name: "Verse", bars: Array(bars.prefix(4))), .init(name: "Chorus", bars: Array(bars.suffix(4)))]
        song.sources = [.init(field: "lyrics, chords, tempo, timing", status: .original, attribution: "Original practice song created for Guitar Jim. Down/up strokes are a visual guide; audio scoring judges harmony and attack timing.", permitsOfflineStorage: true)]
        return song
    }
}
