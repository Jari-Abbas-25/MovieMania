import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef CoreInitC = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> dataDir, ffi.Pointer<Utf8> cacheDir);
typedef CoreInitDart = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> dataDir, ffi.Pointer<Utf8> cacheDir);

typedef CoreHomepageC = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> tabId, ffi.Uint32 page);
typedef CoreHomepageDart = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> tabId, int page);

typedef CoreSearchC = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> provider, ffi.Pointer<Utf8> query, ffi.Uint32 page);
typedef CoreSearchDart = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> provider, ffi.Pointer<Utf8> query, int page);

typedef CoreSuggestC = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> query);
typedef CoreSuggestDart = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> query);

typedef CoreDetailsC = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> provider, ffi.Pointer<Utf8> id);
typedef CoreDetailsDart = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> provider, ffi.Pointer<Utf8> id);

typedef CoreEpisodeStreamsC = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> provider,
    ffi.Pointer<Utf8> id,
    ffi.Uint32 season,
    ffi.Uint32 episode);
typedef CoreEpisodeStreamsDart = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> provider, ffi.Pointer<Utf8> id, int season, int episode);

typedef CoreResolveStreamC = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> provider,
    ffi.Pointer<Utf8> releaseJson,
    ffi.Pointer<Utf8> intent);
typedef CoreResolveStreamDart = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> provider,
    ffi.Pointer<Utf8> releaseJson,
    ffi.Pointer<Utf8> intent);

typedef CoreGetCaptionsC = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> subjectId,
    ffi.Pointer<Utf8> resourceId,
    ffi.Pointer<Utf8> siblingIdsJson,
    ffi.Uint32 season,
    ffi.Uint32 episode);
typedef CoreGetCaptionsDart = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> subjectId,
    ffi.Pointer<Utf8> resourceId,
    ffi.Pointer<Utf8> siblingIdsJson,
    int season,
    int episode);

typedef CoreStartProxyC = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> targetUrl,
    ffi.Pointer<Utf8> headersJson,
    ffi.Pointer<Utf8> subtitleUrl);
typedef CoreStartProxyDart = ffi.Pointer<Utf8> Function(
    ffi.Pointer<Utf8> targetUrl,
    ffi.Pointer<Utf8> headersJson,
    ffi.Pointer<Utf8> subtitleUrl);

typedef CoreFreeStringC = ffi.Void Function(ffi.Pointer<Utf8> ptr);
typedef CoreFreeStringDart = void Function(ffi.Pointer<Utf8> ptr);

class MovieBoxNative {
  static final MovieBoxNative _instance = MovieBoxNative._internal();
  factory MovieBoxNative() => _instance;

  late final ffi.DynamicLibrary _dylib;
  late final CoreInitDart _init;
  late final CoreHomepageDart _homepage;
  late final CoreSearchDart _search;
  late final CoreSuggestDart _suggest;
  late final CoreDetailsDart _details;
  late final CoreEpisodeStreamsDart _episodeStreams;
  late final CoreResolveStreamDart _resolveStream;
  late final CoreGetCaptionsDart _getCaptions;
  late final CoreStartProxyDart _startProxy;
  late final CoreFreeStringDart _freeString;

  bool _isLoaded = false;

  MovieBoxNative._internal() {
    _loadLibrary();
  }

  void _loadLibrary() {
    if (_isLoaded) return;

    if (Platform.isAndroid) {
      try {
        _dylib = ffi.DynamicLibrary.open('libmoviebox_core.so');
      } catch (e) {
        try {
          _dylib = ffi.DynamicLibrary.open('libmoviebox_tui.so');
        } catch (_) {
          _dylib = ffi.DynamicLibrary.process();
        }
      }
    } else if (Platform.isWindows) {
      try {
        _dylib = ffi.DynamicLibrary.open('moviebox_tui.dll');
      } catch (e) {
        try {
          _dylib = ffi.DynamicLibrary.open('target/debug/moviebox_tui.dll');
        } catch (_) {
          _dylib = ffi.DynamicLibrary.open('target/release/moviebox_tui.dll');
        }
      }
    } else if (Platform.isLinux) {
      try {
        _dylib = ffi.DynamicLibrary.open('libmoviebox_tui.so');
      } catch (e) {
        _dylib = ffi.DynamicLibrary.process();
      }
    } else if (Platform.isMacOS) {
      try {
        _dylib = ffi.DynamicLibrary.open('libmoviebox_tui.dylib');
      } catch (e) {
        _dylib = ffi.DynamicLibrary.process();
      }
    } else {
      _dylib = ffi.DynamicLibrary.process();
    }

    _init = _dylib
        .lookup<ffi.NativeFunction<CoreInitC>>('moviebox_core_init')
        .asFunction();

    _homepage = _dylib
        .lookup<ffi.NativeFunction<CoreHomepageC>>('moviebox_core_homepage')
        .asFunction();

    _search = _dylib
        .lookup<ffi.NativeFunction<CoreSearchC>>('moviebox_core_search')
        .asFunction();

    _suggest = _dylib
        .lookup<ffi.NativeFunction<CoreSuggestC>>('moviebox_core_suggest')
        .asFunction();

    _details = _dylib
        .lookup<ffi.NativeFunction<CoreDetailsC>>('moviebox_core_details')
        .asFunction();

    _episodeStreams = _dylib
        .lookup<ffi.NativeFunction<CoreEpisodeStreamsC>>(
            'moviebox_core_episode_streams')
        .asFunction();

    _resolveStream = _dylib
        .lookup<ffi.NativeFunction<CoreResolveStreamC>>(
            'moviebox_core_resolve_stream')
        .asFunction();

    _getCaptions = _dylib
        .lookup<ffi.NativeFunction<CoreGetCaptionsC>>(
            'moviebox_core_get_captions')
        .asFunction();

    _startProxy = _dylib
        .lookup<ffi.NativeFunction<CoreStartProxyC>>(
            'moviebox_core_start_proxy')
        .asFunction();

    _freeString = _dylib
        .lookup<ffi.NativeFunction<CoreFreeStringC>>('moviebox_core_free_string')
        .asFunction();

    _isLoaded = true;
  }

