use axum::{routing::get, Router};

async fn hello() -> &'static str {
    "world"
}

pub fn router() -> Router {
    // let app = Router::new().route("/summary", get(get_summary));
    Router::new().route("/hello", get(hello))
}
