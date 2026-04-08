pub mod rss;

use std::{env, sync::LazyLock};

use axum::{
    Router,
    response::{Html, IntoResponse, Response},
    routing::get,
};
use chrono::{Duration, Local, Timelike, Utc};
use gemini_rust::{Gemini, Model};
use miniflux_api::{
    MinifluxApi,
    models::{EntryStatus, OrderBy, OrderDirection},
};
use reqwest::Client;
use tokio::sync::Mutex;
use url::Url;

const SYSTEM: &str = "
You are the user's highly capable Personal Press Secretary.
Your goal is to provide a concise, sophisticated, and engaging editorial briefing.

# Tone and Style:
- Professional yet conversational (think 'The Economist' meets a high-end personal assistant).
- Group related stories into narrative themes rather than just listing them.
- Use 'You' to address the user.
- Highlight *why* a story matters.
- Avoid repetitive bullet points; use short, punchy paragraphs.

# Structure:
1. A brief, warm greeting based on the current time (Morning/Evening).
2. 'The Big Story' - The most impactful trend or news item of the day.
3. 'Other Notable Developments' - Grouped by theme.
4. 'A Quick Look Ahead' - A one-sentence closing thought.

# Constraints:
- Use Markdown for clear headers and bold text.
- Maintain the original 'Read More' links but weave them naturally or place them at the end of sections.
";

const STYLE: &str = r#"
<style>
    .summary-widget {
        font-family: inherit;
        font-size: var(--font-size-base);
        color: var(--color-text-paragraph);
        line-height: 1.6;
    }
    .summary-widget h1,
    .summary-widget h2,
    .summary-widget h3 {
        color: var(--color-text-highlight);
        margin-top: 1em;
        margin-bottom: 0.4em;
        font-weight: 600;
    }
    .summary-widget h1 {
        font-size: var(--font-size-h1);
    }
    .summary-widget h2 {
        font-size: var(--font-size-h2);
        border-bottom: 1px solid var(--color-separator);
        padding-bottom: 0.3em;
    }
    .summary-widget h3 {
        font-size: var(--font-size-h3);
    }
    .summary-widget p {
        margin-bottom: 1em;
    }
    .summary-widget a {
        color: var(--color-primary);
        text-decoration: none;
    }
    .summary-widget a:hover {
        text-decoration: underline;
    }
    .summary-widget ul,
    .summary-widget ol {
        padding-left: 1.5em;
        margin-bottom: 1em;
        color: var(--color-text-base);
    }
    .summary-widget li {
        margin-bottom: 0.4em;
    }
    .summary-widget strong {
        color: var(--color-text-highlight);
    }
    .summary-widget blockquote {
        border-left: 4px solid var(--color-primary);
        padding: 0.5em 1em;
        margin-left: 0;
        color: var(--color-text-subdue);
        background-color: var(--color-widget-background-highlight);
        border-radius: 0 var(--border-radius) var(--border-radius) 0;
    }
</style>
"#;

const MODEL: Model = Model::Gemini3Flash;

type CachedSummary = (chrono::DateTime<Local>, String);

static SUMMARY_CACHE: LazyLock<Mutex<Option<CachedSummary>>> = LazyLock::new(|| Mutex::new(None));

#[derive(Clone)]
pub struct AppState {
    pub jinja: crate::JinjaEnv,
}

fn md_to_html(md: &str) -> String {
    let parser = pulldown_cmark::Parser::new(md);
    let mut html = String::new();
    pulldown_cmark::html::push_html(&mut html, parser);

    // Inject a <style> block using the actual Glance :root variables.
    format!("{}\n<div class='summary-widget'>{}\n</div>", STYLE, html)
}

