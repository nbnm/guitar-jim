import Foundation

/// Short, authored practice studies. Chord references are linked; voicings,
/// transposition, bar spacing and strokes are deliberately simplified.
public enum PopularSongCatalog {
    public static var songs: [SongArrangement] {
        [
            make(7, "Ring of Fire", "Johnny Cash", bpm: 85, level: 2, pattern: .country,
                 timeline: single(["G", "C", "G", "G", "G", "D", "G", "G"]),
                 source: "https://www.jonmaclennan.com/blog/ring-of-fire-chords",
                 note: "Jon MacLennan identifies G, C and D and a country two-beat feel. This is an even eight-bar chord study; the record's quick changes and horn phrases are omitted."),
            make(8, "Hurt", "Johnny Cash", bpm: 65, level: 3, pattern: .steady,
                 timeline: (0..<4).flatMap { _ in [[chord("Am"), chord("C", at: 2), chord("D", at: 3)], [chord("Am")]] },
                 source: "https://www.jonmaclennan.com/blog/hurt-johnny-cash-guitar-lesson",
                 note: "Jon MacLennan's lesson includes Am, C and Dsus2. This intro-harmony study uses plain D and full downstrums instead of the picked riff. The chorus and its F voicing are not included."),
            make(9, "Yellow", "Coldplay", bpm: 85, level: 3, pattern: .allDown,
                 timeline: single(["G", "G", "D", "D", "C", "C", "G", "G"]),
                 source: "https://www.andyguitar.co.uk/videos/lesson-2-yellow-by-coldplay",
                 note: "Andy Guitar teaches a beginner version using G, C, D and Em with eighth-note downstrokes. This G–D–C verse-harmony study is transposed for no capo and uses even two-bar holds."),
            make(10, "The Scientist", "Coldplay", bpm: 70, level: 2, pattern: .halfTime,
                 timeline: (0..<2).flatMap { _ in [[chord("Em")], [chord("C")], [chord("G")], [chord("G"), chord("D", at: 2)]] },
                 source: "https://www.tusclasesdeguitarra.com/canciones?cancion=the-scientist",
                 note: "TCDG's transposed G-major lesson gives Em–C–G followed by G/D, half a bar each. This study uses that harmonic outline with an authored half-time strum, not the piano part."),
            make(11, "Viva la Vida", "Coldplay", bpm: 95, level: 4, pattern: .syncopated,
                 timeline: single(["C", "D", "G", "Em", "C", "D", "G", "Em"]),
                 source: "https://www.andyguitar.co.uk/videos/coldplay-viva-la-vida",
                 note: "Andy Guitar gives C–D–G–Em shapes with capo 1. This no-capo study sounds a semitone lower and uses a reusable syncopation exercise rather than the exact string-orchestra rhythm."),
            make(12, "Riptide", "Vance Joy", bpm: 90, level: 3, pattern: .folk,
                 timeline: (0..<4).flatMap { _ in [[chord("Am"), chord("G", at: 2)], [chord("C")]] },
                 source: "https://www.justinguitar.com/songs/vance-joy-riptide-chords-tabs-guitar-lesson-sg-151",
                 note: "JustinGuitar's Riptide lesson is the reference. This no-capo main-loop study uses Am and G for half a bar each, then C; its folk strum is an authored exercise. The bridge is omitted."),
            make(13, "Stick Season", "Noah Kahan", bpm: 95, level: 3, pattern: .pickups,
                 timeline: single(["G", "G", "D", "D", "Em", "Em", "C", "C"]),
                 source: "https://www.laurenbateman.com/stick-season-chords/",
                 note: "Lauren Bateman teaches G–D–Em–C shapes with capo 2. This no-capo study sounds a tone lower; eighth-note pickups replace the faster sixteenth-note and fingerpicked parts."),
            make(14, "Beautiful Things", "Benson Boone", bpm: 75, level: 2, pattern: .pickups,
                 timeline: single(["C", "G", "D", "D", "C", "G", "D", "Em"]),
                 source: "https://www.youtube.com/watch?v=N6sCiPydSDM",
                 note: "The beginner tutorial uses C, G, D and Em shapes with capo 3. This selected verse-harmony study is transposed down three semitones for no capo, with even bar spacing and a simplified strum."),
            make(15, "Birds of a Feather", "Billie Eilish", bpm: 90, level: 3, pattern: .alternating,
                 timeline: single(["G", "Em", "Am", "D", "G", "Em", "Am", "D"]),
                 source: "https://for3v3rfaithful.com/tutorials/birds-of-a-feather-guitar-lesson-by-billie-eilish",
                 note: "For3v3rfaithful lists D, Bm7, Em7 and A-based voicings. This study transposes the main loop to G–Em–Am–D, reduces seventh/slash voicings to triads and uses an authored eighth-note strum."),
            make(16, "A Bar Song (Tipsy)", "Shaboozey", bpm: 90, level: 4, pattern: .country,
                 timeline: (0..<2).flatMap { _ in [[chord("Em")], [chord("G")], [chord("C")], [chord("G"), chord("D", at: 2)]] },
                 source: "https://www.youtube.com/watch?v=DxXkhldaZo0",
                 note: "Easy 2 Play Music teaches Em, G, C and D shapes with capo 2. This no-capo study sounds a tone lower, omits moving bass notes and uses an authored country pulse with a G-to-D half-bar change."),
            make(17, "Photograph", "Ed Sheeran", bpm: 80, level: 2, pattern: .folk,
                 timeline: single(["G", "G", "D", "D", "Em", "Em", "C", "C"]),
                 source: "https://www.andyguitar.co.uk/videos/photograph-by-ed-sheeran",
                 note: "Andy Guitar teaches E, B, C#m and A. This selected chorus-harmony study transposes those chords to G, D, Em and C, with even two-bar holds and an authored folk strum. No capo or original recording key is required."),
            make(18, "Shape of You", "Ed Sheeran", bpm: 90, level: 4, pattern: .syncopated,
                 timeline: single(["Em", "Am", "C", "D", "Em", "Am", "C", "D"]),
                 source: "https://www.musicalfuturesonline.org/resources/playalong-shape-of-you-in-em/",
                 note: "Musical Futures teaches an easier E-minor version using Em, Am, C and D. This no-capo guitar study uses that harmonic outline with even one-bar holds and the reusable syncopated preset, not the exact marimba riff or percussion."),
            make(19, "Bad Habits", "Ed Sheeran", bpm: 95, level: 3, pattern: .alternating,
                 timeline: single(["Em", "G", "C", "D", "Em", "G", "C", "D"]),
                 source: "https://www.andyguitar.co.uk/videos/ed-sheeran-bad-habits",
                 note: "Andy Guitar's lesson teaches a five-chord version. This selected main-harmony study transposes Bm–D–G–A to Em–G–C–D and uses plain triads with alternating eighths. Seventh colors, the additional turnaround chord and percussive strumming details are omitted."),
            make(20, "Radioactive", "Imagine Dragons", bpm: 90, level: 3, pattern: .pickups,
                 timeline: single(["Am", "C", "G", "D", "Am", "C", "G", "D"]),
                 source: "https://www.andyguitar.co.uk/videos/imagine-dragons-radioactive",
                 note: "Andy Guitar's acoustic lesson uses Am, C, G and D with downstroke/eighth-note pickups. This study keeps standard tuning, no capo and even one-bar holds. It does not match the detuned live performance linked from the lesson."),
            make(21, "Demons", "Imagine Dragons", bpm: 75, level: 2, pattern: .halfTime,
                 timeline: single(["G", "D", "Em", "C", "G", "D", "Em", "C"]),
                 source: "https://www.supersimplepiano.com/how-to-play/demons-003145800937032986",
                 note: "Super Simple Piano's teaching version uses the C–G–Am–F harmonic outline in 4/4. This guitar study transposes that outline to G–D–Em–C and uses authored half-time downstrums, with no capo. Piano voicings, pickups and the recording's key are not reproduced."),
            make(22, "Thunder", "Imagine Dragons", bpm: 80, level: 1, pattern: .steady,
                 timeline: single(["G", "G", "C", "C", "G", "G", "C", "C"]),
                 source: "https://nailguitar.com/pdf/thunder.pdf",
                 note: "NailGuitar's verse chart uses C and F held for two bars each. This verse-only guitar study transposes them to G and C with four downstrokes per bar. The chorus, bridge and printed strumming rhythm are omitted.")
        ]
    }
    private static func chord(_ shape: String, at beat: Double = 0) -> ChordEvent { .init(beat: beat, shape: shape) }
    private static func single(_ shapes: [String]) -> [[ChordEvent]] { shapes.map { [chord($0)] } }
    private static func make(_ number: Int, _ title: String, _ artist: String, bpm: Double, level: Int,
                             pattern: StrummingPattern, timeline: [[ChordEvent]], source: String, note: String) -> SongArrangement {
        var song = SongArrangement(title: title, artist: artist, version: "Simplified no-capo study · chord-only · 8 bars")
        song.id = UUID(uuidString: String(format: "A1100000-0000-4000-8000-%012d", number))!
        song.practiceBPM = bpm
        song.tuningConfirmed = true; song.capoConfirmed = true; song.suggestionsConfirmed = true
        song.difficulty = .init(level: level, name: level <= 2 ? "Easy study" : level == 3 ? "Building rhythm" : "Rhythm challenge", technique: pattern.name)
        song.sections = [.init(name: "Practice loop", bars: timeline.map { .init(chords: $0, strums: pattern.events) })]
        song.sources = [
            .init(field: "song identity and chord reference", status: .confirmed, attribution: note, url: URL(string: source), permitsOfflineStorage: true),
            .init(field: "practice arrangement", status: .original, attribution: "Guitar Jim authored study: standard tuning, no capo, fixed practice tempo and simplified strumming. Not a complete transcription or recording play-along. Inspect and adapt the loop in the editor.", permitsOfflineStorage: true),
            .init(field: "lyrics and recording", status: .unavailable, attribution: "No lyrics, melody, tablature, artwork or recording are bundled.", permitsOfflineStorage: true)
        ]
        return song
    }
}
