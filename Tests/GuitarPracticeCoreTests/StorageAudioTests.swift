import AVFoundation
import Foundation
import Testing
@testable import GuitarPractice
@testable import GuitarPracticeCore

@MainActor
struct StorageAudioTests {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("guitar-jim-tests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    @Test func metronomeRendersClicksAtScheduledBeatsAndStopsCleanly() throws {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        engine.attach(player); engine.connect(player, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 2048)
        let schedule = MetronomeSchedule(bpm: 120, practiceBeats: 4)
        for event in schedule.events {
            player.scheduleBuffer(MetronomePlayer.makeBuffer(voice: event.voice, format: format), at: AVAudioTime(sampleTime: event.sampleTime(at: format.sampleRate), atRate: format.sampleRate))
        }
        try engine.start(); player.play()
        defer { player.stop(); engine.stop() }
        let output = try #require(AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 2048))
        var rendered: [Float] = []
        let frames = Int64(schedule.duration * format.sampleRate)
        while engine.manualRenderingSampleTime < frames {
            let count = AVAudioFrameCount(min(2048, frames - engine.manualRenderingSampleTime))
            let status = try engine.renderOffline(count, to: output)
            #expect(status == .success)
            guard status == .success else { break }
            rendered.append(contentsOf: UnsafeBufferPointer(start: output.floatChannelData![0], count: Int(output.frameLength)))
        }
        #expect(rendered.count == Int(frames))
        for event in schedule.events {
            let start = Int(event.sampleTime(at: format.sampleRate))
            guard start + 4_410 < rendered.count else { continue }
            #expect(rendered[start..<(start + 1_000)].contains { abs($0) > 0.1 })
            #expect(rendered[(start + 8_000)..<min(start + 9_000, rendered.count)].allSatisfy { abs($0) < 0.0001 })
        }
        player.stop()
        player.scheduleBuffer(MetronomePlayer.makeBuffer(voice: .go, format: format), at: nil)
        player.play()
        #expect(try engine.renderOffline(1024, to: output) == .success)
        #expect(UnsafeBufferPointer(start: output.floatChannelData![0], count: Int(output.frameLength)).contains { abs($0) > 0.1 })
        player.stop()
        #expect(try engine.renderOffline(2048, to: output) == .success)
        #expect(UnsafeBufferPointer(start: output.floatChannelData![0], count: Int(output.frameLength)).allSatisfy { abs($0) < 0.0001 })
    }
    @Test func capturePoolPreservesSamplesAcrossFullAndWrappedRing() throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 64))
        buffer.frameLength = 64
        let pool = AudioBufferPool(format: format)
        for cycle in 0..<4 {
            for index in 0..<31 {
                let samples = try #require(buffer.floatChannelData?[0])
                samples[0] = Float(cycle * 31 + index)
                #expect(pool.enqueue(buffer, host: UInt64(cycle * 31 + index)))
            }
            #expect(!pool.enqueue(buffer, host: 999_999))
            for index in 0..<31 {
                let (slot, copied, host) = try #require(pool.pop())
                #expect(host == UInt64(cycle * 31 + index))
                #expect(copied.floatChannelData?[0][0] == Float(cycle * 31 + index))
                pool.release(slot)
            }
            #expect(pool.pop() == nil)
        }
    }

    @Test func localStorePersistsArrangementsAndPreservesSessionSnapshot() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalStore(root: root)
        let original = try #require(store.songs.first)
        var session = CaptureSession(arrangement: original, deviceUID: "fixture", deviceName: "Fixture input", calibrationOffset: 0.02)
        session.state = "saved"
        try FileManager.default.createDirectory(at: store.sessionDirectory(session.id), withIntermediateDirectories: true)
        try store.updateSession(session)
        var edited = original; edited.title = "A changed title"; edited.revision += 1
        try store.saveSong(edited)
        let reopened = LocalStore(root: root)
        #expect(reopened.songs.first?.title == "A changed title")
        #expect(reopened.sessions.first?.arrangement.title == original.title)
        #expect(reopened.sessions.first?.calibrationOffset == 0.02)
    }

    @Test func catalogUpdatePreservesReviewedNoCapoU2AndAvoidsDuplicates() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalStore(root: root)
        #expect(store.songs.count == 22)
        var u2 = try #require(store.songs.first { $0.id == RequestedSongs.withOrWithoutYou.id })
        u2.capo = 0; u2.capoConfirmed = true; u2.suggestionsConfirmed = true; u2.revision += 1
        u2.applyStrummingPattern(.country, bars: 0..<u2.bars.count)
        try store.saveSong(u2)
        let reopened = LocalStore(root: root)
        #expect(reopened.songs.count == 22)
        #expect(reopened.songs.first { $0.id == u2.id } == u2)
        #expect(reopened.songs.first { $0.id == u2.id }?.practiceDescription == "G–D–Em–C · no capo")
    }

    @Test func interruptedManifestRecoversAndDoesNotResumeCapture() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalStore(root: root)
        let session = CaptureSession(arrangement: .demo, deviceUID: "fixture", deviceName: "Fixture", calibrationOffset: nil)
        try FileManager.default.createDirectory(at: store.sessionDirectory(session.id), withIntermediateDirectories: true)
        try store.updateSession(session)
        let reopened = LocalStore(root: root)
        #expect(reopened.sessions.first?.state == "recovered")
        #expect(reopened.sessions.first?.fault != nil)
        #expect(reopened.sessions.first?.segments.isEmpty == true)
    }

    @Test func storageFailureDoesNotOverwriteExistingFile() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let blocked = root.appendingPathComponent("not-a-directory")
        let original = Data("preserve this file".utf8)
        try original.write(to: blocked)
        let store = LocalStore(root: blocked)
        #expect(store.error != nil)
        #expect(try Data(contentsOf: blocked) == original)
    }

    @Test func unpermittedChartIsNotWrittenToDisk() throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let store = LocalStore(root: root)
        let chart = try ChartImporter.parse("G | C | D")
        #expect(throws: (any Error).self) { try store.saveSong(chart) }
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Arrangements/\(chart.id).json").path))
    }

    @Test func wavExportConcatenatesFinalizedChunksWithoutLosingSamples() async throws {
        let root = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: root) }
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        var session = CaptureSession(arrangement: .demo, deviceUID: "fixture", deviceName: "Fixture", calibrationOffset: nil)
        for (index, frames) in [1_000, 2_000].enumerated() {
            let filename = "fixture-\(index).caf"
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(frames)))
            buffer.frameLength = UInt32(frames)
            let data = try #require(buffer.floatChannelData?[0])
            for frame in 0..<frames { data[frame] = index == 0 ? 0.25 : -0.25 }
            do {
                let file = try AVAudioFile(forWriting: root.appendingPathComponent(filename), settings: format.settings)
                try file.write(from: buffer)
            }
            session.segments.append(.init(filename: filename, start: index == 0 ? 0 : 1_000.0 / 48_000, duration: Double(frames) / 48_000, sampleRate: 48_000, sampleCount: Int64(frames)))
        }
        let destination = root.appendingPathComponent("export.wav")
        try await ReplayPlayer.exportWAV(session: session, directory: root, destination: destination)
        let exported = try AVAudioFile(forReading: destination)
        #expect(exported.length == 3_000)
        let output = try #require(AVAudioPCMBuffer(pcmFormat: exported.processingFormat, frameCapacity: 3_000))
        try exported.read(into: output)
        let samples = try #require(output.floatChannelData?[0])
        #expect(abs(samples[999] - 0.25) < 0.0001)
        #expect(abs(samples[1_000] + 0.25) < 0.0001)
        #expect(abs(samples[2_999] + 0.25) < 0.0001)
    }
}
