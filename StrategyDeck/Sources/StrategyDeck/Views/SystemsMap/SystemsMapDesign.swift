import SwiftUI
import StrategyDeckCore

// MARK: - Diagram selection & tools (view-layer only; not persisted)

enum DiagramSelection: Hashable {
    case element(UUID)
    case flow(UUID)
    case relationship(UUID)
}

enum DiagramTool: Equatable {
    case select
    case addStock, addDelay, addConstraint, addGoal, addNote
    case addFlow, addRelationship
    case connect

    var isAddElementTool: Bool {
        switch self {
        case .addStock, .addDelay, .addConstraint, .addGoal, .addNote: return true
        default: return false
        }
    }

    var elementKind: SystemElementKind? {
        switch self {
        case .addStock: return .stock
        case .addDelay: return .delay
        case .addConstraint: return .constraint
        case .addGoal: return .goal
        case .addNote: return .note
        default: return nil
        }
    }

    var label: String {
        switch self {
        case .select: return "Select"
        case .addStock: return "Add Stock"
        case .addDelay: return "Add Delay"
        case .addConstraint: return "Add Constraint"
        case .addGoal: return "Add Goal"
        case .addNote: return "Add Note"
        case .addFlow: return "Add Flow"
        case .addRelationship: return "Add Relationship"
        case .connect: return "Connect"
        }
    }

    var systemImage: String {
        switch self {
        case .select: return "cursorarrow"
        case .addStock: return "cylinder.split.1x2"
        case .addDelay: return "hourglass"
        case .addConstraint: return "exclamationmark.triangle"
        case .addGoal: return "flag.checkered"
        case .addNote: return "note.text"
        case .addFlow: return "arrow.right"
        case .addRelationship: return "link"
        case .connect: return "point.3.connected.trianglepath.dotted"
        }
    }
}

// MARK: - Color/style mapping onto the arena palette

extension SystemElementKind {
    var arenaColor: Color {
        switch self {
        case .stock: return AC.cyan
        case .delay: return .purple
        case .constraint: return AC.threat
        case .goal: return AC.gold
        case .note: return AC.textDim
        }
    }
}

extension RelationshipType {
    var arenaColor: Color {
        switch self {
        case .reinforces: return AC.available
        case .balances: return AC.cyan
        case .increases: return AC.available
        case .decreases: return AC.threat
        case .enables: return AC.cyan
        case .disables: return AC.threat
        case .constrains: return .orange
        case .suppliesInformationTo: return .purple
        case .triggers: return AC.gold
        case .delays: return AC.textDim
        case .dependsOn: return AC.textSub
        }
    }
}

extension SystemCardStatus {
    var arenaColor: Color {
        switch self {
        case .active: return AC.cyan
        case .available: return AC.available
        case .recommended: return AC.gold
        case .locked: return AC.lockedTint
        case .disabled: return AC.threat
        case .exhausted: return .orange
        case .resolved: return AC.resolved
        case .pending: return .purple
        case .irrelevant: return AC.textGhost
        }
    }
}
