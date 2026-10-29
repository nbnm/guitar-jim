import SwiftUI
import GuitarPracticeCore

struct ChordTableView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        let bars = model.song.bars
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                SectionLabel(text: "Chord table")
                Text("↓ down  ↑ up  · rest  — hold chord").font(Theme.body(10)).foregroundStyle(Theme.muted)
                Spacer()
                Text("BAR \(model.currentBar + 1) / \(bars.count)").font(Theme.strong(10)).monospacedDigit().foregroundStyle(Theme.accent)
            }
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("BAR / SECTION").frame(width: 100, alignment: .leading)
                    ForEach(0..<8) { index in
                        Text(index.isMultiple(of: 2) ? "\(index / 2 + 1)" : "&").frame(maxWidth: .infinity)
                    }
                }.font(Theme.strong(9)).foregroundStyle(Theme.muted).padding(.horizontal, 8).padding(.vertical, 5)
                Divider().overlay(Theme.line)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(bars.indices, id: \.self) { index in
                                row(bars[index], index: index).id(index)
                            }
                        }
                    }.onAppear { proxy.scrollTo(model.currentBar, anchor: .center) }
                        .onChange(of: model.currentBar) { _, bar in proxy.scrollTo(bar, anchor: .center) }
                        .onChange(of: model.song.id) { _, _ in proxy.scrollTo(model.currentBar, anchor: .center) }
                }
            }.background(Theme.stage, in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.line))
        }
    }
    private func row(_ bar: PracticeBar, index: Int) -> some View {
        let current = index == model.currentBar
        let selected = (model.startBar..<model.endBar).contains(index)
        let slots = bar.strumGrid
        return HStack(spacing: 0) {
            HStack(spacing: 7) {
                Text(String(format: "%02d", index + 1)).font(Theme.strong(12)).monospacedDigit()
                Text(sectionName(for: index)).font(Theme.body(9)).lineLimit(1)
            }.foregroundStyle(current ? Theme.accent : Theme.muted).frame(width: 100, alignment: .leading)
            ForEach(slots) { slot in
                let active = current && model.activeStrumSlot == slot.id
                VStack(spacing: 0) {
                    Text(slot.id == 0 || slots[slot.id - 1].chord != slot.chord ? slot.chord : "—").font(Theme.strong(12))
                    Text(slot.stroke.symbol).font(.system(size: 12, weight: .semibold))
                }.foregroundStyle(active ? Theme.stage : slot.stroke == .rest ? Theme.muted : Theme.ink)
                    .frame(maxWidth: .infinity).frame(height: 27)
                    .background(active ? Theme.accent : .clear, in: RoundedRectangle(cornerRadius: 3))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Bar \(index + 1), beat \(slot.spokenCount), \(slot.chord), \(slot.stroke.rawValue)\(active ? ", current" : "")")
            }
        }.padding(.horizontal, 8).padding(.vertical, 2)
            .background(current ? Theme.accent.opacity(0.08) : .clear)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line.opacity(0.6)).frame(height: 0.5) }
            .opacity(selected || current ? 1 : 0.45)
    }
    private func sectionName(for bar: Int) -> String {
        var start = 0
        for section in model.song.sections {
            if (start..<(start + section.bars.count)).contains(bar) { return section.name }
            start += section.bars.count
        }
        return ""
    }
}
