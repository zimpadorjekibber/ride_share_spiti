import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booked_trip_model.dart';

class LocalStorageService {
  static const String _tripsKey = 'booked_trips';
  static const String _profileKey = 'user_profile';
  static const String _notifKey = 'notifications';

  // ─── Trips ──────────────────────────────────────────
  static Future<List<BookedTrip>> getTrips() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_tripsKey);
    if (raw == null) {
      // Seed two mock booked trips for a fantastic testing experience
      final seed = [
        BookedTrip(
          bookingRef: "SPI-7Y8A2E",
          rideId: "d1",
          driverName: "Tenzin Dorje",
          driverPhone: "+91 98160 12345",
          vehicleName: "Force Traveller 4x4",
          plateNumber: "HP 01 T 4562",
          from: "Manali (Mall Road)",
          to: "Kaza (Spiti)",
          date: DateTime.now().toString().split(' ')[0],
          time: "05:00",
          seatIds: ["S1", "S2"],
          totalPaid: 2400.0,
          status: "upcoming",
          bookedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        BookedTrip(
          bookingRef: "SPI-R3K9W2",
          rideId: "d7",
          driverName: "Sunny 'Badmash' Singh",
          driverPhone: "+91 99999 12345",
          vehicleName: "Modified Offroad Gypsy",
          plateNumber: "DL 01 C 9999",
          from: "Kaza",
          to: "Manali",
          date: DateTime.now().subtract(const Duration(days: 3)).toString().split(' ')[0],
          time: "12:00",
          seatIds: ["S3"],
          totalPaid: 1800.0,
          status: "completed",
          bookedAt: DateTime.now().subtract(const Duration(days: 3, hours: 4)),
        ),
      ];
      final rawList = seed.map((t) => jsonEncode(t.toJson())).toList();
      await prefs.setStringList(_tripsKey, rawList);
      return seed;
    }
    return raw.map((s) => BookedTrip.fromJson(jsonDecode(s))).toList();
  }

  static Future<void> saveTrip(BookedTrip trip) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_tripsKey) ?? [];
    raw.insert(0, jsonEncode(trip.toJson())); // newest first
    await prefs.setStringList(_tripsKey, raw);
  }

  static Future<void> cancelTrip(String bookingRef) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_tripsKey) ?? [];
    final updated = raw.map((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      if (map['bookingRef'] == bookingRef) {
        map['status'] = 'cancelled';
      }
      return jsonEncode(map);
    }).toList();
    await prefs.setStringList(_tripsKey, updated);
  }

  static Future<void> reviewTrip(String bookingRef, double rating, List<String> flags) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_tripsKey) ?? [];
    final updated = raw.map((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      if (map['bookingRef'] == bookingRef) {
        map['isReviewed'] = true;
        map['ratingGiven'] = rating;
        map['safetyIssuesFlagged'] = flags;
      }
      return jsonEncode(map);
    }).toList();
    await prefs.setStringList(_tripsKey, updated);
  }

  // ─── Profile ─────────────────────────────────────────
  static Future<UserProfile> getProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw == null) return UserProfile();
    return UserProfile.fromJson(jsonDecode(raw));
  }

  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  // ─── Notifications ────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_notifKey) ?? [];
    return raw.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  static Future<void> addNotification(String title, String body) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_notifKey) ?? [];
    raw.insert(
        0,
        jsonEncode({
          'title': title,
          'body': body,
          'time': DateTime.now().toIso8601String(),
          'read': false,
        }));
    // Keep only last 20
    final trimmed = raw.take(20).toList();
    await prefs.setStringList(_notifKey, trimmed);
  }

  static Future<void> markAllNotificationsRead() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_notifKey) ?? [];
    final updated = raw.map((s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      map['read'] = true;
      return jsonEncode(map);
    }).toList();
    await prefs.setStringList(_notifKey, updated);
  }

  static const String _adsKey = 'tourism_ads';
  static const String _verifsKey = 'document_verifications';

  // ─── Ads Management ───────────────────────────────────
  static Future<List<Map<String, dynamic>>> getAds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_adsKey);
    if (raw == null) {
      // Pre-seed three gorgeous tourism ads
      final seed = [
        {
          'id': 'ad1',
          'title': '🏡 Spiti Valley Homestay Booking',
          'body': 'Stay with local families in Kaza. Authentic organic food & Spitian hospitality. Book now!',
          'imageUrl': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&q=80&w=400',
          'isActive': true,
          'link': '+91 98160 55443',
        },
        {
          'id': 'ad2',
          'title': '🚙 Kaza Local Jeep Union Specials',
          'body': '4x4 Offroad SUVs for Chandratal Lake, Pin Valley & Kibber. Safety verified drivers.',
          'imageUrl': 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&q=80&w=400',
          'isActive': true,
          'link': '+91 94180 22350',
        },
        {
          'id': 'ad3',
          'title': '🏔️ High Altitude Trekking Guides',
          'body': 'Cross Pin Parvati Pass & Kunzum Pass with certified, expert local guides of Spiti.',
          'imageUrl': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&q=80&w=400',
          'isActive': false,
          'link': '+91 98055 77665',
        },
      ];
      final rawList = seed.map((m) => jsonEncode(m)).toList();
      await prefs.setStringList(_adsKey, rawList);
      return seed;
    }
    return raw.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  static Future<void> saveAds(List<Map<String, dynamic>> adsList) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = adsList.map((m) => jsonEncode(m)).toList();
    await prefs.setStringList(_adsKey, raw);
  }

  // ─── Verifications Management ────────────────────────
  static Future<List<Map<String, dynamic>>> getVerifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_verifsKey);
    if (raw == null) {
      // Pre-seed one pending driver document review
      final seed = [
        {
          'driverName': 'Ramesh Negi',
          'vehicleName': 'Mahindra Scorpio 4WD',
          'plateNumber': 'HP 03 T 7001',
          'phone': '+91 98165 44321',
          'isApproved': false,
          'vehicleType': 'suv',
        }
      ];
      final rawList = seed.map((m) => jsonEncode(m)).toList();
      await prefs.setStringList(_verifsKey, rawList);
      return seed;
    }
    return raw.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  static Future<void> saveVerifications(List<Map<String, dynamic>> verifs) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = verifs.map((m) => jsonEncode(m)).toList();
    await prefs.setStringList(_verifsKey, raw);
  }
}
