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
    var elevationProfile: [Double]? = nil
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
        guard let p = elevationProfile, p.count >= 2 else { return 0 }
        return zip(p, p.dropFirst()).reduce(0.0) { acc, pair in
            let d = pair.1 - pair.0; return d > 0 ? acc + d : acc
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
}
