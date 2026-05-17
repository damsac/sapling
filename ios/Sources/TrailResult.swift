import CoreLocation
import Foundation

struct TrailResult: Identifiable {
    let id: String
    let name: String
    let distanceM: Double
    let coordinates: [CLLocationCoordinate2D]
    let description: String?
    let sacScale: String?
    let network: String?
    var allowsDogs: Bool? = nil
    var hasWater: Bool? = nil
    var hasCamping: Bool? = nil
    var trailVisibility: String? = nil
    var surface: String? = nil
    var website: String? = nil
    var isFeeRequired: Bool? = nil
    var osmAscent: Double? = nil
    var elevationProfile: [Double]? = nil
    var relevanceScore: Double = 0
}

enum TrailCategory: String, CaseIterable {
    case shortWalk   = "Short Walks"
    case dayHike     = "Day Hikes"
    case longDay     = "Long Days"
    case overnight   = "Overnight"

    var icon: String {
        switch self {
        case .shortWalk:  return "figure.walk"
        case .dayHike:    return "figure.hiking"
        case .longDay:    return "mountain.2"
        case .overnight:  return "tent"
        }
    }

    var subtitle: String {
        switch self {
        case .shortWalk:  return "Under 8 km · Great for families"
        case .dayHike:    return "8–20 km · Full day out"
        case .longDay:    return "20–35 km · Push your limits"
        case .overnight:  return "35 km+ · Multi-day adventure"
        }
    }
}

extension TrailResult {
    var elevationGainM: Double {
        if let a = osmAscent { return a }
        guard let p = elevationProfile, p.count >= 2 else { return 0 }
        return zip(p, p.dropFirst()).reduce(0.0) { acc, pair in
            let d = pair.1 - pair.0; return d > 0 ? acc + d : acc
        }
    }

    var visibilityLabel: String? {
        switch trailVisibility {
        case "excellent":                   return "Well-marked"
        case "good":                        return "Clear path"
        case "intermediate":               return "Some route-finding"
        case "bad":                         return "Faint trail"
        case "horrible", "no":             return "Expert navigation"
        default:                            return nil
        }
    }

    var visibilityIsWarning: Bool {
        trailVisibility == "bad" || trailVisibility == "horrible" || trailVisibility == "no"
    }

    var surfaceLabel: String? {
        switch surface?.lowercased() {
        case "paved", "asphalt", "concrete":            return "Paved"
        case "unpaved", "dirt", "ground", "earth", "soil": return "Dirt"
        case "gravel", "fine_gravel", "compacted":      return "Gravel"
        case "rock", "rocks", "stone", "cobblestone":   return "Rocky"
        case "grass":                                   return "Grass"
        case "sand":                                    return "Sand"
        case "wood", "boardwalk":                       return "Boardwalk"
        default:                                        return nil
        }
    }

    var category: TrailCategory {
        let km = distanceM / 1000
        if km < 8  { return .shortWalk }
        if km < 20 { return .dayHike }
        if km < 35 { return .longDay }
        return .overnight
    }

    var difficultyLabel: String? {
        switch sacScale {
        case "hiking":                       return "Easy"
        case "mountain_hiking":              return "Moderate"
        case "demanding_mountain_hiking":    return "Hard"
        case "alpine_hiking", "demanding_alpine_hiking", "difficult_alpine_hiking": return "Epic"
        default: return nil
        }
    }

    // OSM tag if available, otherwise computed from distance + elevation gain.
    // Score = distanceKm * 0.1 + gainM * 0.01; falls back to distance-only when
    // the elevation profile hasn't been fetched yet.
    var computedDifficultyLabel: String {
        if let label = difficultyLabel { return label }
        let km = distanceM / 1000
        if let profile = elevationProfile, !profile.isEmpty {
            let score = km * 0.1 + elevationGainM * 0.01
            if score < 2.0  { return "Easy" }
            if score < 6.0  { return "Moderate" }
            if score < 12.0 { return "Hard" }
            return "Epic"
        }
        // Distance-only fallback until elevation is loaded
        if km < 8  { return "Easy" }
        if km < 20 { return "Moderate" }
        if km < 35 { return "Hard" }
        return "Epic"
    }

    var isDifficultyEstimated: Bool { difficultyLabel == nil }
}
