#[cfg(not(target_os = "android"))]
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;

use serde::Deserialize;
use serde_json::json;
use tokio::io::{AsyncBufReadExt, AsyncReadExt, AsyncWriteExt, BufReader};
use tokio::net::{TcpListener, TcpStream};

use crate::models::{ProviderKind, Release};
use crate::player::{mpv_executable, PlayerKind};
use crate::providers::ResolutionIntent;
use crate::service::MovieBoxService;

const MAX_BODY_BYTES: usize = 2 * 1024 * 1024;
const DEFAULT_DEV_BRIDGE_PORT: u16 = 8765;

#[derive(Debug, Deserialize)]
struct SearchPayload {
    query: String,
    #[serde(default = "default_provider")]
    provider: String,
    #[serde(default = "default_page")]
    page: usize,
}

#[derive(Debug, Deserialize)]
struct HomepagePayload {
    #[serde(default = "default_tab")]
    tab: String,
    #[serde(default = "default_page")]
    page: usize,
}

#[derive(Debug, Deserialize)]
struct DetailsPayload {
    id: serde_json::Value,
    #[serde(default = "default_provider")]
    provider: String,
}

#[derive(Debug, Deserialize)]
struct EpisodeStreamsPayload {
    id: serde_json::Value,
    #[serde(default = "default_provider")]
    provider: String,
    #[serde(default)]
    season: usize,
    #[serde(default)]
    episode: usize,
}

fn extract_id_string(val: &serde_json::Value) -> String {
    if let Some(s) = val.as_str() {
        s.to_string()
    } else if let Some(obj) = val.as_object() {
        if let Some(v) = obj.get("value").and_then(|x| x.as_str()) {
            v.to_string()
        } else if let Some(v) = obj.get("id").and_then(|x| x.as_str()) {
            v.to_string()
        } else {
            val.to_string().trim_matches('"').to_string()
        }
    } else {
        val.to_string().trim_matches('"').to_string()
    }
}

#[derive(Debug, Deserialize)]
struct CaptionsPayload {
    #[serde(default)]
    subject_id: serde_json::Value,
    #[serde(default)]
    resource_id: Option<String>,
    #[serde(default)]
    sibling_ids: Vec<String>,
    #[serde(default)]
    season: usize,
    #[serde(default)]
    episode: usize,
}

#[derive(Debug, Deserialize)]
struct ResolveStreamPayload {
    release: serde_json::Value,
    #[serde(default = "default_provider")]
    provider: String,
}

#[derive(Debug, Deserialize)]
struct PlayPayload {
    title: Option<String>,
    url: String,
    #[serde(default)]
    headers: HashMap<String, String>,
    subtitle: Option<String>,
    #[serde(default = "default_provider")]
    provider: String,
    subject_id: Option<String>,
    #[serde(default)]
    season: usize,
    #[serde(default)]
    episode: usize,
}

fn default_provider() -> String {
    "moviebox".to_string()
}

fn default_page() -> usize {
    1
}

fn default_tab() -> String {
    "movie".to_string()
}

fn sanitize_stream_url(raw: &str) -> String {
    if let Ok(parsed) = url::Url::parse(raw) {
        let scheme = parsed.scheme();
        let host = parsed.host_str().unwrap_or("unknown");
        let port_part = parsed.port().map(|p| format!(":{p}")).unwrap_or_default();
        let path = parsed.path();
        format!("{scheme}://{host}{port_part}{path}")
    } else {
        "invalid_url".to_string()
    }
}

