import AVFoundation
import Foundation
import Testing
@testable import GuitarPractice
@testable import GuitarPracticeCore

@MainActor
struct ReviewRegressionTests {
    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("guitar-jim-review-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test func stopAndQuitJoinTheSameRecordingFinalization() async {
        let finalizer = RecordingFinalizer()
        let gate = AsyncStream<Void>.makeStream()
        var executions = 0
        var saved = false
        let firstStop = finalizer.begin {
            executions += 1
            for await _ in gate.stream { break }
            saved = true
        }
        let secondStop = finalizer.begin { executions += 100 }
        #expect(finalizer.isRunning)
        let release = Task {
            await Task.yield()
            gate.continuation.yield(())
            gate.continuation.finish()
        }
        await finalizer.wait()
        #expect(saved)
        await firstStop.value; await secondStop.value; await release.value
        #expect(executions == 1)
        #expect(!finalizer.isRunning)
    }

    @Test func unreadableBuiltInChartIsPreservedInsteadOfReseeded() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        _ = LocalStore(root: root)
        let id = RequestedSongs.withOrWithoutYou.id
        let path = root.appendingPathComponent("Arrangements/\(id).json")
        let damaged = Data("{ user edits awaiting repair".utf8)
        try damaged.write(to: path)
        for _ in 0..<2 {
            let reopened = LocalStore(root: root)
            #expect(reopened.error?.contains("preserved") == true)
            #expect(!reopened.songs.contains { $0.id == id })
            #expect(try Data(contentsOf: path) == damaged)
        }
    }

    @Test func earlyStrumKeepsItsChordEstimateUntilAssignmentSettles() throws {
        let targets = [ExpectedAttack(id: 0, time: 0, chord: "Em"), .init(id: 1, time: 0.75, chord: "G"), .init(id: 2, time: 1.5, chord: "C")]
        let attack = DetectedAttack(time: 0.58)
        let usable = [TimeRange(start: -1, end: 3)]
        let estimate = HarmonicEstimate(chord: "G", strength: 0.95, quality: .usable, rmsDB: -20, reason: "Fixture")
        var buffer = ChordFeedbackBuffer()
        buffer.record(estimate, for: attack)
        let awaiting = RhythmMatcher.evaluate(expected: targets, detected: [attack], usable: usable, through: 0.89)
        buffer.settle(expected: targets, detected: [attack], rhythm: awaiting, capo: 0)
        #expect(buffer.feedback.isEmpty)
        let settled = RhythmMatcher.evaluate(expected: targets, detected: [attack], usable: usable, through: 0.94)
        #expect(settled.count(.early) == 1)
        buffer.settle(expected: targets, detected: [attack], rhythm: settled, capo: 0)
        let feedback = try #require(buffer.feedback.first)
        #expect(feedback.expectedShape == "G" && feedback.verdict == .matches)
        #expect(feedback.detectedID == attack.id && feedback.time == 0.58)
        buffer.record(estimate, for: attack)
        buffer.settle(expected: targets, detected: [attack], rhythm: settled, capo: 0)
        #expect(buffer.feedback.count == 1 && buffer.feedback[0].id == feedback.id)
    }

    @Test func pausedAttemptReplayUsesItsActualDurationAndReadsLegacySessions() throws {
        var attempt = PracticeAttempt(startInRecording: 5, startBar: 0, endBar: 4, bpm: 80,
                                      expected: [], detected: [], summary: .init(results: [], expectedDuringUsableAudio: 0), recordedDuration: 3)
        #expect(attempt.replayDuration == 3)
        #expect(attempt.startInRecording + attempt.replayDuration == 8)
        let encoded = try JSONEncoder().encode(attempt)
        #expect(try JSONDecoder().decode(PracticeAttempt.self, from: encoded).replayDuration == 3)
        var old = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        old.removeValue(forKey: "recordedDuration")
        let legacy = try JSONDecoder().decode(PracticeAttempt.self, from: JSONSerialization.data(withJSONObject: old))
        #expect(legacy.replayDuration == 12)
        attempt.recordedDuration = 20
        #expect(attempt.replayDuration == 12)
    }

    @Test func storageUsageCountsTheActualStereoFileBytes() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalStore(root: root)
        var session = CaptureSession(arrangement: .demo, deviceUID: "fixture", deviceName: "Stereo fixture", calibrationOffset: nil)
        session.state = "saved"
        let directory = store.sessionDirectory(session.id)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 128))
        buffer.frameLength = 128
        for channel in 0..<2 { for frame in 0..<128 { buffer.floatChannelData![channel][frame] = 0.1 } }
        let path = directory.appendingPathComponent("stereo.caf")
        var file: AVAudioFile? = try AVAudioFile(forWriting: path, settings: format.settings)
        try file?.write(from: buffer); file = nil
        session.segments = [.init(filename: "stereo.caf", start: 0, duration: 128.0 / 48_000, sampleRate: 48_000, sampleCount: 128)]
        try store.updateSession(session)
        store.reloadSessions()
        let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
        let size = try #require(attributes[.size] as? NSNumber).int64Value
        #expect(size > 128 * 4)
        #expect(store.storageBytes == size)
        #expect(LocalStore(root: root).storageBytes == size)
        try store.deleteSession(session)
        #expect(store.storageBytes == 0)
    }

    @Test func movingChordChangesKeepsTheBeatGridOrderedAndUnique() {
        var bar = PracticeBar(chords: [.init(beat: 0, shape: "G"), .init(beat: 0.5, shape: "C"), .init(beat: 2, shape: "D")],
                              strums: StrummingPattern.steady.events, lyrics: [.init(beat: 0, text: "Original line")])
        let strums = bar.strums; let lyrics = bar.lyrics
        let moved = bar.moveChord(at: 1, to: 2.5)
        #expect(moved)
        #expect(bar.chords.map(\.beat) == [0, 2, 2.5])
        #expect(bar.chords.map(\.shape) == ["G", "D", "C"])
        let occupied = bar.moveChord(at: 2, to: 2)
        let firstChord = bar.moveChord(at: 0, to: 1)
        #expect(!occupied && !firstChord)
        #expect(bar.strums == strums && bar.lyrics == lyrics)
        #expect(bar.strumGrid[4].chord == "D" && bar.strumGrid[5].chord == "C")
    }
}
