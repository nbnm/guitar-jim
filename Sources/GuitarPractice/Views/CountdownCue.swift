import SwiftUI

struct CountdownCue: View {
    var number: Int
    var pulse: Double
    var isGo: Bool
    var soundEnabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var color: Color { isGo ? Theme.green : Theme.accent }
    var body: some View {
        VStack(spacing: 12) {
            Text(isGo ? "YOU’RE IN" : "GET READY").font(Theme.strong(11)).tracking(3).foregroundStyle(color)
            ZStack {
                Circle().fill(Theme.stage.opacity(0.92)).frame(width: 158, height: 158)
                Circle().stroke(color.opacity(0.18), lineWidth: 2).frame(width: 158, height: 158)
                if !reduceMotion {
                    Circle().stroke(color.opacity(pulse * 0.8), lineWidth: 3).frame(width: 158, height: 158)
                        .scaleEffect(1 + (1 - pulse) * 0.22)
                }
                Text(isGo ? "GO!" : "\(number)").font(Theme.title(isGo ? 72 : 100)).foregroundStyle(isGo ? Theme.green : Theme.ink)
                    .scaleEffect(reduceMotion ? 1 : 1 + pulse * 0.09)
            }.frame(width: 195, height: 180)
            HStack(spacing: 10) {
                ForEach(0..<4) { index in
                    Circle().fill(isGo || index <= 4 - number ? color : Theme.line).frame(width: 7, height: 7)
                }
            }
            HStack(spacing: 7) {
                Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash").font(.system(size: 10))
                HStack(spacing: 3) {
                    ForEach(0..<5) { index in
                        Capsule().fill(color).frame(width: 3, height: 17)
                            .scaleEffect(x: 1, y: reduceMotion ? 0.6 : 0.2 + pulse * (index % 2 == 0 ? 0.8 : 0.5), anchor: .center)
                    }
                }.accessibilityHidden(true)
                Text(soundEnabled ? "FOLLOW THE CLICK" : "SOUND MUTED").font(Theme.strong(9)).tracking(1.5)
            }.foregroundStyle(color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isGo ? "Go" : "Count-in \(number). \(soundEnabled ? "Sound on" : "Sound muted").")
    }
}
