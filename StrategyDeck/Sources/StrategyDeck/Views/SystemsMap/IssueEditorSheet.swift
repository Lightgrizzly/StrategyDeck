import SwiftUI
import StrategyDeckCore

/// The full issue editor — everything Quick Add doesn't cover. Reachable
/// from an issue's row menu ("Edit…"), never required for ordinary
/// creation.
struct IssueEditorSheet: View {
    @Binding var issue: SystemIssue
    let allElements: [SystemElement]
    let allScenarios: [SystemScenario]
    let availableCards: [KnowledgeCard]
    let onSave: (SystemIssue) -> Void
    let onCancel: () -> Void

    @State private var tagsText: String = ""
    @State private var newRelatedCardID: UUID?
    @State private var newRelationshipType: IssueCardRelationshipType = .investigates

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onCancel).buttonStyle(ArenaOutlineButtonStyle()).keyboardShortcut(.escape)
                Spacer()
                Text("EDIT ISSUE").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(issue.severity.arenaColor).kerning(2)
                Spacer()
                Button("Save") {
                    issue.tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    onSave(issue)
                }
                .buttonStyle(ArenaButtonStyle(color: issue.severity.arenaColor, isDisabled: issue.title.trimmingCharacters(in: .whitespaces).isEmpty))
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(issue.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AC.surface)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    field("Title") { TextField("What's wrong or affecting the element", text: $issue.title) }
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("TYPE").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim)
                            Picker("Type", selection: $issue.type) {
                                ForEach(IssueType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                            }
                            .labelsHidden().pickerStyle(.menu).tint(AC.cyan)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("SEVERITY").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim)
                            Picker("Severity", selection: $issue.severity) {
                                ForEach(IssueSeverity.allCases, id: \.self) { Text($0.displayName).tag($0) }
                            }
                            .labelsHidden().pickerStyle(.menu).tint(AC.cyan)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("STATUS").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim)
                            Picker("Status", selection: $issue.status) {
                                ForEach(IssueStatus.allCases, id: \.self) { Text($0.displayName).tag($0) }
                            }
                            .labelsHidden().pickerStyle(.menu).tint(AC.cyan)
                        }
                    }
                    field("Description") { TextEditor(text: $issue.description).frame(minHeight: 60) }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AFFECTED ELEMENTS").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim).kerning(1)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 6)], spacing: 6) {
                            ForEach(allElements) { element in
                                let isOn = issue.affectedElementIDs.contains(element.id)
                                Button(action: {
                                    if isOn { issue.affectedElementIDs.removeAll { $0 == element.id } }
                                    else { issue.affectedElementIDs.append(element.id) }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: element.kind.systemImage).font(.system(size: 9))
                                        Text(element.name).font(.system(size: 10)).lineLimit(1)
                                    }
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 5).fill(isOn ? AC.threatSoft : AC.surface))
                                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(isOn ? AC.threat.opacity(0.6) : AC.borderDim, lineWidth: 0.75))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(isOn ? AC.threat : AC.textSub)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("SCENARIO SCOPE").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim).kerning(1)
                        Text(issue.scenarioIDs.isEmpty ? "Applies to all scenarios" : "Applies to \(issue.scenarioIDs.count) selected scenario(s)")
                            .font(.system(size: 10)).foregroundStyle(AC.textSub)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 6)], spacing: 6) {
                            Button(action: { issue.scenarioIDs = [] }) {
                                Text("All Scenarios").font(.system(size: 10))
                                    .padding(.horizontal, 6).padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 5).fill(issue.scenarioIDs.isEmpty ? AC.cyanSoft : AC.surface))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(issue.scenarioIDs.isEmpty ? AC.cyan : AC.textSub)

                            ForEach(allScenarios) { s in
                                let isOn = issue.scenarioIDs.contains(s.id)
                                Button(action: {
                                    if isOn { issue.scenarioIDs.removeAll { $0 == s.id } }
                                    else { issue.scenarioIDs.append(s.id) }
                                }) {
                                    Text(s.name).font(.system(size: 10)).lineLimit(1)
                                        .padding(.horizontal, 6).padding(.vertical, 4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(RoundedRectangle(cornerRadius: 5).fill(isOn ? AC.cyanSoft : AC.surface))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(isOn ? AC.cyan : AC.textSub)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("RELATED RESPONSE CARDS").font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim).kerning(1)
                        Text("Cards get contextual-ranking priority when this issue is attached to the selection.")
                            .font(.system(size: 9)).foregroundStyle(AC.textGhost)
                        ForEach(issue.relatedCards) { rel in
                            HStack(spacing: 6) {
                                Text(availableCards.first(where: { $0.id == rel.cardID })?.title ?? "Unknown Card")
                                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(AC.text)
                                Text(rel.relationshipType.displayName).font(.system(size: 9)).foregroundStyle(AC.cyan)
                                Spacer()
                                Button(action: { issue.relatedCards.removeAll { $0.id == rel.id } }) {
                                    Image(systemName: "xmark.circle").font(.system(size: 10))
                                }
                                .buttonStyle(.plain).foregroundStyle(AC.textDim)
                            }
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 5).fill(AC.surface))
                        }
                        HStack(spacing: 6) {
                            Picker("Card", selection: $newRelatedCardID) {
                                Text("Choose a card…").tag(UUID?.none)
                                ForEach(availableCards) { card in Text(card.title).tag(Optional(card.id)) }
                            }
                            .labelsHidden().pickerStyle(.menu).tint(AC.cyan)
                            Picker("Relationship", selection: $newRelationshipType) {
                                ForEach(IssueCardRelationshipType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                            }
                            .labelsHidden().pickerStyle(.menu).tint(AC.cyan)
                            Button("Add") {
                                guard let cardID = newRelatedCardID else { return }
                                issue.relatedCards.append(IssueCardRelationship(cardID: cardID, relationshipType: newRelationshipType))
                                newRelatedCardID = nil
                            }
                            .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.55)))
                            .disabled(newRelatedCardID == nil)
                        }
                    }

                    field("Owner") { TextField("Optional", text: $issue.owner) }
                    field("Source") { TextField("Optional — where this came from", text: $issue.source) }
                    field("Tags (comma-separated)") { TextField("e.g. infrastructure, database", text: $tagsText) }
                    field("Notes") { TextEditor(text: $issue.notes).frame(minHeight: 44) }

                    field("Produces Blocking Conditions (one per line, while active)") {
                        multilineList($issue.blockingConditionsProduced)
                    }
                    field("Produces Known Information (one per line, while active/resolved)") {
                        multilineList($issue.knownInformationProduced)
                    }
                    field("Produces Unknown Information (one per line)") {
                        multilineList($issue.unknownInformationProduced)
                    }
                }
                .padding(14)
            }
        }
        .background(AC.bg)
        .colorScheme(.dark)
        .onAppear { tagsText = issue.tags.joined(separator: ", ") }
    }

    @ViewBuilder
    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(.system(size: 8, weight: .black, design: .monospaced)).foregroundStyle(AC.textDim).kerning(1)
            content().arenaFieldStyle()
        }
    }

    private func multilineList(_ binding: Binding<[String]>) -> some View {
        TextEditor(text: Binding(
            get: { binding.wrappedValue.joined(separator: "\n") },
            set: { binding.wrappedValue = $0.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        ))
        .frame(minHeight: 40)
    }
}
