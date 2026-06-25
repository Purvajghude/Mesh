import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

/// FCM push: ask permission, register this device's token to the backend, and
/// keep it fresh. All best-effort and Android-only — it never blocks the app,
/// and no-ops on web/desktop (no Firebase config there).
class PushService {
  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Call once the user is signed in (e.g. when the home shell mounts).
  static Future<void> register() async {
    if (!_supported) return;
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(); // contextual permission prompt
      final token = await fm.getToken();
      if (token != null) await _save(uid, token);
      fm.onTokenRefresh.listen((t) {
        final id = SupabaseService.currentUser?.id;
        if (id != null) _save(id, t);
      });
    } catch (_) {
      // Push is a bonus, never a blocker.
    }
  }

  static Future<void> _save(String uid, String token) async {
    await SupabaseService.client.from('device_tokens').upsert({
      'token': token,
      'profile_id': uid,
      'platform': 'android',
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Drop this device's token on sign-out so it stops receiving pushes.
  static Future<void> unregister() async {
    if (!_supported) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await SupabaseService.client
            .from('device_tokens')
            .delete()
            .eq('token', token);
      }
    } catch (_) {}
  }
}
