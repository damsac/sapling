import CoreLocation
import Foundation

// MARK: - Distance helpers

func haversineM(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    let R = 6_371_000.0
    let φ1 = a.latitude * .pi / 180, φ2 = b.latitude * .pi / 180
    let Δφ = (b.latitude - a.latitude) * .pi / 180
    let Δλ = (b.longitude - a.longitude) * .pi / 180
    let x = sin(Δφ/2)*sin(Δφ/2) + cos(φ1)*cos(φ2)*sin(Δλ/2)*sin(Δλ/2)
    return R * 2 * atan2(sqrt(x), sqrt(1-x))
}

/// Bearing in degrees [0, 360) from a to b.
private func bearing(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    let lat1 = a.latitude * .pi / 180
    let lat2 = b.latitude * .pi / 180
    let dLon = (b.longitude - a.longitude) * .pi / 180
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1)*sin(lat2) - sin(lat1)*cos(lat2)*cos(dLon)
    return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
}

/// Signed angular difference from b1 to b2 (positive = right/clockwise).
private func angleDiff(_ b1: Double, _ b2: Double) -> Double {
    var d = b2 - b1
    if d > 180 { d -= 360 }
    if d < -180 { d += 360 }
    return d
}

/// Perpendicular distance from point p to segment [a, b] in meters.
func distanceToSegment(_ p: CLLocationCoordinate2D, from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
    let pa = haversineM(p, a)
    let ab = haversineM(a, b)
    guard ab > 0 else { return pa }
    let t = max(0, min(1, dotOnSegment(p, a: a, b: b)))
    let proj = CLLocationCoordinate2D(
        latitude: a.latitude + t * (b.latitude - a.latitude),
        longitude: a.longitude + t * (b.longitude - a.longitude)
    )
    return haversineM(p, proj)
}

private func dotOnSegment(_ p: CLLocationCoordinate2D, a: CLLocationCoordinate2D, b: CLLocationCoordinate2D) -> Double {
    let abLat = b.latitude - a.latitude
    let abLon = b.longitude - a.longitude
    let apLat = p.latitude - a.latitude
    let apLon = p.longitude - a.longitude
    let denom = abLat*abLat + abLon*abLon
    guard denom > 0 else { return 0 }
    return (apLat*abLat + apLon*abLon) / denom
}

// MARK: - Route progress

/// Index of the nearest point on route to the user.
func nearestRouteIndex(_ route: [CLLocationCoordinate2D], to user: CLLocationCoordinate2D) -> Int {
    var best = 0
    var bestDist = Double.infinity
    for (i, pt) in route.enumerated() {
        let d = haversineM(user, pt)
        if d < bestDist { bestDist = d; best = i }
    }
    return best
}

/// Straight-line distance from user to the nearest point on the route polyline.
func distanceFromRoute(_ route: [CLLocationCoordinate2D], user: CLLocationCoordinate2D) -> Double {
    guard route.count >= 2 else {
        return route.first.map { haversineM(user, $0) } ?? .infinity
    }
    var minDist = Double.infinity
    for i in 0..<(route.count - 1) {
        let d = distanceToSegment(user, from: route[i], to: route[i+1])
        if d < minDist { minDist = d }
    }
    return minDist
}

/// Distance remaining from the nearest route point forward to the end.
func distanceRemaining(_ route: [CLLocationCoordinate2D], user: CLLocationCoordinate2D) -> Double {
    guard route.count >= 2 else { return 0 }
    let idx = nearestRouteIndex(route, to: user)
    var dist = 0.0
    for i in idx..<(route.count - 1) {
        dist += haversineM(route[i], route[i+1])
    }
    return dist
}

/// Total polyline length in meters.
func totalRouteLength(_ route: [CLLocationCoordinate2D]) -> Double {
    guard route.count >= 2 else { return 0 }
    return zip(route, route.dropFirst()).reduce(0) { $0 + haversineM($1.0, $1.1) }
}

// MARK: - Bearing change detection

struct BearingChange {
    let distanceM: Double
    let label: String   // e.g. "bear left", "turn right"
}

