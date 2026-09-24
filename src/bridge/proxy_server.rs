use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use futures::StreamExt;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::watch;

const MAX_LINE_BYTES: usize = 8 * 1024;
const MAX_HEADERS: usize = 64;
const MAX_MANIFEST_BYTES: usize = 10 * 1024 * 1024;
const CHUNK_IDLE_TIMEOUT_SECS: u64 = 60;
const IN_PROCESS_WATCHDOG_IDLE_SECS: u64 = 600;

static CURRENT_PROXY: Mutex<Option<Arc<InProcessProxy>>> = Mutex::new(None);

pub struct InProcessProxy {
    pub port: u16,
    pub proxy_url: String,
    cancel_tx: watch::Sender<bool>,
}

impl InProcessProxy {
    pub async fn start_singleton(
        target_url: &str,
        headers: &[(String, String)],
        subtitle_url: Option<&str>,
    ) -> Result<Arc<Self>, String> {
        let existing = {
            let mut lock = CURRENT_PROXY
                .lock()
                .map_err(|e| format!("Proxy lock error: {e}"))?;
            lock.take()
        };
        if let Some(existing) = existing {
            existing.stop();
        }

        let proxy = Arc::new(Self::start(target_url, headers, subtitle_url).await?);
        {
            let mut lock = CURRENT_PROXY
                .lock()
                .map_err(|e| format!("Proxy lock error: {e}"))?;
            *lock = Some(proxy.clone());
        }
        Ok(proxy)
    }

    pub fn stop_current() {
        if let Ok(mut lock) = CURRENT_PROXY.lock() {
            if let Some(existing) = lock.take() {
                existing.stop();
            }
        }
    }

    pub async fn start(
        target_url: &str,
        headers: &[(String, String)],
        subtitle_url: Option<&str>,
    ) -> Result<Self, String> {
        let listener = TcpListener::bind("127.0.0.1:0")
            .await
            .map_err(|e| format!("Failed to bind in-process proxy TCP listener: {e}"))?;

        let port = listener
            .local_addr()
            .map_err(|e| format!("Failed to get local port: {e}"))?
            .port();

        let (cancel_tx, mut cancel_rx) = watch::channel(false);

        let proxy_path = if let Some(rest) = target_url.strip_prefix("https://") {
            format!("/https/{rest}")
        } else if let Some(rest) = target_url.strip_prefix("http://") {
            format!("/http/{rest}")
        } else {
            format!("/https/{target_url}")
        };

        let proxy_url = format!("http://127.0.0.1:{port}{proxy_path}");

        let client = crate::net::http_client_builder()
            .connect_timeout(Duration::from_secs(15))
            .build()
            .unwrap_or_default();

        let active_connections = Arc::new(AtomicUsize::new(0));
        let last_activity = Arc::new(Mutex::new(Instant::now()));

        let target_host = extract_host_authority(target_url);
        let _target_url_owned = target_url.to_string();
        let headers_owned = headers.to_vec();
        let subtitle_url_owned = subtitle_url.map(|s| s.to_string());

        let watchdog_conns = Arc::clone(&active_connections);
        let watchdog_activity = Arc::clone(&last_activity);
        let cancel_tx_watchdog = cancel_tx.clone();

        tokio::spawn(async move {
            loop {
                tokio::time::sleep(Duration::from_secs(15)).await;
                let conns = watchdog_conns.load(Ordering::Relaxed);
                let elapsed = {
                    let lock = watchdog_activity.lock().unwrap();
                    lock.elapsed()
                };
                if conns == 0 && elapsed > Duration::from_secs(IN_PROCESS_WATCHDOG_IDLE_SECS) {
                    let _ = cancel_tx_watchdog.send(true);
                    break;
                }
            }
        });

        tokio::spawn(async move {
            loop {
                tokio::select! {
                    changed_res = cancel_rx.changed() => {
                        match changed_res {
                            Ok(_) => {
                                if *cancel_rx.borrow() {
                                    break;
                                }
                            }
                            Err(_) => {
                                break;
                            }
                        }
                    }
                    accept_res = listener.accept() => {
                        let (stream, _) = match accept_res {
                            Ok(val) => val,
                            Err(err) => {
                                log::warn!("transient in-process proxy accept error: {err}");
                                tokio::time::sleep(Duration::from_millis(50)).await;
                                continue;
                            }
                        };

                        let client = client.clone();
                        let headers = headers_owned.clone();
                        let target_host = target_host.clone();
                        let active_conns = Arc::clone(&active_connections);
                        let activity = Arc::clone(&last_activity);
                        let sub_opt = subtitle_url_owned.clone();

                        active_conns.fetch_add(1, Ordering::Relaxed);
                        {
                            if let Ok(mut lock) = activity.lock() {
                                *lock = Instant::now();
                            }
                        }

                        tokio::spawn(async move {
                            struct ConnGuard {
                                conns: Arc<AtomicUsize>,
                                activity: Arc<Mutex<Instant>>,
                            }
                            impl Drop for ConnGuard {
                                fn drop(&mut self) {
                                    self.conns.fetch_sub(1, Ordering::Relaxed);
                                    if let Ok(mut lock) = self.activity.lock() {
                                        *lock = Instant::now();
                                    }
                                }
                            }

                            let _guard = ConnGuard {
                                conns: active_conns,
                                activity,
                            };

                            let _ = handle_connection(
                                stream,
                                port,
                                &client,
                                &headers,
                                target_host.as_deref(),
                                sub_opt.as_deref(),
                            )
                            .await;
                        });
                    }
                }
            }
        });

        Ok(Self {
            port,
            proxy_url,
            cancel_tx,
        })
    }

