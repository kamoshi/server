use axum::{routing::get, Router, response::IntoResponse, http::StatusCode};
use serde::{Deserialize, Serialize};
use std::env;
use tokio::net::TcpListener;

#[derive(Deserialize, Debug)]
struct MinifluxResponse {
    entries: Vec<MinifluxEntry>,
}

#[derive(Deserialize, Debug)]
struct MinifluxEntry {
    title: String,
    content: String,
}

#[derive(Serialize, Debug)]
struct GeminiRequest {
    contents: Vec<GeminiContent>,
    system_instruction: Option<GeminiSystemInstruction>,
}

#[derive(Serialize, Debug)]
struct GeminiSystemInstruction {
    parts: Vec<GeminiPart>,
}

#[derive(Serialize, Deserialize, Debug)]
struct GeminiContent {
    parts: Vec<GeminiPart>,
}

#[derive(Serialize, Deserialize, Debug)]
struct GeminiPart {
    text: String,
}

#[derive(Deserialize, Debug)]
struct GeminiResponse {
    candidates: Option<Vec<GeminiCandidate>>,
}

#[derive(Deserialize, Debug)]
struct GeminiCandidate {
    content: GeminiContent,
}

async fn get_summary() -> Result<String, (StatusCode, String)> {
    let miniflux_url = env::var("MINIFLUX_URL")
        .unwrap_or_else(|_| "http://localhost:8080".to_string());
    let miniflux_api_key = env::var("MINIFLUX_API_KEY")
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Missing MINIFLUX_API_KEY".to_string()))?;
    let gemini_api_key = env::var("GEMINI_API_KEY")
        .map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, "Missing GEMINI_API_KEY".to_string()))?;

    let client = reqwest::Client::new();

    let mf_res = client
        .get(&format!("{}/v1/entries?status=unread", miniflux_url))
        .header("X-Auth-Token", miniflux_api_key)
        .send()
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Miniflux request failed: {}", e)))?;

    if !mf_res.status().is_success() {
        return Err((StatusCode::INTERNAL_SERVER_ERROR, "Miniflux API returned error".to_string()));
    }

    let mf_data: MinifluxResponse = mf_res
        .json()
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to parse Miniflux response: {}", e)))?;

    if mf_data.entries.is_empty() {
        return Ok("No unread articles.".to_string());
    }

    let mut combined_content = String::new();
    for entry in mf_data.entries {
        combined_content.push_str(&format!("Title: {}\nContent: {}\n\n", entry.title, entry.content));
    }

    let gemini_url = format!(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={}",
        gemini_api_key
    );

    let system_prompt = "Summarize the following articles in Polish. If there are any Japanese terms, vocabulary, or concepts that require explanation, you must provide those explanations in English using 漢字. You must never, ever use Romaji.";

    let gemini_req = GeminiRequest {
        contents: vec![GeminiContent {
            parts: vec![GeminiPart {
                text: combined_content,
            }],
        }],
        system_instruction: Some(GeminiSystemInstruction {
            parts: vec![GeminiPart {
                text: system_prompt.to_string(),
            }]
        })
    };

    let gemini_res = client
        .post(&gemini_url)
        .json(&gemini_req)
        .send()
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Gemini request failed: {}", e)))?;

    if !gemini_res.status().is_success() {
        let err_text = gemini_res.text().await.unwrap_or_default();
        return Err((StatusCode::INTERNAL_SERVER_ERROR, format!("Gemini API returned error: {}", err_text)));
    }

    let gemini_data: GeminiResponse = gemini_res
        .json()
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, format!("Failed to parse Gemini response: {}", e)))?;

    let summary = gemini_data
        .candidates
        .and_then(|mut c| c.pop())
        .map(|c| c.content.parts.into_iter().map(|p| p.text).collect::<Vec<_>>().join("\n"))
        .unwrap_or_else(|| "No summary generated.".to_string());

    Ok(summary)
}

async fn hello() -> &'static str {
    "world"
}

#[tokio::main]
async fn main() {
    // let app = Router::new().route("/summary", get(get_summary));
    let app = Router::new().route("/hello", get(hello));

    let port = env::var("PORT").unwrap_or_else(|_| "3000".to_string());
    let addr = format!("0.0.0.0:{}", port);
    let listener = TcpListener::bind(&addr).await.expect("Failed to bind to port");

    println!("Server running on {}", addr);
    axum::serve(listener, app).await.expect("Server failed");
}