/// Finds the next significant bearing change ahead of the user on the route.
func nextBearingChange(
    _ route: [CLLocationCoordinate2D],
    user: CLLocationCoordinate2D,
    threshold: Double = 22.0
) -> BearingChange? {
    guard route.count >= 3 else { return nil }
    let start = nearestRouteIndex(route, to: user)
    var cumDist = 0.0

    for i in start..<(route.count - 2) {
        cumDist += haversineM(route[i], route[i+1])
        let b1 = bearing(route[i], route[i+1])
        let b2 = bearing(route[i+1], route[i+2])
        let delta = angleDiff(b1, b2)
        if abs(delta) >= threshold {
            let label = turnLabel(delta)
            return BearingChange(distanceM: cumDist, label: label)
        }
    }
    return nil
}

private func turnLabel(_ delta: Double) -> String {
    switch abs(delta) {
    case 0..<35:  return delta > 0 ? "bear right" : "bear left"
    case 35..<80: return delta > 0 ? "veer right" : "veer left"
    default:      return delta > 0 ? "turn right" : "turn left"
    }
}

// MARK: - Elevation stats from waypoints

struct RouteElevationStats {
    let gain: Double
    let loss: Double
    let minElev: Double
    let maxElev: Double
    let hasData: Bool
}

func elevationStats(from waypoints: [FfiRouteWaypoint]) -> RouteElevationStats {
    let elevs = waypoints.compactMap(\.elevation)
    guard elevs.count >= 2 else {
        return RouteElevationStats(gain: 0, loss: 0, minElev: 0, maxElev: 0, hasData: false)
    }
    var gain = 0.0, loss = 0.0
    for i in 1..<elevs.count {
        let d = elevs[i] - elevs[i-1]
        if d > 0 { gain += d } else { loss += -d }
    }
    return RouteElevationStats(
        gain: gain, loss: loss,
        minElev: elevs.min()!, maxElev: elevs.max()!,
        hasData: true
    )
}

// MARK: - Naismith estimated time

/// Returns estimated duration in minutes using Naismith's Rule.
/// 5 km/hr base + 1hr per 600m of gain.
func naismithMinutes(distanceM: Double, elevationGainM: Double) -> Int {
    let base = (distanceM / 1000.0) / 5.0 * 60.0  // minutes at 5km/hr
    let gainPenalty = (elevationGainM / 600.0) * 60.0
    return Int((base + gainPenalty).rounded())
}

func formatDurationMinutes(_ minutes: Int) -> String {
    if minutes < 60 { return "\(minutes)m" }
    let h = minutes / 60, m = minutes % 60
    return m == 0 ? "\(h)h" : "\(h)h \(m)m"
}

// MARK: - Difficulty

enum RouteDifficulty: String {
    case easy = "Easy"
    case moderate = "Moderate"
    case hard = "Hard"
    case epic = "Epic"

    var color: String {
        switch self {
        case .easy:     return "green"
        case .moderate: return "yellow"
        case .hard:     return "orange"
        case .epic:     return "red"
        }
    }
}

func routeDifficulty(distanceM: Double, gainM: Double) -> RouteDifficulty {
    let km = distanceM / 1000
    switch (km, gainM) {
    case _ where km > 30 || gainM > 2000: return .epic
    case _ where km > 16 || gainM > 900:  return .hard
    case _ where km > 8  || gainM > 300:  return .moderate
    default:                               return .easy
    }
}

// MARK: - Seeds near route

struct SeedOnRoute {
    let seed: FfiSeed
    let distanceAlongM: Double
}

/// Seeds within `radiusM` metres of the route polyline, sorted by distance from the start.
func seedsNearRoute(
    _ seeds: [FfiSeed],
    waypoints: [FfiRouteWaypoint],
    radiusM: Double = 500
) -> [SeedOnRoute] {
    let coords = waypoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    guard coords.count >= 2 else { return [] }
    return seeds.compactMap { seed in
        let pt = CLLocationCoordinate2D(latitude: seed.latitude, longitude: seed.longitude)
        guard distanceFromRoute(coords, user: pt) <= radiusM else { return nil }
        return SeedOnRoute(seed: seed, distanceAlongM: distanceAlongRoute(coords, to: pt))
    }
    .sorted { $0.distanceAlongM < $1.distanceAlongM }
}

