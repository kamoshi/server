use axum::{
    extract::{Path, Query, State},
    response::{Html, IntoResponse},
    routing::get,
    Form, Json, Router,
};
use chrono::{NaiveDate, Utc};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use sqlx::{FromRow, SqlitePool};
use std::collections::HashMap;
use url::Url;

#[derive(Clone)]
pub struct AppState {
    pub pool: SqlitePool,
    pub http_client: Client,
    pub jinja: crate::JinjaEnv,
}

pub fn router(pool: SqlitePool, jinja: crate::JinjaEnv) -> Router {
    let state = AppState {
        pool,
        http_client: Client::new(),
        jinja,
    };

    Router::new()
        .route("/", get(index))
        .route("/rate/{id}", axum::routing::put(rate_story).delete(unrate_story))
        .route("/export", get(export))
        .with_state(state)
}

fn parse_date(s: &str) -> Option<NaiveDate> {
    NaiveDate::parse_from_str(s, "%Y-%m-%d").ok()
}

fn day_bounds(date: NaiveDate) -> (i64, i64) {
    let start = date.and_hms_opt(0, 0, 0).unwrap().and_utc().timestamp();
    let end = date
        .succ_opt()
        .unwrap_or(date)
        .and_hms_opt(0, 0, 0)
        .unwrap()
        .and_utc()
        .timestamp();
    (start, end)
}

#[derive(Deserialize)]
struct IndexQuery {
    filter: Option<String>,
    sort: Option<String>,
    date: Option<String>,
}

/// Unified story data merged from Algolia + DB ratings.
struct StoryData {
    id: i64,
    title: String,
    url: Option<String>,
    author: String,
    points: i64,
    num_comments: i64,
    created_at: i64,
    rating: Option<String>,
}

#[derive(Serialize)]
struct StoryContext {
    id: i64,
    title: String,
    title_url: String,
    /// Raw URL string for hidden form field; empty if no URL.
    url_raw: String,
    domain: String,
    author: String,
    points: i64,
    num_comments: i64,
    created_at: i64,
    time_ago: String,
    rating_html: String,
}

#[derive(Serialize)]
struct TabContext {
    key: String,
    label: String,
    count: i64,
}

#[derive(Deserialize)]
struct AlgoliaResponse {
    hits: Vec<AlgoliaHit>,
}

#[derive(Deserialize)]
struct AlgoliaHit {
    #[serde(rename = "objectID")]
    object_id: String,
    title: Option<String>,
    url: Option<String>,
    author: Option<String>,
    points: Option<i64>,
    num_comments: Option<i64>,
    created_at_i: Option<i64>,
}

#[derive(FromRow)]
struct RatedStory {
    id: i64,
    title: String,
    url: Option<String>,
    author: String,
    points: i64,
    num_comments: i64,
    created_at: i64,
    rating: String,
}

async fn fetch_day_algolia(client: &Client, date: NaiveDate) -> Result<Vec<AlgoliaHit>, String> {
    let (start, end) = day_bounds(date);
    let url = format!(
        "http://hn.algolia.com/api/v1/search?tags=story&numericFilters=created_at_i>={},created_at_i<={}&hitsPerPage=20",
        start,
        end - 1
    );
    let resp = client.get(&url).send().await.map_err(|e| e.to_string())?;
    let data = resp.json::<AlgoliaResponse>().await.map_err(|e| e.to_string())?;
    Ok(data.hits)
}

