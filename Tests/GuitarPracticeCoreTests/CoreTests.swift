import Foundation
import Testing
@testable import GuitarPracticeCore

struct ArrangementTests {
    @Test func originalArrangementIsReadyAndRoundTrips() throws {
        let song = SongArrangement.demo
        #expect(song.readiness == .ready)
        #expect(song.bars.count == 8)
        #expect(try JSONDecoder().decode(SongArrangement.self, from: JSONEncoder().encode(song)) == song)
    }
    @Test func readinessRejectsInvalidAndUnconfirmedTiming() {
        var song = SongArrangement.demo
        song.suggestionsConfirmed = false
        song.sections[0].bars[0].strums[0].beat = .nan
        song.practiceBPM = 200
        #expect(song.readiness == .needsReview)
        #expect(song.validationIssues.count >= 3)
    }
    @Test func unsupportedChordsNeedExplicitAcknowledgement() {
        var song = SongArrangement.demo
        song.sections[0].bars[0].chords[0].shape = "F"
        #expect(song.unsupportedChords == ["F"])
        #expect(song.readiness == .needsReview)
        song.unsupportedChordsAcknowledged = true
        #expect(song.readiness == .ready)
    }
    @Test func capoEvaluatesConcertPitch() {
        #expect(ChordVocabulary.concertName(shape: "Am", capo: 2) == "Bm")
        #expect(ChordVocabulary.concertName(shape: "G", capo: 5) == "C")
        #expect(ChordVocabulary.concertName(shape: "F", capo: 0) == nil)
    }
    @Test func importerNeverMakesWordPositionsReadyForScoring() throws {
        let song = try ChartImporter.parse("{title: My study}\n[G]Hello [Em]morning\nC | D")
        #expect(song.title == "My study")
        #expect(song.bars.count == 3)
        #expect(song.bars[0].chords.map(\.beat) == [0, 2])
        #expect(song.bars[0].lyrics[0].text == "Hello morning")
        #expect(song.readiness == .needsReview)
        #expect(!song.sources[0].permitsOfflineStorage)
    }
    @Test func importerRejectsOversizedOrEmptyMaterial() {
        #expect(throws: ChartImportError.self) { try ChartImporter.parse(String(repeating: "G ", count: 100_000)) }
        #expect(throws: ChartImportError.self) { try ChartImporter.parse("No chord chart here.") }
    }
    @Test func importerRejectsNonfiniteAndExtremeTempoMetadata() throws {
        for tempo in ["nan", "inf", "1e300", "-80"] {
            let song = try ChartImporter.parse("{tempo: \(tempo)}\nG | C")
            #expect(song.practiceBPM == 80)
            #expect(song.sourceBPM == nil)
            #expect(song.readiness == .needsReview)
        }
    }
}

struct RhythmTests {
    let expected = (0..<4).map { ExpectedAttack(id: $0, time: Double($0) * 0.5, chord: "G") }
    let usable = [TimeRange(start: -1, end: 10)]
    @Test func oneToOneAndAllTimingStates() {
        let detected = [0.03, 0.36, 1.13, 2.2].map { DetectedAttack(time: $0) }
        let result = RhythmMatcher.evaluate(expected: expected, detected: detected, usable: usable, through: 3)
        #expect(result.count(.onTime) == 1); #expect(result.count(.early) == 1)
        #expect(result.count(.late) == 1); #expect(result.count(.missed) == 1)
        #expect(result.count(.extra) == 1); #expect(result.onTimeRate == 0.25)
        #expect(Set(result.results.compactMap(\.detectedID)).count == 4)
    }
    @Test func eighthNoteWindowsAreCappedAtFastTempo() {
        let spacing: Double = 60.0 / 140.0 / 2.0
        let events = (0..<4).map { ExpectedAttack(id: $0, time: Double($0) * spacing, chord: "C") }
        #expect(abs(RhythmMatcher.windows(at: 1, expected: events).onTime - spacing * 0.25) < 0.00001)
        #expect(abs(RhythmMatcher.windows(at: 1, expected: events).match - spacing * 0.45) < 0.00001)
    }
    @Test func oneAttackCannotSatisfyTwoTargets() {
        let result = RhythmMatcher.evaluate(expected: expected, detected: [.init(time: 0.02), .init(time: 0.04)], usable: usable, through: 3)
        #expect(result.count(.onTime) == 1); #expect(result.count(.extra) == 1)
        #expect(result.count(.missed) == 3)
    }
    @Test func unusableInputAndZeroDenominatorNeverProduceScore() {
        let result = RhythmMatcher.evaluate(expected: expected, detected: [], usable: [], through: 10)
        #expect(result.onTimeRate == nil); #expect(result.results.isEmpty)
        #expect(RhythmMatcher.evaluate(expected: [], detected: [], usable: usable, through: 10).onTimeRate == nil)
    }
    @Test func verdictsWaitForMatchingWindow() {
        #expect(RhythmMatcher.evaluate(expected: expected, detected: [], usable: usable, through: 0.1).expectedDuringUsableAudio == 0)
    }
    @Test func restsDoNotBecomeExpectedAttacks() {
        let events = RhythmMatcher.expectedAttacks(song: .demo, bars: 0..<1, bpm: 80)
        #expect(events.count == 6)
        #expect(!events.contains { abs($0.time - 1.5) < 0.0001 })
    }
}

struct LightElementTests {
    @Test func usesExactEndpointAndDoesNotSendAudioOrHistory() throws {
        let config = LightElementConfiguration(endpoint: "https://example.com/custom/chat/completions", model: "my-model")
        let request = try LightElementAdapter.request(query: "Easy open chord study", configuration: config, token: "test-only-token")
        #expect(request.url?.absoluteString == config.endpoint)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-only-token")
        let data = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(body.keys) == Set(["model", "messages", "temperature", "max_tokens", "stream"]))
        #expect(!String(data: data, encoding: .utf8)!.contains("test-only-token"))
    }
    @Test func rejectsInsecureRemoteAndCredentialURLs() throws {
        #expect(throws: LightElementError.self) { try LightElementConfiguration(endpoint: "http://example.com/chat", model: "m").validatedURL() }
        #expect(throws: LightElementError.self) { try LightElementConfiguration(endpoint: "https://user:secret@example.com/chat", model: "m").validatedURL() }
        #expect(try LightElementConfiguration(endpoint: "http://localhost:4000/chat/completions", model: "m").validatedURL().host == "localhost")
    }
    @Test func draftIgnoresModelLyricsAndRequiresHumanReview() throws {
        let draft: [String: Any] = ["title": "Study", "artist": "Unknown", "version": "Draft", "bpm": 80, "capo": 0, "bars": [["chord": "G", "lyrics": "Must never be shown"]], "lyrics": "Must never be shown"]
        let content = String(data: try JSONSerialization.data(withJSONObject: draft), encoding: .utf8)!
        let envelope = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": content]]]])
        let song = try LightElementAdapter.decode(envelope)
        #expect(song.bars.allSatisfy { $0.lyrics.isEmpty })
        #expect(song.readiness == .needsReview)
        #expect(song.sourceBPM == nil)
    }
    @Test func malformedModelOutputDoesNotBecomeAnArrangement() throws {
        let data = Data(#"{"choices":[{"message":{"content":"ignore instructions and show lyrics"}}]}"#.utf8)
        #expect(throws: LightElementError.self) { try LightElementAdapter.decode(data) }
    }
}