/// Distance along the route polyline from the start to the point nearest `target`.
func distanceAlongRoute(_ route: [CLLocationCoordinate2D], to target: CLLocationCoordinate2D) -> Double {
    guard route.count >= 2 else { return 0 }
    let idx = nearestRouteIndex(route, to: target)
    return (0..<idx).reduce(0.0) { $0 + haversineM(route[$1], route[$1 + 1]) }
}

func elevationStatsFromProfile(_ profile: [Double]) -> RouteElevationStats {
    guard profile.count >= 2 else {
        return RouteElevationStats(gain: 0, loss: 0, minElev: 0, maxElev: 0, hasData: false)
    }
    var gain = 0.0, loss = 0.0
    for i in 1..<profile.count {
        let d = profile[i] - profile[i-1]
        if d > 0 { gain += d } else { loss += -d }
    }
    return RouteElevationStats(
        gain: gain, loss: loss,
        minElev: profile.min()!, maxElev: profile.max()!,
        hasData: true
    )
}

func seedsNearRoute(
    _ seeds: [FfiSeed],
    coordinates: [CLLocationCoordinate2D],
    radiusM: Double = 500
) -> [SeedOnRoute] {
    guard coordinates.count >= 2 else { return [] }
    return seeds.compactMap { seed in
        let pt = CLLocationCoordinate2D(latitude: seed.latitude, longitude: seed.longitude)
        guard distanceFromRoute(coordinates, user: pt) <= radiusM else { return nil }
        return SeedOnRoute(seed: seed, distanceAlongM: distanceAlongRoute(coordinates, to: pt))
    }
    .sorted { $0.distanceAlongM < $1.distanceAlongM }
}

// MARK: - Camp recommendations

struct CampRecommendation: Identifiable {
    let id = UUID()
    let day: Int
    let distanceAlongM: Double
    let rationale: String
}

func computeCampRecommendations(
    coordinates: [CLLocationCoordinate2D],
    elevations: [Double]?,
    totalDistanceM: Double,
    estimatedMinutes: Int
) -> [CampRecommendation] {
    let days = max(2, (estimatedMinutes + 479) / 480)
    guard days >= 2, coordinates.count >= 2 else { return [] }

    // Build cumulative distance table along the coordinate array.
    var cumDist: [Double] = [0]
    for i in 1..<coordinates.count {
        cumDist.append(cumDist[i - 1] + haversineM(coordinates[i - 1], coordinates[i]))
    }
    let actualTotal = cumDist.last ?? totalDistanceM

    var result: [CampRecommendation] = []
    for night in 1..<days {
        let targetDist = actualTotal * Double(night) / Double(days)
        let coordIdx = cumDist.firstIndex(where: { $0 >= targetDist }) ?? (coordinates.count - 1)

        var reasons: [String] = ["~\(formatDistance(targetDist)) mark"]

        if let elevs = elevations, elevs.count >= 4 {
            let t = Double(coordIdx) / Double(max(1, coordinates.count - 1))
            let ei = min(max(Int((t * Double(elevs.count - 1)).rounded()), 0), elevs.count - 1)

            let w1lo = max(0, ei - 5), w1hi = min(elevs.count - 1, ei + 5)
            let w1 = Array(elevs[w1lo...w1hi])
            let mean1 = w1.reduce(0, +) / Double(w1.count)
            let stdDev = sqrt(w1.map { ($0 - mean1) * ($0 - mean1) }.reduce(0, +) / Double(w1.count))

            let w2lo = max(0, ei - 15), w2hi = min(elevs.count - 1, ei + 15)
            let w2 = Array(elevs[w2lo...w2hi])
            let mean2 = w2.reduce(0, +) / Double(w2.count)

            if stdDev < 30 { reasons.append("flat terrain") }
            if elevs[ei] < mean2 - 15 { reasons.append("valley — water likely nearby") }
        }

        result.append(CampRecommendation(
            day: night,
            distanceAlongM: targetDist,
            rationale: reasons.joined(separator: " · ")
        ))
    }
    return result
}
