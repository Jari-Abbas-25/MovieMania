use std::ffi::{CStr, CString};
use moviebox_tui::bridge::*;

#[test]
fn test_bridge_init() {
    let data_dir = CString::new("").unwrap();
    let cache_dir = CString::new("").unwrap();
    let res_ptr = moviebox_core_init(data_dir.as_ptr(), cache_dir.as_ptr());
    assert!(!res_ptr.is_null());

    let res_str = unsafe { CStr::from_ptr(res_ptr).to_str().unwrap() };
    assert!(res_str.contains("\"success\":true"));
    assert!(res_str.contains("MovieBox Core initialized"));

    moviebox_core_free_string(res_ptr);
}

#[test]
fn test_bridge_suggest() {
    let _ = moviebox_core_init(std::ptr::null(), std::ptr::null());

    let query = CString::new("avengers").unwrap();
    let res_ptr = moviebox_core_suggest(query.as_ptr());
    assert!(!res_ptr.is_null());

    let res_str = unsafe { CStr::from_ptr(res_ptr).to_str().unwrap() };
    assert!(res_str.contains("\"success\":"));

    moviebox_core_free_string(res_ptr);
}

#[test]
fn test_bridge_search_empty_query() {
    let _ = moviebox_core_init(std::ptr::null(), std::ptr::null());

    let prov = CString::new("moviebox").unwrap();
    let query = CString::new("").unwrap();
    let res_ptr = moviebox_core_search(prov.as_ptr(), query.as_ptr(), 1);
    assert!(!res_ptr.is_null());

    let res_str = unsafe { CStr::from_ptr(res_ptr).to_str().unwrap() };
    assert!(res_str.contains("\"success\":true"));
    assert!(res_str.contains("\"results\":[]"));

    moviebox_core_free_string(res_ptr);
}

#[test]
fn test_bridge_in_process_proxy() {
    let target = CString::new("https://example.com/dash/index.mpd").unwrap();
    let headers = CString::new(r#"[["User-Agent","TestUA"],["Referer","https://example.com"]]"#).unwrap();
    let sub = CString::new("").unwrap();

    let res_ptr = moviebox_core_start_proxy(target.as_ptr(), headers.as_ptr(), sub.as_ptr());
    assert!(!res_ptr.is_null());

    let res_str = unsafe { CStr::from_ptr(res_ptr).to_str().unwrap() };
    assert!(res_str.contains("\"success\":true"));
    assert!(res_str.contains("127.0.0.1"));
    assert!(res_str.contains("\"port\":"));

    moviebox_core_free_string(res_ptr);
}
