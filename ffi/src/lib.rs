uniffi::setup_scaffolding!();

use std::sync::Mutex;

use sapling_core::error::SaplingError;
use sapling_core::models::{
    ActivityState, CreateGemInput, Gem, GemType, RecordingUpdate, TrackPoint, TripSummary,
};
use sapling_core::recording::Recorder;
use sapling_core::store::Store;

/// Error type exposed to foreign code via UniFFI.
#[derive(Debug, thiserror::Error, uniffi::Error)]
pub enum FfiError {
    #[error("{msg}")]
    Database { msg: String },
    #[error("{msg}")]
    NotFound { msg: String },
    #[error("{msg}")]
    InvalidInput { msg: String },
    #[error("{msg}")]
    Io { msg: String },
    #[error("{msg}")]
    GpxParse { msg: String },
}

impl From<SaplingError> for FfiError {
    fn from(e: SaplingError) -> Self {
        match e {
            SaplingError::Database(msg) => FfiError::Database { msg },
            SaplingError::NotFound(msg) => FfiError::NotFound { msg },
            SaplingError::InvalidInput(msg) => FfiError::InvalidInput { msg },
            SaplingError::Io(msg) => FfiError::Io { msg },
            SaplingError::GpxParse(msg) => FfiError::GpxParse { msg },
        }
    }
}

/// UniFFI enum types — typed alternatives to String for gem types and activity states.

#[derive(uniffi::Enum)]
pub enum FfiGemType {
    Campsite,
    Water,
    Hazard,
    Viewpoint,
    Trailhead,
    Junction,
    Resupply,
    Note,
}

impl From<GemType> for FfiGemType {
    fn from(g: GemType) -> Self {
        match g {
            GemType::Campsite => FfiGemType::Campsite,
            GemType::Water => FfiGemType::Water,
            GemType::Hazard => FfiGemType::Hazard,
            GemType::Viewpoint => FfiGemType::Viewpoint,
            GemType::Trailhead => FfiGemType::Trailhead,
            GemType::Junction => FfiGemType::Junction,
            GemType::Resupply => FfiGemType::Resupply,
            GemType::Note => FfiGemType::Note,
        }
    }
}

impl From<FfiGemType> for GemType {
    fn from(g: FfiGemType) -> Self {
        match g {
            FfiGemType::Campsite => GemType::Campsite,
            FfiGemType::Water => GemType::Water,
            FfiGemType::Hazard => GemType::Hazard,
            FfiGemType::Viewpoint => GemType::Viewpoint,
            FfiGemType::Trailhead => GemType::Trailhead,
            FfiGemType::Junction => GemType::Junction,
            FfiGemType::Resupply => GemType::Resupply,
            FfiGemType::Note => GemType::Note,
        }
    }
}

#[derive(uniffi::Enum)]
pub enum FfiActivityState {
    Moving,
    Paused,
    Stopped,
}

impl From<ActivityState> for FfiActivityState {
    fn from(s: ActivityState) -> Self {
        match s {
            ActivityState::Moving => FfiActivityState::Moving,
            ActivityState::Paused => FfiActivityState::Paused,
            ActivityState::Stopped => FfiActivityState::Stopped,
        }
    }
}

/// UniFFI record types — re-exported from core with UniFFI derives.

#[derive(uniffi::Record)]
pub struct FfiTrackPoint {
    pub latitude: f64,
    pub longitude: f64,
    pub elevation: Option<f64>,
    pub h_accuracy: f64,
    pub v_accuracy: f64,
    pub speed: f64,
    pub course: f64,
    pub timestamp_ms: i64,
    pub baro_relative_altitude: Option<f64>,
}

impl From<FfiTrackPoint> for TrackPoint {
    fn from(p: FfiTrackPoint) -> Self {
        TrackPoint {
            latitude: p.latitude,
            longitude: p.longitude,
            elevation: p.elevation,
            h_accuracy: p.h_accuracy,
            v_accuracy: p.v_accuracy,
            speed: p.speed,
            course: p.course,
            timestamp_ms: p.timestamp_ms,
            baro_relative_altitude: p.baro_relative_altitude,
        }
    }
}

#[derive(uniffi::Record)]
pub struct FfiGem {
    pub id: String,
    pub gem_type: FfiGemType,
    pub title: String,
    pub notes: Option<String>,
    pub latitude: f64,
    pub longitude: f64,
    pub elevation: Option<f64>,
    pub confidence: u8,
    pub tags: Vec<String>,
    pub created_at: String,
    pub updated_at: String,
}

impl From<Gem> for FfiGem {
    fn from(g: Gem) -> Self {
        FfiGem {
            id: g.id,
            gem_type: g.gem_type.into(),
            title: g.title,
            notes: g.notes,
            latitude: g.latitude,
            longitude: g.longitude,
            elevation: g.elevation,
            confidence: g.confidence,
            tags: g.tags,
            created_at: g.created_at,
            updated_at: g.updated_at,
        }
    }
}

#[derive(uniffi::Record)]
pub struct FfiCreateGemInput {
    pub gem_type: FfiGemType,
    pub title: String,
    pub notes: Option<String>,
    pub latitude: f64,
    pub longitude: f64,
    pub elevation: Option<f64>,
    pub confidence: u8,
    pub tags: Vec<String>,
}