async fn index(State(state): State<AppState>, Query(query): Query<IndexQuery>) -> impl IntoResponse {
    let filter = query.filter.unwrap_or_else(|| "all".to_string());
    let sort = query.sort.unwrap_or_else(|| "points".to_string());

    let today = Utc::now().date_naive();
    let today_str = today.format("%Y-%m-%d").to_string();
    let date = query.date.as_deref().and_then(parse_date).unwrap_or(today);
    let date_str = date.format("%Y-%m-%d").to_string();
    let prev_date = date.pred_opt().unwrap_or(date).format("%Y-%m-%d").to_string();
    let next_date = date.succ_opt().unwrap_or(date).format("%Y-%m-%d").to_string();
    let (start_ts, end_ts) = day_bounds(date);

    // Fetch top 20 from Algolia (non-blocking on error)
    let (algolia_hits, fetch_error) = match fetch_day_algolia(&state.http_client, date).await {
        Ok(hits) => (hits, None),
        Err(e) => (vec![], Some(e)),
    };

    // Fetch all rated stories for this day from DB
    let db_rated: Vec<RatedStory> = sqlx::query_as(
        "SELECT s.id, s.title, s.url, s.author, s.points, s.num_comments, s.created_at, r.rating \
         FROM hn_stories s \
         JOIN hn_ratings r ON s.id = r.story_id \
         WHERE s.created_at >= ? AND s.created_at < ?",
    )
    .bind(start_ts)
    .bind(end_ts)
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    // Merge: Algolia provides unrated stories; DB provides rated ones.
    // DB entries that don't appear in Algolia top-20 are included too.
    let mut stories: HashMap<i64, StoryData> = HashMap::new();

    for hit in algolia_hits {
        let id: i64 = match hit.object_id.parse() {
            Ok(n) if n != 0 => n,
            _ => continue,
        };
        let title = hit.title.unwrap_or_default();
        if title.is_empty() {
            continue;
        }
        stories.insert(id, StoryData {
            id,
            title,
            url: hit.url,
            author: hit.author.unwrap_or_default(),
            points: hit.points.unwrap_or(0),
            num_comments: hit.num_comments.unwrap_or(0),
            created_at: hit.created_at_i.unwrap_or(0),
            rating: None,
        });
    }

    for s in db_rated {
        stories
            .entry(s.id)
            .and_modify(|e| e.rating = Some(s.rating.clone()))
            .or_insert(StoryData {
                id: s.id,
                title: s.title,
                url: s.url,
                author: s.author,
                points: s.points,
                num_comments: s.num_comments,
                created_at: s.created_at,
                rating: Some(s.rating),
            });
    }

    // Count per category across the full merged set
    let mut count_map: HashMap<&str, i64> = HashMap::new();
    for s in stories.values() {
        let key = match s.rating.as_deref() {
            Some("thumbs_up") => "thumbs_up",
            Some("average") => "average",
            Some("thumbs_down") => "thumbs_down",
            _ => "unrated",
        };
        *count_map.entry(key).or_insert(0) += 1;
    }
    let total = stories.len() as i64;

    let tabs = vec![
        TabContext { key: "all".to_string(),         label: "All".to_string(),     count: total },
        TabContext { key: "unrated".to_string(),    label: "Unrated".to_string(), count: *count_map.get("unrated").unwrap_or(&0) },
        TabContext { key: "thumbs_up".to_string(),  label: "👍 Up".to_string(),   count: *count_map.get("thumbs_up").unwrap_or(&0) },
        TabContext { key: "average".to_string(),    label: "👋 Mid".to_string(),  count: *count_map.get("average").unwrap_or(&0) },
        TabContext { key: "thumbs_down".to_string(),label: "👎 Down".to_string(), count: *count_map.get("thumbs_down").unwrap_or(&0) },
    ];

    // Filter and sort
    let mut filtered: Vec<&StoryData> = stories.values().filter(|s| match filter.as_str() {
        "thumbs_up"   => s.rating.as_deref() == Some("thumbs_up"),
        "average"     => s.rating.as_deref() == Some("average"),
        "thumbs_down" => s.rating.as_deref() == Some("thumbs_down"),
        "all"         => true,
        _             => s.rating.is_none(),
    }).collect();

    if sort == "date" {
        filtered.sort_by(|a, b| b.created_at.cmp(&a.created_at));
    } else {
        filtered.sort_by(|a, b| b.points.cmp(&a.points));
    }

    let now = Utc::now().timestamp();
    let stories_ctx: Vec<StoryContext> = filtered.into_iter().map(|s| {
        let domain = s.url.as_ref()
            .and_then(|u| Url::parse(u).ok())
            .and_then(|u| u.host_str().map(|h| h.strip_prefix("www.").unwrap_or(h).to_string()))
            .unwrap_or_default();
        let title_url = s.url.clone()
            .unwrap_or_else(|| format!("https://news.ycombinator.com/item?id={}", s.id));
        let url_raw = s.url.clone().unwrap_or_default();

        let diff = now - s.created_at;
        let time_ago = if diff < 3600 { format!("{}m ago", diff / 60) }
            else if diff < 86400 { format!("{}h ago", diff / 3600) }
            else { format!("{}d ago", diff / 86400) };

        let rating_html = render_rating_group_html(&state.jinja, s.id, s.rating.as_deref());

        StoryContext {
            id: s.id,
            title: s.title.clone(),
            title_url,
            url_raw,
            domain,
            author: s.author.clone(),
            points: s.points,
            num_comments: s.num_comments,
            created_at: s.created_at,
            time_ago,
            rating_html,
        }
    }).collect();

    let html = state.jinja.render("hn/index.html", minijinja::context! {
        filter => filter,
        sort => sort,
        date => date_str,
        today => today_str,
        prev_date => prev_date,
        next_date => next_date,
        tabs => tabs,
        stories => stories_ctx,
        fetch_error => fetch_error,
    });

    Html(html)
}

