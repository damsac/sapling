import Charts
import CoreLocation
import SwiftUI

struct ElevationProfileView: View {
    let trackPoints: [FfiTrackPoint]

    private struct Sample: Identifiable {
        let id: Int
        let distanceKm: Double
        let elevationM: Double
    }

    private var samples: [Sample] {
        var result: [Sample] = []
        var cumulativeM: Double = 0
        var prev: FfiTrackPoint? = nil
        for (i, pt) in trackPoints.enumerated() {
            guard let elev = pt.elevation else { prev = pt; continue }
            if let p = prev {
                cumulativeM += haversineM(
                    lat1: p.latitude, lon1: p.longitude,
                    lat2: pt.latitude, lon2: pt.longitude
                )
            }
            result.append(Sample(id: i, distanceKm: cumulativeM / 1000, elevationM: elev))
            prev = pt
        }
        return result
    }

    private var elevationGain: Double {
        var gain = 0.0
        let elevations = trackPoints.compactMap(\.elevation)
        for i in 1 ..< elevations.count {
            let delta = elevations[i] - elevations[i - 1]
            if delta > 0 { gain += delta }
        }
        return gain
    }

    private var minElevation: Double { trackPoints.compactMap(\.elevation).min() ?? 0 }
    private var maxElevation: Double { trackPoints.compactMap(\.elevation).max() ?? 0 }

    var body: some View {
        guard !samples.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Chart(samples) { s in
                    AreaMark(
                        x: .value("Distance", s.distanceKm),
                        y: .value("Elevation", s.elevationM)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [SaplingColors.brand.opacity(0.35), SaplingColors.brand.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Distance", s.distanceKm),
                        y: .value("Elevation", s.elevationM)
                    )
                    .foregroundStyle(SaplingColors.brand)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { v in
                        AxisGridLine()
                        AxisValueLabel {
                            if let d = v.as(Double.self) {
                                Text(String(format: "%.1f km", d))
                                    .font(.caption2)
                                    .foregroundStyle(SaplingColors.bark)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { v in
                        AxisGridLine()
                        AxisValueLabel {
                            if let e = v.as(Double.self) {
                                Text(formatElevation(e))
                                    .font(.caption2)
                                    .foregroundStyle(SaplingColors.bark)
                            }
                        }
                    }
                }
                .frame(height: 100)

                HStack(spacing: 16) {
                    ProfileStat(label: "Gain", value: "+\(formatElevation(elevationGain))")
                    ProfileStat(label: "Min", value: formatElevation(minElevation))
                    ProfileStat(label: "Max", value: formatElevation(maxElevation))
                }
            }
        )
    }
}

private struct ProfileStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(SaplingColors.ink)
            Text(label)
                .font(.caption2)
                .foregroundStyle(SaplingColors.bark)
        }
    }
}

private func haversineM(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let R = 6_371_000.0
    let φ1 = lat1 * .pi / 180
    let φ2 = lat2 * .pi / 180
    let Δφ = (lat2 - lat1) * .pi / 180
    let Δλ = (lon2 - lon1) * .pi / 180
    let a = sin(Δφ / 2) * sin(Δφ / 2) + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
    return R * 2 * atan2(sqrt(a), sqrt(1 - a))
}
