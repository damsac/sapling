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
pub struct Gem {
    pub id: String,
    pub gem_type: GemType,
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

/// Input for creating a new Gem (no id or timestamps — those are generated).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateGemInput {
    pub gem_type: GemType,
    pub title: String,
    pub notes: Option<String>,
    pub latitude: f64,
    pub longitude: f64,
    pub elevation: Option<f64>,
    pub confidence: u8,
    pub tags: Vec<String>,
}

/// The type/category of a Gem.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum GemType {
    Water,
    Camp,
    Beauty,
    Service,
    Custom,
}

impl GemType {
    pub fn as_str(&self) -> &'static str {
        match self {
            GemType::Water => "water",
            GemType::Camp => "camp",
            GemType::Beauty => "beauty",
            GemType::Service => "service",
            GemType::Custom => "custom",
        }
    }
}

impl std::str::FromStr for GemType {
    type Err = crate::error::SaplingError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "water" => Ok(GemType::Water),
            "camp" => Ok(GemType::Camp),
            "beauty" => Ok(GemType::Beauty),
            "service" => Ok(GemType::Service),
            "custom" => Ok(GemType::Custom),
            _other => Ok(GemType::Custom), // Unknown types fall back to Custom for forward compatibility
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

/// Summary of a completed trip.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TripSummary {
    pub id: String,
    pub name: String,
    pub distance_m: f64,
    pub elevation_gain: f64,
    pub elevation_loss: f64,
    pub duration_ms: i64,
    pub gem_count: u32,
    pub segment_count: u32,
}
