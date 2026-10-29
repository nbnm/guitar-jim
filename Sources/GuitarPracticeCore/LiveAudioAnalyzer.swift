import Foundation

public struct AnalyzedStrum: Sendable {
    public var onsetHostTime: Double
    public var estimate: HarmonicEstimate
}

/// Runs exclusively on the recording worker. Audio timestamps survive the delayed
/// harmonic window. Each onset produces at most one harmonic result.
public final class LiveAudioAnalyzer {
    private var detector = OnsetDetector()
    private var history: [Float] = []
    private var historyHost: Double?
    private var pending: [Double] = []
    public init() { history.reserveCapacity(96_000) }
    public func process(samples: UnsafeBufferPointer<Float>, sampleRate: Double, hostTime: Double) -> (onsets: [Double], strums: [AnalyzedStrum]) {
        if historyHost == nil { historyHost = hostTime }
        let onsets = detector.process(samples: samples, sampleRate: sampleRate, hostTime: hostTime)
        pending += onsets
        history.append(contentsOf: samples)
        let endHost = hostTime + Double(samples.count) / sampleRate
        var results: [AnalyzedStrum] = []
        while let onset = pending.first, endHost - onset >= 0.30 {
            let nextOnset = pending.dropFirst().first
            let end = min(onset + 0.27, nextOnset.map { $0 - 0.008 } ?? .infinity)
            let startIndex = max(0, Int((onset + 0.018 - historyHost!) * sampleRate))
            let endIndex = min(history.count, Int((end - historyHost!) * sampleRate))
            if endIndex > startIndex {
                let estimate = HarmonicAnalyzer.analyze(samples: Array(history[startIndex..<endIndex]), sampleRate: sampleRate)
                results.append(.init(onsetHostTime: onset, estimate: estimate))
            }
            pending.removeFirst()
        }
        let keepFrom = min(pending.first ?? endHost, endHost - 0.7) - 0.02
        let discard = max(0, min(history.count, Int((keepFrom - historyHost!) * sampleRate)))
        if discard > 0 { history.removeFirst(discard); historyHost! += Double(discard) / sampleRate }
        return (onsets, results)
    }
}
