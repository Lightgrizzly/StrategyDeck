import SwiftUI
import StrategyDeckCore

/// Full-form editor for creating or updating a KnowledgeCard. Only the
/// `.softwareStrategy` metadata case has a real form in this slice — a
/// future deck's metadata case gets its own editor section here without
/// touching the identity/tags fields above.
struct KnowledgeCardEditorView: View {
    enum Mode { case create, edit }

    let mode: Mode
    @Binding var card: KnowledgeCard
    let suits: [CardSuit]
    let onSave: (KnowledgeCard) -> Void
    let onCancel: () -> Void

    @State private var tagsText: String = ""
    @State private var requirementsText: String = ""
    @State private var advantagesText: String = ""
    @State private var costsText: String = ""
    @State private var failureModesText: String = ""
    // Playability rule texts (one item per line)
    @State private var prereqText: String = ""
    @State private var requiredActiveText: String = ""
    @State private var requiredKnownText: String = ""
    @State private var unlockedByText: String = ""
    @State private var blockedByText: String = ""
    @State private var unlocksText: String = ""
    @State private var disablesText: String = ""

    /// `nil` when `card.metadata` isn't `.softwareStrategy` — used to hide
    /// the software-strategy-only sections rather than fabricate blank
    /// fields and silently clobber whatever metadata case the card actually
    /// has (e.g. `.generic`, or a case from a newer app version) the moment
    /// Save is pressed.
    private var isSoftwareStrategy: Bool {
        if case .softwareStrategy = card.metadata { return true }
        return false
    }

    private var softwareFields: Binding<SoftwareStrategyFields> {
        Binding(
            get: {
                if case .softwareStrategy(let f) = card.metadata { return f }
                return SoftwareStrategyFields()
            },
            set: { card.metadata = .softwareStrategy($0) }
        )
    }

