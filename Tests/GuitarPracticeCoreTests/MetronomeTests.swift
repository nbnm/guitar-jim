import Foundation
import Testing
@testable import GuitarPracticeCore

struct MetronomeTests {
    @Test func countdownIncludesFourBeepsThenGoAndBarAccents() {
        let schedule = MetronomeSchedule(bpm: 120, practiceBeats: 8)
        #expect(schedule.events.prefix(4).allSatisfy { $0.voice == .countIn })
        #expect(schedule.events[4].voice == .go)
        #expect(schedule.events[5].voice == .beat)
        #expect(schedule.events[8].voice == .downbeat)
        #expect(schedule.events.count == 12)
        #expect(schedule.songStart == 2)
        for (time, number) in [(0.0, 4), (0.5, 3), (1.0, 2), (1.5, 1)] {
            let cue = schedule.countdown(at: time)
            #expect(cue.number == number && cue.pulse == 1 && !cue.isGo)
        }
        #expect(schedule.countdown(at: 2).isGo)
        #expect(!schedule.countdown(at: 2.5).isGo)
        #expect(schedule.countdown(at: -0.15).number == 4)
    }
    @Test func sampleRoundingDoesNotAccumulateDrift() {
        let schedule = MetronomeSchedule(bpm: 137, practiceBeats: 2048)
        for rate in [44_100.0, 48_000.0] {
            for event in schedule.events {
                let renderedTime = Double(event.sampleTime(at: rate)) / rate
                #expect(abs(renderedTime - Double(event.index) * 60 / 137) <= 0.5 / rate + 1e-10)
            }
        }
    }
    @Test func clicksAreAudibleBoundedAndDistinct() {
        for voice in ClickVoice.allCases {
            let samples = ClickSynthesizer.samples(voice: voice, sampleRate: 48_000)
            #expect(!samples.isEmpty && samples.allSatisfy(\.isFinite))
            let peak = samples.map { abs($0) }.max() ?? 0
            #expect(peak > 0.2 && peak < 0.8)
            #expect(abs(samples.first ?? 1) < 0.001)
            #expect(abs(samples.last ?? 1) < 0.001)
        }
        #expect(ClickSynthesizer.samples(voice: .go, sampleRate: 48_000).count > ClickSynthesizer.samples(voice: .countIn, sampleRate: 48_000).count)
    }
}
