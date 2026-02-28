mod external;
mod internal;
#[cfg(not(debug_assertions))]
mod kotori;

use std::env;
use tokio::net::TcpListener;

#[tokio::main]
async fn main() {
    #[cfg(not(debug_assertions))]
    let _kotori = tokio::spawn(kotori::run());

    let external_port = env::var("PORT").unwrap_or_else(|_| "3000".to_string());
    let internal_port = env::var("PORT_INTERNAL").unwrap_or_else(|_| "3001".to_string());

    let external_addr = format!("0.0.0.0:{}", external_port);
    let internal_addr = format!("0.0.0.0:{}", internal_port);

    let external_listener = TcpListener::bind(&external_addr)
        .await
        .expect("Failed to bind to external port");

    let internal_listener = TcpListener::bind(&internal_addr)
        .await
        .expect("Failed to bind to internal port");

    println!("External server running on http://{}", external_addr);
    println!("Internal server running on http://{}", internal_addr);

    let external_server = axum::serve(external_listener, external::router());
    let internal_server = axum::serve(internal_listener, internal::router());

    tokio::select! {
        res = external_server => res.expect("External server failed"),
        res = internal_server => res.expect("Internal server failed"),
    }
}