async fn get_rss_data() -> (String, Vec<i64>) {
    // 1. Initialize the client for megumu
    // The domain is rss.kamoshi.org as defined in your Nix configuration
    let url = Url::parse("https://rss.kamoshi.org").unwrap();

    let api_token = env::var("TOKEN_MINIFLUX").unwrap_or_default();
    if api_token.is_empty() {
        return ("MINIFLUX_API_TOKEN is not set".to_string(), vec![]);
    }

    let api = MinifluxApi::new_from_token(&url, api_token);

    let http_client = Client::new();

    // Calculate the Unix timestamp for 2 days ago
    let two_days_ago = (Utc::now() - Duration::days(2)).timestamp();

    // 2. Fetch entries using a parameterized query
    // Parameters: status, offset, limit, order, direction, before, after, etc.
    let entries = api
        .get_entries(
            Some(EntryStatus::Unread),  // Filter only unread
            None,                       // offset
            Some(20),                   // limit
            Some(OrderBy::PublishedAt), // order
            Some(OrderDirection::Desc), // direction
            None,                       // before
            Some(two_days_ago),         // after: entries published since this timestamp
            None,                       // before_entry_id
            None,                       // after_entry_id
            None,                       // starred
            &http_client,
        )
        .await;

    let entries = match entries {
        Ok(e) => e,
        Err(err) => return (format!("Failed to fetch entries: {:?}", err), vec![]),
    };

    let entry_ids: Vec<i64> = entries.iter().map(|e| e.id).collect();

    // 3. Process the results
    let mut output = String::new();
    for entry in entries {
        output.push_str(&format!(
            "Title: {}\nPublished at: {}\nURL: {}\n\n{}\n\n===\n\n",
            entry.title, entry.published_at, entry.url, entry.content
        ));
    }

    if output.is_empty() {
        ("No unread entries found.".to_string(), vec![])
    } else {
        (output, entry_ids)
    }
}

async fn summary() -> Response {
    let mut cache = SUMMARY_CACHE.lock().await;
    let now = Local::now();

    if let Some((cached_time, cached_result)) = &*cache {
        // Shift time back by 6 hours so the natural 12-hour halves (AM/PM) align exactly with [06:00, 18:00) and [18:00, 06:00)
        let c = *cached_time - Duration::hours(6);
        let n = now - Duration::hours(6);

        if c.date_naive() == n.date_naive() && (c.hour() / 12) == (n.hour() / 12) {
            // Return cached HTML with Glance headers
            return (
                [
                    ("Widget-Content-Type", "html"),
                    ("Widget-Title", "News Summary"),
                ],
                Html(cached_result.clone()),
            )
                .into_response();
        }
    }

    let api_key = env::var("TOKEN_GEMINI").unwrap_or_default();
    if api_key.is_empty() {
        return "TOKEN_GEMINI is not set".into_response();
    }

    let client = match Gemini::with_model(api_key, MODEL) {
        Ok(c) => c,
        Err(e) => return format!("Failed to create client: {e}").into_response(),
    };

    let (data, entry_ids) = get_rss_data().await;

    let time = Local::now().format("%Y-%m-%d %H:%M").to_string();
    let data =
        format!("Current time: {time}\nI have the following articles from RSS tracker: {data}");

    let result = match client
        .generate_content()
        .with_system_instruction(SYSTEM)
        .with_user_message(data)
        .with_max_output_tokens(4096)
        .with_temperature(0.7)
        .with_top_p(0.9)
        .with_top_k(40)
        .execute()
        .await
    {
        Ok(response) => {
            if !entry_ids.is_empty() {
                let url = Url::parse("https://rss.kamoshi.org").unwrap();
                let api_token = env::var("TOKEN_MINIFLUX").unwrap_or_default();
                if !api_token.is_empty() {
                    let api = MinifluxApi::new_from_token(&url, api_token);
                    let http_client = Client::new();
                    let _ = api
                        .update_entries_status(entry_ids, EntryStatus::Read, &http_client)
                        .await;
                }
            }
            response.text()
        }
        Err(e) => return format!("Error: {e}").into_response(),
    };

    let html = md_to_html(&result);

    *cache = Some((now, html.clone()));

    (
        [
            ("Widget-Content-Type", "html"),
            ("Widget-Title", "News Summary"),
        ],
        Html(html),
    )
        .into_response()
}

pub fn router(jinja: crate::JinjaEnv) -> Router {
    use tower::ServiceBuilder;
    use tower_http::normalize_path::NormalizePathLayer;

    let state = AppState { jinja };

    Router::new()
        .route("/summary", get(summary))
        .route("/rss", get(rss::index))
        .route(
            "/rss/anthropic/research",
            get(rss::anthropic::research::handler),
        )
        .route("/rss/anthropic/red", get(rss::anthropic::red::handler))
        .route(
            "/rss/anthropic/transformer-circuits",
            get(rss::anthropic::transformer_circuits::handler),
        )
        .route(
            "/rss/anthropic/alignment",
            get(rss::anthropic::alignment::handler),
        )
        .with_state(state)
        .layer(ServiceBuilder::new().layer(NormalizePathLayer::trim_trailing_slash()))
}
