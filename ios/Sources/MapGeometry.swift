import CoreLocation

/// Bounding box for a set of coordinates.
struct CoordinateBBox {
    var minLat: Double
    var maxLat: Double
    var minLon: Double
    var maxLon: Double

    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
    }
}

/// Compute the bounding box for an array of coordinates.
func boundingBox(for coords: [CLLocationCoordinate2D]) -> CoordinateBBox {
    guard let first = coords.first else {
        return CoordinateBBox(minLat: 0, maxLat: 0, minLon: 0, maxLon: 0)
    }
    var bbox = CoordinateBBox(
        minLat: first.latitude, maxLat: first.latitude,
        minLon: first.longitude, maxLon: first.longitude
    )
    for c in coords {
        bbox.minLat = min(bbox.minLat, c.latitude)
        bbox.maxLat = max(bbox.maxLat, c.latitude)
        bbox.minLon = min(bbox.minLon, c.longitude)
        bbox.maxLon = max(bbox.maxLon, c.longitude)
    }
    return bbox
}

/// Compute a zoom level that fits the given bounding box with padding.
func zoomToFit(bounds: CoordinateBBox) -> Double {
    let latSpan = bounds.maxLat - bounds.minLat
    let lonSpan = bounds.maxLon - bounds.minLon
    let span = max(latSpan, lonSpan)
    guard span > 0 else { return 15 }
    let paddedSpan = span * 1.4
    let zoom = log2(360.0 / paddedSpan)
    return min(max(zoom, 1), 18)
}
