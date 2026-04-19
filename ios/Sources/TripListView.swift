import SwiftUI

struct TripListView: View {
    var viewModel: TripListViewModel
    @State private var tripToDelete: FfiTripSummary? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.trips.isEmpty {
                    emptyState
                } else {
                    tripList
                }
            }
            .navigationTitle("Trips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Trip List

    private var tripList: some View {
        List {
            ForEach(viewModel.trips, id: \.id) { trip in
                NavigationLink(value: trip.id) {
                    TripRow(trip: trip)
                }
            }
            .onDelete { indexSet in
                guard let index = indexSet.first else { return }
                tripToDelete = viewModel.trips[index]
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: String.self) { tripId in
            if let trip = viewModel.trips.first(where: { $0.id == tripId }) {
                TripDetailView(trip: trip, viewModel: viewModel)
            }
        }
        .alert("Delete Trip?", isPresented: Binding(
            get: { tripToDelete != nil },
            set: { if !$0 { tripToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { tripToDelete = nil }
            Button("Delete", role: .destructive) {
                if let trip = tripToDelete {
                    viewModel.deleteTrip(id: trip.id)
                    tripToDelete = nil
                }
            }
        } message: {
            if let trip = tripToDelete {
                Text("Are you sure you want to delete \"\(trip.name)\"?")
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.hiking")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No trips yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Hit record and go for a walk.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Trip Row

private struct TripRow: View {
    let trip: FfiTripSummary

    var body: some View {
        HStack(spacing: 12) {
            // Brand accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(SaplingColors.brand)
                .frame(width: 3)
                .frame(minHeight: 44)

            VStack(alignment: .leading, spacing: 5) {
                Text(trip.name)
                    .font(.headline.weight(.semibold))

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Label(formatDistance(trip.distanceM), systemImage: "arrow.left.and.right")
                    Text("·")
                    Label(formatDuration(trip.durationMs), systemImage: "clock")
                    Text("·")
                    Label("+\(formatElevation(trip.elevationGain))", systemImage: "arrow.up")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .labelStyle(.titleOnly)

                if trip.seedCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.caption2)
                            .foregroundStyle(SaplingColors.brand)
                        Text("\(trip.seedCount) seed\(trip.seedCount == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(SaplingColors.brand.opacity(0.8))
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var formattedDate: String {
        // Parse RFC 3339 date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: trip.createdAt) else {
            // Fallback without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: trip.createdAt) else {
                return trip.createdAt
            }
            return formatTripDate(date)
        }
        return formatTripDate(date)
    }

    private func formatTripDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            return "Today, \(timeFormatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            return "Yesterday, \(timeFormatter.string(from: date))"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d, h:mm a"
            return dateFormatter.string(from: date)
        }
    }
}
