use axum::{http::StatusCode, response::Response};
use chrono::NaiveDate;
use reqwest::Client;
use rss::{CategoryBuilder, ChannelBuilder, GuidBuilder, ItemBuilder};
use scraper::{Html, Selector};

pub const TITLE: &str = "Anthropic Research";
pub const DESCRIPTION: &str = "Our research teams investigate the safety, inner workings, and societal impacts of AI models – so that artificial intelligence has a positive impact as it becomes increasingly capable.";

pub async fn handler() -> Response {
    super::super::cached_xml("rss:anthropic:research", render_feed()).await
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

    let html_content = match client
        .get("https://www.anthropic.com/research")
        .send()
        .await
    {
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

    let item_selector = Selector::parse(r#"a[class*="listItem"]"#).unwrap();
    let title_selector = Selector::parse(r#"span[class*="title"]"#).unwrap();
    let date_selector = Selector::parse("time").unwrap();
    let subject_selector = Selector::parse(r#"span[class*="subject"]"#).unwrap();

    let items: Vec<rss::Item> = document
        .select(&item_selector)
        .filter_map(|el| {
            let href = el.value().attr("href")?;
            let link = if href.starts_with("http") {
                href.to_string()
            } else {
                format!("https://www.anthropic.com{href}")
            };

            // Require a title and date — nav/footer links have neither
            let title = el
                .select(&title_selector)
                .next()
                .map(|e| e.text().collect::<String>())?;

            let raw_date = el
                .select(&date_selector)
                .next()
                .map(|e| e.text().collect::<String>())?;

            let pub_date = NaiveDate::parse_from_str(raw_date.trim(), "%b %e, %Y")
                .ok()
                .and_then(|d| d.and_hms_opt(0, 0, 0))
                .map(|dt| dt.and_utc().to_rfc2822())?;

            let subject = el
                .select(&subject_selector)
                .next()
                .map(|e| e.text().collect::<String>())
                .unwrap_or_default();

            let category = CategoryBuilder::default().name(subject).build();

            Some(
                ItemBuilder::default()
                    .title(Some(title))
                    .link(Some(link.clone()))
                    .categories(vec![category])
                    .pub_date(Some(pub_date))
                    .guid(Some(GuidBuilder::default().value(link).build()))
                    .build(),
            )
        })
        .collect();

    let channel = ChannelBuilder::default()
        .title(TITLE)
        .link("https://www.anthropic.com/research")
        .description(DESCRIPTION)
        .items(items)
        .build();

    Ok(channel.to_string())
}
