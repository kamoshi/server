use std::{env, sync::LazyLock};

use axum::{routing::get, Router};
use chrono::{Duration, Local, Timelike, Utc};
use gemini_rust::{Gemini, Model};
use miniflux_api::{
    models::{EntryStatus, OrderBy, OrderDirection},
    MinifluxApi,
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

type CachedSummary = (chrono::DateTime<Local>, String);

static SUMMARY_CACHE: LazyLock<Mutex<Option<CachedSummary>>> = LazyLock::new(|| Mutex::new(None));

fn md_to_html(md: &str) -> String {
    let parser = pulldown_cmark::Parser::new(md);
    let mut html = String::new();
    pulldown_cmark::html::push_html(&mut html, parser);
    html
}

async fn get_rss_data() -> String {
    // 1. Initialize the client for megumu
    // The domain is rss.kamoshi.org as defined in your Nix configuration
    let url = Url::parse("https://rss.kamoshi.org").unwrap();

    let api_token = env::var("TOKEN_MINIFLUX").unwrap_or_default();
    if api_token.is_empty() {
        return "MINIFLUX_API_TOKEN is not set".to_string();
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
        Err(err) => return format!("Failed to fetch entries: {:?}", err),
    };

    // 3. Process the results
    let mut output = String::new();
    for entry in entries {
        output.push_str(&format!(
            "Title: {}\nPublished at: {}\nURL: {}\n\n{}\n\n===\n\n",
            entry.title, entry.published_at, entry.url, entry.content
        ));
    }

    if output.is_empty() {
        "No unread entries found.".to_string()
    } else {
        output
    }
}

async fn summary() -> String {
    let mut cache = SUMMARY_CACHE.lock().await;
    let now = Local::now();

    if let Some((cached_time, cached_result)) = &*cache {
        // Shift time back by 6 hours so the natural 12-hour halves (AM/PM) align exactly with [06:00, 18:00) and [18:00, 06:00)
        let c = *cached_time - Duration::hours(6);
        let n = now - Duration::hours(6);

        if c.date_naive() == n.date_naive() && (c.hour() / 12) == (n.hour() / 12) {
            return cached_result.clone();
        }
    }

    let api_key = env::var("TOKEN_GEMINI").unwrap_or_default();
    if api_key.is_empty() {
        return "TOKEN_GEMINI is not set".to_string();
    }

    let client = match Gemini::with_model(api_key, Model::Gemini25Flash) {
        Ok(c) => c,
        Err(e) => return format!("Failed to create client: {}", e),
    };

    let data = get_rss_data().await;
    let data = format!("I have the following articles from RSS tracker: {data}");

    let result = match client
        .generate_content()
        .with_system_instruction(SYSTEM)
        .with_user_message(data)
        .with_max_output_tokens(2048)
        .with_temperature(0.7)
        .with_top_p(0.9)
        .with_top_k(40)
        .execute()
        .await
    {
        Ok(response) => response.text(),
        Err(e) => return format!("Error: {}", e),
    };

    let result = md_to_html(&result);

    *cache = Some((now, result.clone()));

    result
}

pub fn router() -> Router {
    Router::new().route("/summary", get(summary))
}
