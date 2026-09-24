# MovieBox-TUI → Standalone Android Application Architecture Assessment

**Document Version**: 1.0  
**Target Platform**: Standalone Android (aarch64-linux-android, armv7-linux-androideabi, x86_64-linux-android)  
**Date**: September 2026  

---

## 1. Executive Summary

The **MovieBox-TUI** repository is a mature, production-grade Rust project that aggregates multiple streaming providers (MovieBox, 4KHDHub, BDIX mirrors, Stremio Addons, and IPTV M3U playlists) into a unified headless domain and headless service layer (`MovieBoxService`).

This assessment provides a complete technical evaluation of the current codebase, delineating reusable core components from terminal-specific subsystems, analyzing Android runtime and compilation feasibility, evaluating stream resolution and playback requirements, and defining the production architecture for the standalone Android application.

---

## 2. Current Repository Architecture

The current repository follows a clean, decoupled layered architecture:

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│                            PRESENTATION LAYER                                │
│  src/tui/ (screens, widgets, text, theme, overlay, event loop, crossterm)    │
│  src/main.rs (TerminalGuard, alternate screen, raw mode, CLI parser)         │
└──────────────────────────────────────┬───────────────────────────────────────┘
                                       │ Calls Headless Facade
                                       ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                         APPLICATION / SERVICE LAYER                          │
│  src/service.rs (MovieBoxService multi-provider aggregation facade)          │
│  src/models.rs (Pure domain types: CatalogItem, MediaDetails, Release, etc.) │
└──────────────────────────────────────┬───────────────────────────────────────┘
                                       │ Dispatches Requests
                                       ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                            CORE PROVIDERS ENGINE                             │
│  src/providers/                                                              │
│  ├── moviebox/   (Anti-bot HMAC-MD5 signing, mobile device spoofing, DASH)   │
│  ├── fourkhdhub/ (HTML scraper, HubCloud/PixelDrain resolver, multi-audio)   │
│  ├── bdix/       (CircleFTP & DhakaFlix optical intranet indexers)           │
│  ├── addons/     (Stremio manifest aggregator: Cinemeta, stream addons)      │
│  └── tv/         (IPTV M3U parser, deduplication, group management)          │
└──────────────────────────────────────┬───────────────────────────────────────┘
                                       │ Relies on
                                       ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                    NETWORKING, PROXY & PERSISTENCE                           │
│  src/net.rs      (Hickory pure-Rust DNS fallback resolver, reqwest + rustls) │
│  src/proxy.rs    (Loopback HTTP proxy for CloudFront cookie injection & DASH)│
│  src/cache.rs    (MessagePack binary disk cache with MBC1 header + TTL)      │
│  src/config.rs   (Atomic JSON config persistence)                            │
│  src/history.rs  (Watch progress tracking, latched resume, reconciliation)   │
│  src/favorites.rs(Bookmarked titles persistence & deduplication)             │
│  src/download.rs (Resilient multi-segment HTTP range downloader)             │
│  src/logging.rs  (Rotating file logger with privacy URL/path sanitization)   │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Component Breakdown: Core vs. Terminal/TUI-Specific

