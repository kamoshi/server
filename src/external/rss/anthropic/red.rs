use axum::{http::StatusCode, response::Response};
use chrono::Utc;
use reqwest::Client;
use rss::{ChannelBuilder, GuidBuilder, ItemBuilder};
use scraper::{Html, Selector};

pub const TITLE: &str = "red.anthropic.com";
pub const DESCRIPTION: &str = "Welcome to red.anthropic.com, the home for research from Anthropic's Frontier Red Team (and occasionally other teams at Anthropic) on what frontier AI models mean for national security. We provide evidence-based analysis about AI's implications for cybersecurity, biosecurity, and autonomous systems.";

pub async fn handler() -> Response {
    super::super::cached_xml("rss:anthropic:red", render_feed()).await
}

async fn render_feed() -> Result<String, (StatusCode, String)> {
    let client = match Client::builder()
        .user_agent("Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0")
        .build()
    {
        Ok(c) => c,
        Err(e) => {
            return Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("Client error: {e}"),
            ));
        }
    };

    let html_content = match client.get("https://red.anthropic.com").send().await {
        Ok(res) => match res.text().await {
            Ok(text) => text,
            Err(e) => {
                return Err((
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("Read error: {e}"),
                ));
            }
        },
        Err(e) => {
            return Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("Fetch error: {e}"),
            ));
        }
    };

    let document = Html::parse_document(&html_content);

    let note_selector = Selector::parse("a.note").unwrap();
    let title_selector = Selector::parse("h3").unwrap();
    let desc_selector = Selector::parse("div.description").unwrap();

    let items: Vec<rss::Item> = document
        .select(&note_selector)
        .filter_map(|el| {
            let href = el.value().attr("href")?;
            let link = if href.starts_with("http") {
                href.to_string()
            } else {
                format!("https://red.anthropic.com/{href}")
            };

            let title = el
                .select(&title_selector)
                .next()
                .map(|e| e.text().collect::<String>())?;

            let description = el
                .select(&desc_selector)
                .next()
                .map(|e| e.text().collect::<String>())
                .unwrap_or_default();

            // Best-effort date: parse year from the leading path segment of href
            // e.g. "2026/exploit/" → year 2026 → "Thu, 01 Jan 2026 00:00:00 +0000"
            let pub_date = href
                .split('/')
                .find(|s| s.len() == 4 && s.chars().all(|c| c.is_ascii_digit()))
                .and_then(|y| y.parse::<i32>().ok())
                .and_then(|y| chrono::NaiveDate::from_ymd_opt(y, 1, 1))
                .and_then(|d| d.and_hms_opt(0, 0, 0))
                .map(|dt| dt.and_utc().to_rfc2822())
                .unwrap_or_else(|| Utc::now().to_rfc2822());

            Some(
                ItemBuilder::default()
                    .title(Some(title))
                    .link(Some(link.clone()))
                    .description(Some(description))
                    .pub_date(Some(pub_date))
                    .guid(Some(GuidBuilder::default().value(link).build()))
                    .build(),
            )
        })
        .collect();

    let channel = ChannelBuilder::default()
        .title(TITLE)
        .link("https://red.anthropic.com")
        .description(DESCRIPTION)
        .items(items)
        .build();

    Ok(channel.to_string())
}
