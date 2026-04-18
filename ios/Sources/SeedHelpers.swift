import SwiftUI

// MARK: - Seed Type Display Properties

extension FfiSeedType {
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
        case .custom: "Custom Seed"
        }
    }

    var color: Color {
        switch self {
        case .water: SaplingColors.water
        case .camp: SaplingColors.camp
        case .beauty: SaplingColors.beauty
        case .service: SaplingColors.service
        case .custom: SaplingColors.custom
        }
    }

    var uiColor: UIColor {
        switch self {
        case .water: SaplingColors.waterUI
        case .camp: SaplingColors.campUI
        case .beauty: SaplingColors.beautyUI
        case .service: SaplingColors.serviceUI
        case .custom: SaplingColors.customUI
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

// MARK: - Seed Type Ordering

/// All seed types in display order.
let allSeedTypes: [FfiSeedType] = [.water, .camp, .beauty, .service, .custom]
