mod kotori;

use axum::{routing::get, Router};
use std::env;
use tokio::net::TcpListener;

async fn hello() -> &'static str {
    "world"
}

#[tokio::main]
async fn main() {
    let _kotori = tokio::spawn(kotori::run());

    // let app = Router::new().route("/summary", get(get_summary));
    let app = Router::new().route("/hello", get(hello));

    let port = env::var("PORT").unwrap_or_else(|_| "3000".to_string());
    let addr = format!("0.0.0.0:{}", port);
    let listener = TcpListener::bind(&addr)
        .await
        .expect("Failed to bind to port");

    println!("Server running on {}", addr);
    axum::serve(listener, app).await.expect("Server failed");
}
