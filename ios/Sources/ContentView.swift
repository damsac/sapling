import SwiftUI

struct ContentView: View {
    @State private var statusText = "Ready"
    @State private var gemCount = 0

    private let core: SaplingCore

    init() {
        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        let dbPath = documentsDir.appendingPathComponent("sapling.db").path
        self.core = try! SaplingCore(dbPath: dbPath)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("\u{1F331}")
                .font(.system(size: 64))

            Text("Sapling")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Trail companion powered by Rust")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Gems created: \(gemCount)")
                .font(.title3)

            Button("Create Test Gem") {
                do {
                    let input = FfiCreateGemInput(
                        gemType: .viewpoint,
                        title: "Test Viewpoint #\(gemCount + 1)",
                        notes: "Created from iOS",
                        latitude: 37.7749,
                        longitude: -122.4194,
                        elevation: 100.0,
                        confidence: 90,
                        tags: ["test", "ios"]
                    )
                    let gem = try core.createGem(input: input)
                    gemCount += 1
                    statusText = "Created gem: \(gem.title)"
                } catch {
                    statusText = "Error: \(error.localizedDescription)"
                }
            }
            .buttonStyle(.borderedProminent)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
