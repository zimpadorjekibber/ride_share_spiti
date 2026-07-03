import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_service.dart';
import 'local_storage_service.dart';
import 'phone_utils.dart';

/// FCM push notifications.
///
/// Topic scheme (Cloud Functions in `functions/index.js` send to these):
///  - `all_users`        — every app install (admin announcements)
///  - `user_<10digits>`  — personal: booking/cancellation alerts for the
///                          rides this phone number owns
///  - `providers_ride`   — drivers: a passenger broadcast a ride request
///  - `providers_stay`   — hosts: a tourist broadcast a room request
///  - `providers_food`   — cooks: someone broadcast a food request
class PushService {
  static Future<void> init() async {
    if (!FirebaseService.isInitialized) return;
    try {
      final fm = FirebaseMessaging.instance;
      // Android 13+ shows the system notification permission dialog here.
      await fm.requestPermission();
      await fm.subscribeToTopic('all_users');

      // Foreground pushes don't hit the system tray — mirror them into the
      // in-app bell so nothing is missed while the app is open.
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) {
          LocalStorageService.addNotification(
              n.title ?? 'Spiti Setu', n.body ?? '');
        }
      });

      final profile = await LocalStorageService.getProfile();
      await subscribeForPhone(profile.phone);
    } catch (_) {
      // Push is best-effort — the app works fully without it.
    }
  }

  /// Personal topic — booking alerts for listings owned by this phone.
  static Future<void> subscribeForPhone(String phone) async {
    final p = normPhone(phone);
    if (p.length != 10) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic('user_$p');
    } catch (_) {}
  }

  /// Provider topics — new seeker-broadcast alerts. [kind] is
  /// 'ride' | 'stay' | 'food'; called when the user registers a listing.
  static Future<void> subscribeProviders(String kind) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic('providers_$kind');
    } catch (_) {}
  }
}
