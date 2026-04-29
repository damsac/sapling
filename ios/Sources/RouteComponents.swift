import Charts
import CoreLocation
import MapLibre
import MapLibreSwiftDSL
import MapLibreSwiftUI
import SwiftUI

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let difficulty: RouteDifficulty

    private var color: Color {
        switch difficulty {
        case .easy:     return .green
        case .moderate: return Color(hue: 0.13, saturation: 0.8, brightness: 0.85)
        case .hard:     return .orange
        case .epic:     return .red
        }
    }

    var body: some View {
        Text(difficulty.rawValue)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color, in: Capsule())
    }
}

// MARK: - Route Stat Cell

struct RouteStatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SaplingColors.ink)
            Text(label)
                .font(.caption2)
                .foregroundStyle(SaplingColors.bark)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Elevation Profile Card

struct ElevationProfileCard: View {
    let elevations: [Double]
    let stats: RouteElevationStats

    private var baseline: Double { stats.minElev - max(10, (stats.maxElev - stats.minElev) * 0.12) }
    private var ceiling: Double { stats.maxElev + max(10, (stats.maxElev - stats.minElev) * 0.12) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Elevation Profile")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SaplingColors.bark)

            Chart {
                ForEach(Array(elevations.enumerated()), id: \.offset) { i, elev in
                    AreaMark(
                        x: .value("Point", i),
                        yStart: .value("Base", baseline),
                        yEnd: .value("Elevation", elev)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [SaplingColors.brand.opacity(0.22), SaplingColors.brand.opacity(0.04)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Point", i),
                        y: .value("Elevation", elev)
                    )
                    .foregroundStyle(SaplingColors.brand)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            .chartYScale(domain: baseline...ceiling)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatElevation(v))
                                .font(.caption2)
                                .foregroundStyle(SaplingColors.bark)
                        }
                    }
                }
            }
            .frame(height: 100)

            HStack(spacing: 0) {
                ElevMiniStat(label: "Gain", value: "+\(formatElevation(stats.gain))", color: SaplingColors.brand)
                ElevMiniStat(label: "Loss", value: "-\(formatElevation(stats.loss))", color: SaplingColors.accent)
                ElevMiniStat(label: "High Point", value: formatElevation(stats.maxElev), color: SaplingColors.ink)
            }
        }
        .padding(14)
        .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct ElevMiniStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(SaplingColors.bark)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Route Map Preview

struct RouteMapPreview: View {
    let coordinates: [CLLocationCoordinate2D]
    var sourceId: String = "route-preview"

    private var bounds: CoordinateBBox { boundingBox(for: coordinates) }
    private var center: CLLocationCoordinate2D { bounds.center }
    private var zoom: Double { zoomToFit(bounds: bounds) }

    var body: some View {
        MapView(
            styleURL: URL(string: "https://tiles.openfreemap.org/styles/liberty")!,
            camera: .constant(.center(center, zoom: zoom))
        ) {
            let src = ShapeSource(identifier: sourceId) {
                MLNPolylineFeature(coordinates: coordinates)
            }
            LineStyleLayer(identifier: "\(sourceId)-line", source: src)
                .lineColor(SaplingColors.brandUI)
                .lineWidth(3)
                .lineCap(.round)
                .lineJoin(.round)
        }
        .mapControls { LogoView().position(.bottomLeft) }
    }
}

// MARK: - Seeds Along Route Section

struct SeedsAlongRouteSection: View {
    let seeds: [SeedOnRoute]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Seeds Along Route")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SaplingColors.bark)
                Spacer()
                Text("\(seeds.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SaplingColors.brand)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(SaplingColors.brand.opacity(0.1), in: Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(allSeedTypes, id: \.displayName) { type in
                        let count = seeds.filter { $0.seed.seedType == type }.count
                        if count > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: type.sfSymbol)
                                    .font(.caption2)
                                    .foregroundStyle(type.color)
                                Text("\(count) \(type.displayName)")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(SaplingColors.ink)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(type.color.opacity(0.1), in: Capsule())
                        }
                    }
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(seeds.enumerated()), id: \.element.seed.id) { i, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text(formatDistance(item.distanceAlongM))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(SaplingColors.bark)
                            .frame(width: 44, alignment: .trailing)
                            .padding(.top, 5)

                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(item.seed.seedType.color)
                                    .frame(width: 28, height: 28)
                                Image(systemName: item.seed.seedType.sfSymbol)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                            }
                            if i < seeds.count - 1 {
                                Rectangle()
                                    .fill(SaplingColors.bark.opacity(0.2))
                                    .frame(width: 1.5, height: 28)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.seed.title)
                                .font(.subheadline)
                                .foregroundStyle(SaplingColors.ink)
                            if let notes = item.seed.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption2)
                                    .foregroundStyle(SaplingColors.bark)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.top, 4)

                        Spacer()
                    }
                }
            }
        }
        .padding(14)
        .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Day Breakdown Section

struct DayBreakdownSection: View {
    let campSeeds: [SeedOnRoute]
    let recommendations: [CampRecommendation]
    let totalDistanceM: Double
    let estimatedMinutes: Int

    private var days: Int { max(2, (estimatedMinutes + 479) / 480) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Multi-Day Planning")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SaplingColors.bark)

            if !campSeeds.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(daySegments.enumerated()), id: \.offset) { i, seg in
                        HStack(spacing: 8) {
                            Text("Day \(i + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(SaplingColors.brand, in: Capsule())
                            Text(seg.label)
                                .font(.subheadline)
                                .foregroundStyle(SaplingColors.ink)
                                .lineLimit(1)
                            Spacer()
                            Text(formatDistance(seg.distanceM))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SaplingColors.bark)
                        }
                    }
                }
            } else if !recommendations.isEmpty {
                VStack(spacing: 0) {
                    ForEach(recommendations) { rec in
                        HStack(alignment: .top, spacing: 10) {
                            Text("Night \(rec.day)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(SaplingColors.accent, in: Capsule())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Suggested camp")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(SaplingColors.ink)
                                Text(rec.rationale)
                                    .font(.caption2)
                                    .foregroundStyle(SaplingColors.bark)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        if rec.day < recommendations.count {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(SaplingColors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

                Text("Add camp seeds along the route to customize your plan.")
                    .font(.caption2)
                    .foregroundStyle(SaplingColors.bark)
                    .padding(.top, 2)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "moon.stars.fill")
                        .font(.title3)
                        .foregroundStyle(SaplingColors.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("~\(days) days estimated")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(SaplingColors.ink)
                        Text("Loading elevation data for camp recommendations…")
                            .font(.caption2)
                            .foregroundStyle(SaplingColors.bark)
                    }
                    Spacer()
                }
                .padding(10)
                .background(SaplingColors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(14)
        .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 14))
    }

    private struct DaySegment { let label: String; let distanceM: Double }

    private var daySegments: [DaySegment] {
        var result: [DaySegment] = []
        var prevDist = 0.0
        var checkpoints = campSeeds.map { ($0.seed.title, $0.distanceAlongM) }
        checkpoints.append(("End", totalDistanceM))
        for (name, dist) in checkpoints {
            result.append(DaySegment(label: "→ \(name)", distanceM: dist - prevDist))
            prevDist = dist
        }
        return result
    }
}
