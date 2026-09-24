use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::OnceLock;
use serde_json::json;

use crate::models::{ProviderKind, Release};
use crate::providers::ResolutionIntent;
use crate::service::MovieBoxService;

static RUNTIME: OnceLock<tokio::runtime::Runtime> = OnceLock::new();
static SERVICE: OnceLock<MovieBoxService> = OnceLock::new();

fn get_runtime() -> &'static tokio::runtime::Runtime {
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(4)
            .enable_all()
            .thread_name("moviebox-core-worker")
            .build()
            .expect("Failed to initialize Tokio runtime for MovieBox Core")
    })
}

fn get_service() -> &'static MovieBoxService {
    SERVICE.get_or_init(MovieBoxService::new)
}

fn string_to_c_char(s: String) -> *mut c_char {
    match CString::new(s) {
        Ok(c_string) => c_string.into_raw(),
        Err(_) => {
            let fallback =
                CString::new("{\"success\":false,\"error\":\"CString conversion error\"}").unwrap();
            fallback.into_raw()
        }
    }
}

fn parse_c_str(ptr: *const c_char) -> Option<String> {
    if ptr.is_null() {
        return None;
    }
    unsafe {
        CStr::from_ptr(ptr)
            .to_str()
            .ok()
            .map(|s| s.trim().to_string())
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn moviebox_core_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn moviebox_core_init(
    data_dir: *const c_char,
    cache_dir: *const c_char,
) -> *mut c_char {
    std::panic::catch_unwind(|| {
        if let Some(data) = parse_c_str(data_dir) {
            if !data.is_empty() {
                unsafe {
                    std::env::set_var("MOVIEBOX_DATA_DIR", &data);
                }
            }
        }
        if let Some(cache) = parse_c_str(cache_dir) {
            if !cache.is_empty() {
                unsafe {
                    std::env::set_var("MOVIEBOX_CACHE_DIR", &cache);
                }
            }
        }

        let _ = get_runtime();
        let _ = get_service();

        let res = json!({
            "success": true,
            "message": "MovieBox Core initialized successfully",
            "version": env!("CARGO_PKG_VERSION")
        });
        string_to_c_char(res.to_string())
    })
    .unwrap_or_else(|_| {
        string_to_c_char(
            json!({
                "success": false,
                "error": "Panic caught in moviebox_core_init"
            })
            .to_string(),
        )
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn moviebox_core_homepage(tab_id: *const c_char, page: u32) -> *mut c_char {
    std::panic::catch_unwind(|| {
        let tab = parse_c_str(tab_id).unwrap_or_else(|| "movie".to_string());
        let rt = get_runtime();
        let service = get_service();

        let page_num = if page == 0 { 1 } else { page as usize };

        match rt.block_on(async { service.homepage(&tab, page_num).await }) {
            Ok((items, metrics)) => {
                let res = json!({
                    "success": true,
                    "items": items,
                    "metrics": metrics
                });
                string_to_c_char(res.to_string())
            }
            Err(e) => {
                let res = json!({
                    "success": false,
                    "error": e
                });
                string_to_c_char(res.to_string())
            }
        }
    })
    .unwrap_or_else(|_| {
        string_to_c_char(
            json!({
                "success": false,
                "error": "Panic caught in moviebox_core_homepage"
            })
            .to_string(),
        )
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn moviebox_core_search(
    provider_str: *const c_char,
    query_str: *const c_char,
    page: u32,
) -> *mut c_char {
    std::panic::catch_unwind(|| {
        let provider_name = parse_c_str(provider_str).unwrap_or_else(|| "moviebox".to_string());
        let provider = ProviderKind::parse(&provider_name).unwrap_or(ProviderKind::MovieBox);
        let query = parse_c_str(query_str).unwrap_or_default();

        if query.is_empty() {
            return string_to_c_char(
                json!({
                    "success": true,
                    "results": []
                })
                .to_string(),
            );
        }

        let rt = get_runtime();
        let service = get_service();
        let page_num = if page == 0 { 1 } else { page as usize };

        match rt.block_on(async { service.search_typed(provider, &query, page_num).await }) {
            Ok(results) => {
                let res = json!({
                    "success": true,
                    "results": results
                });
                string_to_c_char(res.to_string())
            }
            Err(e) => {
                let res = json!({
                    "success": false,
                    "error": e.user_message(provider),
                    "raw_error": e.to_string()
                });
                string_to_c_char(res.to_string())
            }
        }
    })
    .unwrap_or_else(|_| {
        string_to_c_char(
            json!({
                "success": false,
                "error": "Panic caught in moviebox_core_search"
            })
            .to_string(),
        )
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn moviebox_core_suggest(query_str: *const c_char) -> *mut c_char {
    std::panic::catch_unwind(|| {
        let query = parse_c_str(query_str).unwrap_or_default();
        if query.is_empty() {
            return string_to_c_char(
                json!({
                    "success": true,
                    "suggestions": []
                })
                .to_string(),
            );
        }

        let rt = get_runtime();
        let service = get_service();

        match rt.block_on(async { service.suggest(&query).await }) {
            Ok(suggestions) => {
                let res = json!({
                    "success": true,
                    "suggestions": suggestions
                });
                string_to_c_char(res.to_string())
            }
            Err(e) => {
                let res = json!({
                    "success": false,
                    "error": e
                });
                string_to_c_char(res.to_string())
            }
        }
    })
    .unwrap_or_else(|_| {
        string_to_c_char(
            json!({
                "success": false,
                "error": "Panic caught in moviebox_core_suggest"
            })
            .to_string(),
        )
    })
}

fn sanitize_id(raw_id: &str) -> String {
    let trimmed = raw_id.trim();
    if trimmed.starts_with('{') {
        if let Ok(val) = serde_json::from_str::<serde_json::Value>(trimmed) {
            if let Some(v) = val.get("value").and_then(|s| s.as_str()) {
                return v.to_string();
            }
            if let Some(v) = val.get("id").and_then(|s| s.as_str()) {
                return v.to_string();
            }
        }
    }
    trimmed.to_string()
}

#[unsafe(no_mangle)]
pub extern "C" fn moviebox_core_details(
    provider_str: *const c_char,
    id_str: *const c_char,
) -> *mut c_char {
    std::panic::catch_unwind(|| {
        let provider_name = parse_c_str(provider_str).unwrap_or_else(|| "moviebox".to_string());
        let provider = ProviderKind::parse(&provider_name).unwrap_or(ProviderKind::MovieBox);
        let raw_id = parse_c_str(id_str).unwrap_or_default();
        let id = sanitize_id(&raw_id);

        if id.is_empty() {
            return string_to_c_char(
                json!({
                    "success": false,
                    "error": "Missing content id"
                })
                .to_string(),
            );
        }

        let rt = get_runtime();
        let service = get_service();

        match rt.block_on(async { service.details_typed(provider, &id).await }) {
            Ok(details) => {
                let res = json!({
                    "success": true,
                    "details": details
                });
                string_to_c_char(res.to_string())
            }
            Err(e) => {
                let res = json!({
                    "success": false,
                    "error": e.user_message(provider),
                    "raw_error": e.to_string()
                });
                string_to_c_char(res.to_string())
            }
        }
    })
    .unwrap_or_else(|_| {
        string_to_c_char(
            json!({
                "success": false,
                "error": "Panic caught in moviebox_core_details"
            })
            .to_string(),
        )
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn moviebox_core_episode_streams(
    provider_str: *const c_char,
    id_str: *const c_char,
    season: u32,
    episode: u32,
) -> *mut c_char {
    std::panic::catch_unwind(|| {
        let provider_name = parse_c_str(provider_str).unwrap_or_else(|| "moviebox".to_string());
        let provider = ProviderKind::parse(&provider_name).unwrap_or(ProviderKind::MovieBox);
        let raw_id = parse_c_str(id_str).unwrap_or_default();
        let id = sanitize_id(&raw_id);

        if id.is_empty() {
            return string_to_c_char(
                json!({
                    "success": false,
                    "error": "Missing content id"
                })
                .to_string(),
            );
        }

        let rt = get_runtime();
        let service = get_service();
        let s = season as usize;
        let ep = episode as usize;

        let result = rt.block_on(async {
            match provider {
                ProviderKind::MovieBox => {
                    crate::providers::ReleaseProvider::episode_streams(&service.client, &id, s, ep)
                        .await
                }
                ProviderKind::FourKHdHub => {
                    if let Some(fourk) = service.fourk_client.as_ref() {
                        crate::providers::ReleaseProvider::episode_streams(fourk, &id, s, ep).await
                    } else {
                        Err(crate::providers::models::ProviderError::Unavailable(
                            "4KHDHub provider unavailable".to_string(),
                        ))
                    }
                }
                ProviderKind::BdixCircleFtp => {
                    crate::providers::ReleaseProvider::episode_streams(
                        &service.circleftp_client,
                        &id,
                        s,
                        ep,
                    )
                    .await
                }
                ProviderKind::BdixDhakaFlix => {
                    crate::providers::ReleaseProvider::episode_streams(
                        &service.dhakaflix_client,
                        &id,
                        s,
                        ep,
                    )
                    .await
                }
                ProviderKind::Addons => {
                    let addons = crate::config::load_addons();
                    let is_series = s > 0 || ep > 0;
                    let (releases, _) = crate::providers::addons::aggregate_streams(
                        &service.addon_client,
                        &addons,
                        &id,
                        s,
                        ep,
                        is_series,
                    )
                    .await;
                    Ok(releases)
                }
            }
        });

        match result {
            Ok(releases) => {
                let res = json!({
                    "success": true,
                    "releases": releases
                });
                string_to_c_char(res.to_string())
            }
            Err(e) => {
                let res = json!({
                    "success": false,
                    "error": e.user_message(provider),
                    "raw_error": e.to_string()
                });
                string_to_c_char(res.to_string())
            }
        }
    })
    .unwrap_or_else(|_| {
        string_to_c_char(
            json!({
                "success": false,
                "error": "Panic caught in moviebox_core_episode_streams"
            })
            .to_string(),
        )
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn moviebox_core_resolve_stream(
    provider_str: *const c_char,
    release_json: *const c_char,
    _intent_str: *const c_char,
) -> *mut c_char {
    std::panic::catch_unwind(|| {
        let provider_name = parse_c_str(provider_str).unwrap_or_else(|| "moviebox".to_string());
        let provider = ProviderKind::parse(&provider_name).unwrap_or(ProviderKind::MovieBox);
        let raw_release = parse_c_str(release_json).unwrap_or_default();

        let release: Release = match serde_json::from_str(&raw_release) {
            Ok(r) => r,
            Err(e) => {
                return string_to_c_char(
                    json!({
                        "success": false,
                        "error": format!("Invalid release JSON: {e}")
                    })
                    .to_string(),
                );
            }
        };

        let rt = get_runtime();
        let service = get_service();

        let source_res = rt.block_on(async {
            match provider {
                ProviderKind::FourKHdHub => {
                    if let Some(fourk) = service.fourk_client.as_ref() {
                        fourk
                            .resolve_release(&release, ResolutionIntent::Playback)
                            .await
                            .map_err(|e| e.to_string())
                    } else {
                        Err("4KHDHub is unavailable".to_string())
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
                        Ok(crate::providers::models::PlaybackSource {
                            provider,
                            url: direct_url.to_string(),
                            headers,
                            subtitle: None,
                            source_label: release.source_label().to_string(),
                        })
                    } else {
                        Err("No direct mirror available for release".to_string())
                    }
                }
            }
        });

        match source_res {
            Ok(source) => {
                let res = json!({
                    "success": true,
                    "source": source
                });
                string_to_c_char(res.to_string())
            }
            Err(err_msg) => {
                let res = json!({
                    "success": false,
                    "error": err_msg
                });
                string_to_c_char(res.to_string())
            }
        }
    })
    .unwrap_or_else(|_| {
        string_to_c_char(
            json!({
                "success": false,
                "error": "Panic caught in moviebox_core_resolve_stream"
            })
            .to_string(),
        )
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn moviebox_core_get_captions(
    subject_id_str: *const c_char,
    resource_id_str: *const c_char,
    sibling_ids_json: *const c_char,
    season: u32,
    episode: u32,
) -> *mut c_char {
    std::panic::catch_unwind(|| {
        let subject_id = parse_c_str(subject_id_str).unwrap_or_default();
        let resource_id = parse_c_str(resource_id_str).unwrap_or_default();
        let sibling_json_str = parse_c_str(sibling_ids_json).unwrap_or_else(|| "[]".to_string());
        let sibling_ids: Vec<String> =
            serde_json::from_str(&sibling_json_str).unwrap_or_default();

        let rt = get_runtime();
        let service = get_service();

        match rt.block_on(async {
            service
                .get_ext_captions(
                    &subject_id,
                    &resource_id,
                    &sibling_ids,
                    season as usize,
                    episode as usize,
                )
                .await
        }) {
            Ok(captions) => {
                let res = json!({
                    "success": true,
                    "captions": captions
                });
                string_to_c_char(res.to_string())
            }
            Err(e) => {
                let res = json!({
                    "success": false,
                    "error": e
                });
                string_to_c_char(res.to_string())
            }
        }
    })
    .unwrap_or_else(|_| {
        string_to_c_char(
            json!({
                "success": false,
                "error": "Panic caught in moviebox_core_get_captions"
            })
            .to_string(),
        )
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn moviebox_core_start_proxy(
    target_url_str: *const c_char,
    headers_json_str: *const c_char,
    subtitle_url_str: *const c_char,
) -> *mut c_char {
    std::panic::catch_unwind(|| {
        let target_url = parse_c_str(target_url_str).unwrap_or_default();
        let headers_json = parse_c_str(headers_json_str).unwrap_or_else(|| "[]".to_string());
        let subtitle_url = parse_c_str(subtitle_url_str).filter(|s| !s.is_empty());

        let headers: Vec<(String, String)> =
            serde_json::from_str(&headers_json).unwrap_or_default();

        let rt = get_runtime();

        match rt.block_on(async {
            super::proxy_server::InProcessProxy::start_singleton(
                &target_url,
                &headers,
                subtitle_url.as_deref(),
            )
            .await
        }) {
            Ok(proxy) => {
                let res = json!({
                    "success": true,
                    "proxy_url": proxy.proxy_url,
                    "port": proxy.port
                });
                string_to_c_char(res.to_string())
            }
            Err(e) => {
                let res = json!({
                    "success": false,
                    "error": e
                });
                string_to_c_char(res.to_string())
            }
        }
    })
    .unwrap_or_else(|_| {
        string_to_c_char(
            json!({
                "success": false,
                "error": "Panic caught in moviebox_core_start_proxy"
            })
            .to_string(),
        )
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn moviebox_core_stop_proxy() -> *mut c_char {
    std::panic::catch_unwind(|| {
        super::proxy_server::InProcessProxy::stop_current();
        string_to_c_char(json!({ "success": true }).to_string())
    })
    .unwrap_or_else(|_| {
        string_to_c_char(json!({ "success": false }).to_string())
    })
}
