import SwiftUI

struct ChordDiagram: View {
    var chord: String
    // Low E to high E; -1 muted, 0 open, positive fret number.
    private let shapes = ["G": [3,2,0,0,0,3], "Em": [0,2,2,0,0,0], "C": [-1,3,2,0,1,0], "D": [-1,-1,0,2,3,2], "A": [-1,0,2,2,2,0], "Am": [-1,0,2,2,1,0], "E": [0,2,2,1,0,0], "Dm": [-1,-1,0,2,3,1]]
    var body: some View {
        Canvas { context, size in
            guard let frets = shapes[chord] else {
                context.draw(Text("Unscored chord").font(Theme.body(12)), at: CGPoint(x: size.width / 2, y: size.height / 2)); return
            }
            let x0: CGFloat = 18, y0: CGFloat = 30, dx = (size.width - 36) / 5, dy: CGFloat = 29
            for string in 0..<6 {
                let x = x0 + CGFloat(string) * dx
                var path = Path(); path.move(to: CGPoint(x: x, y: y0)); path.addLine(to: CGPoint(x: x, y: y0 + dy * 4))
                context.stroke(path, with: .color(Theme.line), lineWidth: 1)
                if frets[string] <= 0 {
                    context.draw(Text(frets[string] == 0 ? "○" : "×").font(Theme.body(14)).foregroundColor(Theme.muted), at: CGPoint(x: x, y: 12))
                } else {
                    let y = y0 + (CGFloat(frets[string]) - 0.5) * dy
                    context.fill(Path(ellipseIn: CGRect(x: x - 7, y: y - 7, width: 14, height: 14)), with: .color(Theme.accent))
                }
            }
            for fret in 0..<5 {
                var path = Path(); path.move(to: CGPoint(x: x0, y: y0 + CGFloat(fret) * dy)); path.addLine(to: CGPoint(x: size.width - x0, y: y0 + CGFloat(fret) * dy))
                context.stroke(path, with: .color(fret == 0 ? Theme.ink : Theme.line), lineWidth: fret == 0 ? 3 : 1)
            }
        }.accessibilityLabel("\(chord) chord diagram")
    }
}
