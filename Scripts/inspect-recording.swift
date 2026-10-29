// swift Scripts/inspect-recording.swift /path/to/session-directory
// Reports file integrity and signal levels; never plays or uploads audio.
import AVFoundation
import Foundation

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let json = try JSONSerialization.jsonObject(with: Data(contentsOf: directory.appendingPathComponent("session.json"))) as! [String: Any]
let segments = json["segments"] as? [[String: Any]] ?? []
var frames: Int64 = 0
var peak: Float = 0
var energy = 0.0
var sampleCount: Int64 = 0
var rates = Set<Double>()
var channelCounts = Set<UInt32>()
var valid = true
var previousEnd: Double?
var maximumHostGap = 0.0
for segment in segments {
    let file = try AVAudioFile(forReading: directory.appendingPathComponent(segment["filename"] as! String))
    rates.insert(file.processingFormat.sampleRate); channelCounts.insert(file.processingFormat.channelCount)
    if file.length != (segment["sampleCount"] as? NSNumber)?.int64Value { valid = false }
    frames += file.length
    if let host = segment["firstSampleHostTime"] as? Double, let duration = segment["duration"] as? Double {
        if let previousEnd { maximumHostGap = max(maximumHostGap, abs(host - previousEnd)) }
        previousEnd = host + duration
    }
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 8192)!
    while file.framePosition < file.length {
        try file.read(into: buffer)
        for channel in 0..<Int(buffer.format.channelCount) {
            let samples = buffer.floatChannelData![channel]
            for i in 0..<Int(buffer.frameLength) {
                peak = max(peak, abs(samples[i])); energy += Double(samples[i] * samples[i])
            }
        }
        sampleCount += Int64(buffer.frameLength) * Int64(buffer.format.channelCount)
    }
}
let result: [String: Any] = ["state": json["state"] ?? "unknown", "device": json["deviceName"] ?? "unknown", "finalizedChunks": segments.count, "frames": frames, "sampleRates": rates.sorted(), "channels": channelCounts.sorted(), "manifestFrameCountsMatch": valid, "maximumChunkHostGapMs": maximumHostGap * 1000, "peak": Double(peak), "rmsDBFS": 10 * log10(max(1e-12, energy / Double(max(1, sampleCount)))), "waveformPoints": (json["waveform"] as? [Double])?.count ?? 0]
print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
