use axum::{http::StatusCode, response::Response};
use chrono::Utc;
use reqwest::Client;
use rss::{ChannelBuilder, GuidBuilder, ItemBuilder};
use scraper::{Html, Selector};

pub const TITLE: &str = "Anthropic Transformer Circuits";
pub const DESCRIPTION: &str = "A surprising fact about modern large language models is that nobody really knows how they work internally. The Interpretability team strives to change that — to understand these models to better plan for a future of safe AI.";

pub async fn handler() -> Response {
    super::super::cached_xml("rss:anthropic:transformer-circuits", render_feed()).await
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

    let html_content = match client.get("https://transformer-circuits.pub/").send().await {
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

    let date_or_note_selector = Selector::parse("div.date, a.paper, a.note").unwrap();
    let title_selector = Selector::parse("h3").unwrap();
    let desc_selector = Selector::parse("div.description").unwrap();

    let mut current_date: Option<chrono::NaiveDate> = None;
    let mut items: Vec<rss::Item> = Vec::new();

    for el in document.select(&date_or_note_selector) {
        if el.value().name() == "div" {
            let text = el.text().collect::<String>();
            let text = text.trim();
            if let Ok(d) = chrono::NaiveDate::parse_from_str(&format!("1 {text}"), "%d %B %Y") {
                current_date = Some(d);
            }
        } else {
            let Some(href) = el.value().attr("href") else {
                continue;
            };
            let link = if href.starts_with("http") {
                href.to_string()
            } else {
                format!("https://transformer-circuits.pub/{href}")
            };

            let Some(title) = el
                .select(&title_selector)
                .next()
                .map(|e| e.text().collect::<String>())
            else {
                continue;
            };

            let description = el
                .select(&desc_selector)
                .next()
                .map(|e| e.text().collect::<String>())
                .unwrap_or_default();

            let pub_date = current_date
                .and_then(|d| d.and_hms_opt(0, 0, 0))
                .map(|dt| dt.and_utc().to_rfc2822())
                .unwrap_or_else(|| Utc::now().to_rfc2822());

            items.push(
                ItemBuilder::default()
                    .title(Some(title))
                    .link(Some(link.clone()))
                    .description(Some(description))
                    .pub_date(Some(pub_date))
                    .guid(Some(GuidBuilder::default().value(link).build()))
                    .build(),
            );
        }
    }

    let channel = ChannelBuilder::default()
        .title(TITLE)
        .link("https://transformer-circuits.pub/")
        .description(DESCRIPTION)
        .items(items)
        .build();

    Ok(channel.to_string())
}