    pub fn stop(&self) {
        let _ = self.cancel_tx.send(true);
    }
}

fn extract_host_authority(url: &str) -> Option<String> {
    let after_scheme = url
        .strip_prefix("https://")
        .or_else(|| url.strip_prefix("http://"))?;
    let authority = after_scheme.split('/').next()?;
    if authority.is_empty() {
        None
    } else {
        Some(authority.to_string())
    }
}

#[cfg(target_os = "android")]
pub fn android_log(msg: &str) {
    use std::ffi::CString;
    unsafe extern "C" {
        fn __android_log_write(prio: i32, tag: *const std::ffi::c_char, text: *const std::ffi::c_char) -> i32;
    }
    if let Ok(tag) = CString::new("MovieBoxProxy") {
        if let Ok(c_msg) = CString::new(msg) {
            unsafe {
                __android_log_write(3, tag.as_ptr(), c_msg.as_ptr());
            }
        }
    }
}

#[cfg(not(target_os = "android"))]
pub fn android_log(msg: &str) {
    println!("[MovieBoxProxy] {msg}");
}

async fn handle_connection(
    stream: TcpStream,
    proxy_port: u16,
    client: &reqwest::Client,
    auth_headers: &[(String, String)],
    target_host: Option<&str>,
    subtitle_url: Option<&str>,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let (reader, mut writer) = stream.into_split();
    let mut buf_reader = BufReader::new(reader);

    let mut request_line = String::new();
    let n = buf_reader.read_line(&mut request_line).await?;
    if n == 0 {
        return Ok(());
    }
    if request_line.len() > MAX_LINE_BYTES {
        writer
            .write_all(b"HTTP/1.1 431 Request Header Fields Too Large\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
            .await?;
        return Ok(());
    }

    let mut parts = request_line.split_whitespace();
    let method = parts.next().unwrap_or("GET");
    let path_and_query = parts.next().unwrap_or("/");

    let mut range_header = None;
    let mut header_count = 0usize;
    loop {
        let mut header_line = String::new();
        if buf_reader.read_line(&mut header_line).await? == 0 {
            break;
        }
        let trimmed = header_line.trim();
        if trimmed.is_empty() {
            break;
        }
        if header_line.len() > MAX_LINE_BYTES {
            break;
        }
        header_count += 1;
        if header_count > MAX_HEADERS {
            break;
        }
        if let Some((name, val)) = trimmed.split_once(':') {
            if name.trim().eq_ignore_ascii_case("range") {
                range_header = Some(val.trim().to_string());
            }
        }
    }

    let target_url = match extract_target_url(path_and_query) {
        Some(url) => url,
        None => {
            android_log(&format!("400 Bad Request for path={path_and_query}"));
            let response =
                "HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
            writer.write_all(response.as_bytes()).await?;
            return Ok(());
        }
    };

    let safe_url = target_url.split('?').next().unwrap_or(&target_url);
    let start_time = Instant::now();
    android_log(&format!("REQ {method} {safe_url} (range={range_header:?})"));

    let mut req = match method {
        "HEAD" => client.head(&target_url),
        _ => client.get(&target_url),
    };

    for (name, val) in auth_headers {
        req = req.header(name.as_str(), val.as_str());
    }
    if let Some(range) = range_header {
        req = req.header("Range", range);
    }

    let upstream_res = match req.send().await {
        Ok(res) => res,
        Err(e) => {
            android_log(&format!("502 Bad Gateway for {safe_url}: {e}"));
            let body = format!("Gateway Error: {e}");
            let response = format!(
                "HTTP/1.1 502 Bad Gateway\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                body.len()
            );
            writer.write_all(response.as_bytes()).await?;
            return Ok(());
        }
    };

    let status = upstream_res.status();
    let content_length = upstream_res
        .headers()
        .get(reqwest::header::CONTENT_LENGTH)
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.parse::<usize>().ok());

    android_log(&format!("RESP {status} for {safe_url} (len={content_length:?})"));

    let status_line = format!(
        "HTTP/1.1 {} {}\r\n",
        status.as_u16(),
        status.canonical_reason().unwrap_or("OK")
    );
    writer.write_all(status_line.as_bytes()).await?;

    let is_dash_manifest = target_url.ends_with(".mpd")
        || upstream_res
            .headers()
            .get(reqwest::header::CONTENT_TYPE)
            .and_then(|v| v.to_str().ok())
            .map(|ct| ct.contains("dash+xml") || ct.contains("xml"))
            .unwrap_or(false);

    let within_manifest_limit = content_length.is_none_or(|len| len <= MAX_MANIFEST_BYTES);

    if is_dash_manifest && status.is_success() && within_manifest_limit {
        let manifest_bytes = upstream_res.bytes().await?;
        if manifest_bytes.len() > MAX_MANIFEST_BYTES {
            let body = "Manifest too large";
            writer
                .write_all(
                    format!(
                        "Content-Type: text/plain\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                        body.len()
                    )
                    .as_bytes(),
                )
                .await?;
            return Ok(());
        }
        let manifest_str = String::from_utf8_lossy(&manifest_bytes);
        let rewritten = rewrite_dash_manifest(&manifest_str, proxy_port, target_host, subtitle_url);
        let rewritten_bytes = rewritten.as_bytes();

        let headers_out = format!(
            "Content-Type: application/dash+xml\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
            rewritten_bytes.len()
        );
        writer.write_all(headers_out.as_bytes()).await?;
        writer.write_all(rewritten_bytes).await?;
        writer.flush().await?;
        android_log(&format!("DASH manifest rewritten & served in {:?}", start_time.elapsed()));
        return Ok(());
    }

    let headers_bytes = format_proxy_response_headers(upstream_res.headers(), &target_url);
    writer.write_all(&headers_bytes).await?;

    let mut stream = upstream_res.bytes_stream();
    let mut total_bytes = 0usize;
    loop {
        let chunk_result =
            tokio::time::timeout(Duration::from_secs(CHUNK_IDLE_TIMEOUT_SECS), stream.next()).await;
        match chunk_result {
            Ok(Some(Ok(chunk))) => {
                total_bytes += chunk.len();
                writer.write_all(&chunk).await?;
            }
            Ok(Some(Err(e))) => {
                android_log(&format!("Stream chunk error for {safe_url}: {e}"));
                return Err(Box::new(e));
            }
            Ok(None) => break,
            Err(_elapsed) => {
                android_log(&format!("Chunk idle timeout for {safe_url}"));
                break;
            }
        }
    }
    writer.flush().await?;
    android_log(&format!("DONE {safe_url} streamed {total_bytes} bytes in {:?}", start_time.elapsed()));

    Ok(())
}

