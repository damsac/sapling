import Foundation
import MapLibre
import CoreLocation

// MARK: - Pack Metadata (stored in MLNOfflinePack context)

struct OfflinePackMetadata: Codable {
    let id: String
    let name: String
    let createdAt: Date
    let minZoom: Double
    let maxZoom: Double
}

// MARK: - Pack Info (observable view data)

struct OfflinePackInfo: Identifiable {
    let id: String
    let name: String
    let createdAt: Date
    let bounds: MLNCoordinateBounds
    let minZoom: Double
    let maxZoom: Double
    let bytesCompleted: UInt64
    let resourcesCompleted: UInt64
    let resourcesExpected: UInt64

    var isComplete: Bool {
        resourcesExpected > 0 && resourcesCompleted >= resourcesExpected
    }

    var progress: Float {
        guard resourcesExpected > 0 else { return 0 }
        return Float(resourcesCompleted) / Float(resourcesExpected)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(bytesCompleted), countStyle: .file)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }
}

// MARK: - Offline Map Manager

@Observable
class OfflineMapManager {
    static let shared = OfflineMapManager()

    private(set) var packs: [OfflinePackInfo] = []
    private(set) var isDownloading: Bool = false
    private(set) var activeDownloadProgress: Float = 0
    private(set) var activeDownloadId: String?

    private let styleURL = URL(string: "https://tiles.openfreemap.org/styles/liberty")!
    private var progressObserver: NSObjectProtocol?
    private var errorObserver: NSObjectProtocol?

    private init() {
        setupNotificationObservers()
        refreshPacks()
    }