pub async fn run_dev_bridge(port_override: Option<u16>) -> Result<(), Box<dyn std::error::Error>> {
    let port = port_override.unwrap_or(DEFAULT_DEV_BRIDGE_PORT);
    let addr = format!("127.0.0.1:{port}");
    let listener = TcpListener::bind(&addr).await?;
    println!("\n=======================================================");
    println!(" [MovieBox Desktop Bridge] Running on http://{addr}");
    println!(" - Connected to real MovieBox Rust core");
    if let Some(mpv_path) = mpv_executable() {
        println!(" - Detected Windows mpv: {mpv_path}");
    } else {
        println!(" - Warning: mpv executable not found in PATH or bin/");
    }
    println!(" - Ready for Flutter Chrome development on localhost");
    println!("=======================================================\n");

    let service = Arc::new(MovieBoxService::new());

    loop {
        match listener.accept().await {
            Ok((stream, _)) => {
                let service = Arc::clone(&service);
                tokio::spawn(async move {
                    if let Err(e) = handle_http_client(stream, service).await {
                        log::debug!("Dev bridge client error: {e}");
                    }
                });
            }
            Err(e) => {
                log::warn!("Dev bridge accept error: {e}");
                tokio::time::sleep(Duration::from_millis(50)).await;
            }
        }
    }
}

async fn handle_http_client(
    mut stream: TcpStream,
    service: Arc<MovieBoxService>,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let (reader, mut writer) = stream.split();
    let mut buf_reader = BufReader::new(reader);

    let mut request_line = String::new();
    if buf_reader.read_line(&mut request_line).await? == 0 {
        return Ok(());
    }

    let mut parts = request_line.split_whitespace();
    let method = parts.next().unwrap_or("GET");
    let path = parts.next().unwrap_or("/");

    let mut content_length = 0usize;
    loop {
        let mut header_line = String::new();
        if buf_reader.read_line(&mut header_line).await? == 0 {
            break;
        }
        let trimmed = header_line.trim();
        if trimmed.is_empty() {
            break;
        }
        if let Some((k, v)) = trimmed.split_once(':') {
            if k.trim().eq_ignore_ascii_case("content-length") {
                if let Ok(len) = v.trim().parse::<usize>() {
                    content_length = len;
                }
            }
        }
    }

    // Handle CORS preflight
    if method == "OPTIONS" {
        let response = "HTTP/1.1 204 No Content\r\n\
Access-Control-Allow-Origin: *\r\n\
Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n\
Access-Control-Allow-Headers: Content-Type, Authorization\r\n\
Access-Control-Max-Age: 86400\r\n\
Connection: close\r\n\r\n";
        writer.write_all(response.as_bytes()).await?;
        return Ok(());
    }

    // Read body if present
    let mut body = Vec::new();
    if content_length > 0 && content_length <= MAX_BODY_BYTES {
        body.resize(content_length, 0);
        buf_reader.read_exact(&mut body).await?;
    }

    let clean_path = path.split('?').next().unwrap_or(path);
    let (status_code, response_json) = route_request(method, clean_path, &body, service).await;

    let body_bytes = serde_json::to_vec(&response_json).unwrap_or_default();
    let header = format!(
        "HTTP/1.1 {status_code}\r\n\
Content-Type: application/json; charset=utf-8\r\n\
Content-Length: {}\r\n\
Access-Control-Allow-Origin: *\r\n\
Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n\
Access-Control-Allow-Headers: Content-Type, Authorization\r\n\
Connection: close\r\n\r\n",
        body_bytes.len()
    );

    writer.write_all(header.as_bytes()).await?;
    writer.write_all(&body_bytes).await?;
    writer.flush().await?;

    Ok(())
}