fn format_proxy_response_headers(
    headers: &reqwest::header::HeaderMap,
    target_url: &str,
) -> Vec<u8> {
    let mut out = Vec::new();
    let clean_path = target_url
        .split('?')
        .next()
        .unwrap_or("")
        .split('#')
        .next()
        .unwrap_or("")
        .to_ascii_lowercase();
    let is_srt = clean_path.ends_with(".srt");
    let is_vtt = clean_path.ends_with(".vtt");

    for (header_name, header_val) in headers {
        let name_str = header_name.as_str();
        if (is_srt || is_vtt) && name_str.eq_ignore_ascii_case("content-type") {
            continue;
        }
        if name_str.eq_ignore_ascii_case("content-type")
            || name_str.eq_ignore_ascii_case("content-length")
            || name_str.eq_ignore_ascii_case("content-range")
            || name_str.eq_ignore_ascii_case("accept-ranges")
        {
            if let Ok(val_str) = header_val.to_str() {
                out.extend_from_slice(format!("{name_str}: {val_str}\r\n").as_bytes());
            }
        }
    }

    out.extend_from_slice(b"Access-Control-Allow-Origin: *\r\n");
    if is_srt {
        out.extend_from_slice(b"Content-Type: application/x-subrip\r\n");
    } else if is_vtt {
        out.extend_from_slice(b"Content-Type: text/vtt\r\n");
    }
    out.extend_from_slice(b"Connection: close\r\n\r\n");
    out
}