| Component / Module | Path | Classification | Reusability in Android App | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **Domain Models** | `src/models.rs`, `src/providers/models.rs` | **Core** | **100% Reusable** | Strictly typed domain entities (`CatalogItem`, `MediaDetails`, `Season`, `Episode`, `Release`, `SourceMirror`, `PlaybackSource`, `ProviderKind`). Fully serializable with `serde`. |
| **MovieBox Service Facade** | `src/service.rs` | **Core** | **100% Reusable** | `MovieBoxService` aggregates provider clients, handles typed search, details, suggestions, homepage curation, collections, subtitles, and caching. Completely headless. |
| **MovieBox Provider** | `src/providers/moviebox/` | **Core** | **100% Reusable** | HMAC-MD5 cryptographic request signing (`crypto.rs`), client session (`session.rs`), adaptive DASH extraction and parser (`adapt.rs`), title normalization (`title.rs`). |
| **4KHDHub Provider** | `src/providers/fourkhdhub/` | **Core** | **100% Reusable** | HTML parsing (`parser.rs`), HubCloud, HubDrive, and GreenMotors redirector unpacking (`hubcloud.rs`), candidate scoring and multi-audio language detection. |
| **BDIX Providers** | `src/providers/bdix/` | **Core** | **100% Reusable** | CircleFTP and DhakaFlix scraping, codec and resolution heuristics (`common.rs`). |
| **Stremio Addons Provider** | `src/providers/addons/` | **Core** | **100% Reusable** | Manifest parsing (`models.rs`), Cinemeta metadata client (`client.rs`), stream aggregator (`aggregator.rs`), adapter (`adapter.rs`). |
| **IPTV / TV Provider** | `src/providers/tv/` | **Core** | **100% Reusable** | Memory-bounded streaming M3U playlist parser (`parser.rs`), deduplication by stream URL, channel grouping (`models.rs`). |
| **Networking Engine** | `src/net.rs` | **Core** | **100% Reusable** | Hickory DNS fallback resolver (Cloudflare, Google, Quad9) avoiding JNI DNS traps; `reqwest` with pure-Rust `rustls` (webpki-roots). |
| **Loopback Proxy Engine** | `src/proxy.rs` | **Core** | **100% Reusable** | Localhost HTTP streaming proxy with DASH manifest rewriter and CloudFront cookie injection. (Can be run directly in-process via `tokio::spawn` rather than spawning a CLI subprocess). |
| **Disk Binary Cache** | `src/cache.rs` | **Core** | **100% Reusable** | `rmp-serde` (MessagePack) high-performance disk cache with `MBC1` magic header and atomic tempfile replacement. |
| **Watch History** | `src/history.rs` | **Core** | **100% Reusable** | Progress tracking, episode resume calculation, relative time formatting, and JSON persistence. |
| **Favorites / Watchlist** | `src/favorites.rs` | **Core** | **100% Reusable** | Bookmark storage with `SubjectIdentity` deduplication. |
| **Config & Persistence** | `src/config.rs` | **Core** | **100% Reusable** | Safe JSON settings persistence and directory resolution. |
| **Downloader** | `src/download.rs` | **Core** | **100% Reusable** | Resilient chunked multi-segment downloader with `.part` resume and cancellation tokens. |
| **Self-Updater** | `src/updater/` | **Terminal Tool** | **Not Reusable** | Designed for CLI binary self-replacement via GitHub releases; Android apps update via APK distribution / app stores. |
| **TUI Presentation** | `src/tui/` | **Terminal UI** | **Not Reusable** | Crossterm event loop, Ratatui frame drawing, ANSI terminal styling, Braille spinners, Sixel/Kitty image protocols. Retained for desktop TUI target. |
| **CLI Entrypoint** | `src/main.rs` | **Terminal Tool** | **Not Reusable** | Raw mode terminal setup, alternate screen allocation, and CLI flag handling. Retained for desktop CLI binary. |

---

## 4. In-Depth Analysis of Core Subsystems

### 4.1 How `MovieBoxService` Works
`MovieBoxService` (`src/service.rs`) is the single headless coordinator that wraps all provider clients:
- `client: MovieBoxClient`
- `fourk_client: Option<FourKHdHubClient>`
- `circleftp_client: CircleFtpClient`
- `dhakaflix_client: DhakaFlixClient`
- `addon_client: AddonClient`
- `http_client: reqwest::Client`

Key methods provided:
1. `homepage(tab_id, page)`: Returns curated discovery lists and `BrowseMetrics` (Trending rank, IMDb rating, 30-day popularity).
2. `search_typed(provider, query, page)`: Dispatches concurrent or targeted queries across providers, returning normalized `Vec<CatalogItem>`.
3. `details_typed(provider, id)`: Fetches comprehensive media metadata (`MediaDetails`), seasons, episodes, and dubs.
4. `fetch_addon_catalog(manifest_url, type, catalog_id)`: Fetches categorized catalogs from Stremio community addons.
5. `fetch_collection_resolutions(subject_id)`: Dynamically queries all available stream qualities (4K, 1080p, 720p, 480p, 360p).
6. `get_ext_captions(subject_id, resource_id, sibling_ids, season, episode)`: Dispatches multi-lingual subtitle searches with automatic language normalization and deduplication.

