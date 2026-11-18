import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';
import 'profile_service.dart';

typedef PushTokenRegistrar = Future<void> Function({
  required String token,
  String? playerCode,
  String provider,
  String platform,
});

/// Bridge service managing external push token registration (`player_push_tokens`)
/// and notification tap routing directly to `/inbox` (`AppRoutes.royalInbox`).
/// Note: Client-side Firebase SDK (`firebase_messaging`) activates as soon as
/// `google-services.json` is added to `android/app/`.
class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._();
  PushNotificationService._();

  String? _lastRegisteredToken;

  @visibleForTesting
  PushTokenRegistrar? tokenRegistrarOverride;

  String? get lastRegisteredToken => _lastRegisteredToken;

  @visibleForTesting
  void resetForTesting() {
    tokenRegistrarOverride = null;
    _lastRegisteredToken = null;
  }

  /// Registers a device push token cleanly on Supabase (`register_player_push_token`).
  Future<bool> registerToken(
    String rawToken, {
    String provider = 'fcm',
    String platform = 'android',
  }) async {
    final token = rawToken.trim();
    if (token.length < 16 || token.length > 512) return false;
    final playerCode = ProfileService.instance.activeProfile?.playerCode;

    try {
      if (tokenRegistrarOverride != null) {
        await tokenRegistrarOverride!(
          token: token,
          playerCode: playerCode,
          provider: provider,
          platform: platform,
        );
      } else {
        final client = Supabase.instance.client;
        await client.rpc(
          'register_player_push_token',
          params: {
            'p_device_token': token,
            if (playerCode != null && playerCode.trim().isNotEmpty)
              'p_player_code': playerCode.trim().toUpperCase(),
            'p_provider': provider,
            'p_platform': platform,
          },
        ).timeout(const Duration(seconds: 6));
      }
      _lastRegisteredToken = token;
      return true;
    } catch (e) {
      debugPrint('PushNotificationService registerToken notice: $e');
      return false;
    }
  }

  /// Routes any tapped OS notification payload directly to `/inbox` or a safe route.
  void handleExternalTapPayload(String? payload) {
    NotificationService.handleNotificationPayload(payload ?? '/inbox');
  }
}
