#[cfg(not(debug_assertions))]
mod discord;
mod external;
mod internal;

use std::env;
use tokio::net::TcpListener;

/// Template environment, abstracting over autoreload (debug) and embedded (release).
#[derive(Clone)]
pub struct JinjaEnv {
    #[cfg(debug_assertions)]
    inner: std::sync::Arc<minijinja_autoreload::AutoReloader>,
    #[cfg(not(debug_assertions))]
    inner: minijinja::Environment<'static>,
}

impl JinjaEnv {
    pub fn render(&self, name: &str, ctx: impl serde::Serialize) -> String {
        #[cfg(debug_assertions)]
        {
            let env = self
                .inner
                .acquire_env()
                .expect("failed to acquire jinja env");
            env.get_template(name).unwrap().render(ctx).unwrap()
        }
        #[cfg(not(debug_assertions))]
        {
            self.inner.get_template(name).unwrap().render(ctx).unwrap()
        }
    }
}

pub fn make_jinja() -> JinjaEnv {
    #[cfg(debug_assertions)]
    {
        let reloader = minijinja_autoreload::AutoReloader::new(|notifier| {
            let mut env = minijinja::Environment::new();
            notifier.watch_path("templates", true);
            env.set_loader(minijinja::path_loader("templates"));
            Ok(env)
        });
        JinjaEnv {
            inner: std::sync::Arc::new(reloader),
        }
    }
    #[cfg(not(debug_assertions))]
    {
        let mut env = minijinja::Environment::new();
        env.add_template(
            "hn/index.jinja",
            include_str!("../templates/hn/index.jinja"),
        )
        .unwrap();
        env.add_template(
            "hn/rating_group.jinja",
            include_str!("../templates/hn/rating_group.jinja"),
        )
        .unwrap();
        env.add_template(
            "rss/index.jinja",
            include_str!("../templates/rss/index.jinja"),
        )
        .unwrap();
        JinjaEnv { inner: env }
    }
}

#[tokio::main]
async fn main() {
    #[cfg(not(debug_assertions))]
    let _discord = tokio::spawn(discord::run());

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

    let state_dir = env::var("STATE_DIRECTORY").unwrap_or_else(|_| ".".to_string());
    let db_url = format!("sqlite:{}/hn.db?mode=rwc", state_dir);

    let pool = sqlx::sqlite::SqlitePoolOptions::new()
        .max_connections(5)
        .connect(&db_url)
        .await
        .expect("Failed to create sqlite pool");

    sqlx::migrate!()
        .run(&pool)
        .await
        .expect("Failed to run migrations");

    let jinja = make_jinja();
    let external_server = axum::serve(external_listener, external::router(jinja.clone()));
    let internal_server = axum::serve(internal_listener, internal::router(pool, jinja));

    tokio::select! {
        res = external_server => res.expect("External server failed"),
        res = internal_server => res.expect("Internal server failed"),
    }
}
