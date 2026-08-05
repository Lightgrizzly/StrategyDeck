import SwiftUI
import StrategyDeckCore

/// A small color + icon badge that identifies a suite.
///
/// Uses both color AND text initials so the interface is usable in grayscale
/// and for users with color-vision differences.
struct SuiteBadge: View {
    let suite: CardSuit
    var size: CGFloat = 20

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.3)
                .fill(suiteColor.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.3)
                        .stroke(suiteColor.opacity(0.4), lineWidth: 0.5)
                )
            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(suiteColor)
        }
        .frame(width: size, height: size)
    }

    private var initials: String {
        String(suite.name.prefix(2)).uppercased()
    }

    var suiteColor: Color {
        SuiteColors.color(for: suite.id)
    }
}

/// Suite accent colors. Defined as stable named colors so they work in
/// both light and dark mode.
enum SuiteColors {
    static func color(for suiteID: String) -> Color {
        switch suiteID {
        case "search":         return .blue
        case "transformation": return .orange
        case "structure":      return .purple
        case "state":          return .green
        case "reliability":    return Color(red: 0.85, green: 0.15, blue: 0.15)
        case "debugging":      return Color(red: 0.7,  green: 0.5,  blue: 0.1)
        default:               return .secondary
        }
    }
}
#if DEBUG
struct SuiteBadge_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            SuiteBadge(
                suite: CardSuit(
                    id: "search",
                    deckID: "software-engineering",
                    name: "Search",
                    iconName: "magnifyingglass",
                    displayOrder: 0
                )
            )
        }
        .padding()
    }
}
#endif