import AVFoundation
import Foundation
import GuitarPracticeCore

// Local diagnostics only. No playback, transcription, networking or file changes.
guard CommandLine.arguments.count >= 2 else {
    print("Usage: swift run GuitarJimAudioCheck <session-directory> [--details]")
    exit(1)
}
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let session = try JSONDecoder().decode(CaptureSession.self, from: Data(contentsOf: directory.appendingPathComponent("session.json")))
let analyzer = LiveAudioAnalyzer()
let reference = session.segments.first?.firstSampleHostTime ?? 0
var results: [AnalyzedStrum] = []
var onsets: [Double] = []
for segment in session.segments {
    let file = try AVAudioFile(forReading: directory.appendingPathComponent(segment.filename))
    let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 2048)!
    while file.framePosition < file.length {
        let position = file.framePosition
        try file.read(into: buffer)
        let channels = buffer.floatChannelData!
        let count = Int(buffer.frameLength)
        let selected = (0..<Int(buffer.format.channelCount)).max { a, b in
            (0..<count).reduce(Float(0)) { $0 + channels[a][$1] * channels[a][$1] } < (0..<count).reduce(Float(0)) { $0 + channels[b][$1] * channels[b][$1] }
        } ?? 0
        let host = (segment.firstSampleHostTime ?? reference + segment.start) + Double(position) / file.processingFormat.sampleRate
        let analysis = analyzer.process(samples: UnsafeBufferPointer(start: channels[selected], count: count), sampleRate: file.processingFormat.sampleRate, hostTime: host)
        results += analysis.strums; onsets += analysis.onsets
    }
}
var rows: [[String: Any]] = []
for result in results {
    var row: [String: Any] = ["time": (result.onsetHostTime - reference) * 1000 / 1000, "chord": result.estimate.chord ?? "unclear", "evidence": result.estimate.strength, "quality": result.estimate.quality.rawValue, "rmsDBFS": result.estimate.rmsDB]
    if CommandLine.arguments.contains("--details"), let chroma = result.estimate.diagnosticChroma {
        let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
        row["chroma"] = Dictionary(uniqueKeysWithValues: zip(names, chroma))
        var ranks: [(String, Double)] = []
        for root in 0..<12 { for third in [3,4] { ranks.append((names[root] + (third == 3 ? "m" : ""), chroma[root] + chroma[(root + third) % 12] + chroma[(root + 7) % 12])) } }
        row["topCandidates"] = ranks.sorted { $0.1 > $1.1 }.prefix(3).map { ["name": $0.0, "mass": $0.1] as [String: Any] }
    }
    rows.append(row)
}
let summary: [String: Any] = ["duration": session.duration, "onsets": onsets.count, "analyzedStrums": results.count, "judgedChords": results.filter { $0.estimate.chord != nil }.count, "estimates": rows]
print(String(data: try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
