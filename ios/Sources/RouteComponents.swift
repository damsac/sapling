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

// MARK: - Multi-Day Plan Section

struct MultiDayPlanSection: View {
    let coordinates: [CLLocationCoordinate2D]
    let elevations: [Double]?
    let seeds: [SeedOnRoute]
    @Binding var numDays: Int

    private var segments: [DaySegment] {
        computeDaySegments(coordinates: coordinates, elevations: elevations, seeds: seeds, numDays: numDays)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Multi-Day Plan")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SaplingColors.bark)
                Spacer()
                Stepper(value: $numDays, in: 2...14) {
                    Text("\(numDays) days")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SaplingColors.ink)
                }
                .fixedSize()
            }

            VStack(spacing: 8) {
                ForEach(segments) { seg in
                    DaySegmentCard(segment: seg)
                }
            }
        }
        .padding(14)
        .background(SaplingColors.stone, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct DaySegmentCard: View {
    let segment: DaySegment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Day \(segment.day)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(SaplingColors.brand, in: Capsule())
                if let stop = segment.campStop {
                    Text("→ \(stop)")
                        .font(.caption)
                        .foregroundStyle(SaplingColors.ink)
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(spacing: 0) {
                DayStatCell(label: "Distance", value: formatDistance(segment.distanceM))
                Divider().frame(height: 20)
                DayStatCell(label: "Est. Time", value: formatDurationMinutes(segment.estimatedMinutes))
                if segment.elevationGainM > 5 {
                    Divider().frame(height: 20)
                    DayStatCell(label: "Gain", value: "+\(formatElevation(segment.elevationGainM))")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(SaplingColors.bark.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

            if !segment.seeds.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(segment.seeds, id: \.seed.id) { item in
                            HStack(spacing: 3) {
                                Image(systemName: item.seed.seedType.sfSymbol)
                                    .font(.caption2)
                                    .foregroundStyle(item.seed.seedType.color)
                                Text(item.seed.title)
                                    .font(.caption2)
                                    .foregroundStyle(SaplingColors.ink)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(item.seed.seedType.color.opacity(0.1), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct DayStatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SaplingColors.ink)
            Text(label)
                .font(.caption2)
                .foregroundStyle(SaplingColors.bark)
        }
        .frame(maxWidth: .infinity)
    }
}
