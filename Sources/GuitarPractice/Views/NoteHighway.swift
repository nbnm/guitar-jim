import SwiftUI
import GuitarPracticeCore

struct NoteHighway: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let laneNames = ["G", "C", "D / Dm", "A / Am", "E / Em"]
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Theme.stage
                Canvas { context, size in drawHighway(context: &context, size: size) }
                    .accessibilityHidden(true)
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionLabel(text: "Play this chord")
                        Text(model.currentChord).font(Theme.title(64)).foregroundStyle(Theme.lanes[lane(for: model.currentChord)])
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 5) {
                        SectionLabel(text: "Up next")
                        Text(model.nextChord).font(Theme.title(30)).foregroundStyle(Theme.ink)
                    }
                }.padding(20)
                if model.transport == .counting || model.showGoCue {
                    CountdownCue(number: model.countIn, pulse: model.countdownPulse, isGo: model.showGoCue, soundEnabled: model.metronomeAudible)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(min(1, max(0.65, (geometry.size.height - 90) / 250)), anchor: .top)
                        .offset(y: max(68, min(100, geometry.size.height * 0.20)))
                }
                VStack {
                    Spacer()
                    HStack {
                        HStack(spacing: 6) {
                            ForEach(0..<4) { i in
                                Circle().fill(Int(model.beat.truncatingRemainder(dividingBy: 4)) == i && model.transport == .playing ? Theme.accent : Theme.line).frame(width: 5, height: 5)
                            }
                        }
                        Spacer()
                        Text("↓ DOWN   ↑ UP   • \(model.metronomeAudible ? "CLICK ON" : "CLICK MUTED")").font(Theme.strong(8)).tracking(1).foregroundStyle(Theme.muted)
                    }.padding(.horizontal, 20).padding(.bottom, 14)
                }
            }.clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Note highway. Play \(model.currentChord), next \(model.nextChord). Beat \(Int(model.beat.truncatingRemainder(dividingBy: 4)) + 1). \(model.showGoCue ? "Go" : model.transportLabel).")
        }
    }
    private func lane(for chord: String) -> Int {
        switch chord { case "G": return 0; case "C": return 1; case "D", "Dm": return 2; case "A", "Am": return 3; default: return 4 }
    }
    private func drawHighway(context: inout GraphicsContext, size: CGSize) {
        let top: CGFloat = 104, strike = size.height - 76
        let topWidth: CGFloat = size.width * 0.21, bottomWidth = size.width - 60
        let center = size.width / 2
        let currentBeat = reduceMotion ? floor(model.beat) : model.beat
        func width(_ depth: Double) -> CGFloat { topWidth + (bottomWidth - topWidth) * CGFloat(depth * depth) }
        func y(_ depth: Double) -> CGFloat { top + (strike - top) * CGFloat(depth * depth) }
        func x(_ depth: Double, _ position: CGFloat) -> CGFloat { center + (position - 0.5) * width(depth) }
        var road = Path()
        road.move(to: CGPoint(x: center - topWidth / 2, y: top))
        road.addLine(to: CGPoint(x: center + topWidth / 2, y: top))
        road.addLine(to: CGPoint(x: center + bottomWidth / 2, y: strike + 22))
        road.addLine(to: CGPoint(x: center - bottomWidth / 2, y: strike + 22)); road.closeSubpath()
        context.fill(road, with: .color(Theme.sidebar.opacity(0.70)))
        for lane in 0...5 {
            var line = Path(); line.move(to: CGPoint(x: x(0, CGFloat(lane) / 5), y: top))
            line.addLine(to: CGPoint(x: x(1, CGFloat(lane) / 5), y: strike + 22))
            context.stroke(line, with: .color(Theme.line.opacity(lane == 0 || lane == 5 ? 1 : 0.75)), lineWidth: 1)
        }
        for relative in 0...8 {
            let target = ceil(currentBeat) + Double(relative)
            let depth = 1 - (target - currentBeat) / 8
            guard depth >= 0, depth <= 1 else { continue }
            var line = Path(); line.move(to: CGPoint(x: x(depth, 0), y: y(depth))); line.addLine(to: CGPoint(x: x(depth, 1), y: y(depth)))
            let isBar = Int(target) % 4 == 0
            context.stroke(line, with: .color(isBar ? Theme.muted.opacity(0.40) : Theme.line), lineWidth: isBar ? 1.4 : 0.6)
        }
        let range = max(0, model.startBar)..<min(model.endBar, model.song.bars.count)
        for barIndex in range.reversed() {
            let bar = model.song.bars[barIndex]
            for strum in bar.strums.reversed() where strum.stroke != .rest {
                let eventBeat = Double(barIndex * 4) + strum.beat
                let delta = eventBeat - currentBeat
                guard delta >= -0.12, delta <= 8 else { continue }
                let depth = max(0, min(1, 1 - delta / 8))
                let chord = bar.chords.last(where: { $0.beat <= strum.beat })?.shape ?? "?"
                let lane = lane(for: chord)
                let color = Theme.lanes[lane]
                let noteWidth = max(10, width(depth) / 5 * 0.70)
                let noteHeight = max(5, 22 * CGFloat(depth))
                let rect = CGRect(x: x(depth, (CGFloat(lane) + 0.5) / 5) - noteWidth / 2, y: y(depth) - noteHeight / 2, width: noteWidth, height: noteHeight)
                context.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 3 * CGFloat(depth)), cornerRadius: 4), with: .color(color.opacity(0.20)))
                context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(color))
                if depth > 0.38 {
                    context.draw(Text(strum.stroke.symbol).font(.system(size: max(9, 15 * depth), weight: .heavy)).foregroundColor(Theme.stage), at: CGPoint(x: rect.midX, y: rect.midY))
                }
            }
        }
        var strikeLine = Path(); strikeLine.move(to: CGPoint(x: 24, y: strike)); strikeLine.addLine(to: CGPoint(x: size.width - 24, y: strike))
        context.stroke(strikeLine, with: .color(Theme.ink.opacity(0.8)), lineWidth: 1.5)
        for lane in 0..<5 {
            let centerX = x(1, (CGFloat(lane) + 0.5) / 5)
            let color = Theme.lanes[lane]
            let active = lane == self.lane(for: model.currentChord)
            let receptor = CGRect(x: centerX - 21, y: strike - 10, width: 42, height: 20)
            context.stroke(Path(ellipseIn: receptor), with: .color(color.opacity(active ? 1 : 0.6)), lineWidth: active ? 2.5 : 1)
            context.draw(Text(laneNames[lane]).font(Theme.strong(9)).foregroundColor(color), at: CGPoint(x: centerX, y: strike + 30))
        }
        context.draw(Text("HIT HERE").font(Theme.strong(8)).foregroundColor(Theme.muted), at: CGPoint(x: size.width - 35, y: strike - 18))
    }
}
