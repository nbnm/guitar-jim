import Foundation
import Testing
@testable import GuitarPracticeCore

struct StrummingTests {
    @Test func gridShowsRestsAndTheChordSoundingAtEachSubdivision() {
        let bar = PracticeBar(chords: [.init(beat: 0, shape: "G"), .init(beat: 2, shape: "D")],
                              strums: [.init(beat: 0, stroke: .down), .init(beat: 2.5, stroke: .up)])
        #expect(bar.strumGrid.map(\.chord) == ["G", "G", "G", "G", "D", "D", "D", "D"])
        #expect(bar.strumGrid.map(\.stroke) == [.down, .rest, .rest, .rest, .rest, .up, .rest, .rest])
        #expect(StrumSlot.activeIndex(at: 0.49) == 0)
        #expect(StrumSlot.activeIndex(at: 0.5) == 1)
        #expect(StrumSlot.activeIndex(at: 3.999) == 7)
        for beat in [-0.01, 4, .infinity, .nan] { #expect(StrumSlot.activeIndex(at: beat) == nil) }
    }
    @Test func applyingPatternPreservesHarmonyAndLyricsAndOnlyChangesSelectedBars() {
        let original = SongArrangement.demo
        var song = original
        song.applyStrummingPattern(.country, bars: 3..<5)
        for index in song.bars.indices {
            #expect(song.bars[index].id == original.bars[index].id)
            #expect(song.bars[index].chords == original.bars[index].chords)
            #expect(song.bars[index].lyrics == original.bars[index].lyrics)
            if (3..<5).contains(index) { #expect(StrummingPattern.matching(song.bars[index]) == .country) }
            else { #expect(song.bars[index].strums == original.bars[index].strums) }
        }
        #expect(song.readiness == .ready)
        let targets = RhythmMatcher.expectedAttacks(song: song, bars: 3..<4, bpm: 60)
        #expect(targets.map(\.time) == [0, 1, 1.5, 2, 3, 3.5])
        var custom = song.bars[3]
        custom.strums[0].stroke = .up
        #expect(StrummingPattern.matching(custom) == nil)
    }
    @Test func newPopularStudiesAreDistinctPlayableAndSourceLinked() throws {
        let studies = PopularSongCatalog.songs
        #expect(studies.count == 16)
        #expect(studies.filter { $0.artist == "Johnny Cash" }.count == 2)
        #expect(studies.filter { $0.artist == "Coldplay" }.count == 3)
        #expect(studies.filter { $0.artist == "Ed Sheeran" }.count == 3)
        #expect(studies.filter { $0.artist == "Imagine Dragons" }.count == 3)
        let all = PracticeCatalog.songs + [RequestedSongs.withOrWithoutYou] + studies
        #expect(Set(all.map(\.id)).count == 22)
        #expect(Set(studies.compactMap { StrummingPattern.matching($0.bars[0]) }).count >= 5)
        for song in studies {
            #expect(song.readiness == .ready)
            #expect(song.capo == 0)
            #expect(song.bars.count == 8)
            #expect(song.bars.allSatisfy { $0.lyrics.isEmpty })
            #expect(song.unsupportedChords.isEmpty)
            #expect(song.sourceBPM == nil)
            #expect(song.sources.contains { $0.url?.scheme == "https" })
            let decoded = try JSONDecoder().decode(SongArrangement.self, from: JSONEncoder().encode(song))
            #expect(decoded == song)
            let targets = RhythmMatcher.expectedAttacks(song: song, bars: 0..<8, bpm: song.practiceBPM)
            #expect(!targets.isEmpty)
            #expect(targets.allSatisfy { $0.time.isFinite && $0.time >= 0 })
        }
    }
}
