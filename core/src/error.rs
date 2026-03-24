use thiserror::Error;

#[derive(Debug, Error)]
pub enum SaplingError {
    #[error("database error: {0}")]
    Database(String),

    #[error("invalid input: {0}")]
    InvalidInput(String),

    #[error("not found: {0}")]
    NotFound(String),

    #[error("GPX parse error: {0}")]
    GpxParse(String),

    #[error("IO error: {0}")]
    Io(String),
}

impl From<rusqlite::Error> for SaplingError {
    fn from(e: rusqlite::Error) -> Self {
        SaplingError::Database(e.to_string())
    }
}

impl From<std::io::Error> for SaplingError {
    fn from(e: std::io::Error) -> Self {
        SaplingError::Io(e.to_string())
    }
}
