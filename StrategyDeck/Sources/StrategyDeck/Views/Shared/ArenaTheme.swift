import SwiftUI
import StrategyDeckCore

// MARK: - Arena color system
//
// Shared dark navy / cyan holographic palette used across the entire app —
// originally introduced for the Duel Board, now the app-wide design system.

enum AC {
    // Backgrounds
    static let bg         = Color(red: 0.03, green: 0.06, blue: 0.13)
    static let surface    = Color(red: 0.06, green: 0.10, blue: 0.20)
    static let surfaceHi  = Color(red: 0.09, green: 0.15, blue: 0.28)
    static let glassPanel = Color(red: 0.08, green: 0.14, blue: 0.26)
    // Cyan / player accent
    static let cyan       = Color(red: 0.15, green: 0.75, blue: 1.00)
    static let cyanDim    = Color(red: 0.10, green: 0.50, blue: 0.80)
    static let cyanGlow   = Color(red: 0.15, green: 0.75, blue: 1.00).opacity(0.55)
    static let cyanSoft   = Color(red: 0.10, green: 0.45, blue: 0.75).opacity(0.18)
    // Opponent / destructive accent
    static let threat     = Color(red: 0.95, green: 0.30, blue: 0.35)
    static let threatSoft = Color(red: 0.80, green: 0.20, blue: 0.25).opacity(0.18)
    // Objective / highlight
    static let gold       = Color(red: 1.00, green: 0.85, blue: 0.20)
    static let goldSoft   = Color(red: 1.00, green: 0.85, blue: 0.20).opacity(0.15)
    // Status
    static let available  = Color(red: 0.20, green: 0.90, blue: 0.50)
    static let lockedTint  = Color(white: 0.35)
    static let exhausted   = Color(white: 0.28)
    static let resolved    = Color(red: 0.20, green: 0.85, blue: 0.65)
    // Grid / borders
    static let gridLine   = Color(red: 0.10, green: 0.30, blue: 0.60).opacity(0.18)
    static let border     = Color(red: 0.15, green: 0.40, blue: 0.75).opacity(0.55)
    static let borderDim  = Color(red: 0.10, green: 0.25, blue: 0.50).opacity(0.35)
    // Text
    static let text       = Color.white
    static let textSub    = Color(white: 0.68)
    static let textDim    = Color(white: 0.40)
    static let textGhost  = Color(white: 0.25)
}

// MARK: - Angular card/panel shape (futuristic diagonal cut on top-right)

struct AngularCardShape: Shape {
    var cornerRadius: CGFloat = 7
    var cornerCut: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        let cr  = min(cornerRadius, rect.width * 0.4, rect.height * 0.4)
        let cut = min(cornerCut,    rect.width * 0.4)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + cr, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX,       y: rect.minY + cut))
        p.addLine(to: CGPoint(x: rect.maxX,       y: rect.maxY - cr))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - cr, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + cr, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - cr),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cr))
        p.addQuadCurve(to: CGPoint(x: rect.minX + cr, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - CardKind arena extensions

extension CardKind {
    var boardSFSymbol: String {
        switch self {
        case .action:      return "bolt.fill"
        case .condition:   return "exclamationmark.circle.fill"
        case .principle:   return "star.fill"
        case .observation: return "eye.fill"
        case .entity:      return "person.fill"
        case .relation:    return "arrow.left.and.right"
        case .modifier:    return "slider.horizontal.3"
        case .chunk:       return "rectangle.stack.fill"
        case .strategy:    return "map.fill"
        }
    }

    var arenaColor: Color {
        switch self {
        case .action:      return Color(red: 1.0, green: 0.50, blue: 0.10)
        case .condition:   return Color(red: 1.0, green: 0.25, blue: 0.32)
        case .principle:   return Color(red: 0.70, green: 0.35, blue: 1.00)
        case .observation: return Color(red: 0.15, green: 0.90, blue: 0.80)
        case .entity:      return Color(red: 0.25, green: 0.65, blue: 1.00)
        case .relation:    return Color(red: 0.20, green: 0.90, blue: 0.50)
        case .modifier:    return Color(red: 1.00, green: 0.80, blue: 0.10)
        case .chunk:       return Color(red: 0.60, green: 0.50, blue: 1.00)
        case .strategy:    return AC.cyan
        }
    }
}

// MARK: - Digital arena background
//
// Reusable dark holographic backdrop: base color + depth gradient + circuit
// grid (skipped under Reduce Motion). Used behind every top-level screen.

struct DigitalArenaBackground: View {
    var reduceEffects: Bool = false
    var accentSoft: Color = AC.cyanSoft

    var body: some View {
        ZStack {
            AC.bg

            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.55), location: 0.00),
                    .init(color: Color.black.opacity(0.20), location: 0.28),
                    .init(color: Color.clear,               location: 0.48),
                    .init(color: accentSoft.opacity(0.3),   location: 1.00),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if !reduceEffects {
                Canvas { ctx, size in
                    let s: CGFloat = 44
                    var grid = Path()
                    var x: CGFloat = 0
                    while x <= size.width  { grid.move(to: .init(x: x, y: 0)); grid.addLine(to: .init(x: x, y: size.height)); x += s }
                    var y: CGFloat = 0
                    while y <= size.height { grid.move(to: .init(x: 0, y: y)); grid.addLine(to: .init(x: size.width, y: y)); y += s }
                    ctx.stroke(grid, with: .color(AC.gridLine), lineWidth: 0.5)

                    let mid = size.height * 0.5
                    var h = Path()
                    h.move(to: .init(x: 0, y: mid))
                    h.addLine(to: .init(x: size.width, y: mid))
                    ctx.stroke(h, with: .color(AC.cyan.opacity(0.10)), lineWidth: 1.5)
                }
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Arena zone divider — labeled gradient rule used to separate sections

struct ArenaZoneDivider: View {
    let label: String
    var color: Color = AC.cyan

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                LinearGradient(colors: [.clear, color.opacity(0.5)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1)
                LinearGradient(colors: [color.opacity(0.5), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1)
            }
            HStack {
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(color.opacity(0.85))
                    .kerning(2.5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        AngularCardShape(cornerRadius: 3, cornerCut: 6)
                            .fill(AC.bg)
                            .overlay(AngularCardShape(cornerRadius: 3, cornerCut: 6)
                                .stroke(color.opacity(0.35), lineWidth: 0.75))
                    )
                    .padding(.leading, 14)
                Spacer()
            }
        }
        .frame(height: 20)
        .shadow(color: color.opacity(0.3), radius: 6)
    }
}

// MARK: - Arena empty slot — dashed placeholder for an unfilled card position

struct ArenaEmptySlot: View {
    let text: String
    let size: CGSize
    var color: Color = AC.cyan.opacity(0.3)

    var body: some View {
        ZStack {
            AngularCardShape(cornerRadius: 7, cornerCut: 10)
                .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [4]))
            AngularCardShape(cornerRadius: 7, cornerCut: 10)
                .fill(color.opacity(0.04))
            Text(text)
                .font(.system(size: 9))
                .foregroundStyle(color.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(6)
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Arena stack badge — fanned-card count indicator (e.g. "3 USED")

struct ArenaStackBadge: View {
    let count: Int
    let label: String
    var color: Color = AC.textDim

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                ForEach(0..<min(count, 3), id: \.self) { i in
                    AngularCardShape(cornerRadius: 5, cornerCut: 7)
                        .fill(AC.surfaceHi)
                        .overlay(AngularCardShape(cornerRadius: 5, cornerCut: 7)
                            .stroke(AC.borderDim, lineWidth: 0.75))
                        .frame(width: 38, height: 50)
                        .offset(x: CGFloat(i) * 2, y: CGFloat(i) * -2)
                }
            }
            .frame(width: 44, height: 56)
            Text("\(count)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(color.opacity(0.7))
                .kerning(1)
        }
    }
}

// MARK: - Arena action banner — transient center-screen confirmation flash

struct ArenaActionBanner: View {
    let text: String
    var color: Color = AC.cyan

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text(text)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
                    .kerning(3)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(
                        ZStack {
                            AngularCardShape(cornerRadius: 4, cornerCut: 14)
                                .fill(AC.bg.opacity(0.96))
                            AngularCardShape(cornerRadius: 4, cornerCut: 14)
                                .stroke(color.opacity(0.8), lineWidth: 1.5)
                        }
                    )
                    .shadow(color: color.opacity(0.55), radius: 20)
                Spacer()
            }
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Arena section label — small kerned monospaced heading

struct ArenaSectionLabel: View {
    let text: String
    var color: Color = AC.cyan
    var icon: String?

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon).font(.system(size: 8))
            }
            Text(text.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .kerning(2)
        }
        .foregroundStyle(color.opacity(0.75))
    }
}