#[derive(uniffi::Record)]
pub struct FfiRecordingUpdate {
    pub state: FfiActivityState,
    pub distance_m: f64,
    pub elevation_gain: f64,
    pub elapsed_ms: i64,
    pub point_count: u32,
}

impl From<RecordingUpdate> for FfiRecordingUpdate {
    fn from(u: RecordingUpdate) -> Self {
        FfiRecordingUpdate {
            state: u.state.into(),
            distance_m: u.distance_m,
            elevation_gain: u.elevation_gain,
            elapsed_ms: u.elapsed_ms,
            point_count: u.point_count,
        }
    }
}

#[derive(uniffi::Record)]
pub struct FfiTripSummary {
    pub id: String,
    pub name: String,
    pub distance_m: f64,
    pub elevation_gain: f64,
    pub elevation_loss: f64,
    pub duration_ms: i64,
    pub gem_count: u32,
    pub segment_count: u32,
}

impl From<TripSummary> for FfiTripSummary {
    fn from(s: TripSummary) -> Self {
        FfiTripSummary {
            id: s.id,
            name: s.name,
            distance_m: s.distance_m,
            elevation_gain: s.elevation_gain,
            elevation_loss: s.elevation_loss,
            duration_ms: s.duration_ms,
            gem_count: s.gem_count,
            segment_count: s.segment_count,
        }
    }
}

/// Main entry point exposed to Swift/Kotlin via UniFFI.
#[derive(uniffi::Object)]
pub struct SaplingCore {
    store: Mutex<Store>,
    recorder: Mutex<Recorder>,
}

#[uniffi::export]
impl SaplingCore {
    #[uniffi::constructor]
    pub fn new(db_path: String) -> Result<Self, FfiError> {
        let store = Store::open(&db_path)?;
        Ok(SaplingCore {
            store: Mutex::new(store),
            recorder: Mutex::new(Recorder::new()),
        })
    }

    // -- Recording --

    pub fn start_recording(&self, name: Option<String>) -> Result<String, FfiError> {
        let trip_name = name.clone().unwrap_or_else(|| "Untitled Trip".into());
        let id = self.recorder.lock().unwrap().start(name);
        self.store.lock().unwrap().create_trip(&id, &trip_name)?;
        Ok(id)
    }

    pub fn add_location(
        &self,
        point: FfiTrackPoint,
    ) -> Result<Option<FfiRecordingUpdate>, FfiError> {
        let core_point: TrackPoint = point.into();
        // Lock recorder, process point, unlock before touching store
        let (update, trip_id, accepted_point) = {
            let mut rec = self.recorder.lock().unwrap();
            let trip_id = rec.trip_id().map(|s| s.to_string());
            let update = rec.add_location(core_point.clone());
            // If update is Some, the point was accepted
            (update, trip_id, core_point)
        };
        // Persist accepted points to store
        if update.is_some() {
            if let Some(tid) = &trip_id {
                self.store
                    .lock()
                    .unwrap()
                    .add_track_point(tid, &accepted_point)?;
            }
        }
        Ok(update.map(|u| u.into()))
    }

    pub fn stop_recording(&self) -> Result<Option<FfiTripSummary>, FfiError> {
        let summary = self.recorder.lock().unwrap().stop();
        if let Some(ref s) = summary {
            self.store.lock().unwrap().finalize_trip(
                &s.id,
                s.distance_m,
                s.elevation_gain,
                s.elevation_loss,
                s.duration_ms,
            )?;
        }
        Ok(summary.map(|s| s.into()))
    }

    // -- Gems --

    pub fn create_gem(&self, input: FfiCreateGemInput) -> Result<FfiGem, FfiError> {
        let core_input = CreateGemInput {
            gem_type: input.gem_type.into(),
            title: input.title,
            notes: input.notes,
            latitude: input.latitude,
            longitude: input.longitude,
            elevation: input.elevation,
            confidence: input.confidence,
            tags: input.tags,
        };
        let gem = self.store.lock().unwrap().create_gem(&core_input)?;
        Ok(gem.into())
    }

    pub fn get_gem(&self, id: String) -> Result<Option<FfiGem>, FfiError> {
        Ok(self.store.lock().unwrap().get_gem(&id)?.map(|g| g.into()))
    }

    pub fn search_gems(&self, query: String) -> Result<Vec<FfiGem>, FfiError> {
        Ok(self
            .store
            .lock()
            .unwrap()
            .search_gems(&query)?
            .into_iter()
            .map(|g| g.into())
            .collect())
    }

    pub fn list_gems(&self) -> Result<Vec<FfiGem>, FfiError> {
        Ok(self
            .store
            .lock()
            .unwrap()
            .list_gems()?
            .into_iter()
            .map(|g| g.into())
            .collect())
    }

    // -- GPX Import --

    pub fn import_gpx(&self, file_path: String) -> Result<Vec<FfiTrackPoint>, FfiError> {
        let (points, _waypoints) = sapling_core::gpx::import_gpx(&file_path)?;
        Ok(points
            .into_iter()
            .map(|p| FfiTrackPoint {
                latitude: p.latitude,
                longitude: p.longitude,
                elevation: p.elevation,
                h_accuracy: p.h_accuracy,
                v_accuracy: p.v_accuracy,
                speed: p.speed,
                course: p.course,
                timestamp_ms: p.timestamp_ms,
                baro_relative_altitude: p.baro_relative_altitude,
            })
            .collect())
    }
}