### 4.2 How Providers and Metadata are Structured
Providers implement the async `Provider` and `ReleaseProvider` traits:
- `Provider::id(&self) -> ProviderKind`
- `Provider::capabilities(&self) -> ProviderCapabilities`
- `Provider::search(&self, query: &str, page: usize) -> Result<Vec<CatalogItem>, ProviderError>`
- `Provider::details(&self, id: &str) -> Result<MediaDetails, ProviderError>`
- `ReleaseProvider::episode_streams(&self, id: &str, season: usize, episode: usize) -> Result<Vec<Release>, ProviderError>`

Metadata is normalized into canonical structs:
- `CatalogItem`: ID (`ProviderMediaId`), title, media type (`Movie` or `Series`), year, poster URL, season count.
- `MediaDetails`: Full metadata including title, tagline, description, IMDb rating, director, actors, duration, genres, `seasons` (`Vec<Season>` with `Vec<Episode>`), and `dubs` (`Vec<AudioTrackOption>`).
- `Release`: High-resolution stream descriptor with filename, quality (4K, 1080p, Multi), codec (HEVC, AV1), language tracks, file size in bytes, and `mirrors` (`Vec<SourceMirror>`).

### 4.3 Stream Resolution & Playback Mechanics
Streams are resolved through different pipelines depending on the provider:
1. **MovieBox Streams**:
   - The provider returns segmented MPEG-DASH manifests (`index.mpd`) and CloudFront signed cookies (`CloudFront-Policy`, `CloudFront-Signature`, `CloudFront-Key-Pair-Id`).
   - The playback source carries `Referer: https://sportslive.wine`, spoofed `User-Agent`, and the signed `Cookie`.
   - In Android, media players (like ExoPlayer) cannot always attach arbitrary cookies across segmented chunk downloads unless configured with custom HttpDataSources.
   - **The loopback proxy (`src/proxy.rs`)** solves this completely: it exposes a local HTTP URL `http://127.0.0.1:<port>/https/<cdn_host>/dash/index.mpd`, rewrites the manifest URLs on the fly, and injects the CloudFront cookies into all outgoing media segment requests transparently.
2. **4KHDHub Streams**:
   - Releases contain mediator mirrors (`hubcloud.`, `hubdrive.`, `greenmotors.`).
   - `hubcloud.rs` unpacks JavaScript redirects and Base64/ROT13 payloads to resolve direct seekable CDN URLs (Google Video CDN, Cloudflare R2, PixelDrain).
   - Direct streams are formatted as `PlaybackSource` with required `Referer` and `User-Agent` headers.
3. **Stremio Addons**:
   - Resolves direct HTTP/HTTPS video URLs from configured community addon endpoints (`/stream/movie/...` or `/stream/series/...`).
4. **Live TV / IPTV**:
   - M3U parser yields direct HLS/M3U8/MP4 channel streams with category grouping and channel logos.

### 4.4 Subtitle and Caption Handling
- `MovieBoxService::get_ext_captions` queries subtitle servers, decodes language codes into clean display labels (e.g. English, Spanish, Bengali), and deduplicates options.
- The proxy rewriter can inject external WebVTT/SRT subtitles directly into the DASH manifest as an AdaptationSet (`<AdaptationSet contentType="text" mimeType="text/vtt">`), or provide local converted `.vtt` / `.srt` paths to the media player.

### 4.5 Persistence & Storage
- `cache.rs`: Provider-isolated binary MessagePack files with `MBC1` magic header and TTL expiration.
- `history.rs`: Watch progress, last watched episode, completion latching (at ≥ 90% progress), relative time calculations.
- `favorites.rs`: Starred items deduplicated with `SubjectIdentity`.
- `config.rs`: JSON user settings (active provider, streaming toggles, IPTV playlists).

---

## 5. Android Compilation & Dependency Feasibility Analysis

### 5.1 Cargo Dependencies Analysis for Android