    deinit {
        if let observer = progressObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = errorObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Download

    func downloadRegion(
        name: String,
        bounds: MLNCoordinateBounds,
        minZoom: Double = 10,
        maxZoom: Double = 14
    ) {
        let region = MLNTilePyramidOfflineRegion(
            styleURL: styleURL,
            bounds: bounds,
            fromZoomLevel: minZoom,
            toZoomLevel: maxZoom
        )

        let metadata = OfflinePackMetadata(
            id: UUID().uuidString,
            name: name,
            createdAt: Date(),
            minZoom: minZoom,
            maxZoom: maxZoom
        )

        guard let context = try? JSONEncoder().encode(metadata) else { return }

        isDownloading = true
        activeDownloadProgress = 0
        activeDownloadId = metadata.id

        MLNOfflineStorage.shared.addPack(for: region, withContext: context) { [weak self] pack, error in
            if let error {
                print("Failed to create offline pack: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.isDownloading = false
                    self?.activeDownloadId = nil
                }
                return
            }
            pack?.resume()
            DispatchQueue.main.async {
                self?.refreshPacks()
            }
        }
    }

    // MARK: - Pack Management

    func deletePack(id: String) {
        guard let rawPack = findRawPack(id: id) else { return }
        MLNOfflineStorage.shared.removePack(rawPack) { [weak self] error in
            if let error {
                print("Failed to remove offline pack: \(error.localizedDescription)")
                return
            }
            DispatchQueue.main.async {
                self?.refreshPacks()
                if self?.activeDownloadId == id {
                    self?.isDownloading = false
                    self?.activeDownloadId = nil
                }
            }
        }
    }

    func pausePack(id: String) {
        guard let rawPack = findRawPack(id: id) else { return }
        rawPack.suspend()
        refreshPacks()
    }

    func resumePack(id: String) {
        guard let rawPack = findRawPack(id: id) else { return }
        rawPack.resume()
        activeDownloadId = id
        isDownloading = true
        refreshPacks()
    }

    func refreshPacks() {
        guard let rawPacks = MLNOfflineStorage.shared.packs else {
            packs = []
            return
        }

        packs = rawPacks.compactMap { pack -> OfflinePackInfo? in
            guard let metadata = decodeMetadata(from: pack.context) else { return nil }
            guard let region = pack.region as? MLNTilePyramidOfflineRegion else { return nil }

            let progress = pack.progress

            return OfflinePackInfo(
                id: metadata.id,
                name: metadata.name,
                createdAt: metadata.createdAt,
                bounds: region.bounds,
                minZoom: metadata.minZoom,
                maxZoom: metadata.maxZoom,
                bytesCompleted: progress.countOfBytesCompleted,
                resourcesCompleted: progress.countOfResourcesCompleted,
                resourcesExpected: progress.countOfResourcesExpected
            )
        }
    }

    // MARK: - Size Estimation

    /// Estimate download size for a bounding box at the given zoom range.
    /// Uses average wilderness vector tile size (~8 KB) plus ~2 MB for style resources.
    static func estimateSize(
        bounds: MLNCoordinateBounds,
        minZoom: Double = 10,
        maxZoom: Double = 14
    ) -> (tileCount: Int, bytes: Int) {
        let avgTileBytes = 8_000 // ~8 KB per tile for wilderness areas
        let styleOverhead = 2_000_000 // ~2 MB for style JSON, sprites, glyphs

        var totalTiles = 0

        for z in Int(minZoom)...Int(maxZoom) {
            let zPow = pow(2.0, Double(z))

            let xMin = Int(floor((bounds.sw.longitude + 180.0) / 360.0 * zPow))
            let xMax = Int(floor((bounds.ne.longitude + 180.0) / 360.0 * zPow))

            let latMinRad = bounds.sw.latitude * .pi / 180.0
            let latMaxRad = bounds.ne.latitude * .pi / 180.0

            // Y tile indices (note: in tile coords, higher lat = lower Y)
            let yMin = Int(floor((1.0 - log(tan(latMaxRad) + 1.0 / cos(latMaxRad)) / .pi) / 2.0 * zPow))
            let yMax = Int(floor((1.0 - log(tan(latMinRad) + 1.0 / cos(latMinRad)) / .pi) / 2.0 * zPow))

            let tilesX = max(xMax - xMin + 1, 1)
            let tilesY = max(yMax - yMin + 1, 1)
            totalTiles += tilesX * tilesY
        }

        let totalBytes = totalTiles * avgTileBytes + styleOverhead
        return (tileCount: totalTiles, bytes: totalBytes)
    }

    static func formatEstimatedSize(bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    // MARK: - Total Storage

    var totalBytesUsed: UInt64 {
        packs.reduce(0) { $0 + $1.bytesCompleted }
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytesUsed), countStyle: .file)
    }

    // MARK: - Private

    private func setupNotificationObservers() {
        progressObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.MLNOfflinePackProgressChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let pack = notification.object as? MLNOfflinePack else { return }
            let progress = pack.progress

            // Update active download progress
            if let metadata = self?.decodeMetadata(from: pack.context),
               metadata.id == self?.activeDownloadId
            {
                if progress.countOfResourcesExpected > 0 {
                    self?.activeDownloadProgress = Float(progress.countOfResourcesCompleted)
                        / Float(progress.countOfResourcesExpected)
                }

                // Download complete
                if progress.countOfResourcesCompleted >= progress.countOfResourcesExpected,
                   progress.countOfResourcesExpected > 0
                {
                    self?.isDownloading = false
                    self?.activeDownloadId = nil
                }
            }

            self?.refreshPacks()
        }

        errorObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.MLNOfflinePackError,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userInfo = notification.userInfo,
               let error = userInfo[MLNOfflinePackUserInfoKey.error] as? NSError
            {
                print("Offline pack error: \(error.localizedDescription)")
            }
            self?.isDownloading = false
            self?.refreshPacks()
        }
    }

    private func decodeMetadata(from context: Data) -> OfflinePackMetadata? {
        try? JSONDecoder().decode(OfflinePackMetadata.self, from: context)
    }

    private func findRawPack(id: String) -> MLNOfflinePack? {
        MLNOfflineStorage.shared.packs?.first { pack in
            guard let metadata = decodeMetadata(from: pack.context) else { return false }
            return metadata.id == id
        }
    }
}
