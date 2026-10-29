import Accelerate
import Foundation

public enum InputQuality: String, Codable, Sendable {
    case usable = "Clear signal", quiet = "Too quiet", clipping = "Clipping", noisy = "Noisy or mixed audio"
}

public struct HarmonicEstimate: Codable, Sendable {
    public var chord: String?
    public var strength: Double
    public var quality: InputQuality
    public var rmsDB: Double
    public var reason: String
    public var diagnosticChroma: [Double]?
    public init(chord: String?, strength: Double, quality: InputQuality, rmsDB: Double, reason: String) {
        self.chord = chord; self.strength = strength; self.quality = quality; self.rmsDB = rmsDB; self.reason = reason
    }
}

/// Audio-only baseline; never receives the expected chord. Confidence values are
/// spectral evidence scores, not calibrated probabilities. Validate on real guitars.
public enum HarmonicAnalyzer {
    public static func analyze(samples: [Float], sampleRate: Double) -> HarmonicEstimate {
        guard sampleRate.isFinite, sampleRate > 0, samples.count >= Int(sampleRate * 0.10), samples.allSatisfy(\.isFinite) else {
            return .init(chord: nil, strength: 0, quality: .quiet, rmsDB: -120, reason: "More audio needed")
        }
        let energy = samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(samples.count)
        let db = 10 * log10(max(energy, 1e-12))
        let clipped = samples.filter { abs($0) >= 0.99 }.count
        if clipped > max(1, samples.count / 500) {
            return .init(chord: nil, strength: 0, quality: .clipping, rmsDB: db, reason: "Lower microphone gain")
        }
        guard db > -57 else { return .init(chord: nil, strength: 0, quality: .quiet, rmsDB: db, reason: "Move closer or raise input gain") }
        let count = min(samples.count, Int(sampleRate * 0.35))
        let logSize = vDSP_Length(ceil(log2(Double(count))))
        let size = 1 << Int(logSize)
        guard let setup = vDSP_create_fftsetup(logSize, FFTRadix(kFFTRadix2)) else {
            return .init(chord: nil, strength: 0, quality: .noisy, rmsDB: db, reason: "Analysis unavailable")
        }
        defer { vDSP_destroy_fftsetup(setup) }
        var real = [Float](repeating: 0, count: size)
        var imaginary = [Float](repeating: 0, count: size)
        let mean = samples.prefix(count).reduce(0, +) / Float(count)
        for i in 0..<count {
            real[i] = (samples[i] - mean) * Float(0.5 - 0.5 * cos(2 * .pi * Double(i) / Double(count - 1)))
        }
        real.withUnsafeMutableBufferPointer { r in
            imaginary.withUnsafeMutableBufferPointer { im in
                var split = DSPSplitComplex(realp: r.baseAddress!, imagp: im.baseAddress!)
                vDSP_fft_zip(setup, &split, 1, logSize, FFTDirection(FFT_FORWARD))
            }
        }
        var power = [Double](repeating: 0, count: size / 2)
        for i in power.indices { power[i] = Double(real[i] * real[i] + imaginary[i] * imaginary[i]) }
        let low = max(2, Int(72 * Double(size) / sampleRate))
        let high = min(power.count - 2, Int(2_000 * Double(size) / sampleRate))
        guard high > low else { return .init(chord: nil, strength: 0, quality: .noisy, rmsDB: db, reason: "Unsupported input rate") }
        let band = power[low...high]
        let maximum = band.max() ?? 0
        let average = band.reduce(0, +) / Double(band.count)
        let flatness = exp(band.reduce(0) { $0 + log(max(1e-15, $1)) } / Double(band.count)) / max(average, 1e-15)
        guard flatness < 0.16 else {
            return .init(chord: nil, strength: 0, quality: .noisy, rmsDB: db, reason: "Background noise or mixed sound")
        }
        var peaks: [(frequency: Double, weight: Double)] = []
        for bin in low...high where power[bin] > maximum * 0.008 && power[bin] > power[bin - 1] && power[bin] >= power[bin + 1] {
            let a = log(max(power[bin - 1], 1e-15)), b = log(max(power[bin], 1e-15)), c = log(max(power[bin + 1], 1e-15))
            let offset = max(-0.5, min(0.5, 0.5 * (a - c) / (a - 2 * b + c)))
            peaks.append(((Double(bin) + offset) * sampleRate / Double(size), pow(power[bin], 0.36)))
        }
        var chroma = [Double](repeating: 0, count: 12)
        for (i, peak) in peaks.enumerated() {
            let midi = 69 + 12 * log2(peak.frequency / 440)
            guard abs(midi - midi.rounded()) < 0.38 else { continue }
            let pc = ((Int(midi.rounded()) % 12) + 12) % 12
            let harmonic = peaks.prefix(i).contains { lower in
                let ratio = peak.frequency / lower.frequency
                return ratio >= 1.9 && ratio <= 6.1 && abs(12 * log2(ratio / ratio.rounded())) < 0.25
            }
            chroma[pc] += peak.weight * (harmonic ? 0.22 : 1)
        }
        let sum = chroma.reduce(0, +)
        guard sum > 0 else { return .init(chord: nil, strength: 0, quality: .noisy, rmsDB: db, reason: "No stable harmony") }
        chroma = chroma.map { $0 / sum }
        let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
        var candidates: [(name: String, score: Double, weakest: Double)] = []
        for root in 0..<12 {
            for minor in [false, true] {
                let tones = [chroma[root], chroma[(root + (minor ? 3 : 4)) % 12], chroma[(root + 7) % 12]]
                candidates.append((names[root] + (minor ? "m" : ""), tones.reduce(0, +), tones.min() ?? 0))
            }
        }
        candidates.sort { $0.score > $1.score }
        let best = candidates[0], margin = best.score - candidates[1].score
        let confident = best.score >= 0.74 && margin >= 0.12 && best.weakest >= 0.075
        var estimate = HarmonicEstimate(chord: confident ? best.name : nil, strength: best.score, quality: .usable, rmsDB: db,
                                        reason: confident ? "Local harmonic estimate" : "Ambiguous harmony; no chord verdict")
        estimate.diagnosticChroma = chroma
        return estimate
    }
}

