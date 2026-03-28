pub mod hn;
pub mod summarizer;

use axum::Router;
use sqlx::SqlitePool;

pub fn router(pool: SqlitePool, jinja: crate::JinjaEnv) -> Router {
    summarizer::router().nest("/hn", hn::router(pool, jinja))
}
