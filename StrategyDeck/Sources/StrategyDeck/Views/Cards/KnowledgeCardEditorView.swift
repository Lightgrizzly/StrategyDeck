import SwiftUI
import StrategyDeckCore

/// Full-form editor for creating or updating a KnowledgeCard. Only the
/// `.softwareStrategy` metadata case has a real form in this slice — a
/// future deck's metadata case gets its own editor section here without
/// touching the identity/tags fields above.
///
/// The form is progressive: only Basics is always visible. Everything else
/// — rules, trade-offs, examples, systems metadata, advanced info — lives
/// behind collapsible sections so opening the editor doesn't present a
/// twenty-field wall. A card saved from Quick Create is a fully valid
/// `KnowledgeCard` already, so opening it here later is just filling in
/// more of the same fields, never a different code path.
struct KnowledgeCardEditorView: View {
    enum Mode { case create, edit }

    let mode: Mode
    @Binding var card: KnowledgeCard
    let suits: [CardSuit]
    let onSave: (KnowledgeCard) -> Void
    let onCancel: () -> Void

    @EnvironmentObject var cardStore: CardStore

    @State private var tagsText: String = ""
    @State private var requirementsText: String = ""
    @State private var advantagesText: String = ""
    @State private var costsText: String = ""
    @State private var failureModesText: String = ""
    // Playability rule texts (one item per line)
    @State private var prereqText: String = ""
    @State private var requiredActiveText: String = ""
    @State private var requiredKnownText: String = ""
    @State private var requiredStateText: String = ""
    @State private var unlockedByText: String = ""
    @State private var blockedByText: String = ""
    @State private var unlocksText: String = ""
    @State private var disablesText: String = ""

    @State private var showingNewSuiteField = false
    @State private var expandedSections: Set<String> = []

    private var kindColor: Color { card.kind.arenaColor }

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

    private var currentDeckID: String? { card.deckIDs.first }

