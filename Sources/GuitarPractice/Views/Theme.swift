import SwiftUI

enum Theme {
    static let paper = Color(red: 0.065, green: 0.075, blue: 0.085)
    static let sidebar = Color(red: 0.09, green: 0.105, blue: 0.115)
    static let ink = Color(red: 0.96, green: 0.95, blue: 0.89)
    static let muted = Color(red: 0.61, green: 0.65, blue: 0.66)
    static let accent = Color(red: 0.98, green: 0.74, blue: 0.30)
    static let line = Color(red: 0.19, green: 0.22, blue: 0.23)
    static let green = Color(red: 0.68, green: 0.88, blue: 0.36)
    static let coral = Color(red: 0.97, green: 0.45, blue: 0.39)
    static let stage = Color(red: 0.037, green: 0.045, blue: 0.055)
    static let lanes: [Color] = [green, Color(red: 0.45, green: 0.69, blue: 0.94), accent, coral, Color(red: 0.73, green: 0.57, blue: 0.92)]
    static func body(_ size: CGFloat = 14) -> Font { .custom("AvenirNext-Regular", size: size, relativeTo: .body) }
    static func strong(_ size: CGFloat = 14) -> Font { .custom("AvenirNext-DemiBold", size: size, relativeTo: .body) }
    static func title(_ size: CGFloat = 36) -> Font { .custom("Futura-CondensedExtraBold", size: size, relativeTo: .title) }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(Theme.strong()).padding(.horizontal, 20).padding(.vertical, 12)
            .foregroundStyle(Theme.stage).background(Theme.accent.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 5))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct SectionLabel: View {
    var text: String
    var body: some View { Text(text.uppercased()).font(Theme.strong(10)).tracking(1.8).foregroundStyle(Theme.muted) }
}

struct EmptyMessage: View {
    var icon: String
    var title: String
    var detail: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 36, weight: .ultraLight)).foregroundStyle(Theme.accent)
            Text(title).font(Theme.title(27))
            Text(detail).font(Theme.body()).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 420)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(40)
    }
}
