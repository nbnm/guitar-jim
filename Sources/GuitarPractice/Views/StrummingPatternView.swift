import SwiftUI
import GuitarPracticeCore

struct StrummingPatternView: View {
    var bar: PracticeBar
    var activeSlot: Int?
    var canEdit: Bool
    var onEdit: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                SectionLabel(text: "Strumming pattern")
                Spacer()
                Button("Edit pattern", action: onEdit).font(Theme.strong(10)).buttonStyle(.plain)
                    .foregroundStyle(Theme.accent).disabled(!canEdit)
            }
            HStack(spacing: 4) {
                ForEach(bar.strumGrid) { slot in
                    VStack(spacing: 2) {
                        Text(slot.count).font(Theme.strong(10)).foregroundStyle(activeSlot == slot.id ? Theme.accent : Theme.muted)
                        Text(slot.stroke.symbol).font(.system(size: 23, weight: .bold))
                            .foregroundStyle(slot.stroke == .rest ? Theme.muted : activeSlot == slot.id ? Theme.accent : Theme.ink)
                    }.frame(maxWidth: .infinity).frame(height: 48)
                        .background(activeSlot == slot.id ? Theme.accent.opacity(0.14) : Theme.stage, in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(activeSlot == slot.id ? Theme.accent : Theme.line, lineWidth: 1))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Beat \(slot.spokenCount), \(slot.stroke.rawValue), \(slot.chord)\(activeSlot == slot.id ? ", current" : "")")
                }
            }
            HStack {
                Text(StrummingPattern.matching(bar)?.name ?? "Custom pattern")
                Spacer()
                Text("↓ down   ↑ up   · rest")
            }.font(Theme.body(10)).foregroundStyle(Theme.muted)
        }
    }
}