    private var currentDeckName: String {
        guard let currentDeckID else { return "No Deck" }
        return cardStore.decks.first(where: { $0.id == currentDeckID })?.name ?? "No Deck"
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
                    .buttonStyle(ArenaOutlineButtonStyle())
                    .keyboardShortcut(.escape)
                Spacer()
                Text(mode == .create ? "NEW CARD" : "EDIT CARD")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(kindColor)
                    .kerning(2)
                Spacer()
                Button("Save") { commitAndSave() }
                    .buttonStyle(ArenaButtonStyle(color: kindColor, isDisabled: card.title.trimmingCharacters(in: .whitespaces).isEmpty))
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(card.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AC.surface)
            .overlay(alignment: .bottom) { Rectangle().fill(kindColor.opacity(0.3)).frame(height: 1) }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("Basics") {
                        LabeledField("Name") {
                            TextField("e.g. Hash-Based Lookup", text: $card.title)
                        }
                        LabeledField("Deck") {
                            Text(currentDeckName)
                                .font(.system(size: 11))
                                .foregroundStyle(AC.textSub)
                        }
                        LabeledField("Suite") {
                            HStack(spacing: 6) {
                                if showingNewSuiteField {
                                    InlineCreateRow(placeholder: "New suite name…", autoFocus: true) { name in
                                        guard let currentDeckID else { return }
                                        let suit = cardStore.createSuit(deckID: currentDeckID, name: name)
                                        selectedSuitID.wrappedValue = suit.id
                                        showingNewSuiteField = false
                                    }
                                } else {
                                    Picker("Suite", selection: selectedSuitID) {
                                        ForEach(suits.sorted { $0.displayOrder < $1.displayOrder }) { s in
                                            Text(s.name).tag(s.id)
                                        }
                                    }
                                    .labelsHidden()
                                    .tint(AC.cyan)
                                    if currentDeckID != nil {
                                        Button(action: { showingNewSuiteField = true }) {
                                            Image(systemName: "plus.circle").font(.system(size: 11))
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(AC.textDim)
                                        .help("New suite, without leaving this form")
                                    }
                                }
                            }
                        }
                        LabeledField("Card Type") {
                            Picker("Card Type", selection: $card.kind) {
                                ForEach(CardKind.allCases, id: \.self) { kind in
                                    Text(kind.displayName).tag(kind)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(AC.cyan)
                        }
                        LabeledField("Short Description") {
                            TextField("One line — shown in Duel Board and Systems Map", text: $card.frontText)
                        }
                        LabeledField("Tags (comma-separated)") {
                            TextField("e.g. hash, lookup, membership", text: $tagsText)
                        }
                    }

                    if isSoftwareStrategy {
                        collapsibleSection("Problem & Mechanism") {
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
                            LabeledField("How It Works") {
                                TextEditor(text: softwareFields.mechanism)
                                    .frame(minHeight: 60)
                            }
                            LabeledField("Requirements (one per line)") {
                                TextEditor(text: $requirementsText)
                                    .frame(minHeight: 44)
                            }
                        }

                        collapsibleSection("Trade-offs & Complexity") {
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
                            HStack(spacing: 12) {
                                LabeledField("Time") {
                                    TextField("O(n)", text: softwareFields.timeComplexity)
                                }
                                LabeledField("Space") {
                                    TextField("O(1)", text: softwareFields.spaceComplexity)
                                }
                            }
                        }

                        collapsibleSection("Examples") {
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

                    collapsibleSection("Notes") {
                        LabeledField("Personal Notes") {
                            TextEditor(text: $card.backText)
                                .frame(minHeight: 60)
                        }
                    }

                    collapsibleSection("Rules & Availability") {
                        Text("Define when this card is available in a Duel or Systems Map. Leave blank to make it always available.")
                            .font(.system(size: 10))
                            .foregroundStyle(AC.textSub)
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
                        LabeledField("Required state conditions (one per line)") {
                            TextEditor(text: $requiredStateText)
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
                                .tint(AC.cyan)
                            Toggle("Exhausts after use", isOn: $card.playabilityRules.exhaustsAfterUse)
                                .font(.system(size: 11))
                                .tint(AC.cyan)
                        }
                        .foregroundStyle(AC.textSub)
                    }

                    collapsibleSection("Systems Metadata") {
                        Text("Used only by the Systems Map — leverage classification and which element types this card can target.")
                            .font(.system(size: 10))
                            .foregroundStyle(AC.textSub)
                        LabeledField("Leverage Level") {
                            Picker("Leverage Level", selection: $card.playabilityRules.leverageLevel) {
                                Text("Not Classified").tag(LeverageLevel?.none)
                                ForEach(LeverageLevel.allCases, id: \.self) { level in
                                    Text(level.displayName).tag(Optional(level))
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(AC.cyan)
                        }
                        LabeledField("Supported Element Types (empty = untargeted, applies anywhere)") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90, maximum: 140), spacing: 6)], spacing: 6) {
                                ForEach(SystemTargetKind.allCases, id: \.self) { kind in
                                    targetKindChip(kind)
                                }
                            }
                        }
                    }

                    collapsibleSection("Advanced") {
                        LabeledField("ID") {
                            Text(card.id.uuidString)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(AC.textSub)
                                .textSelection(.enabled)
                        }
                        HStack(spacing: 16) {
                            LabeledField("Created") {
                                Text(card.createdAt, format: Date.FormatStyle(date: .numeric, time: .shortened))
                                    .font(.system(size: 10))
                                    .foregroundStyle(AC.textSub)
                            }
                            LabeledField("Updated") {
                                Text(card.updatedAt, format: Date.FormatStyle(date: .numeric, time: .shortened))
                                    .font(.system(size: 10))
                                    .foregroundStyle(AC.textSub)
                            }
                        }
                        LabeledField("Metadata Type") {
                            Text(isSoftwareStrategy ? "Software Strategy" : "Generic")
                                .font(.system(size: 10))
                                .foregroundStyle(AC.textSub)
                        }
                    }
                }
                .padding(14)
            }
        }
        .background(AC.bg)
        .colorScheme(.dark)
        .onAppear { populateListFields() }
    }

    // MARK: - Helpers

    private func targetKindChip(_ kind: SystemTargetKind) -> some View {
        let isOn = card.playabilityRules.systemTargetTypes.contains(kind)
        return Button(action: {
            if isOn {
                card.playabilityRules.systemTargetTypes.removeAll { $0 == kind }
            } else {
                card.playabilityRules.systemTargetTypes.append(kind)
            }
        }) {
            Text(kind.displayName.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(
                    AngularCardShape(cornerRadius: 4, cornerCut: 6)
                        .fill(isOn ? AC.cyanSoft : AC.surface)
                )
                .overlay(
                    AngularCardShape(cornerRadius: 4, cornerCut: 6)
                        .stroke(isOn ? AC.cyan : AC.borderDim, lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isOn ? AC.cyan : AC.textSub)
    }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ArenaSectionLabel(text: title, color: kindColor)
            content()
        }
        .padding(12)
        .background(
            AngularCardShape(cornerRadius: 8, cornerCut: 12)
                .fill(AC.surface.opacity(0.6))
                .overlay(AngularCardShape(cornerRadius: 8, cornerCut: 12)
                    .stroke(AC.borderDim, lineWidth: 0.75))
        )
    }

    /// Same visual chrome as `section`, but collapsible — expansion state is
    /// remembered per section title for the life of this editing session.
    private func collapsibleSection<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        let isExpanded = expandedSections.contains(title)
        return VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if isExpanded { expandedSections.remove(title) } else { expandedSections.insert(title) }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(kindColor.opacity(0.75))
                    ArenaSectionLabel(text: title, color: kindColor)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            if isExpanded {
                content()
            }
        }
        .padding(12)
        .background(
            AngularCardShape(cornerRadius: 8, cornerCut: 12)
                .fill(AC.surface.opacity(0.6))
                .overlay(AngularCardShape(cornerRadius: 8, cornerCut: 12)
                    .stroke(AC.borderDim, lineWidth: 0.75))
        )
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
        requiredStateText = rules.requiredStateConditions.joined(separator: "\n")
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
            requiredStateConditions: lines(requiredStateText),
            unlockedByCardTitles: lines(unlockedByText),
            blockedByCardTitles: lines(blockedByText),
            unlocksCardTitles: lines(unlocksText),
            disablesCardTitles: lines(disablesText),
            canBeReused: card.playabilityRules.canBeReused,
            exhaustsAfterUse: card.playabilityRules.exhaustsAfterUse,
            systemTargetTypes: card.playabilityRules.systemTargetTypes,
            leverageLevel: card.playabilityRules.leverageLevel
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
            Text(label.uppercased())
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(AC.textDim)
                .kerning(1)
            content
                .arenaFieldStyle()
        }
    }
}
