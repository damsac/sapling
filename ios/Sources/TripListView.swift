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
        VStack(alignment: .leading, spacing: 4) {
            Text(trip.name)
                .font(.headline.weight(.semibold))

            Text(formattedDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(formatDistance(trip.distanceM))
                Text("\u{00B7}")
                Text(formatDuration(trip.durationMs))
                Text("\u{00B7}")
                Text("+\(formatElevation(trip.elevationGain))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
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
