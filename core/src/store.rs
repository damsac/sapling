use rusqlite::Connection;
use rusqlite_migration::{Migrations, M};

use crate::error::SaplingError;
use crate::models::{CreateGemInput, Gem, GemType, TrackPoint};

/// SQLite-backed persistent store.
pub struct Store {
    conn: Connection,
}

impl Store {
    /// Open (or create) a SQLite database at `path`, apply pragmas and migrations.
    pub fn open(path: &str) -> Result<Self, SaplingError> {
        let mut conn = Connection::open(path)?;

        // Pragmas
        conn.execute_batch(
            "PRAGMA journal_mode = WAL;
             PRAGMA synchronous = FULL;
             PRAGMA foreign_keys = ON;",
        )?;

        let migrations = Migrations::new(vec![
            M::up(
                "CREATE TABLE IF NOT EXISTS gems (
                    id          TEXT PRIMARY KEY NOT NULL,
                    gem_type    TEXT NOT NULL,
                    title       TEXT NOT NULL,
                    notes       TEXT,
                    latitude    REAL NOT NULL,
                    longitude   REAL NOT NULL,
                    elevation   REAL,
                    confidence  INTEGER NOT NULL DEFAULT 50,
                    tags        TEXT NOT NULL DEFAULT '[]',
                    device_id   TEXT,
                    created_at  TEXT NOT NULL,
                    updated_at  TEXT NOT NULL,
                    deleted_at  TEXT
                );

                CREATE VIRTUAL TABLE IF NOT EXISTS gems_fts USING fts5(
                    title, notes, tags, content='gems', content_rowid='rowid'
                );

                CREATE TRIGGER IF NOT EXISTS gems_ai AFTER INSERT ON gems BEGIN
                    INSERT INTO gems_fts(rowid, title, notes, tags)
                    VALUES (new.rowid, new.title, new.notes, new.tags);
                END;

                CREATE TRIGGER IF NOT EXISTS gems_ad AFTER DELETE ON gems BEGIN
                    INSERT INTO gems_fts(gems_fts, rowid, title, notes, tags)
                    VALUES ('delete', old.rowid, old.title, old.notes, old.tags);
                END;

                CREATE TRIGGER IF NOT EXISTS gems_au AFTER UPDATE ON gems BEGIN
                    INSERT INTO gems_fts(gems_fts, rowid, title, notes, tags)
                    VALUES ('delete', old.rowid, old.title, old.notes, old.tags);
                    INSERT INTO gems_fts(rowid, title, notes, tags)
                    VALUES (new.rowid, new.title, new.notes, new.tags);
                END;",
            ),
            M::up(
                "CREATE TABLE IF NOT EXISTS trips (
                    id              TEXT PRIMARY KEY NOT NULL,
                    name            TEXT NOT NULL,
                    distance_m      REAL NOT NULL DEFAULT 0,
                    elevation_gain  REAL NOT NULL DEFAULT 0,
                    elevation_loss  REAL NOT NULL DEFAULT 0,
                    duration_ms     INTEGER NOT NULL DEFAULT 0,
                    device_id       TEXT,
                    created_at      TEXT NOT NULL,
                    updated_at      TEXT NOT NULL,
                    deleted_at      TEXT
                );

                CREATE TABLE IF NOT EXISTS track_points (
                    id                      INTEGER PRIMARY KEY AUTOINCREMENT,
                    trip_id                 TEXT NOT NULL REFERENCES trips(id),
                    segment_index           INTEGER NOT NULL DEFAULT 0,
                    latitude                REAL NOT NULL,
                    longitude               REAL NOT NULL,
                    elevation               REAL,
                    h_accuracy              REAL NOT NULL,
                    v_accuracy              REAL NOT NULL,
                    speed                   REAL NOT NULL,
                    course                  REAL NOT NULL,
                    timestamp_ms            INTEGER NOT NULL,
                    baro_relative_altitude  REAL,
                    device_id               TEXT,
                    created_at              TEXT NOT NULL,
                    updated_at              TEXT NOT NULL,
                    deleted_at              TEXT
                );

                CREATE INDEX IF NOT EXISTS idx_track_points_trip
                    ON track_points(trip_id, segment_index, timestamp_ms);

                CREATE TABLE IF NOT EXISTS trip_gems (
                    trip_id     TEXT NOT NULL REFERENCES trips(id),
                    gem_id      TEXT NOT NULL REFERENCES gems(id),
                    device_id   TEXT,
                    created_at  TEXT NOT NULL,
                    updated_at  TEXT NOT NULL,
                    deleted_at  TEXT,
                    PRIMARY KEY (trip_id, gem_id)
                );",
            ),
        ]);

        migrations.to_latest(&mut conn).map_err(|e| {
            SaplingError::Database(format!("migration failed: {e}"))
        })?;

        Ok(Store { conn })
    }

    /// Create a new Gem and return it with generated id and timestamps.
    pub fn create_gem(&self, input: &CreateGemInput) -> Result<Gem, SaplingError> {
        let id = uuid::Uuid::now_v7().to_string();
        let now = chrono::Utc::now().to_rfc3339();
        let tags_json = serde_json::to_string(&input.tags)
            .map_err(|e| SaplingError::InvalidInput(e.to_string()))?;

        self.conn.execute(
            "INSERT INTO gems (id, gem_type, title, notes, latitude, longitude, elevation, confidence, tags, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)",
            rusqlite::params![
                id,
                input.gem_type.as_str(),
                input.title,
                input.notes,
                input.latitude,
                input.longitude,
                input.elevation,
                input.confidence,
                tags_json,
                now,
                now,
            ],
        )?;

        Ok(Gem {
            id,
            gem_type: input.gem_type,
            title: input.title.clone(),
            notes: input.notes.clone(),
            latitude: input.latitude,
            longitude: input.longitude,
            elevation: input.elevation,
            confidence: input.confidence,
            tags: input.tags.clone(),
            created_at: now.clone(),
            updated_at: now,
        })
    }

    /// Fetch a gem by id, or None if not found (ignores soft-deleted).
    pub fn get_gem(&self, id: &str) -> Result<Option<Gem>, SaplingError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, gem_type, title, notes, latitude, longitude, elevation, confidence, tags, created_at, updated_at
             FROM gems WHERE id = ?1 AND deleted_at IS NULL",
        )?;

        let mut rows = stmt.query_map(rusqlite::params![id], |row| {
            Ok(GemRow {
                id: row.get(0)?,
                gem_type: row.get(1)?,
                title: row.get(2)?,
                notes: row.get(3)?,
                latitude: row.get(4)?,
                longitude: row.get(5)?,
                elevation: row.get(6)?,
                confidence: row.get(7)?,
                tags: row.get(8)?,
                created_at: row.get(9)?,
                updated_at: row.get(10)?,
            })
        })?;

        match rows.next() {
            Some(row) => {
                let r = row?;
                Ok(Some(gem_from_row(r)?))
            }
            None => Ok(None),
        }
    }

    /// List all non-deleted gems.
    pub fn list_gems(&self) -> Result<Vec<Gem>, SaplingError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, gem_type, title, notes, latitude, longitude, elevation, confidence, tags, created_at, updated_at
             FROM gems WHERE deleted_at IS NULL ORDER BY created_at DESC",
        )?;

        let rows = stmt.query_map([], |row| {
            Ok(GemRow {
                id: row.get(0)?,
                gem_type: row.get(1)?,
                title: row.get(2)?,
                notes: row.get(3)?,
                latitude: row.get(4)?,
                longitude: row.get(5)?,
                elevation: row.get(6)?,
                confidence: row.get(7)?,
                tags: row.get(8)?,
                created_at: row.get(9)?,
                updated_at: row.get(10)?,
            })
        })?;

        let mut gems = Vec::new();
        for row in rows {
            gems.push(gem_from_row(row?)?);
        }
        Ok(gems)
    }

    // -- Trip persistence --

    /// Insert a new trip row with default zero stats.
    pub fn create_trip(&self, id: &str, name: &str) -> Result<(), SaplingError> {
        let now = chrono::Utc::now().to_rfc3339();
        self.conn.execute(
            "INSERT INTO trips (id, name, created_at, updated_at) VALUES (?1, ?2, ?3, ?4)",
            rusqlite::params![id, name, now, now],
        )?;
        Ok(())
    }

    /// Insert a track point for the given trip.
    pub fn add_track_point(&self, trip_id: &str, point: &TrackPoint) -> Result<(), SaplingError> {
        let now = chrono::Utc::now().to_rfc3339();
        self.conn.execute(
            "INSERT INTO track_points (trip_id, latitude, longitude, elevation, h_accuracy, v_accuracy, speed, course, timestamp_ms, baro_relative_altitude, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)",
            rusqlite::params![
                trip_id,
                point.latitude,
                point.longitude,
                point.elevation,
                point.h_accuracy,
                point.v_accuracy,
                point.speed,
                point.course,
                point.timestamp_ms,
                point.baro_relative_altitude,
                now,
                now,
            ],
        )?;
        Ok(())
    }

    /// Update a trip's final stats after recording stops.
    pub fn finalize_trip(
        &self,
        id: &str,
        distance_m: f64,
        elevation_gain: f64,
        elevation_loss: f64,
        duration_ms: i64,
    ) -> Result<(), SaplingError> {
        let now = chrono::Utc::now().to_rfc3339();
        self.conn.execute(
            "UPDATE trips SET distance_m = ?1, elevation_gain = ?2, elevation_loss = ?3, duration_ms = ?4, updated_at = ?5 WHERE id = ?6",
            rusqlite::params![distance_m, elevation_gain, elevation_loss, duration_ms, now, id],
        )?;
        Ok(())
    }

    /// Full-text search across gem title, notes, and tags.
    pub fn search_gems(&self, query: &str) -> Result<Vec<Gem>, SaplingError> {
        let mut stmt = self.conn.prepare(
            "SELECT g.id, g.gem_type, g.title, g.notes, g.latitude, g.longitude, g.elevation, g.confidence, g.tags, g.created_at, g.updated_at
             FROM gems g
             JOIN gems_fts f ON g.rowid = f.rowid
             WHERE gems_fts MATCH ?1 AND g.deleted_at IS NULL
             ORDER BY rank",
        )?;

        let rows = stmt.query_map(rusqlite::params![query], |row| {
            Ok(GemRow {
                id: row.get(0)?,
                gem_type: row.get(1)?,
                title: row.get(2)?,
                notes: row.get(3)?,
                latitude: row.get(4)?,
                longitude: row.get(5)?,
                elevation: row.get(6)?,
                confidence: row.get(7)?,
                tags: row.get(8)?,
                created_at: row.get(9)?,
                updated_at: row.get(10)?,
            })
        })?;

        let mut gems = Vec::new();
        for row in rows {
            gems.push(gem_from_row(row?)?);
        }
        Ok(gems)
    }
}

