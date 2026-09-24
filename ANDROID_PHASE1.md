# MovieBox-TUI: Phase 1 — Rust Core Bridge Layer & Android Foundation

**Status**: Phase 1 Implementation Complete  
**Date**: September 2026  
**Repository**: `MovieBox-TUI`  

---

## 1. Executive Summary

Phase 1 establishes the in-process native bridge foundation and Android mobile project structure for **MovieBox-TUI**. It enables standalone Android clients (via Flutter / Dart FFI or native Android) to communicate with the existing headless Rust multi-provider engine with zero dependency on terminals, Termux, external processes, or manual server commands.

The existing desktop terminal UI (`src/tui/`, `src/main.rs`) and all provider implementations remain **completely untouched and 100% intact**.

---

## 2. Files Created and Modified

### Newly Created Files:
1. [`src/bridge/mod.rs`](file:///e:/jari/moviebox%20tui/src/bridge/mod.rs) — Bridge module root re-exporting FFI and in-process proxy.
2. [`src/bridge/ffi.rs`](file:///e:/jari/moviebox%20tui/src/bridge/ffi.rs) — C-compatible FFI boundary with panic guards, null pointer protection, and serialized JSON interfaces.
3. [`src/bridge/proxy_server.rs`](file:///e:/jari/moviebox%20tui/src/bridge/proxy_server.rs) — In-process Tokio loopback proxy for DASH manifest rewriting and CloudFront cookie attachment.
4. [`tests/android_bridge_validation.rs`](file:///e:/jari/moviebox%20tui/tests/android_bridge_validation.rs) — Automated integration tests verifying bridge functions (`init`, `suggest`, `search`, `start_proxy`, `free_string`).
5. [`android_app/pubspec.yaml`](file:///e:/jari/moviebox%20tui/android_app/pubspec.yaml) — Flutter application manifest and dependencies (`ffi`).
6. [`android_app/lib/core/bridge/moviebox_native.dart`](file:///e:/jari/moviebox%20tui/android_app/lib/core/bridge/moviebox_native.dart) — Low-level Dart FFI bindings for `libmoviebox_core.so`.
7. [`android_app/lib/core/bridge/moviebox_bridge.dart`](file:///e:/jari/moviebox%20tui/android_app/lib/core/bridge/moviebox_bridge.dart) — High-level asynchronous Dart service wrapping FFI calls in non-blocking Futures with typed JSON decoding.
8. [`android_app/lib/main.dart`](file:///e:/jari/moviebox%20tui/android_app/lib/main.dart) — Phase 1 verification and test screen with real-time JSON display and status monitors.
9. [`android_app/android/settings.gradle`](file:///e:/jari/moviebox%20tui/android_app/android/settings.gradle) — Android Gradle settings configuration.
10. [`android_app/android/build.gradle`](file:///e:/jari/moviebox%20tui/android_app/android/build.gradle) — Android root Gradle build script.
11. [`android_app/android/app/build.gradle`](file:///e:/jari/moviebox%20tui/android_app/android/app/build.gradle) — Android app Gradle build script configured for Android SDK 34 and NDK ABI filters.
12. [`android_app/android/app/src/main/AndroidManifest.xml`](file:///e:/jari/moviebox%20tui/android_app/android/app/src/main/AndroidManifest.xml) — Android permissions (`INTERNET`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`, `FOREGROUND_SERVICE`).
13. [`android_app/android/app/src/main/kotlin/com/moviebox/app/MainActivity.kt`](file:///e:/jari/moviebox%20tui/android_app/android/app/src/main/kotlin/com/moviebox/app/MainActivity.kt) — Flutter Activity entrypoint.

### Modified Files:
1. [`Cargo.toml`](file:///e:/jari/moviebox%20tui/Cargo.toml) — Added `crate-type = ["lib", "cdylib"]` under `[lib]`.
2. [`src/lib.rs`](file:///e:/jari/moviebox%20tui/src/lib.rs) — Registered `pub mod bridge;`.

---

## 3. Rust Bridge Architecture

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        FLUTTER / DART CLIENT                           │
│  android_app/lib/main.dart (UI / Test Screen)                          │
│  android_app/lib/core/bridge/moviebox_bridge.dart (Async Future API)   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Dart FFI
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                       DART FFI NATIVE BINDINGS                         │
│  android_app/lib/core/bridge/moviebox_native.dart                      │
│  - DynamicLibrary.open("libmoviebox_core.so")                          │
│  - UTF-8 string conversion & malloc / free memory management           │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ C ABI Boundary
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        RUST C-COMPATIBLE BRIDGE                        │
│  src/bridge/ffi.rs                                                     │
│  - std::panic::catch_unwind on all entrypoints                         │
│  - Persistent multi-thread Tokio runtime (4 worker threads)            │
│  - Thread-safe OnceLock<MovieBoxService> singleton                     │
│  - moviebox_core_free_string deallocator                               │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Native In-Process Calls
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        EXISTING RUST CORE                              │
│  src/service.rs (MovieBoxService)                                      │
│  src/providers/ (MovieBox, 4KHDHub, BDIX, Addons, TV M3U)               │
│  src/bridge/proxy_server.rs (In-Process Tokio HTTP Loopback Proxy)     │
│  src/cache.rs, src/net.rs, src/history.rs, src/favorites.rs           │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 4. FFI Function Signatures

| Function | C Signature | Purpose |
| :--- | :--- | :--- |
| `moviebox_core_init` | `*mut c_char (data_dir: *const c_char, cache_dir: *const c_char)` | Initializes Tokio runtime, sets Android storage directories, and prepares `MovieBoxService`. |
| `moviebox_core_homepage` | `*mut c_char (tab_id: *const c_char, page: u32)` | Fetches curated homepage catalog items and `BrowseMetrics`. |
| `moviebox_core_search` | `*mut c_char (provider: *const c_char, query: *const c_char, page: u32)` | Dispatches typed search to the active provider. |
| `moviebox_core_suggest` | `*mut c_char (query: *const c_char)` | Returns live auto-complete search suggestions. |
| `moviebox_core_details` | `*mut c_char (provider: *const c_char, id: *const c_char)` | Fetches full media metadata, seasons, episodes, and dubs. |
| `moviebox_core_episode_streams` | `*mut c_char (provider: *const c_char, id: *const c_char, season: u32, episode: u32)` | Dispatches release stream discovery for movies or episodes. |
| `moviebox_core_resolve_stream` | `*mut c_char (provider: *const c_char, release_json: *const c_char, intent: *const c_char)` | Resolves candidate mirrors into a playable direct source. |
| `moviebox_core_get_captions` | `*mut c_char (subject_id: *const c_char, resource_id: *const c_char, sibling_ids_json: *const c_char, season: u32, episode: u32)` | Dispatches subtitle lookup and language deduplication. |
| `moviebox_core_start_proxy` | `*mut c_char (target_url: *const c_char, headers_json: *const c_char, subtitle_url: *const c_char)` | Spawns in-process loopback proxy on `127.0.0.1:0` for DASH streaming. |
| `moviebox_core_free_string` | `void (ptr: *mut c_char)` | Deallocates heap-allocated CStrings returned across FFI. |

---

## 5. JSON Response Contract

All bridge functions return a standardized JSON envelope:

### Success Response
```json
{
  "success": true,
  "data": { ... } // or "items", "results", "suggestions", "details", "releases", "source"
}
```

### Error Response
```json
{
  "success": false,
  "error": "User-facing concise error message",
  "raw_error": "Internal technical diagnostic (optional)"
}
```

---

## 6. Memory Ownership & Safety Strategy

1. **Rust to Dart**:
   - Rust allocates C strings via `CString::into_raw()`.
   - Dart receives the pointer, converts it to a Dart string via `ptr.toDartString()`, and immediately calls `moviebox_core_free_string(ptr)` in a `finally` block.
   - `moviebox_core_free_string` reclaims ownership with `CString::from_raw(ptr)` which drops and frees the heap memory safely.
2. **Dart to Rust**:
   - Dart converts strings to UTF-8 via `toNativeUtf8()`.
   - Rust reads them immutably via `CStr::from_ptr()`.
   - Dart frees its allocated parameter pointers in `finally` blocks via `malloc.free(ptr)`.
3. **Panic Boundary**:
   - Every exported FFI function is wrapped inside `std::panic::catch_unwind`.
   - If an unexpected panic occurs inside Rust, it is intercepted and converted to `{"success": false, "error": "Panic caught in ..."}` rather than crashing the Android host process.

---

## 7. Tokio Runtime Strategy

- Recreating a Tokio runtime on every FFI invocation causes massive thread creation overhead and memory thrashing.
- `src/bridge/ffi.rs` utilizes a `static RUNTIME: OnceLock<tokio::runtime::Runtime>` multi-threaded runtime with 4 dedicated worker threads named `moviebox-core-worker`.
- The runtime is initialized on first call and persists across the entire lifetime of the application process.
- All async network requests, disk cache queries, and stream scraping run inside this background runtime.
- Dart wraps all FFI calls in `Future(() => ...)` so the main UI thread is never blocked.

---

## 8. Android Build & ABI Configuration

### Supported ABIs:
- Primary: `arm64-v8a` (`aarch64-linux-android`)
- Secondary: `armeabi-v7a` (`armv7-linux-androideabi`), `x86_64` (`x86_64-linux-android`)

### Rust Build Command for Android:
```bash
cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 -o android_app/android/app/src/main/jniLibs build --release
```

---

## 9. Verification & Phase 1 Conclusion

- **Rust Core & TUI Independence**: Verified that `src/tui/`, `src/main.rs`, and all core providers remain completely unchanged.
- **FFI Boundary**: Verified C-ABI compatibility, panic isolation, and memory deallocation.
- **In-Process Proxy**: Verified `InProcessProxy` compiles and runs as an asynchronous task inside Tokio.
- **Flutter / Dart Layer**: Verified clean separation between UI and Rust core via `MovieBoxBridge` and `MovieBoxNative`.

Phase 1 foundation is ready.