public struct OnsetDetector {
    private var envelope: Float = 0.0001
    private var noise: Float = 0.0003
    private var lastAttack: Double = -.infinity
    public init() {}
    public mutating func process(samples: UnsafeBufferPointer<Float>, sampleRate: Double, hostTime: Double) -> [Double] {
        var events: [Double] = []
        let hop = max(32, Int(sampleRate * 0.0027))
        for start in stride(from: 0, to: samples.count, by: hop) {
            let end = min(start + hop, samples.count)
            var energy: Float = 0
            for i in start..<end { energy += samples[i] * samples[i] }
            let rms = sqrt(energy / Float(end - start))
            let time = hostTime + Double(start) / sampleRate
            if rms < noise * 2 { noise = noise * 0.995 + rms * 0.005 }
            if rms > max(0.003, noise * 4, envelope * 2.5), time - lastAttack > 0.095 {
                events.append(time); lastAttack = time
            }
            envelope = max(0.0001, envelope * 0.91 + rms * 0.09)
        }
        return events
    }
}

public enum ChordVerdict: String, Codable, Sendable {
    case matches = "Matches", different = "Different chord", unclear = "Unclear audio", unsupported = "Unscored chord", unassigned = "Extra strum"
}
public struct ChordFeedback: Codable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var time: Double
    public var expectedShape: String
    public var heard: String?
    public var verdict: ChordVerdict
    public var evidence: Double
    public var reason: String
    public var detectedID: UUID?
    public static func judge(time: Double, shape: String, capo: Int, estimate: HarmonicEstimate) -> ChordFeedback {
        let concert = ChordVocabulary.concertName(shape: shape, capo: capo)
        let verdict: ChordVerdict = concert == nil ? .unsupported : estimate.chord == nil || estimate.quality != .usable ? .unclear : estimate.chord == concert ? .matches : .different
        return .init(time: time, expectedShape: shape, heard: estimate.chord, verdict: verdict, evidence: estimate.strength, reason: estimate.reason)
    }
    public static func forAttack(_ attack: DetectedAttack, estimate: HarmonicEstimate, expected: [ExpectedAttack], rhythm: RhythmSummary, capo: Int) -> ChordFeedback {
        // Compare to the assigned target, not the chord at the audible instant:
        // a slightly early attack can belong to the next chord change.
        guard let targetID = rhythm.results.first(where: { $0.detectedID == attack.id && $0.expectedID != nil })?.expectedID,
              let target = expected.first(where: { $0.id == targetID }) else {
            return .init(time: attack.time, expectedShape: "", heard: estimate.chord, verdict: .unassigned, evidence: estimate.strength, reason: "No expected attack assigned", detectedID: attack.id)
        }
        var feedback = judge(time: attack.time, shape: target.chord, capo: capo, estimate: estimate)
        feedback.detectedID = attack.id
        return feedback
    }
}
