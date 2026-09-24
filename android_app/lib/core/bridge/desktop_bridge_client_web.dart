// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class DesktopBridgeClient {
  static const String baseUrl = 'http://127.0.0.1:8765';

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    try {
      final req = await html.HttpRequest.request(
        '$baseUrl$path',
        method: 'POST',
        sendData: jsonEncode(body),
        requestHeaders: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (req.status == 200 || req.status == 204) {
        final text = req.responseText ?? '{}';
        return jsonDecode(text) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'error': 'Desktop bridge HTTP ${req.status}: ${req.responseText}',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Desktop bridge request timed out. Make sure "cargo run -- --dev-bridge" is running.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Could not connect to desktop bridge at $baseUrl. Please start it with: cargo run -- --dev-bridge',
      };
    }
  }

  static Future<Map<String, dynamic>> get(String path) async {
    try {
      final req = await html.HttpRequest.request(
        '$baseUrl$path',
        method: 'GET',
      ).timeout(const Duration(seconds: 5));

      if (req.status == 200) {
        return jsonDecode(req.responseText ?? '{}') as Map<String, dynamic>;
      } else {
        return {'status': 'error', 'error': 'HTTP ${req.status}'};
      }
    } catch (e) {
      return {'status': 'offline', 'error': '$e'};
    }
  }
}
