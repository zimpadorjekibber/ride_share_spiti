import 'package:geolocator/geolocator.dart';

/// Real device GPS (previously the "Auto-GPS" buttons silently pinned a
/// hardcoded Kaza Center and claimed success).
class LocationService {
  /// Returns the device position, or null when location services are off,
  /// permission is denied, or the fix times out. Never throws — callers fall
  /// back to a sensible default and tell the user honestly.
  static Future<Position?> getCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // High accuracy; bounded so the button never spins forever in a valley
      // with weak signal.
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
