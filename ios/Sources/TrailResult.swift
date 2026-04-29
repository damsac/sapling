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

extension TrailResult {
    var elevationGainM: Double {
        guard let p = elevationProfile, p.count >= 2 else { return 0 }
        return zip(p, p.dropFirst()).reduce(0.0) { acc, pair in
            let d = pair.1 - pair.0; return d > 0 ? acc + d : acc
        }
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
