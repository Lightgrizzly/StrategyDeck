import SwiftUI

/// A small rounded tag for displaying a single string tag.
struct TagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(.secondary.opacity(0.15))
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
