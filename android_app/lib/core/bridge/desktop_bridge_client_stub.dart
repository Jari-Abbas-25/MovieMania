class DesktopBridgeClient {
  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    return {'success': false, 'error': 'Desktop bridge is not used on Android native'};
  }

  static Future<Map<String, dynamic>> get(String path) async {
    return {'status': 'offline'};
  }
}