// MARK: - Arena panel — angular holographic container for grouping content

struct ArenaPanel<Content: View>: View {
    var fill: Color = AC.glassPanel
    var stroke: Color = AC.border
    var cornerRadius: CGFloat = 10
    var cornerCut: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(
                AngularCardShape(cornerRadius: cornerRadius, cornerCut: cornerCut)
                    .fill(fill)
            )
            .overlay(
                AngularCardShape(cornerRadius: cornerRadius, cornerCut: cornerCut)
                    .stroke(stroke, lineWidth: 0.75)
            )
            .clipShape(AngularCardShape(cornerRadius: cornerRadius, cornerCut: cornerCut))
    }
}

// MARK: - Arena button styles

/// Primary filled angular button (e.g. "SAVE", "CREATE").
struct ArenaButtonStyle: ButtonStyle {
    var color: Color = AC.cyan
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .kerning(1.2)
            .foregroundStyle(AC.bg)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                AngularCardShape(cornerRadius: 4, cornerCut: 8)
                    .fill(isDisabled ? AC.textDim : color)
            )
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .shadow(color: isDisabled ? .clear : color.opacity(0.5), radius: configuration.isPressed ? 2 : 6)
    }
}

/// Secondary outlined angular button (e.g. "CANCEL", "EXPORT").
struct ArenaOutlineButtonStyle: ButtonStyle {
    var color: Color = AC.border

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .kerning(1)
            .foregroundStyle(AC.textSub)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                AngularCardShape(cornerRadius: 4, cornerCut: 8)
                    .fill(AC.surface.opacity(configuration.isPressed ? 0.4 : 0.0))
            )
            .overlay(
                AngularCardShape(cornerRadius: 4, cornerCut: 8)
                    .stroke(color, lineWidth: 0.75)
            )
    }
}

// MARK: - Arena text field style — dark holographic field chrome

struct ArenaFieldBackground: ViewModifier {
    var accent: Color = AC.cyan

    func body(content: Content) -> some View {
        content
            .font(.system(size: 11))
            .foregroundStyle(AC.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(AC.surface)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(AC.borderDim, lineWidth: 0.75))
            )
            .textFieldStyle(.plain)
            .colorScheme(.dark)
    }
}

extension View {
    /// Applies the arena's dark holographic field chrome to a TextField/TextEditor.
    func arenaFieldStyle(accent: Color = AC.cyan) -> some View {
        modifier(ArenaFieldBackground(accent: accent))
    }
}