/// Internal row type for mapping SQLite results.
struct GemRow {
    id: String,
    gem_type: String,
    title: String,
    notes: Option<String>,
    latitude: f64,
    longitude: f64,
    elevation: Option<f64>,
    confidence: u8,
    tags: String,
    created_at: String,
    updated_at: String,
}

fn gem_from_row(r: GemRow) -> Result<Gem, SaplingError> {
    let tags: Vec<String> = serde_json::from_str(&r.tags)
        .map_err(|e| SaplingError::Database(format!("bad tags JSON: {e}")))?;
    let gem_type = GemType::from_str(&r.gem_type)?;

    Ok(Gem {
        id: r.id,
        gem_type,
        title: r.title,
        notes: r.notes,
        latitude: r.latitude,
        longitude: r.longitude,
        elevation: r.elevation,
        confidence: r.confidence,
        tags,
        created_at: r.created_at,
        updated_at: r.updated_at,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{CreateGemInput, GemType};
    use tempfile::NamedTempFile;

    fn test_store() -> Store {
        let f = NamedTempFile::new().unwrap();
        Store::open(f.path().to_str().unwrap()).unwrap()
    }

    #[test]
    fn test_open_and_migrate() {
        let _store = test_store();
    }

    #[test]
    fn test_create_and_get_gem() {
        let store = test_store();
        let input = CreateGemInput {
            gem_type: GemType::Water,
            title: "Crystal Spring".into(),
            notes: Some("Cold and clear".into()),
            latitude: 37.7749,
            longitude: -122.4194,
            elevation: Some(150.0),
            confidence: 90,
            tags: vec!["reliable".into(), "cold".into()],
        };

        let gem = store.create_gem(&input).unwrap();
        assert_eq!(gem.title, "Crystal Spring");
        assert_eq!(gem.gem_type, GemType::Water);
        assert!(!gem.id.is_empty());

        let fetched = store.get_gem(&gem.id).unwrap().unwrap();
        assert_eq!(fetched.id, gem.id);
        assert_eq!(fetched.title, "Crystal Spring");
        assert_eq!(fetched.tags, vec!["reliable", "cold"]);
    }

    #[test]
    fn test_get_gem_not_found() {
        let store = test_store();
        let result = store.get_gem("nonexistent").unwrap();
        assert!(result.is_none());
    }

    #[test]
    fn test_list_gems() {
        let store = test_store();

        let input1 = CreateGemInput {
            gem_type: GemType::Campsite,
            title: "Ridge Camp".into(),
            notes: None,
            latitude: 36.0,
            longitude: -118.0,
            elevation: None,
            confidence: 70,
            tags: vec![],
        };
        let input2 = CreateGemInput {
            gem_type: GemType::Viewpoint,
            title: "Sunset Vista".into(),
            notes: Some("Best at golden hour".into()),
            latitude: 36.1,
            longitude: -118.1,
            elevation: Some(2400.0),
            confidence: 95,
            tags: vec!["photography".into()],
        };

        store.create_gem(&input1).unwrap();
        store.create_gem(&input2).unwrap();

        let gems = store.list_gems().unwrap();
        assert_eq!(gems.len(), 2);
    }

    #[test]
    fn test_search_gems() {
        let store = test_store();

        store
            .create_gem(&CreateGemInput {
                gem_type: GemType::Water,
                title: "Mountain Stream".into(),
                notes: Some("Flows year-round".into()),
                latitude: 37.0,
                longitude: -119.0,
                elevation: None,
                confidence: 80,
                tags: vec!["water".into()],
            })
            .unwrap();

        store
            .create_gem(&CreateGemInput {
                gem_type: GemType::Campsite,
                title: "Pine Flat".into(),
                notes: Some("Sheltered site near creek".into()),
                latitude: 37.1,
                longitude: -119.1,
                elevation: None,
                confidence: 75,
                tags: vec![],
            })
            .unwrap();

        // Search for "stream" should find the water source
        let results = store.search_gems("stream").unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].title, "Mountain Stream");

        // Search for "creek" should find Pine Flat (in notes)
        let results = store.search_gems("creek").unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].title, "Pine Flat");
    }

    #[test]
    fn test_trip_persistence_round_trip() {
        let f = NamedTempFile::new().unwrap();
        let db_path = f.path().to_str().unwrap();
        let store = Store::open(db_path).unwrap();

        let trip_id = "test-trip-001";
        store.create_trip(trip_id, "Morning Hike").unwrap();

        // Add several track points
        let points = vec![
            TrackPoint {
                latitude: 0.0,
                longitude: 0.0,
                elevation: Some(100.0),
                h_accuracy: 5.0,
                v_accuracy: 3.0,
                speed: 1.0,
                course: 0.0,
                timestamp_ms: 1000,
                baro_relative_altitude: None,
            },
            TrackPoint {
                latitude: 0.001,
                longitude: 0.0,
                elevation: Some(150.0),
                h_accuracy: 5.0,
                v_accuracy: 3.0,
                speed: 1.2,
                course: 0.0,
                timestamp_ms: 2000,
                baro_relative_altitude: Some(0.5),
            },
            TrackPoint {
                latitude: 0.002,
                longitude: 0.0,
                elevation: Some(140.0),
                h_accuracy: 5.0,
                v_accuracy: 3.0,
                speed: 1.1,
                course: 0.0,
                timestamp_ms: 3000,
                baro_relative_altitude: None,
            },
        ];
        for p in &points {
            store.add_track_point(trip_id, p).unwrap();
        }

        // Finalize with computed stats
        store.finalize_trip(trip_id, 222.0, 50.0, 10.0, 2000).unwrap();

        // Verify trip row
        let mut stmt = store.conn.prepare(
            "SELECT name, distance_m, elevation_gain, elevation_loss, duration_ms FROM trips WHERE id = ?1"
        ).unwrap();
        let (name, dist, gain, loss, dur): (String, f64, f64, f64, i64) = stmt.query_row(
            rusqlite::params![trip_id],
            |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?, row.get(4)?)),
        ).unwrap();
        assert_eq!(name, "Morning Hike");
        assert!((dist - 222.0).abs() < 0.01);
        assert!((gain - 50.0).abs() < 0.01);
        assert!((loss - 10.0).abs() < 0.01);
        assert_eq!(dur, 2000);

        // Verify track points
        let count: i64 = store.conn.query_row(
            "SELECT COUNT(*) FROM track_points WHERE trip_id = ?1",
            rusqlite::params![trip_id],
            |row| row.get(0),
        ).unwrap();
        assert_eq!(count, 3);

        // Verify a specific track point
        let (lat, lon, elev, ts): (f64, f64, Option<f64>, i64) = store.conn.query_row(
            "SELECT latitude, longitude, elevation, timestamp_ms FROM track_points WHERE trip_id = ?1 ORDER BY timestamp_ms LIMIT 1",
            rusqlite::params![trip_id],
            |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?)),
        ).unwrap();
        assert!((lat - 0.0).abs() < 1e-6);
        assert!((lon - 0.0).abs() < 1e-6);
        assert_eq!(elev, Some(100.0));
        assert_eq!(ts, 1000);
    }
}
