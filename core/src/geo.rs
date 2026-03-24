use crate::models::TrackPoint;

/// Earth's mean radius in meters.
const EARTH_RADIUS_M: f64 = 6_371_000.0;

/// Haversine distance between two lat/lon points, in meters.
pub fn haversine_distance(lat1: f64, lon1: f64, lat2: f64, lon2: f64) -> f64 {
    let lat1_rad = lat1.to_radians();
    let lat2_rad = lat2.to_radians();
    let dlat = (lat2 - lat1).to_radians();
    let dlon = (lon2 - lon1).to_radians();

    let a = (dlat / 2.0).sin().powi(2)
        + lat1_rad.cos() * lat2_rad.cos() * (dlon / 2.0).sin().powi(2);
    let c = 2.0 * a.sqrt().asin();

    EARTH_RADIUS_M * c
}

/// Cumulative elevation gain from a sequence of track points (only positive deltas).
pub fn elevation_gain(points: &[TrackPoint]) -> f64 {
    points
        .windows(2)
        .filter_map(|w| {
            match (w[0].elevation, w[1].elevation) {
                (Some(a), Some(b)) if b > a => Some(b - a),
                _ => None,
            }
        })
        .sum()
}

/// Cumulative elevation loss from a sequence of track points (only negative deltas, returned as positive).
pub fn elevation_loss(points: &[TrackPoint]) -> f64 {
    points
        .windows(2)
        .filter_map(|w| {
            match (w[0].elevation, w[1].elevation) {
                (Some(a), Some(b)) if a > b => Some(a - b),
                _ => None,
            }
        })
        .sum()
}

/// Ramer-Douglas-Peucker track simplification.
///
/// `epsilon` is the perpendicular distance threshold in meters.
/// Returns a simplified copy of the input points.
pub fn simplify_track(points: &[TrackPoint], epsilon: f64) -> Vec<TrackPoint> {
    if points.len() <= 2 {
        return points.to_vec();
    }

    // Use the geo crate's Simplify trait via conversion to a LineString.
    use geo::algorithm::simplify::Simplify;
    use geo::{coord, LineString};

    let line: LineString<f64> = LineString::from(
        points
            .iter()
            .map(|p| coord! { x: p.longitude, y: p.latitude })
            .collect::<Vec<_>>(),
    );

    // epsilon here is in degrees — convert meters to approximate degrees
    // 1 degree latitude ~ 111_320 m
    let eps_deg = epsilon / 111_320.0;
    let simplified = line.simplify(&eps_deg);

    // Map back: for each simplified coord, find the original point (by exact coord match)
    simplified
        .into_inner()
        .iter()
        .filter_map(|c| {
            points
                .iter()
                .find(|p| (p.longitude - c.x).abs() < 1e-12 && (p.latitude - c.y).abs() < 1e-12)
                .cloned()
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_haversine_known_distance() {
        // New York (40.7128, -74.0060) to Los Angeles (34.0522, -118.2437)
        // Expected: ~3,944 km
        let d = haversine_distance(40.7128, -74.0060, 34.0522, -118.2437);
        assert!(
            (d - 3_944_000.0).abs() < 50_000.0,
            "NY to LA should be ~3944km, got {:.0}m",
            d
        );
    }

    #[test]
    fn test_haversine_same_point() {
        let d = haversine_distance(45.0, 90.0, 45.0, 90.0);
        assert!(d.abs() < 0.01, "same point should be 0m, got {d}");
    }

    #[test]
    fn test_haversine_short_distance() {
        // Two points ~111m apart (0.001 degree latitude at equator)
        let d = haversine_distance(0.0, 0.0, 0.001, 0.0);
        assert!(
            (d - 111.0).abs() < 2.0,
            "0.001 deg lat at equator should be ~111m, got {d:.1}m"
        );
    }

    #[test]
    fn test_elevation_gain_basic() {
        let points = vec![
            make_tp(0.0, 0.0, Some(100.0)),
            make_tp(0.0, 0.0, Some(150.0)),
            make_tp(0.0, 0.0, Some(120.0)),
            make_tp(0.0, 0.0, Some(200.0)),
        ];
        // gain: 50 + 80 = 130
        assert!((elevation_gain(&points) - 130.0).abs() < 0.01);
    }

    #[test]
    fn test_elevation_gain_no_elevation() {
        let points = vec![
            make_tp(0.0, 0.0, None),
            make_tp(0.0, 0.0, None),
        ];
        assert!((elevation_gain(&points) - 0.0).abs() < 0.01);
    }

    #[test]
    fn test_simplify_preserves_endpoints() {
        let points = vec![
            make_tp(0.0, 0.0, Some(0.0)),
            make_tp(0.0001, 0.0001, Some(0.0)),
            make_tp(0.0002, 0.0002, Some(0.0)),
            make_tp(1.0, 1.0, Some(0.0)),
        ];
        let simplified = simplify_track(&points, 1000.0);
        assert!(simplified.len() >= 2);
        assert!((simplified.first().unwrap().latitude - 0.0).abs() < 1e-10);
        assert!((simplified.last().unwrap().latitude - 1.0).abs() < 1e-10);
    }

    fn make_tp(lat: f64, lon: f64, elev: Option<f64>) -> TrackPoint {
        TrackPoint {
            latitude: lat,
            longitude: lon,
            elevation: elev,
            h_accuracy: 5.0,
            v_accuracy: 3.0,
            speed: 1.0,
            course: 0.0,
            timestamp_ms: 0,
            baro_relative_altitude: None,
        }
    }
}
