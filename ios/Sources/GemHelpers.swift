import SwiftUI

// MARK: - Gem Type Display Properties

extension FfiGemType {
    var displayName: String {
        switch self {
        case .water: "Water"
        case .camp: "Camp"
        case .beauty: "Beauty"
        case .service: "Service"
        case .custom: "Custom"
        }
    }

    var defaultTitle: String {
        switch self {
        case .water: "Water Source"
        case .camp: "Campsite"
        case .beauty: "Beautiful Spot"
        case .service: "Service Area"
        case .custom: "Custom Gem"
        }
    }

    var color: Color {
        switch self {
        case .water: Color(red: 0.231, green: 0.510, blue: 0.965)   // #3B82F6
        case .camp: Color(red: 0.573, green: 0.251, blue: 0.055)    // #92400E
        case .beauty: Color(red: 0.851, green: 0.467, blue: 0.024)  // #D97706
        case .service: Color(red: 0.486, green: 0.235, blue: 0.929) // #7C3AED
        case .custom: Color(red: 0.420, green: 0.451, blue: 0.498)  // #6B7280
        }
    }

    var uiColor: UIColor {
        switch self {
        case .water: UIColor(red: 0.231, green: 0.510, blue: 0.965, alpha: 1)
        case .camp: UIColor(red: 0.573, green: 0.251, blue: 0.055, alpha: 1)
        case .beauty: UIColor(red: 0.851, green: 0.467, blue: 0.024, alpha: 1)
        case .service: UIColor(red: 0.486, green: 0.235, blue: 0.929, alpha: 1)
        case .custom: UIColor(red: 0.420, green: 0.451, blue: 0.498, alpha: 1)
        }
    }

    var sfSymbol: String {
        switch self {
        case .water: "drop.fill"
        case .camp: "tent.fill"
        case .beauty: "sparkles"
        case .service: "antenna.radiowaves.left.and.right"
        case .custom: "diamond.fill"
        }
    }
}

// MARK: - Gem Type Ordering

/// All gem types in display order.
let allGemTypes: [FfiGemType] = [.water, .camp, .beauty, .service, .custom]
