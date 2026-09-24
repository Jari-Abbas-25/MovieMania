export 'desktop_bridge_client_stub.dart'
    if (dart.library.js_interop) 'desktop_bridge_client_web.dart'
    if (dart.library.html) 'desktop_bridge_client_web.dart';