fn extract_target_url(path_and_query: &str) -> Option<String> {
    let raw = path_and_query.strip_prefix('/')?;
    if let Some(rest) = raw.strip_prefix("sub/") {
        if let Ok(decoded) = percent_encoding::percent_decode_str(rest).decode_utf8() {
            return Some(decoded.into_owned());
        }
    }
    if let Some(rest) = raw.strip_prefix("https/") {
        Some(format!("https://{rest}"))
    } else if let Some(rest) = raw.strip_prefix("http/") {
        Some(format!("http://{rest}"))
    } else if raw.starts_with("proxy?") || raw.contains("&url=") || raw.starts_with("proxy?url=") {
        let query_start = raw.find('?')?;
        let query = &raw[query_start + 1..];
        for pair in query.split('&') {
            if let Some((k, v)) = pair.split_once('=') {
                if k == "url" {
                    return percent_encoding::percent_decode_str(v)
                        .decode_utf8()
                        .ok()
                        .map(|s| s.into_owned());
                }
            }
        }
        None
    } else {
        None
    }
}

fn rewrite_dash_manifest(
    manifest: &str,
    proxy_port: u16,
    target_host: Option<&str>,
    subtitle_url: Option<&str>,
) -> String {
    let Some(host) = target_host else {
        return manifest.to_string();
    };

    let https_prefix = format!("https://{host}/");
    let http_prefix = format!("http://{host}/");

    let proxy_https = format!("http://127.0.0.1:{proxy_port}/https/{host}/");
    let proxy_http = format!("http://127.0.0.1:{proxy_port}/http/{host}/");

    let mut rewritten = manifest
        .replace(&https_prefix, &proxy_https)
        .replace(&http_prefix, &proxy_http);

    if let Some(sub) = subtitle_url {
        if !sub.is_empty() {
            let encoded_sub =
                percent_encoding::utf8_percent_encode(sub, percent_encoding::NON_ALPHANUMERIC);
            let sub_proxy_url = format!("http://127.0.0.1:{proxy_port}/sub/{encoded_sub}");
            let sub_adaptation_set = format!(
                r#"<AdaptationSet contentType="text" mimeType="text/vtt" lang="en">
    <Role schemeIdUri="urn:mpeg:dash:role:2011" value="subtitle"/>
    <Representation id="sub_en" bandwidth="1000">
      <BaseURL>{sub_proxy_url}</BaseURL>
    </Representation>
  </AdaptationSet>
</Period>"#
            );
            if rewritten.contains("</Period>") {
                rewritten = rewritten.replacen("</Period>", &sub_adaptation_set, 1);
            }
        }
    }

    rewritten
}