#[derive(Serialize)]
struct RatingButton {
    val: &'static str,
    emoji: &'static str,
}

fn render_rating_group_html(jinja: &crate::JinjaEnv, id: i64, current_rating: Option<&str>) -> String {
    let buttons = vec![
        RatingButton { val: "thumbs_up",   emoji: "👍" },
        RatingButton { val: "average",     emoji: "👋" },
        RatingButton { val: "thumbs_down", emoji: "👎" },
    ];
    jinja.render("hn/rating_group.html", minijinja::context! {
        id => id,
        current_rating => current_rating,
        buttons => buttons,
    })
}

/// Story data submitted alongside every rating action via hx-include.
#[derive(Deserialize)]
struct RateForm {
    rating: String,
    title: String,
    url: Option<String>,
    author: String,
    points: i64,
    num_comments: i64,
    created_at: i64,
}

async fn rate_story(
    State(state): State<AppState>,
    Path(id): Path<i64>,
    Form(form): Form<RateForm>,
) -> impl IntoResponse {
    // Normalise empty-string URL (comes from hidden input) back to NULL
    let url: Option<&str> = form.url.as_deref().filter(|s| !s.is_empty());

    let _ = sqlx::query(
        "INSERT INTO hn_stories (id, title, url, author, points, num_comments, created_at, fetched_at) \
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, datetime('now')) \
         ON CONFLICT(id) DO UPDATE SET \
             points = excluded.points, \
             num_comments = excluded.num_comments",
    )
    .bind(id)
    .bind(&form.title)
    .bind(url)
    .bind(&form.author)
    .bind(form.points)
    .bind(form.num_comments)
    .bind(form.created_at)
    .execute(&state.pool)
    .await;

    let _ = sqlx::query(
        "INSERT INTO hn_ratings (story_id, rating, rated_at) \
         VALUES (?1, ?2, datetime('now')) \
         ON CONFLICT(story_id) DO UPDATE SET \
             rating = excluded.rating, \
             rated_at = excluded.rated_at",
    )
    .bind(id)
    .bind(&form.rating)
    .execute(&state.pool)
    .await;

    Html(render_rating_group_html(&state.jinja, id, Some(&form.rating)))
}

async fn unrate_story(State(state): State<AppState>, Path(id): Path<i64>) -> impl IntoResponse {
    let _ = sqlx::query("DELETE FROM hn_ratings WHERE story_id = ?1").bind(id).execute(&state.pool).await;
    let _ = sqlx::query("DELETE FROM hn_stories  WHERE id        = ?1").bind(id).execute(&state.pool).await;

    Html(render_rating_group_html(&state.jinja, id, None))
}

#[derive(FromRow, Serialize)]
struct ExportStory {
    id: i64,
    title: String,
    url: Option<String>,
    author: String,
    points: i64,
    num_comments: i64,
    hn_created_at: i64,
    rating: String,
    rated_at: String,
}

async fn export(State(state): State<AppState>) -> impl IntoResponse {
    let stories: Vec<ExportStory> = sqlx::query_as(
        "SELECT s.id, s.title, s.url, s.author, s.points, s.num_comments, \
                s.created_at as hn_created_at, r.rating, r.rated_at \
         FROM hn_stories s \
         JOIN hn_ratings r ON s.id = r.story_id",
    )
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    Json(stories)
}
