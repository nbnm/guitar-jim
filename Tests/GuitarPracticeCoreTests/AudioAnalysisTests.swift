import Foundation
import Testing
@testable import GuitarPracticeCore

enum GuitarFixture {
    static let voicings = ["A": [45,52,57,61,64], "Am": [45,52,57,60,64], "C": [48,52,55,60,64], "D": [50,57,62,66], "Dm": [50,57,62,65], "E": [40,47,52,56,59,64], "Em": [40,47,52,55,59,64], "G": [43,47,50,55,59,67]]
    static func chord(_ name: String, capo: Int = 0, duration: Double = 0.30, rate: Double = 48_000) -> [Float] {
        notes(voicings[name]!.map { $0 + capo }, duration: duration, rate: rate)
    }
    static func notes(_ notes: [Int], duration: Double = 0.30, rate: Double = 48_000) -> [Float] {
        (0..<Int(duration * rate)).map { index in
            let time = Double(index) / rate
            var value = 0.0
            for (string, note) in notes.enumerated() {
                let t = time - Double(string) * 0.003
                guard t >= 0 else { continue }
                let frequency = 440 * pow(2, Double(note - 69) / 12)
                for harmonic in 1...5 {
                    value += 0.035 * exp(-t * (2.8 + Double(harmonic) * 0.4)) / pow(Double(harmonic), 1.2) * sin(2 * .pi * frequency * Double(harmonic) * t)
                }
            }
            return Float(value)
        }
    }
}

