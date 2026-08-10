import SwiftUI
import StrategyDeckCore

/// The fast path for adding a card: title only, with optional suite and
/// short description. Creating a card does not close this — the fields
/// clear and the title field re-focuses so a whole deck's worth of cards
/// can be typed in one sitting, one Return per card. The selected suite is
/// remembered for as long as this stays open (a plain `@State`, since
/// SwiftUI keeps it alive for the popover's whole presentation).
struct QuickCreateCardPopover: View {
    let suits: [CardSuit]
    /// title, suiteID, shortDescription
    let onCreate: (String, String?, String) -> Void
    /// title, suiteID, shortDescription — create, then open the full editor on it.
    let onCreateAndEdit: (String, String?, String) -> Void
    let onCreateSuite: ((String) -> CardSuit)?
    let onOpenBlankFullEditor: () -> Void
    let onClose: () -> Void

    init(
        suits: [CardSuit],
        initialSuitID: String? = nil,
        onCreate: @escaping (String, String?, String) -> Void,
        onCreateAndEdit: @escaping (String, String?, String) -> Void,
        onCreateSuite: ((String) -> CardSuit)? = nil,
        onOpenBlankFullEditor: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.suits = suits
        self.onCreate = onCreate
        self.onCreateAndEdit = onCreateAndEdit
        self.onCreateSuite = onCreateSuite
        self.onOpenBlankFullEditor = onOpenBlankFullEditor
        self.onClose = onClose
        _selectedSuitID = State(initialValue: initialSuitID)
    }

    @State private var title = ""
    @State private var shortDescription = ""
    @State private var selectedSuitID: String?
    @State private var showingNewSuiteField = false
    @FocusState private var titleFocused: Bool

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("QUICK ADD CARD")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.cyan)
                    .kerning(1)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(AC.textDim)
                .keyboardShortcut(.escape)
            }

            TextField("Card title…", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AC.text)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 5).fill(AC.surface).overlay(RoundedRectangle(cornerRadius: 5).stroke(AC.borderDim, lineWidth: 0.75)))
                .focused($titleFocused)
                .onSubmit(addAndStayOpen)

            if onCreateSuite != nil {
                suiteField
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("SHORT DESCRIPTION (OPTIONAL)")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.textDim)
                    .kerning(1)
                TextField("One line…", text: $shortDescription)
                    .arenaFieldStyle()
                    .onSubmit(addAndStayOpen)
            }

            Rectangle().fill(AC.borderDim).frame(height: 1)

            HStack(spacing: 6) {
                Button("Open Full Editor", action: onOpenBlankFullEditor)
                    .buttonStyle(ArenaOutlineButtonStyle())
                Spacer()
                Button("Add and Edit Details", action: addAndEdit)
                    .buttonStyle(ArenaOutlineButtonStyle(color: AC.cyan.opacity(0.6)))
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(trimmedTitle.isEmpty)
                Button("Add Card", action: addAndStayOpen)
                    .buttonStyle(ArenaButtonStyle(isDisabled: trimmedTitle.isEmpty))
                    .disabled(trimmedTitle.isEmpty)
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(AC.bg)
        .colorScheme(.dark)
        .onAppear { titleFocused = true }
    }

    @ViewBuilder
    private var suiteField: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("SUITE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(AC.textDim)
                    .kerning(1)
                Spacer()
                Button(action: { withAnimation(.easeInOut(duration: 0.12)) { showingNewSuiteField.toggle() } }) {
                    Image(systemName: showingNewSuiteField ? "xmark.circle" : "plus.circle")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AC.textDim)
                .help("Create a new suite without leaving this form")
            }
            if showingNewSuiteField {
                InlineCreateRow(placeholder: "New suite name…", autoFocus: true) { name in
                    guard let onCreateSuite else { return }
                    let suit = onCreateSuite(name)
                    selectedSuitID = suit.id
                    showingNewSuiteField = false
                }
            } else if suits.isEmpty {
                Text("No suites yet — use + above to create one.")
                    .font(.system(size: 10))
                    .foregroundStyle(AC.textGhost)
            } else {
                Picker("Suite", selection: $selectedSuitID) {
                    Text("No Suite").tag(String?.none)
                    ForEach(suits.sorted { $0.displayOrder < $1.displayOrder }) { s in
                        Text(s.name).tag(Optional(s.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(AC.cyan)
            }
        }
    }

    private func addAndStayOpen() {
        guard !trimmedTitle.isEmpty else { return }
        onCreate(trimmedTitle, selectedSuitID, shortDescription.trimmingCharacters(in: .whitespacesAndNewlines))
        title = ""
        shortDescription = ""
        titleFocused = true
    }

    private func addAndEdit() {
        guard !trimmedTitle.isEmpty else { return }
        onCreateAndEdit(trimmedTitle, selectedSuitID, shortDescription.trimmingCharacters(in: .whitespacesAndNewlines))
        title = ""
        shortDescription = ""
    }
}