async fn route_request(
    method: &str,
    path: &str,
    body: &[u8],
    service: Arc<MovieBoxService>,
) -> (&'static str, serde_json::Value) {
    match (method, path) {
        ("GET", "/health") | ("GET", "/api/health") => {
            let mpv_opt = mpv_executable();
            (
                "200 OK",
                json!({
                    "status": "ok",
                    "mpv_available": mpv_opt.is_some(),
                    "mpv_path": mpv_opt
                }),
            )
        }
        ("POST", "/api/homepage") => {
            let payload: HomepagePayload = serde_json::from_slice(body).unwrap_or(HomepagePayload {
                tab: "movie".to_string(),
                page: 1,
            });
            match service.homepage(&payload.tab, payload.page).await {
                Ok((items, metrics)) => (
                    "200 OK",
                    json!({
                        "success": true,
                        "items": items,
                        "metrics": metrics
                    }),
                ),
                Err(e) => (
                    "200 OK",
                    json!({
                        "success": false,
                        "error": e
                    }),
                ),
            }
        }
        ("POST", "/api/search") => {
            let payload: SearchPayload = match serde_json::from_slice(body) {
                Ok(p) => p,
                Err(e) => {
                    return (
                        "400 Bad Request",
                        json!({"success": false, "error": format!("Invalid JSON: {e}")}),
                    );
                }
            };
            let provider = ProviderKind::parse(&payload.provider).unwrap_or(ProviderKind::MovieBox);
            match service.search_typed(provider, &payload.query, payload.page).await {
                Ok(results) => ("200 OK", json!({"success": true, "results": results})),
                Err(e) => (
                    "200 OK",
                    json!({
                        "success": false,
                        "error": e.user_message(provider),
                        "raw_error": e.to_string()
                    }),
                ),
            }
        }
        ("POST", "/api/details") => {
            let payload: DetailsPayload = match serde_json::from_slice(body) {
                Ok(p) => p,
                Err(e) => {
                    return (
                        "400 Bad Request",
                        json!({"success": false, "error": format!("Invalid JSON: {e}")}),
                    );
                }
            };
            let provider = ProviderKind::parse(&payload.provider).unwrap_or(ProviderKind::MovieBox);
            let id_str = extract_id_string(&payload.id);
            match service.details_typed(provider, &id_str).await {
                Ok(details) => ("200 OK", json!({"success": true, "details": details})),
                Err(e) => (
                    "200 OK",
                    json!({
                        "success": false,
                        "error": e.user_message(provider),
                        "raw_error": e.to_string()
                    }),
                ),
            }
        }
        ("POST", "/api/episode_streams") => {
            let payload: EpisodeStreamsPayload = match serde_json::from_slice(body) {
                Ok(p) => p,
                Err(e) => {
                    return (
                        "400 Bad Request",
                        json!({"success": false, "error": format!("Invalid JSON: {e}")}),
                    );
                }
            };
            let provider = ProviderKind::parse(&payload.provider).unwrap_or(ProviderKind::MovieBox);
            let id_str = extract_id_string(&payload.id);
            let s = payload.season;
            let ep = payload.episode;

            let result = match provider {
                ProviderKind::MovieBox => {
                    crate::providers::ReleaseProvider::episode_streams(&service.client, &id_str, s, ep).await
                }
                ProviderKind::FourKHdHub => {
                    if let Some(fourk) = service.fourk_client.as_ref() {
                        crate::providers::ReleaseProvider::episode_streams(fourk, &id_str, s, ep).await
                    } else {
                        Err(crate::providers::models::ProviderError::Unavailable("4KHDHub unavailable".into()))
                    }
                }
                ProviderKind::BdixCircleFtp => {
                    crate::providers::ReleaseProvider::episode_streams(&service.circleftp_client, &id_str, s, ep).await
                }
                ProviderKind::BdixDhakaFlix => {
                    crate::providers::ReleaseProvider::episode_streams(&service.dhakaflix_client, &id_str, s, ep).await
                }
                ProviderKind::Addons => {
                    let addons = crate::config::load_addons();
                    let (releases, _) = crate::providers::addons::aggregate_streams(
                        &service.addon_client,
                        &addons,
                        &id_str,
                        s,
                        ep,
                        s > 0 || ep > 0,
                    )
                    .await;
                    Ok(releases)
                }
            };

            match result {
                Ok(releases) => ("200 OK", json!({"success": true, "releases": releases})),
                Err(e) => (
                    "200 OK",
                    json!({
                        "success": false,
                        "error": e.user_message(provider),
                        "raw_error": e.to_string()
                    }),
                ),
            }
        }
        ("POST", "/api/captions") => {
            let payload: CaptionsPayload = match serde_json::from_slice(body) {
                Ok(p) => p,
                Err(e) => {
                    return (
                        "400 Bad Request",
                        json!({"success": false, "error": format!("Invalid JSON: {e}")}),
                    );
                }
            };
            let subject_id_str = extract_id_string(&payload.subject_id);
            let resource_id_str = payload.resource_id.unwrap_or_default();
            match service
                .get_ext_captions(
                    &subject_id_str,
                    &resource_id_str,
                    &payload.sibling_ids,
                    payload.season,
                    payload.episode,
                )
                .await
            {
                Ok(captions) => ("200 OK", json!({"success": true, "captions": captions})),
                Err(e) => ("200 OK", json!({"success": false, "error": e})),
            }
        }
        ("POST", "/api/resolve_stream") => {
            let payload: ResolveStreamPayload = match serde_json::from_slice(body) {
                Ok(p) => p,
                Err(e) => {
                    return (
                        "400 Bad Request",
                        json!({"success": false, "error": format!("Invalid JSON: {e}")}),
                    );
                }
            };
            let provider = ProviderKind::parse(&payload.provider).unwrap_or(ProviderKind::MovieBox);
            let release: Release = match serde_json::from_value(payload.release) {
                Ok(r) => r,
                Err(e) => {
                    return (
                        "400 Bad Request",
                        json!({"success": false, "error": format!("Invalid release structure: {e}")}),
                    );
                }
            };

            let source_res = match provider {
                ProviderKind::FourKHdHub => {
                    if let Some(fourk) = service.fourk_client.as_ref() {
                        fourk
                            .resolve_release(&release, ResolutionIntent::Playback)
                            .await
                            .map_err(|e| e.to_string())
                    } else {
                        Err("4KHDHub unavailable".into())
                    }
                }
                _ => {
                    if let Some(direct_url) = release.direct_url() {
                        let mut headers = Vec::new();
                        if let Some(first_mirror) = release.mirrors.first() {
                            headers = first_mirror.headers.clone();
                        }
                        if headers.is_empty() && provider == ProviderKind::MovieBox {
                            headers.push((
                                "Referer".to_string(),
                                crate::providers::moviebox::STREAM_REFERER.to_string(),
                            ));
                            headers.push((
                                "User-Agent".to_string(),
                                service.client.user_agent().to_string(),
                            ));
                        }
                        Ok(crate::providers::PlaybackSource {
                            provider,
                            url: direct_url.to_string(),
                            headers,
                            subtitle: None,
                            source_label: release.source_label().to_string(),
                        })
                    } else {
                        Err("No direct stream available for this release".into())
                    }
                }
            };

            match source_res {
                Ok(source) => ("200 OK", json!({"success": true, "source": source})),
                Err(e) => ("200 OK", json!({"success": false, "error": e})),
            }
        }
        ("POST", "/api/play") => {
            let payload: PlayPayload = match serde_json::from_slice(body) {
                Ok(p) => p,
                Err(e) => {
                    return (
                        "400 Bad Request",
                        json!({"success": false, "error": format!("Invalid JSON payload: {e}")}),
                    );
                }
            };

            let mpv_path = match mpv_executable() {
                Some(p) => p,
                None => {
                    println!("[DesktopBridge] Error: mpv executable not found on this system.");
                    return (
                        "200 OK",
                        json!({
                            "success": false,
                            "error": "mpv was not found on this PC. Please ensure mpv.exe is in PATH or in the project bin/ directory."
                        }),
                    );
                }
            };

            let headers_vec: Vec<(String, String)> = payload.headers.into_iter().collect();
            let header_names: Vec<String> = headers_vec.iter().map(|(k, _)| k.clone()).collect();
            let sanitized_url = sanitize_stream_url(&payload.url);

            println!("\n=======================================================");
            println!("[DesktopBridge] >>> Received Playback Request <<<");
            println!("  Title:       {}", payload.title.as_deref().unwrap_or("Untitled"));
            println!("  Provider:    {}", payload.provider);
            println!("  Stream URL:  {}", sanitized_url);
            println!("  Headers:     [{}]", header_names.join(", "));
            if let Some(sub) = &payload.subtitle {
                println!("  Subtitle:    {}", sanitize_stream_url(sub));
            }

            println!("  Playback:    Direct native MPV playback with Edge-Cache headers (zero proxy overhead)");

            let mut sub_local_path: Option<String> = None;
            if let Some(sub_url) = &payload.subtitle {
                if sub_url.starts_with("http://") || sub_url.starts_with("https://") {
                    println!("  Fetching Subtitle: {sub_url}");
                    let http = reqwest::Client::new();
                    if let Ok(resp) = http.get(sub_url).send().await {
                        if let Ok(content) = resp.text().await {
                            let temp_file = std::env::temp_dir().join("moviebox_selected_sub.srt");
                            if tokio::fs::write(&temp_file, content).await.is_ok() {
                                println!("  Saved Subtitle:    {}", temp_file.display());
                                sub_local_path = Some(temp_file.to_string_lossy().into_owned());
                            }
                        }
                    }
                    if sub_local_path.is_none() {
                        sub_local_path = Some(sub_url.clone());
                    }
                } else {
                    sub_local_path = Some(sub_url.clone());
                }
            }

            let tracker = payload
                .subject_id
                .as_deref()
                .map(|id| (payload.provider.as_str(), id, payload.season, payload.episode));

            let mut std_cmd = crate::player::command(
                PlayerKind::Mpv,
                &payload.url,
                sub_local_path.as_deref(),
                &headers_vec,
                None,
                None,
                tracker,
            );

            // Force window and keep open for dev bridge visibility so errors or short buffers don't vanish
            std_cmd.arg("--force-window=yes");
            std_cmd.arg("--keep-open=yes");

            let mut tokio_cmd = tokio::process::Command::from(std_cmd);
            tokio_cmd.stdout(std::process::Stdio::piped());
            tokio_cmd.stderr(std::process::Stdio::piped());

            println!("  mpv Exec:    {}", mpv_path);

            match tokio_cmd.spawn() {
                Ok(mut child) => {
                    let pid = child.id().unwrap_or(0);
                    println!("  mpv Process: Spawned PID {pid} successfully");
                    println!("=======================================================\n");

                    // Read stdout asynchronously
                    if let Some(stdout) = child.stdout.take() {
                        tokio::spawn(async move {
                            let mut lines = BufReader::new(stdout).lines();
                            while let Ok(Some(line)) = lines.next_line().await {
                                println!("[mpv stdout] {line}");
                            }
                        });
                    }

                    // Read stderr asynchronously
                    if let Some(stderr) = child.stderr.take() {
                        tokio::spawn(async move {
                            let mut lines = BufReader::new(stderr).lines();
                            while let Ok(Some(line)) = lines.next_line().await {
                                println!("[mpv stderr] {line}");
                            }
                        });
                    }

                    // Watch process exit status asynchronously
                    tokio::spawn(async move {
                        match child.wait().await {
                            Ok(status) => {
                                println!("[DesktopBridge] mpv (PID {pid}) finished with exit status: {status}");
                            }
                            Err(e) => {
                                println!("[DesktopBridge] Error awaiting mpv (PID {pid}): {e}");
                            }
                        }
                    });

                    (
                        "200 OK",
                        json!({
                            "success": true,
                            "message": "mpv launched successfully",
                            "pid": pid,
                            "playback_url": payload.url
                        }),
                    )
                }
                Err(e) => {
                    println!("  mpv Spawn Error: {e}");
                    println!("=======================================================\n");
                    (
                        "200 OK",
                        json!({
                            "success": false,
                            "error": format!("Failed to spawn mpv ({mpv_path}): {e}")
                        }),
                    )
                }
            }
        }
        _ => ("404 Not Found", json!({"success": false, "error": "Endpoint not found"})),
    }
}