| Dependency | Purpose | Android Compatibility | Notes |
| :--- | :--- | :--- | :--- |
| `tokio` | Async runtime | **Fully Compatible** | Compiles on `aarch64-linux-android` with epoll backend. |
| `reqwest` + `rustls` | HTTP client & TLS | **Fully Compatible** | Uses `rustls-tls-webpki-roots` (pure Rust). No OpenSSL dependency. |
| `hickory-resolver` | DNS fallback | **Fully Compatible** | Pure Rust DNS resolver. Avoids Android Bionic `/etc/resolv.conf` lookup bugs. |
| `serde` & `serde_json` | Serialization | **Fully Compatible** | Pure Rust. |
| `rmp-serde` | Binary cache | **Fully Compatible** | Pure Rust MessagePack. |
| `scraper` | HTML parsing | **Fully Compatible** | Pure Rust (html5ever + selectors). |
| `image` | Poster decoding | **Fully Compatible** | Pure Rust image decoder (jpeg, png, webp). |
| `hmac` & `md-5` & `sha2` | Crypto signing | **Fully Compatible** | Pure Rust cryptographic primitives. |
| `percent-encoding` & `url` | URL handling | **Fully Compatible** | Pure Rust. |
| `dirs` | Directory resolution | **Compatible with adaptation** | On Android, paths can be initialized using Android Context `filesDir`/`cacheDir` passed during startup. |
| `mimalloc` | Memory allocator | **Handled** | Already gated in `Cargo.toml` with `cfg(not(target_os = "android"))`. |
| `crossterm` / `ratatui` | Terminal UI | **Desktop only** | Remains in `src/tui/` and is excluded from the mobile build. |

**Conclusion**: The entire core networking, parsing, cryptographic signing, caching, and stream resolution engine compiles cleanly for Android targets (`aarch64-linux-android`, `armv7-linux-androideabi`, `x86_64-linux-android`).

---

## 6. Recommended Android Architecture

### 6.1 Architectural Pattern: Standalone Android App with Rust Core Engine
To deliver a standalone Android streaming experience that requires no Termux, no terminal, no external servers, and zero manual configuration:

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                         STANDALONE ANDROID APPLICATION                      │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                    MODERN MOBILE STREAMING UI                         │  │
│  │  - Polished Dark Glassmorphism Theme                                  │  │
│  │  - Hero Backdrop Carousel & Featured Banners                         │  │
│  │  - Horizontal Content Rails (Trending, Popular, Top Rated, Dubs)     │  │
│  │  - Responsive Search with Live Suggestions & Debouncing              │  │
│  │  - Rich Media Details (Backdrop, Cast, Genres, Rating, Seasons)       │  │
│  │  - Interactive Season & Episode Selector Pane                         │  │
│  │  - Release & Stream Quality Picker (4K UHD, 1080p, Multi-Res, Audio) │  │
│  │  - Hardware-Accelerated Video Player with Custom Controls             │  │
│  │  - Local Watchlist & Continue Watching Rails                          │  │
│  │  - Settings Hub (Provider Toggles, Addon Manager, IPTV Sources)       │  │
│  └───────────────────────────────────┬───────────────────────────────────┘  │
│                                      │                                      │
│                                      ▼                                      │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                   APP / REPOSITORY SERVICE LAYER                      │  │
│  │  - MovieBoxRepository                                                 │  │
│  │  - WatchlistRepository                                                │  │
│  │  - HistoryRepository                                                  │  │
│  │  - PlaybackManager (Lifecycle, Buffering, Subtitles, Resume)          │  │
│  └───────────────────────────────────┬───────────────────────────────────┘  │
│                                      │                                      │
│                                      ▼                                      │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                   RUST ↔ ANDROID BRIDGE INTERFACE                     │  │
│  │  - In-Process High-Speed Bridge / JNI Engine                          │  │
│  │  - Asynchronous Future & Stream Dispatch                             │  │
│  │  - Structured JSON / Binary IPC Serialization                        │  │
│  └───────────────────────────────────┬───────────────────────────────────┘  │
│                                      │                                      │
│                                      ▼                                      │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                      REUSED RUST CORE ENGINE                          │  │
│  │  - MovieBoxService (Homepage, Search, Details, Resolutions, Captions) │  │
│  │  - Scrapers & Resolvers (MovieBox, 4KHDHub, BDIX, Addons, TV M3U)     │  │
│  │  - In-Process Loopback Proxy (DASH Rewriting & CloudFront Auth)       │  │
│  │  - Binary Cache Engine (rmp-serde MBC1)                               │  │
│  │  - Hickory DNS Fallback Resolver & Rustls Client                      │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Bridge Mechanism: In-Process Native Rust Bridge
1. The Rust core is compiled as a shared library (`libmoviebox_core.so` / `cdylib`) targeting Android ABIs (`arm64-v8a`, `armeabi-v7a`, `x86_64`).
2. A clean FFI / JNI bridge exports high-level async functions:
   - `moviebox_core_init(data_dir, cache_dir)`
   - `moviebox_core_homepage(tab_id, page)`
   - `moviebox_core_search(provider, query, page)`
   - `moviebox_core_suggest(query)`
   - `moviebox_core_details(provider, subject_id)`
   - `moviebox_core_resolutions(subject_id)`
   - `moviebox_core_episode_streams(provider, id, season, episode)`
   - `moviebox_core_resolve_stream(provider, release_json, intent)`
   - `moviebox_core_get_captions(subject_id, resource_id, sibling_ids_json, season, episode)`
   - `moviebox_core_start_proxy(target_url, headers_json, subtitle_url)`
   - `moviebox_core_parse_tv_playlist(url_or_path)`
