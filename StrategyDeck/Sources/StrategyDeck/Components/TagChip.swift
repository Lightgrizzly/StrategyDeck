import SwiftUI

/// A small rounded tag for displaying a single string tag.
struct TagChip: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .kerning(0.5)
            .foregroundStyle(AC.cyan.opacity(0.85))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                AngularCardShape(cornerRadius: 3, cornerCut: 5)
                    .fill(AC.cyanSoft)
                    .overlay(AngularCardShape(cornerRadius: 3, cornerCut: 5)
                        .stroke(AC.cyan.opacity(0.35), lineWidth: 0.5))
            )
    }
}

/// Wraps a set of tags, flowing them onto multiple lines.
struct TagRow: View {
    let tags: [String]

    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tags, id: \.self) { TagChip(text: $0) }
                }
            }
        }
    }
}
