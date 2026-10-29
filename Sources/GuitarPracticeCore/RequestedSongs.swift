import Foundation

public enum RequestedSongs {
    /// A short, editable chord-loop exercise, not a transcription of the recording.
    /// Stores factual metadata and our practice pattern, with no third-party lyrics,
    /// audio, tablature, melody or full-song timing.
    public static var withOrWithoutYou: SongArrangement {
        var song = SongArrangement(title: "With or Without You", artist: "U2", version: "Beginner chord loop · capo 7 · chord-only")
        song.id = UUID(uuidString: "A1100000-0000-4000-8000-000000000006")!
        song.capo = 7; song.capoConfirmed = false
        song.tuningConfirmed = true
        song.sourceBPM = 110; song.practiceBPM = 80
        song.difficulty = .init(level: 2, name: "Beginner arrangement", technique: "G–D–Em–C shapes · capo 7 sounds D–A–Bm–G")
        let shapes = ["G", "D", "Em", "C", "G", "D", "Em", "C"]
        song.sections = [.init(name: "Chord loop", bars: shapes.map { .init(chords: [.init(beat: 0, shape: $0)], strums: ChartImporter.quarterNotes) })]
        song.sources = [
            .init(field: "title and artist", status: .confirmed, attribution: "Song identity from U2's official site. Metadata and source link only.", url: URL(string: "https://www.u2.com/products/with-or-without-you"), permitsOfflineStorage: true),
            .init(field: "chord progression", status: .confirmed, attribution: "Andy Guitar's lesson identifies a repeating D–A–Bm–G progression, one bar per chord. This exercise uses G–D–Em–C shapes with capo 7.", url: URL(string: "https://www.andyguitar.co.uk/videos/u2-with-or-without-you"), permitsOfflineStorage: true),
            .init(field: "reference tempo", status: .confirmed, attribution: "Hooktheory's community analysis lists 110 BPM for the chorus and 111 for the verse. The fixed 80 BPM practice tempo is chosen separately.", url: URL(string: "https://www.hooktheory.com/theorytab/view/u2/with-or-without-you"), permitsOfflineStorage: true),
            .init(field: "strumming, capo and eight-bar practice loop", status: .suggested, attribution: "Guitar Jim beginner exercise. Confirm your physical capo and review this suggested pattern. This is not the original recording's complete arrangement.", permitsOfflineStorage: true),
            .init(field: "lyrics", status: .unavailable, attribution: "Licensed lyrics are not included. Add permitted user-supplied lyrics in the editor if available.", permitsOfflineStorage: true)
        ]
        return song
    }
}
