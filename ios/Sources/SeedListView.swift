import SwiftUI
import CoreLocation

struct SeedListView: View {
    @Bindable var viewModel: SeedViewModel
    var currentLocation: CLLocationCoordinate2D?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.seeds.isEmpty && currentLocation == nil {
                    emptyState
                } else {
                    seedList
                }
            }
            .navigationTitle("Seeds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { viewModel.loadSeeds() }
    }

    // MARK: - Seed List

    private var seedList: some View {
        List {
            if let location = currentLocation {
                Section("Drop a seed here") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(allSeedTypes, id: \.displayName) { type in
                                Button {
                                    viewModel.quickDropSeed(type: type, at: location)
                                    dismiss()
                                } label: {
                                    VStack(spacing: 6) {
                                        Circle()
                                            .fill(type.color)
                                            .frame(width: 48, height: 48)
                                            .overlay {
                                                Image(systemName: type.sfSymbol)
                                                    .font(.body)
                                                    .foregroundStyle(.white)
                                            }
                                            .overlay {
                                                Circle().stroke(.white, lineWidth: 2)
                                            }
                                        Text(type.displayName)
                                            .font(.caption2)
                                            .foregroundStyle(SaplingColors.ink)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                    }
                }
            }

            ForEach(allSeedTypes, id: \.displayName) { type in
                let group = viewModel.seeds.filter { $0.seedType == type }
                if !group.isEmpty {
                    Section(type.displayName) {
                        ForEach(group, id: \.id) { seed in
                            Button {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    viewModel.selectSeed(seed)
                                }
                            } label: {
                                SeedRow(seed: seed)
                            }
                            .tint(.primary)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                viewModel.deleteSeed(group[index])
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No seeds yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Long-press the map to drop a seed, or start recording to drop one at your location.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Seed Row

private struct SeedRow: View {
    let seed: FfiSeed

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(seed.seedType.color)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: seed.seedType.sfSymbol)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(seed.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let notes = seed.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: seed.createdAt) {
            return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: seed.createdAt) {
            return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
        }
        return seed.createdAt
    }
}
