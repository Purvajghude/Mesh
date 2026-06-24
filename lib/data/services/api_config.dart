import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

/// Base URL for the Mesh AI backend (FastAPI).
///
/// Resolution order (first non-empty wins):
///   1. A runtime override the user sets in-app (persisted) — lets you paste a
///      fresh ngrok/tunnel URL on a real phone with no rebuild.
///   2. A compile-time `--dart-define=API_BASE_URL=...` baked into the build.
///   3. A platform default: localhost (web/desktop) or 10.0.2.2 (Android
///      emulator's alias for the host machine — NOT reachable from a real phone).
///
/// On a physical phone the backend is only reachable via a tunnel (HTTPS) or a
/// deployed URL — set it via (1) or (2), never the emulator default.
class ApiConfig {
  static const String _prefsKey = 'mesh_api_base_url';
  static const String _compileTime = String.fromEnvironment('API_BASE_URL');

  static String? _override;

  /// Load any persisted backend URL. Call once during bootstrap.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && saved.trim().isNotEmpty) _override = saved.trim();
    } catch (_) {
      // Non-fatal: fall back to the compile-time / platform default.
    }
  }

  /// Persist (or clear) the runtime backend URL.
  static Future<void> setOverride(String? url) async {
    final clean = url?.trim();
    _override = (clean == null || clean.isEmpty) ? null : _normalize(clean);
    final prefs = await SharedPreferences.getInstance();
    if (_override == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, _override!);
    }
  }

  /// The override the user has set, if any (for showing in settings).
  static String? get override => _override;

  static String get baseUrl {
    if (_override != null && _override!.isNotEmpty) return _override!;
    if (_compileTime.isNotEmpty) return _normalize(_compileTime);
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  /// Headers for backend calls: JSON + the Supabase access token (the backend
  /// derives the user id from this token, never from the request body). The
  /// ngrok header skips its free-tier browser interstitial for API calls.
  static Map<String, String> headers() {
    final token = SupabaseService.accessToken;
    return {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static String _normalize(String url) {
    var u = url.trim();
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u'; // bare host → assume a tunnel/deployed HTTPS URL
    }
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}
