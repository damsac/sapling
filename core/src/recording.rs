use crate::geo;
use crate::models::{ActivityState, RecordingUpdate, TrackPoint, TripSummary};

/// Minimum horizontal accuracy to accept a location (meters).
const MAX_H_ACCURACY: f64 = 50.0;

/// Minimum distance from last accepted point (meters).
const MIN_DISTANCE_M: f64 = 5.0;

/// Speed threshold below which we consider the user paused (m/s).
const PAUSE_SPEED: f64 = 0.3;

/// Speed threshold above which we consider the user moving (m/s).
const RESUME_SPEED: f64 = 0.5;

/// Duration of low speed before transitioning to Paused (ms).
const PAUSE_DELAY_MS: i64 = 60_000;

/// GPS recording state machine.
pub struct Recorder {
    trip_id: Option<String>,
    trip_name: String,
    points: Vec<TrackPoint>,
    state: ActivityState,
    distance_m: f64,
    elevation_gain: f64,
    elevation_loss: f64,
    start_time_ms: Option<i64>,
    /// Timestamp when speed first dropped below PAUSE_SPEED.
    slow_since_ms: Option<i64>,
}

impl Default for Recorder {
    fn default() -> Self {
        Self::new()
    }
}

impl Recorder {
    pub fn new() -> Self {
        Recorder {
            trip_id: None,
            trip_name: String::new(),
            points: Vec::new(),
            state: ActivityState::Stopped,
            distance_m: 0.0,
            elevation_gain: 0.0,
            elevation_loss: 0.0,
            start_time_ms: None,
            slow_since_ms: None,
        }
    }

    /// Returns the current trip id, if recording.
    pub fn trip_id(&self) -> Option<&str> {
        self.trip_id.as_deref()
    }

    /// Start a new recording session. Returns the trip id.
    pub fn start(&mut self, name: Option<String>) -> String {
        let id = uuid::Uuid::now_v7().to_string();
        self.trip_id = Some(id.clone());
        self.trip_name = name.unwrap_or_else(|| "Untitled Trip".into());
        self.points.clear();
        self.state = ActivityState::Moving;
        self.distance_m = 0.0;
        self.elevation_gain = 0.0;
        self.elevation_loss = 0.0;
        self.start_time_ms = None;
        self.slow_since_ms = None;
        id
    }

    /// Add a GPS location. Returns None if filtered out, Some(update) if accepted.
    pub fn add_location(&mut self, point: TrackPoint) -> Option<RecordingUpdate> {
        self.trip_id.as_ref()?;

        // Filter: reject poor accuracy
        if point.h_accuracy > MAX_H_ACCURACY {
            return None;
        }

        // Set start time from first point
        if self.start_time_ms.is_none() {
            self.start_time_ms = Some(point.timestamp_ms);
        }

        // Filter: reject if too close to last accepted point
        if let Some(last) = self.points.last() {
            let dist = geo::haversine_distance(
                last.latitude,
                last.longitude,
                point.latitude,
                point.longitude,
            );
            if dist < MIN_DISTANCE_M {
                // Still update state machine even if we reject the point for distance
                self.update_activity_state(&point);
                return None;
            }

            // Accumulate distance
            self.distance_m += dist;

            // Accumulate elevation
            if let (Some(prev_elev), Some(curr_elev)) = (last.elevation, point.elevation) {
                let delta = curr_elev - prev_elev;
                if delta > 0.0 {
                    self.elevation_gain += delta;
                } else {
                    self.elevation_loss += delta.abs();
                }
            }
        }

        // Update activity state
        self.update_activity_state(&point);

        self.points.push(point);

        let elapsed_ms = self.elapsed_ms();

        Some(RecordingUpdate {
            state: self.state,
            distance_m: self.distance_m,
            elevation_gain: self.elevation_gain,
            elapsed_ms,
            point_count: self.points.len() as u32,
        })
    }

    /// Stop recording and return a trip summary.
    pub fn stop(&mut self) -> Option<TripSummary> {
        let id = self.trip_id.take()?;
        self.state = ActivityState::Stopped;

        let duration_ms = self.elapsed_ms();

        Some(TripSummary {
            id,
            name: self.trip_name.clone(),
            distance_m: self.distance_m,
            elevation_gain: self.elevation_gain,
            elevation_loss: self.elevation_loss,
            duration_ms,
            gem_count: 0,
            segment_count: 1,
        })
    }

    fn elapsed_ms(&self) -> i64 {
        match (self.start_time_ms, self.points.last()) {
            (Some(start), Some(last)) => last.timestamp_ms - start,
            _ => 0,
        }
    }

    fn update_activity_state(&mut self, point: &TrackPoint) {
        match self.state {
            ActivityState::Moving => {
                if point.speed < PAUSE_SPEED {
                    match self.slow_since_ms {
                        None => {
                            self.slow_since_ms = Some(point.timestamp_ms);
                        }
                        Some(since) => {
                            if point.timestamp_ms - since >= PAUSE_DELAY_MS {
                                self.state = ActivityState::Paused;
                            }
                        }
                    }
                } else {
                    self.slow_since_ms = None;
                }
            }
            ActivityState::Paused => {
                if point.speed > RESUME_SPEED {
                    self.state = ActivityState::Moving;
                    self.slow_since_ms = None;
                }
            }
            ActivityState::Stopped => {}
        }
    }
}

#[cfg(test)]
pub mod test_utils {
    use crate::models::TrackPoint;
    use proptest::prelude::*;

