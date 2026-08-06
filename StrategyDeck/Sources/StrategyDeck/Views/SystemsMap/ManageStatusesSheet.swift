import SwiftUI
import StrategyDeckCore

/// Lets the user rename the built-in status labels and create/edit/delete
/// wholly custom statuses. A custom status always wears one of the
/// built-in behaviors (`behavesLike`) — this sheet only edits how a status
/// looks (name/icon/color), never invents new playability/drag-and-drop
/// behavior, so every other Systems Map view keeps working unmodified.
struct ManageStatusesSheet: View {
    let map: SystemMap
    let onSetLabel: (SystemCardStatus, String?) -> Void
    let onCreateCustomStatus: (String, String, StatusColorToken, SystemCardStatus) -> Void
    let onUpdateCustomStatus: (CustomCardStatus) -> Void
    let onDeleteCustomStatus: (String) -> Void
    @Binding var isPresented: Bool

    static let iconPresets = [
        "tag.fill", "flag.fill", "bookmark.fill", "exclamationmark.triangle.fill",
        "questionmark.circle.fill", "checkmark.seal.fill", "hourglass", "bolt.fill",
        "lock.fill", "star.fill", "person.fill.badge.plus", "clock.fill"
    ]

    @State private var builtInLabels: [String: String] = [:]
    @State private var customNameEdits: [String: String] = [:]
    @State private var newStatusName = ""
    @State private var newStatusBehavior: SystemCardStatus = .available

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("MANAGE STATUSES").font(.system(size: 14, weight: .black, design: .monospaced)).foregroundStyle(AC.cyan).kerning(1.5)
                Spacer()
                Button("Done") { isPresented = false }.buttonStyle(ArenaOutlineButtonStyle()).keyboardShortcut(.defaultAction)
            }
            .padding(14)
            .background(AC.surface)
            Rectangle().fill(AC.borderDim).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        ArenaSectionLabel(text: "Built-in Statuses", color: AC.cyan)
                        Text("Rename the labels shown throughout the Systems Map. Their behavior (playability, drag-and-drop actions) never changes.")
                            .font(.system(size: 10)).foregroundStyle(AC.textSub)
                        ForEach(SystemCardStatus.allCases, id: \.self) { status in
                            builtInRow(status)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ArenaSectionLabel(text: "Custom Statuses", color: AC.gold)
                        if map.customStatuses.isEmpty {
                            Text("No custom statuses yet.").font(.system(size: 11)).foregroundStyle(AC.textGhost)
                        }
                        ForEach(map.customStatuses.sorted { $0.displayOrder < $1.displayOrder }) { custom in
                            customRow(custom)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ArenaSectionLabel(text: "Add Custom Status", color: AC.available)
                        HStack(spacing: 8) {
                            TextField("Status name…", text: $newStatusName).arenaFieldStyle()
                            Picker("Behaves Like", selection: $newStatusBehavior) {
                                ForEach(SystemCardStatus.allCases, id: \.self) { s in
                                    Text(s.displayName).tag(s)
                                }
                            }
                            .labelsHidden().pickerStyle(.menu).tint(AC.cyan).frame(width: 140)
                            Button("Create") {
                                let trimmed = newStatusName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                onCreateCustomStatus(trimmed, "tag.fill", .cyan, newStatusBehavior)
                                newStatusName = ""
                            }
                            .buttonStyle(ArenaButtonStyle(isDisabled: newStatusName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                            .disabled(newStatusName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        Text("Behaves Like decides what this status can actually do — e.g. a status that behaves like Locked shows the same override options Locked cards do.")
                            .font(.system(size: 9)).foregroundStyle(AC.textGhost)
                    }
                }
                .padding(14)
            }
        }
        .frame(minWidth: 480, minHeight: 480)
        .background(AC.bg)
        .colorScheme(.dark)
        .onAppear {
            builtInLabels = map.statusLabelOverrides
            customNameEdits = Dictionary(uniqueKeysWithValues: map.customStatuses.map { ($0.id, $0.name) })
        }
    }

    private func builtInRow(_ status: SystemCardStatus) -> some View {
        HStack(spacing: 8) {
            Image(systemName: status.systemImage).font(.system(size: 12)).foregroundStyle(status.arenaColor).frame(width: 18)
            TextField(status.displayName, text: Binding(
                get: { builtInLabels[status.rawValue] ?? "" },
                set: { builtInLabels[status.rawValue] = $0 }
            ))
            .arenaFieldStyle()
            .onSubmit { onSetLabel(status, builtInLabels[status.rawValue]) }
            if let current = builtInLabels[status.rawValue], !current.isEmpty {
                Button(action: {
                    builtInLabels[status.rawValue] = ""
                    onSetLabel(status, nil)
                }) {
                    Image(systemName: "arrow.uturn.backward.circle").font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AC.textDim)
                .help("Reset to \"\(status.displayName)\"")
            }
        }
    }

    private func customRow(_ custom: CustomCardStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(Self.iconPresets, id: \.self) { icon in
                        Button(action: {
                            var updated = custom
                            updated.iconName = icon
                            onUpdateCustomStatus(updated)
                        }) {
                            Label(icon, systemImage: icon)
                        }
                    }
                } label: {
                    Image(systemName: custom.iconName).font(.system(size: 12)).foregroundStyle(custom.colorToken.color).frame(width: 18)
                }
                .buttonStyle(.plain)

                TextField("Name", text: Binding(
                    get: { customNameEdits[custom.id] ?? custom.name },
                    set: { customNameEdits[custom.id] = $0 }
                ))
                .arenaFieldStyle()
                .onSubmit {
                    var updated = custom
                    updated.name = customNameEdits[custom.id] ?? custom.name
                    onUpdateCustomStatus(updated)
                }

                Button(role: .destructive, action: { onDeleteCustomStatus(custom.id) }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AC.threat.opacity(0.75))
            }

            HStack(spacing: 8) {
                Text("BEHAVES LIKE").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim).kerning(1)
                Picker("Behaves Like", selection: Binding(
                    get: { custom.behavesLike },
                    set: { newBehavior in
                        var updated = custom
                        updated.behavesLike = newBehavior
                        onUpdateCustomStatus(updated)
                    }
                )) {
                    ForEach(SystemCardStatus.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .labelsHidden().pickerStyle(.menu).tint(AC.cyan)

                HStack(spacing: 4) {
                    ForEach(StatusColorToken.allCases, id: \.self) { token in
                        Circle()
                            .fill(token.color)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(AC.text, lineWidth: custom.colorToken == token ? 1.5 : 0))
                            .onTapGesture {
                                var updated = custom
                                updated.colorToken = token
                                onUpdateCustomStatus(updated)
                            }
                    }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(AC.surface))
    }
}