    private var selectedSuitID: Binding<String> {
        Binding(
            get: {
                if let currentID = card.suitIDs.first,
                   suits.contains(where: { $0.id == currentID }) {
                    return currentID
                }
                return suits.first?.id ?? card.suitIDs.first ?? ""
            },
            set: { newID in
                card.suitIDs = [newID]
                if let deckID = suits.first(where: { $0.id == newID })?.deckID {
                    card.deckIDs = [deckID]
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                Spacer()
                Text(mode == .create ? "New Card" : "Edit Card")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Save") { commitAndSave() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(card.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("Identity") {
                        LabeledField("Name") {
                            TextField("e.g. Hash-Based Lookup", text: $card.title)
                        }
                        LabeledField("Suite") {
                            Picker("Suite", selection: selectedSuitID) {
                                ForEach(suits.sorted { $0.displayOrder < $1.displayOrder }) { s in
                                    Text(s.name).tag(s.id)
                                }
                            }
                            .labelsHidden()
                        }
                        LabeledField("Tags (comma-separated)") {
                            TextField("e.g. hash, lookup, membership", text: $tagsText)
                        }
                    }

                    if isSoftwareStrategy {
                        section("Problem") {
                            LabeledField("Trigger") {
                                TextEditor(text: softwareFields.trigger)
                                    .frame(minHeight: 44)
                            }
                            LabeledField("Problem Shape") {
                                TextEditor(text: softwareFields.problemShape)
                                    .frame(minHeight: 44)
                            }
                            LabeledField("Desired Result") {
                                TextEditor(text: softwareFields.desiredResult)
                                    .frame(minHeight: 44)
                            }
                        }

                        section("Mechanism") {
                            LabeledField("How It Works") {
                                TextEditor(text: softwareFields.mechanism)
                                    .frame(minHeight: 60)
                            }
                            LabeledField("Requirements (one per line)") {
                                TextEditor(text: $requirementsText)
                                    .frame(minHeight: 44)
                            }
                        }

                        section("Trade-offs") {
                            LabeledField("Advantages (one per line)") {
                                TextEditor(text: $advantagesText)
                                    .frame(minHeight: 44)
                            }
                            LabeledField("Costs (one per line)") {
                                TextEditor(text: $costsText)
                                    .frame(minHeight: 44)
                            }
                            LabeledField("Failure Modes (one per line)") {
                                TextEditor(text: $failureModesText)
                                    .frame(minHeight: 44)
                            }
                        }

                        section("Complexity") {
                            HStack(spacing: 12) {
                                LabeledField("Time") {
                                    TextField("O(n)", text: softwareFields.timeComplexity)
                                }
                                LabeledField("Space") {
                                    TextField("O(1)", text: softwareFields.spaceComplexity)
                                }
                            }
                        }

                        section("Examples") {
                            LabeledField("Flow Description") {
                                TextEditor(text: softwareFields.flowDescription)
                                    .frame(minHeight: 44)
                            }
                            LabeledField("Code Example") {
                                TextEditor(text: softwareFields.codeExample)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minHeight: 60)
                            }
                            LabeledField("Real-World Example") {
                                TextEditor(text: softwareFields.realWorldExample)
                                    .frame(minHeight: 44)
                            }
                        }
                    }

                    section("Notes") {
                        LabeledField("Personal Notes") {
                            TextEditor(text: $card.backText)
                                .frame(minHeight: 60)
                        }
                    }

                    section("Playability Rules") {
                        Text("Define when this card is available in a Duel. Leave blank to make it always available.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        LabeledField("Prerequisites (one per line)") {
                            TextEditor(text: $prereqText)
                                .frame(minHeight: 40)
                        }
                        LabeledField("Required active cards (one per line)") {
                            TextEditor(text: $requiredActiveText)
                                .frame(minHeight: 40)
                        }
                        LabeledField("Required known info (one per line)") {
                            TextEditor(text: $requiredKnownText)
                                .frame(minHeight: 40)
                        }
                        LabeledField("Unlocked by (one per line)") {
                            TextEditor(text: $unlockedByText)
                                .frame(minHeight: 40)
                        }
                        LabeledField("Blocked by (one per line)") {
                            TextEditor(text: $blockedByText)
                                .frame(minHeight: 40)
                        }
                        LabeledField("Unlocks (one per line)") {
                            TextEditor(text: $unlocksText)
                                .frame(minHeight: 40)
                        }
                        LabeledField("Disables (one per line)") {
                            TextEditor(text: $disablesText)
                                .frame(minHeight: 40)
                        }
                        HStack(spacing: 16) {
                            Toggle("Can be reused", isOn: $card.playabilityRules.canBeReused)
                                .font(.system(size: 11))
                            Toggle("Exhausts after use", isOn: $card.playabilityRules.exhaustsAfterUse)
                                .font(.system(size: 11))
                        }
                    }
                }
                .padding(14)
            }
        }
        .onAppear { populateListFields() }
    }

    // MARK: - Helpers

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
            content()
        }
    }

    private func populateListFields() {
        tagsText = card.tags.joined(separator: ", ")
        requirementsText = softwareFields.wrappedValue.requirements.joined(separator: "\n")
        advantagesText = softwareFields.wrappedValue.advantages.joined(separator: "\n")
        costsText = softwareFields.wrappedValue.costs.joined(separator: "\n")
        failureModesText = softwareFields.wrappedValue.failureModes.joined(separator: "\n")
        let rules = card.playabilityRules
        prereqText = rules.prerequisites.joined(separator: "\n")
        requiredActiveText = rules.requiredActiveCardTitles.joined(separator: "\n")
        requiredKnownText = rules.requiredKnownInfo.joined(separator: "\n")
        unlockedByText = rules.unlockedByCardTitles.joined(separator: "\n")
        blockedByText = rules.blockedByCardTitles.joined(separator: "\n")
        unlocksText = rules.unlocksCardTitles.joined(separator: "\n")
        disablesText = rules.disablesCardTitles.joined(separator: "\n")
    }

    private func commitAndSave() {
        card.tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if isSoftwareStrategy {
            var fields = softwareFields.wrappedValue
            fields.requirements = lines(requirementsText)
            fields.advantages = lines(advantagesText)
            fields.costs = lines(costsText)
            fields.failureModes = lines(failureModesText)
            card.metadata = .softwareStrategy(fields)
        }
        card.playabilityRules = CardPlayabilityRules(
            prerequisites: lines(prereqText),
            requiredActiveCardTitles: lines(requiredActiveText),
            requiredKnownInfo: lines(requiredKnownText),
            unlockedByCardTitles: lines(unlockedByText),
            blockedByCardTitles: lines(blockedByText),
            unlocksCardTitles: lines(unlocksText),
            disablesCardTitles: lines(disablesText),
            canBeReused: card.playabilityRules.canBeReused,
            exhaustsAfterUse: card.playabilityRules.exhaustsAfterUse
        )
        onSave(card)
    }

    private func lines(_ text: String) -> [String] {
        text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

private struct LabeledField<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            content
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
        }
    }
}
