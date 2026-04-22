import SwiftUI
import CoreLocation

struct RouteListView: View {
    var viewModel: RouteBuilderViewModel
    var onSelectRoute: ((FfiRoute) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var routeToRename: FfiRoute?
    @State private var renameText: String = ""
    var onStartBuilding: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.savedRoutes.isEmpty {
                    ContentUnavailableView(
                        "No Planned Routes",
                        systemImage: "map",
                        description: Text("Tap the route builder button on the map to plan a route.")
                    )
                } else {
                    List {
                        ForEach(viewModel.savedRoutes, id: \.id) { route in
                            Button {
                                onSelectRoute?(route)
                                dismiss()
                            } label: {
                                RouteRow(route: route)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteRoute(route.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    routeToRename = route
                                    renameText = route.name
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(SaplingColors.brand)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Planned Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                        onStartBuilding?()
                    } label: {
                        Label("New Route", systemImage: "plus")
                    }
                    .fontDesign(.rounded)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontDesign(.rounded)
                }
            }
        }
        .alert("Rename Route", isPresented: Binding(
            get: { routeToRename != nil },
            set: { if !$0 { routeToRename = nil } }
        )) {
            TextField("Route name", text: $renameText)
            Button("Save") {
                if let r = routeToRename, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    viewModel.renameRoute(r.id, name: renameText.trimmingCharacters(in: .whitespaces))
                }
                routeToRename = nil
            }
            Button("Cancel", role: .cancel) { routeToRename = nil }
        }
        .fontDesign(.rounded)
        .onAppear { viewModel.loadRoutes() }
    }
}

private struct RouteRow: View {
    let route: FfiRoute

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(SaplingColors.brand.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "map")
                    .font(.body)
                    .foregroundStyle(SaplingColors.brand)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(route.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(SaplingColors.ink)
                Text(formatDistance(route.distanceM))
                    .font(.caption)
                    .foregroundStyle(SaplingColors.bark)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

