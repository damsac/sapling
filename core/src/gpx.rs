use std::fs::File;
use std::io::BufReader;

use crate::error::SaplingError;
use crate::models::TrackPoint;

/// Extract track points and waypoints from parsed GPX data.
fn parse_gpx_data(gpx_data: &gpx::Gpx) -> (Vec<TrackPoint>, Vec<gpx::Waypoint>) {
    let mut points = Vec::new();

    for track in &gpx_data.tracks {
        for segment in &track.segments {
            for pt in &segment.points {
                let coord = pt.point();
                let elevation = pt.elevation;
                // gpx::Time wraps time::OffsetDateTime — convert directly
                // to avoid a format-then-reparse string round-trip.
                let timestamp_ms = pt
                    .time
                    .map(|t| {
                        let odt: time::OffsetDateTime = t.into();
                        // OffsetDateTime gives seconds + nanoseconds natively
                        (odt.unix_timestamp() * 1000)
                            + (odt.nanosecond() / 1_000_000) as i64
                    })
                    .unwrap_or(0);

                points.push(TrackPoint {
                    latitude: coord.y(),
                    longitude: coord.x(),
                    elevation,
                    h_accuracy: 0.0,
                    v_accuracy: 0.0,
                    speed: pt.speed.unwrap_or(0.0),
                    course: 0.0,
                    timestamp_ms,
                    baro_relative_altitude: None,
                });
            }
        }
    }

    let waypoints = gpx_data.waypoints.clone();
    (points, waypoints)
}

/// Import a GPX file, returning parsed track points and raw waypoints.
pub fn import_gpx(
    file_path: &str,
) -> Result<(Vec<TrackPoint>, Vec<gpx::Waypoint>), SaplingError> {
    let file = File::open(file_path).map_err(|e| {
        SaplingError::Io(format!("cannot open {file_path}: {e}"))
    })?;
    let reader = BufReader::new(file);

    let gpx_data = gpx::read(reader).map_err(|e| {
        SaplingError::GpxParse(format!("failed to parse GPX: {e}"))
    })?;

    Ok(parse_gpx_data(&gpx_data))
}

/// Import GPX from a string (useful for testing).
pub fn import_gpx_from_str(
    xml: &str,
) -> Result<(Vec<TrackPoint>, Vec<gpx::Waypoint>), SaplingError> {
    let cursor = std::io::Cursor::new(xml);

    let gpx_data = gpx::read(cursor).map_err(|e| {
        SaplingError::GpxParse(format!("failed to parse GPX: {e}"))
    })?;

    Ok(parse_gpx_data(&gpx_data))
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE_GPX: &str = r#"<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test"
     xmlns="http://www.topografix.com/GPX/1/1">
  <wpt lat="37.778" lon="-122.391">
    <name>Ferry Building</name>
    <ele>5.0</ele>
  </wpt>
  <trk>
    <name>Morning Walk</name>
    <trkseg>
      <trkpt lat="37.7749" lon="-122.4194">
        <ele>10.0</ele>
        <time>2024-01-15T08:00:00Z</time>
      </trkpt>
      <trkpt lat="37.7751" lon="-122.4180">
        <ele>15.0</ele>
        <time>2024-01-15T08:01:00Z</time>
      </trkpt>
      <trkpt lat="37.7755" lon="-122.4170">
        <ele>12.0</ele>
        <time>2024-01-15T08:02:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>"#;

    #[test]
    fn test_import_gpx_from_str() {
        let (points, waypoints) = import_gpx_from_str(SAMPLE_GPX).unwrap();

        assert_eq!(points.len(), 3);
        assert_eq!(waypoints.len(), 1);

        // Check first track point
        assert!((points[0].latitude - 37.7749).abs() < 1e-4);
        assert!((points[0].longitude - (-122.4194)).abs() < 1e-4);
        assert_eq!(points[0].elevation, Some(10.0));

        // Check waypoint
        assert_eq!(waypoints[0].name, Some("Ferry Building".into()));
    }

    #[test]
    fn test_import_gpx_bad_xml() {
        let result = import_gpx_from_str("not xml at all");
        assert!(result.is_err());
    }

    #[test]
    fn test_import_gpx_file_not_found() {
        let result = import_gpx("/nonexistent/path.gpx");
        assert!(result.is_err());
    }
}