3. The in-process proxy runs on `127.0.0.1` inside the app process, ensuring that DASH manifests and CloudFront cookies are handled seamlessly on Android without requiring root or external sidecar processes.

---

## 7. Media Playback Architecture for Android

### 7.1 Android-Native Player Engine (ExoPlayer / Media3)
For standalone Android:
- **Primary Player**: Production Android **Media3 / ExoPlayer** integration.
  - Native hardware decoding via MediaCodec (H.264, HEVC, VP9, AV1).
  - Native MPEG-DASH and HLS playback with dynamic resolution adaptation.
  - Custom `HttpDataSource` and local proxy support.
  - Embedded subtitle rendering (SRT, WebVTT, SSA/ASS).
  - Background audio mode, PiP (Picture-in-Picture), orientation locking, and aspect ratio toggling.
- **External Player Delegation (Fallback Option)**: Option in settings to open streams in external Android players (VLC for Android, Just Player, MPV Android) using `android.intent.action.VIEW`.

---

## 8. Preserving the Existing Codebase

To maintain complete backward compatibility and project integrity:
1. **Zero disruption to existing TUI**: All files under `src/tui/`, `src/main.rs`, and tests remain intact and fully functional for desktop targets.
2. **Modular core exports**: Expose the reusable core via `src/lib.rs` and an `android_bridge` module.
3. **Additive architecture**: The Android project lives in `android/` with its native build scripts, Gradle configurations, and UI layer.

---

## 9. Risks and Technical Limitations

1. **CloudFront Cookie Authentication**:
   - *Risk*: MovieBox DASH manifests require signed cookies on every chunk request.
   - *Mitigation*: The in-process Rust HTTP proxy (`src/proxy.rs`) transparently receives player requests on `127.0.0.1`, attaches the cookies, and proxies segments with streaming buffering.
2. **Network Timeouts on Cellular Data**:
   - *Risk*: Slow mobile connections when scraping mirrors.
   - *Mitigation*: Bounded-concurrency probing with timeout fallbacks already built into `hubcloud.rs` and `MovieBoxClient`.
3. **Android Storage Scoped Access**:
   - *Risk*: Strict permissions on Android 11+ for writing downloaded videos.
   - *Mitigation*: Use Android App-Specific External Directory (`getExternalFilesDir`) and MediaStore API for exports.

---

## 10. Conclusion and Next Steps

The repository is structured with high cohesion and low coupling. The Rust core provides an exceptional, feature-rich headless streaming engine. By integrating this core with a native Android interface, we achieve the goal: a standalone Android streaming application.
