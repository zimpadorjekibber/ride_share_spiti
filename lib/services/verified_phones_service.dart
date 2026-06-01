import 'firebase_service.dart';

/// Tracks phone numbers that an admin has manually verified (for locals who
/// can't self-verify via OTP). Cards show a "✓ Verified" badge for these.
class VerifiedPhonesService {
  static final Set<String> _verified = {};

  /// Normalise to the last 10 digits so "+91 98160 12345" == "9816012345".
  static String _norm(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
  }

  static bool isVerified(String phone) {
    if (phone.trim().isEmpty) return false;
    return _verified.contains(_norm(phone));
  }

  /// Start syncing the verified-phones set from Firestore (call once at boot).
  static void init() {
    if (!FirebaseService.isInitialized) return;
    FirebaseService().streamVerifiedPhones().listen((phones) {
      _verified
        ..clear()
        ..addAll(phones.map(_norm));
    });
  }

  static Future<void> add(String phone, String name) async {
    if (phone.trim().isEmpty) return;
    _verified.add(_norm(phone));
    await FirebaseService().addVerifiedPhone(phone, name);
  }

  static Future<void> remove(String phone) async {
    _verified.remove(_norm(phone));
    await FirebaseService().removeVerifiedPhone(phone);
  }
}