  String _invokeAndFree(ffi.Pointer<Utf8> Function() ffiCall) {
    final ptr = ffiCall();
    if (ptr == ffi.nullptr) {
      return '{"success":false,"error":"Null pointer returned from native bridge"}';
    }
    try {
      return ptr.toDartString();
    } finally {
      _freeString(ptr);
    }
  }

  String init({String? dataDir, String? cacheDir}) {
    final dataPtr = dataDir != null ? dataDir.toNativeUtf8() : ffi.nullptr;
    final cachePtr = cacheDir != null ? cacheDir.toNativeUtf8() : ffi.nullptr;
    try {
      return _invokeAndFree(() => _init(dataPtr, cachePtr));
    } finally {
      if (dataPtr != ffi.nullptr) malloc.free(dataPtr);
      if (cachePtr != ffi.nullptr) malloc.free(cachePtr);
    }
  }

  String homepage({String tabId = 'movie', int page = 1}) {
    final tabPtr = tabId.toNativeUtf8();
    try {
      return _invokeAndFree(() => _homepage(tabPtr, page));
    } finally {
      malloc.free(tabPtr);
    }
  }

  String search(String query, {String provider = 'moviebox', int page = 1}) {
    final provPtr = provider.toNativeUtf8();
    final queryPtr = query.toNativeUtf8();
    try {
      return _invokeAndFree(() => _search(provPtr, queryPtr, page));
    } finally {
      malloc.free(provPtr);
      malloc.free(queryPtr);
    }
  }

  String suggest(String query) {
    final queryPtr = query.toNativeUtf8();
    try {
      return _invokeAndFree(() => _suggest(queryPtr));
    } finally {
      malloc.free(queryPtr);
    }
  }

  String details(String id, {String provider = 'moviebox'}) {
    final provPtr = provider.toNativeUtf8();
    final idPtr = id.toNativeUtf8();
    try {
      return _invokeAndFree(() => _details(provPtr, idPtr));
    } finally {
      malloc.free(provPtr);
      malloc.free(idPtr);
    }
  }

  String episodeStreams(String id, int season, int episode,
      {String provider = 'moviebox'}) {
    final provPtr = provider.toNativeUtf8();
    final idPtr = id.toNativeUtf8();
    try {
      return _invokeAndFree(
          () => _episodeStreams(provPtr, idPtr, season, episode));
    } finally {
      malloc.free(provPtr);
      malloc.free(idPtr);
    }
  }

  String resolveStream(String releaseJson, {String provider = 'moviebox', String intent = 'playback'}) {
    final provPtr = provider.toNativeUtf8();
    final releasePtr = releaseJson.toNativeUtf8();
    final intentPtr = intent.toNativeUtf8();
    try {
      return _invokeAndFree(
          () => _resolveStream(provPtr, releasePtr, intentPtr));
    } finally {
      malloc.free(provPtr);
      malloc.free(releasePtr);
      malloc.free(intentPtr);
    }
  }

  String getCaptions(String subjectId, String resourceId,
      {List<String> siblingIds = const [], int season = 0, int episode = 0}) {
    final subPtr = subjectId.toNativeUtf8();
    final resPtr = resourceId.toNativeUtf8();
    final sibPtr = '["${siblingIds.join('","')}"]'.toNativeUtf8();
    try {
      return _invokeAndFree(
          () => _getCaptions(subPtr, resPtr, sibPtr, season, episode));
    } finally {
      malloc.free(subPtr);
      malloc.free(resPtr);
      malloc.free(sibPtr);
    }
  }

  String startProxy(String targetUrl,
      {Map<String, String> headers = const {}, String? subtitleUrl}) {
    final targetPtr = targetUrl.toNativeUtf8();
    final headersList = headers.entries.map((e) => [e.key, e.value]).toList();
    final headersJson = jsonEncode(headersList);
    final headersPtr = headersJson.toNativeUtf8();
    final subPtr = subtitleUrl != null ? subtitleUrl.toNativeUtf8() : ffi.nullptr;
    try {
      return _invokeAndFree(() => _startProxy(targetPtr, headersPtr, subPtr));
    } finally {
      malloc.free(targetPtr);
      malloc.free(headersPtr);
      if (subPtr != ffi.nullptr) malloc.free(subPtr);
    }
  }
}
