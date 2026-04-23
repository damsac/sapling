use serde::{Deserialize, Serialize};

/// A single GPS track point recorded during a trip.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrackPoint {
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

/// A point of interest along a trail.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Seed {
    pub id: String,
    pub seed_type: SeedType,
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

/// Input for creating a new Seed (no id or timestamps — those are generated).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateSeedInput {
    pub seed_type: SeedType,
    pub title: String,
    pub notes: Option<String>,
    pub latitude: f64,
    pub longitude: f64,
    pub elevation: Option<f64>,
    pub confidence: u8,
    pub tags: Vec<String>,
}

/// Input for updating an existing Seed's user-editable fields.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateSeedInput {
    pub title: String,
    pub notes: Option<String>,
    pub tags: Vec<String>,
}

/// The type/category of a Seed.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SeedType {
    Water,
    Camp,
    Beauty,
    Service,
    Custom,
}

impl SeedType {
    pub fn as_str(&self) -> &'static str {
        match self {
            SeedType::Water => "water",
            SeedType::Camp => "camp",
            SeedType::Beauty => "beauty",
            SeedType::Service => "service",
            SeedType::Custom => "custom",
        }
    }
}

impl std::str::FromStr for SeedType {
    type Err = crate::error::SaplingError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "water" => Ok(SeedType::Water),
            "camp" => Ok(SeedType::Camp),
            "beauty" => Ok(SeedType::Beauty),
            "service" => Ok(SeedType::Service),
            "custom" => Ok(SeedType::Custom),
            _other => Ok(SeedType::Custom), // Unknown types fall back to Custom for forward compatibility
        }
    }
}

/// Current motion state during recording.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ActivityState {
    Moving,
    Paused,
    Stopped,
}

/// Snapshot of recording progress returned after each accepted location.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecordingUpdate {
    pub state: ActivityState,
    pub distance_m: f64,
    pub elevation_gain: f64,
    pub elapsed_ms: i64,
    pub point_count: u32,
}

/// A waypoint in a planned route — just a coordinate pair.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RouteWaypoint {
    pub latitude: f64,
    pub longitude: f64,
}

/// A planned route (distinct from a recorded trip).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Route {
    pub id: String,
    pub name: String,
    pub notes: Option<String>,
    pub waypoints: Vec<RouteWaypoint>,
    pub distance_m: f64,
    pub created_at: String,
    pub updated_at: String,
}

/// Summary of a completed trip.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TripSummary {
    pub id: String,
    pub name: String,
    pub notes: Option<String>,
    pub distance_m: f64,
    pub elevation_gain: f64,
    pub elevation_loss: f64,
    pub duration_ms: i64,
    pub seed_count: u32,
    pub segment_count: u32,
    pub created_at: String,
}