struct AudioAnalysisTests {
    @Test(arguments: SongArrangement.supportedChords)
    func recognizesSupportedVoicingsFromAudioOnly(chord: String) {
        let estimate = HarmonicAnalyzer.analyze(samples: Array(GuitarFixture.chord(chord).dropFirst(864)), sampleRate: 48_000)
        #expect(estimate.chord == chord, "\(chord): \(String(describing: estimate.chord)), score \(estimate.strength), \(estimate.reason)")
        #expect(estimate.quality == .usable)
    }
    @Test(arguments: ["C", "Am", "E", "Em"])
    func wrongChordCannotBecomeAMatchByUsingTheExpectedChord(chord: String) {
        let estimate = HarmonicAnalyzer.analyze(samples: GuitarFixture.chord(chord), sampleRate: 48_000)
        let expected = ["C": "Am", "Am": "C", "E": "Em", "Em": "E"][chord]!
        let feedback = ChordFeedback.judge(time: 0, shape: expected, capo: 0, estimate: estimate)
        #expect(feedback.verdict == .different)
    }
    @Test func capoIsComparedInConcertPitch() {
        let estimate = HarmonicAnalyzer.analyze(samples: GuitarFixture.chord("G", capo: 2), sampleRate: 48_000)
        #expect(estimate.chord == "A")
        #expect(ChordFeedback.judge(time: 0, shape: "G", capo: 2, estimate: estimate).verdict == .matches)
    }
    @Test func silenceClippingNoiseAndIncompleteHarmonyAbstain() {
        let silence = HarmonicAnalyzer.analyze(samples: [Float](repeating: 0, count: 14_400), sampleRate: 48_000)
        #expect(silence.chord == nil); #expect(silence.quality == .quiet)
        let clipping = HarmonicAnalyzer.analyze(samples: [Float](repeating: 1, count: 14_400), sampleRate: 48_000)
        #expect(clipping.chord == nil); #expect(clipping.quality == .clipping)
        var seed: UInt64 = 42
        let noise: [Float] = (0..<14_400).map { _ in
            seed = seed &* 6364136223846793005 &+ 1
            return Float(Double(seed >> 32) / Double(UInt32.max) - 0.5) * 0.2
        }
        let noisy = HarmonicAnalyzer.analyze(samples: noise, sampleRate: 48_000)
        #expect(noisy.chord == nil); #expect(noisy.quality == .noisy)
        let powerChord = HarmonicAnalyzer.analyze(samples: GuitarFixture.notes([40, 47, 52, 59]), sampleRate: 48_000)
        #expect(powerChord.chord == nil)
        let singleNote = HarmonicAnalyzer.analyze(samples: GuitarFixture.notes([52]), sampleRate: 48_000)
        #expect(singleNote.chord == nil)
    }
    @Test func groupedStrumsKeepAudioTimestampsAndDoNotRepeatOnSustain() {
        let rate = 48_000.0
        let times = [0.2, 0.7, 1.2]
        var audio = [Float](repeating: 0, count: Int(rate * 1.8))
        for time in times {
            let strum = GuitarFixture.chord("G", duration: 0.40)
            let offset = Int(time * rate)
            for i in strum.indices { audio[offset + i] += strum[i] }
        }
        let analyzer = LiveAudioAnalyzer()
        var onsets: [Double] = []; var estimates: [AnalyzedStrum] = []
        for offset in stride(from: 0, to: audio.count, by: 2048) {
            let chunk = Array(audio[offset..<min(audio.count, offset + 2048)])
            let result = chunk.withUnsafeBufferPointer { analyzer.process(samples: $0, sampleRate: rate, hostTime: 100 + Double(offset) / rate) }
            onsets += result.onsets; estimates += result.strums
        }
        #expect(onsets.count == times.count)
        for (heard, expected) in zip(onsets, times) { #expect(abs(heard - 100 - expected) < 0.025) }
        #expect(estimates.count == times.count)
        #expect(estimates.allSatisfy { $0.estimate.chord == "G" })
    }
    @Test func fiveSongsHaveDistinctPatternsAndValidatedTimelines() {
        let songs = PracticeCatalog.songs
        #expect(songs.count == 5)
        #expect(Set(songs.map(\.id)).count == 5)
        #expect(songs.compactMap(\.difficulty?.level) == [1, 2, 3, 4, 5])
        #expect(songs.allSatisfy { $0.readiness == .ready && $0.sources.allSatisfy(\.permitsOfflineStorage) })
        #expect(Set(songs.map { $0.bars[0].strums.map { "\($0.beat):\($0.stroke)" }.joined() }).count == 5)
        #expect(songs[4].bars.allSatisfy { $0.chords.count == 2 })
    }
    @Test func earlyStrumAtChordChangeIsComparedToItsAssignedTarget() {
        let expected = [ExpectedAttack(id: 0, time: 0, chord: "Em"), .init(id: 1, time: 0.5, chord: "G")]
        let attack = DetectedAttack(time: 0.37)
        let rhythm = RhythmMatcher.evaluate(expected: expected, detected: [attack], usable: [.init(start: -1, end: 2)], through: 1)
        let g = HarmonicEstimate(chord: "G", strength: 0.95, quality: .usable, rmsDB: -20, reason: "Fixture")
        let feedback = ChordFeedback.forAttack(attack, estimate: g, expected: expected, rhythm: rhythm, capo: 0)
        #expect(feedback.expectedShape == "G")
        #expect(feedback.verdict == .matches)
        #expect(rhythm.results.first(where: { $0.detectedID == attack.id })?.verdict == .early)
    }
    @Test func extraStrumsNeverCreateChordMatches() {
        let attack = DetectedAttack(time: 0.5)
        let g = HarmonicEstimate(chord: "G", strength: 0.95, quality: .usable, rmsDB: -20, reason: "Fixture")
        let feedback = ChordFeedback.forAttack(attack, estimate: g, expected: [], rhythm: .init(results: [], expectedDuringUsableAudio: 0), capo: 0)
        #expect(feedback.verdict == .unassigned)
    }
    @Test func requestedU2SongIsChordOnlyAndCapoMapsToTheReferenceKey() {
        let song = RequestedSongs.withOrWithoutYou
        #expect(song.title == "With or Without You")
        #expect(song.artist == "U2")
        #expect(song.bars.allSatisfy { $0.lyrics.isEmpty })
        #expect(song.bars.prefix(4).compactMap { ChordVocabulary.concertName(shape: $0.chords[0].shape, capo: song.capo) } == ["D", "A", "Bm", "G"])
        #expect(song.readiness == .needsReview)
        #expect(!song.capoConfirmed)
        #expect(!song.suggestionsConfirmed)
        #expect(song.sourceBPM == 110 && song.practiceBPM == 80)
    }
}