    prop_compose! {
        pub fn arb_track_point()(
            latitude in -90.0f64..90.0,
            longitude in -180.0f64..180.0,
            elevation in proptest::option::of(0.0f64..9000.0),
            h_accuracy in 0.0f64..100.0,
            speed in 0.0f64..15.0,
            course in 0.0f64..360.0,
            timestamp_ms in 0i64..2000000000000i64,
        ) -> TrackPoint {
            TrackPoint {
                latitude,
                longitude,
                elevation,
                h_accuracy,
                v_accuracy: 10.0,
                speed,
                course,
                timestamp_ms,
                baro_relative_altitude: None,
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_point(lat: f64, lon: f64, speed: f64, ts_ms: i64) -> TrackPoint {
        TrackPoint {
            latitude: lat,
            longitude: lon,
            elevation: Some(100.0),
            h_accuracy: 5.0,
            v_accuracy: 3.0,
            speed,
            course: 0.0,
            timestamp_ms: ts_ms,
            baro_relative_altitude: None,
        }
    }

    #[test]
    fn test_start_stop() {
        let mut rec = Recorder::new();
        let id = rec.start(Some("Test Hike".into()));
        assert!(!id.is_empty());

        let summary = rec.stop().unwrap();
        assert_eq!(summary.name, "Test Hike");
        assert_eq!(summary.distance_m, 0.0);
    }

    #[test]
    fn test_stop_without_start() {
        let mut rec = Recorder::new();
        assert!(rec.stop().is_none());
    }

    #[test]
    fn test_add_location_without_start() {
        let mut rec = Recorder::new();
        let p = make_point(37.0, -122.0, 1.0, 1000);
        assert!(rec.add_location(p).is_none());
    }

    #[test]
    fn test_reject_poor_accuracy() {
        let mut rec = Recorder::new();
        rec.start(None);

        let mut p = make_point(37.0, -122.0, 1.0, 1000);
        p.h_accuracy = 100.0; // too poor
        assert!(rec.add_location(p).is_none());
    }

    #[test]
    fn test_reject_too_close() {
        let mut rec = Recorder::new();
        rec.start(None);

        // First point accepted
        let p1 = make_point(37.0, -122.0, 1.0, 1000);
        let u1 = rec.add_location(p1);
        assert!(u1.is_some());

        // Second point very close — rejected
        let p2 = make_point(37.00001, -122.0, 1.0, 2000);
        let u2 = rec.add_location(p2);
        assert!(u2.is_none());
    }

    #[test]
    fn test_distance_accumulation() {
        let mut rec = Recorder::new();
        rec.start(None);

        // Points about 111m apart (0.001 degree latitude)
        let p1 = make_point(0.0, 0.0, 1.0, 1000);
        rec.add_location(p1);

        let p2 = make_point(0.001, 0.0, 1.0, 2000);
        let update = rec.add_location(p2).unwrap();

        assert!(
            (update.distance_m - 111.0).abs() < 2.0,
            "expected ~111m, got {:.1}m",
            update.distance_m
        );
        assert_eq!(update.point_count, 2);
    }

    #[test]
    fn test_state_machine_pause() {
        let mut rec = Recorder::new();
        rec.start(None);

        // First point, moving
        rec.add_location(make_point(0.0, 0.0, 1.0, 0));

        // Points far enough apart but slow speed, over 60s
        // We need points spread out enough to not be filtered by distance
        let mut lat = 0.001;
        for t in (1000..=61000).step_by(10000) {
            lat += 0.001;
            let update = rec.add_location(make_point(lat, 0.0, 0.1, t));
            if let Some(u) = update {
                if t >= 61000 {
                    assert_eq!(
                        u.state,
                        ActivityState::Paused,
                        "should be paused after 60s of low speed at t={t}"
                    );
                }
            }
        }
    }

    #[test]
    fn test_state_machine_resume() {
        let mut rec = Recorder::new();
        rec.start(None);

        // Get to paused state
        rec.add_location(make_point(0.0, 0.0, 1.0, 0));
        let mut lat = 0.001;
        for t in (1000..=61000).step_by(10000) {
            lat += 0.001;
            rec.add_location(make_point(lat, 0.0, 0.1, t));
        }

        // Now resume with speed > 0.5
        lat += 0.001;
        let update = rec.add_location(make_point(lat, 0.0, 2.0, 70000));
        if let Some(u) = update {
            assert_eq!(u.state, ActivityState::Moving);
        }
    }

    #[test]
    fn test_elevation_tracking() {
        let mut rec = Recorder::new();
        rec.start(None);

        let mut p1 = make_point(0.0, 0.0, 1.0, 1000);
        p1.elevation = Some(100.0);
        rec.add_location(p1);

        let mut p2 = make_point(0.001, 0.0, 1.0, 2000);
        p2.elevation = Some(150.0);
        let update = rec.add_location(p2).unwrap();

        assert!((update.elevation_gain - 50.0).abs() < 0.01);

        let summary = rec.stop().unwrap();
        assert!((summary.elevation_gain - 50.0).abs() < 0.01);
    }

    use proptest::prelude::*;

    proptest! {
        #[test]
        fn add_location_never_panics(point in super::test_utils::arb_track_point()) {
            let mut rec = Recorder::new();
            rec.start(None);
            let _ = rec.add_location(point);
        }

        #[test]
        fn distance_is_never_negative(
            p1 in super::test_utils::arb_track_point(),
            p2 in super::test_utils::arb_track_point(),
        ) {
            let d = crate::geo::haversine_distance(
                p1.latitude, p1.longitude,
                p2.latitude, p2.longitude,
            );
            prop_assert!(d >= 0.0);
        }
    }
}
