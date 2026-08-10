import Foundation

/// Example system maps shipped with the app to demonstrate the feature.
public enum SystemMapTemplates {

    /// The "Inventory Resilience" example from the feature spec: a shared
    /// stocks/flows/relationships workflow, viewed under two scenarios —
    /// "Normal Operations" (the default) and "Supplier Failure," which
    /// overrides supplier capacity and disables the restocking flow to show
    /// the same diagram behaving differently under different conditions.
    public static func inventoryResilience() -> SystemMap {
        let inventory = SystemElement(
            kind: .stock,
            name: "Inventory",
            description: "Units currently in stock and available to sell.",
            position: SystemPoint(x: 320, y: 220),
            size: SystemSize(width: 140, height: 90),
            currentValue: 40,
            minimumValue: 0,
            maximumValue: 100,
            desiredValue: 60,
            unit: "units"
        )
        let cash = SystemElement(
            kind: .stock,
            name: "Available Cash",
            description: "Cash on hand available to spend on restocking.",
            position: SystemPoint(x: 540, y: 220),
            size: SystemSize(width: 140, height: 90),
            currentValue: 5000,
            minimumValue: 0,
            maximumValue: 20000,
            desiredValue: 8000,
            unit: "$"
        )
        let supplierCapacity = SystemElement(
            kind: .stock,
            name: "Supplier Capacity",
            description: "How much of your reorder the supplier can currently fulfill.",
            position: SystemPoint(x: 120, y: 100),
            size: SystemSize(width: 140, height: 90),
            currentValue: 70,
            minimumValue: 0,
            maximumValue: 100,
            desiredValue: 90,
            unit: "%"
        )
        let goal = SystemElement(
            kind: .goal,
            name: "Stockout-Free Growth",
            description: "The outcome this system is being steered toward.",
            position: SystemPoint(x: 320, y: 380),
            size: SystemSize(width: 130, height: 64),
            isPrimaryGoal: true,
            successCriteria: "Inventory never drops to 0 while carrying cost stays below budget.",
            failureCondition: "A stockout occurs, or cash runs out from over-ordering."
        )
        let constraint = SystemElement(
            kind: .constraint,
            name: "Storage Capacity",
            description: "Warehouse can hold at most 100 units.",
            position: SystemPoint(x: 320, y: 80),
            size: SystemSize(width: 120, height: 56)
        )

        let restocking = SystemFlow(
            name: "Restocking",
            description: "Cash is spent to bring new inventory in from the supplier.",
            sourceElementID: nil,
            targetElementID: inventory.id,
            direction: .inflow,
            rate: 20,
            capacity: 40
        )
        let sales = SystemFlow(
            name: "Sales",
            description: "Units leave inventory as customers buy them.",
            sourceElementID: inventory.id,
            targetElementID: nil,
            direction: .outflow,
            rate: 15
        )
        let returns = SystemFlow(
            name: "Returns",
            description: "A small share of sold units come back into inventory.",
            sourceElementID: nil,
            targetElementID: inventory.id,
            direction: .inflow,
            rate: 2
        )
        let waste = SystemFlow(
            name: "Waste",
            description: "Damaged or expired inventory leaves the system unsold.",
            sourceElementID: inventory.id,
            targetElementID: nil,
            direction: .outflow,
            rate: 1
        )

        let reorderLoop = SystemRelationship(
            sourceElementID: inventory.id,
            targetElementID: supplierCapacity.id,
            relationshipType: .balances,
            polarity: .negative,
            label: "Low inventory increases reorder pressure on the supplier"
        )
        let restockLoop = SystemRelationship(
            sourceElementID: supplierCapacity.id,
            targetElementID: inventory.id,
            relationshipType: .increases,
            polarity: .positive,
            label: "Higher supplier capacity increases restocking"
        )
        let carryingCost = SystemRelationship(
            sourceElementID: inventory.id,
            targetElementID: cash.id,
            relationshipType: .decreases,
            polarity: .negative,
            label: "Higher inventory increases carrying cost"
        )

        var map = SystemMap(
            title: "Inventory Resilience",
            description: "Balance restocking against demand and carrying cost without running out of stock.",
            primaryGoal: "Prevent stockouts without excessive carrying cost",
            failureCondition: "A stockout occurs, or cash runs out from over-ordering."
        )
        map.elements = [inventory, cash, supplierCapacity, goal, constraint]
        map.flows = [restocking, sales, returns, waste]
        map.relationships = [reorderLoop, restockLoop, carryingCost]

        var normalOperations = SystemScenario(name: "Normal Operations", description: "Demand is stable and the supplier can fulfill orders.", isDefault: true, order: 0)
        normalOperations.knownInformation = "Current inventory, cash, and supplier capacity levels are known."
        normalOperations.unknownInformation = "Actual customer demand rate has not yet been measured."

        var supplierFailure = SystemScenario(name: "Supplier Failure", description: "The primary supplier can no longer fulfill restocking orders.", isDefault: false, order: 1)
        supplierFailure.knownInformation = "The primary supplier has failed to deliver for two consecutive orders."
        supplierFailure.unknownInformation = "Whether the supplier will recover or needs to be replaced."
        supplierFailure.elementOverrides[supplierCapacity.id] = SystemElementOverride(currentValue: 0, state: .atRisk)
        supplierFailure.flowOverrides[restocking.id] = SystemFlowOverride(rate: 0, isEnabled: false, state: .disabled)

        map.scenarios = [normalOperations, supplierFailure]
        map.selectedScenarioID = normalOperations.id

        return map
    }
}
