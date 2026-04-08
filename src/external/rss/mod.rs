pub mod anthropic;

use axum::{
    extract::State,
    http::{StatusCode, header},
    response::{Html, IntoResponse, Response},
};
use chrono::{Duration, Utc};
use serde::Serialize;
use std::{collections::HashMap, future::Future, sync::LazyLock};
use tokio::sync::Mutex;

#[derive(Serialize)]
pub struct FeedItem {
    url: &'static str,
    title: &'static str,
    description: &'static str,
}

impl FeedItem {
    pub const fn new(url: &'static str, title: &'static str, description: &'static str) -> Self {
        Self {
            url,
            title,
            description,
        }
    }
}

#[derive(Serialize)]
pub struct FeedGroup {
    title: &'static str,
    feeds: &'static [FeedItem],
}

impl FeedGroup {
    pub const fn new(title: &'static str, feeds: &'static [FeedItem]) -> Self {
        Self { title, feeds }
    }
}

const GROUPS: &[FeedGroup] = &[anthropic::GROUP];

type CachedFeed = (chrono::DateTime<Utc>, String);

const FEED_CACHE_TTL: Duration = Duration::days(1);
const XML_CONTENT_TYPE: &str = "application/xml; charset=utf-8";

static FEED_CACHE: LazyLock<Mutex<HashMap<&'static str, CachedFeed>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

pub async fn index(State(state): State<crate::external::AppState>) -> Response {
    let html = state.jinja.render(
        "rss/index.jinja",
        minijinja::context! {
            groups => GROUPS,
        },
    );

    Html(html).into_response()
}

pub async fn cached_xml<F>(cache_key: &'static str, fetch: F) -> Response
where
    F: Future<Output = Result<String, (StatusCode, String)>>,
{
    let mut cache = FEED_CACHE.lock().await;
    let now = Utc::now();

    if let Some((fetched_at, xml)) = cache.get(cache_key) {
        if now.signed_duration_since(*fetched_at) < FEED_CACHE_TTL {
            return xml_response(xml.clone());
        }
    }

    let stale_xml = cache.get(cache_key).map(|(_, xml)| xml.clone());

    match fetch.await {
        Ok(xml) => {
            cache.insert(cache_key, (now, xml.clone()));
            xml_response(xml)
        }
        Err((status, message)) => {
            if let Some(xml) = stale_xml {
                xml_response(xml)
            } else {
                (status, message).into_response()
            }
        }
    }
}

fn xml_response(xml: String) -> Response {
    (
        StatusCode::OK,
        [(header::CONTENT_TYPE, XML_CONTENT_TYPE)],
        xml,
    )
        .into_response()
}
