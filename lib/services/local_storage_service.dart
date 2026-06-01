import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booked_trip_model.dart';
import '../models/review_model.dart';
import 'firebase_service.dart';

class LocalStorageService {
  static const String _tripsKey = 'booked_trips';
  static const String _profileKey = 'user_profile';
  static const String _notifKey = 'notifications';
  static const String _reviewsKey = 'reviews';
  static const String _demoDisabledKey = 'demo_seeding_disabled';

  /// When true, providers never seed/re-seed mock data. Defaults to true for
  /// the live launch so empty collections stay empty (no fake listings revive).
  static bool demoSeedingDisabled = true;

  /// Broadcast requests (room/food/ride seekers) auto-expire after this long,
  /// so stale "still looking" posts don't waste providers' time.
  static const Duration requestValidity = Duration(hours: 24);

  /// A record is demo/seed data if its id has NO underscore (e.g. s1, f1, rv1,
  /// ad1, pr1). Real records use timestamp ids with '_' (s_…, preq_…, sponsor_…).
  static bool isDemoId(String id) => !id.contains('_');

  static Future<void> loadFlags() async {
    final prefs = await SharedPreferences.getInstance();
    demoSeedingDisabled = prefs.getBool(_demoDisabledKey) ?? true;
  }

  static Future<void> disableDemoSeeding() async {
    demoSeedingDisabled = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_demoDisabledKey, true);
  }

  /// Remove locally-stored demo records (reviews, ads, seeded trips, seeded
  /// verifications) — keeps real data. Cloud demo docs are removed separately.
  static Future<void> clearDemoLocalData() async {
    final prefs = await SharedPreferences.getInstance();

    // Reviews & ads: keep only real (id contains '_')
    List<String> keepReal(String key) {
      final raw = prefs.getStringList(key) ?? [];
      return raw.where((s) {
        final id = (jsonDecode(s) as Map<String, dynamic>)['id'] as String? ?? '';
        return id.contains('_');
      }).toList();
    }

    await prefs.setStringList(_reviewsKey, keepReal(_reviewsKey));
    await prefs.setStringList(_adsKey, keepReal(_adsKey));

    // Seeded booked trips (fixed refs)
    const demoTripRefs = ['SPI-7Y8A2E', 'SPI-R3K9W2'];
    final trips = prefs.getStringList(_tripsKey) ?? [];
    await prefs.setStringList(
        _tripsKey,
        trips.where((s) => !demoTripRefs.contains((jsonDecode(s) as Map)['bookingRef'])).toList());

    // Seeded verifications (fixed names)
    const demoVerifNames = ['Ramesh Negi', 'Padma Angmo'];
    final verifs = prefs.getStringList(_verifsKey) ?? [];
    await prefs.setStringList(
        _verifsKey,
        verifs.where((s) {
          final m = jsonDecode(s) as Map<String, dynamic>;
          final name = m['driverName'] ?? m['hostName'] ?? m['ownerName'] ?? '';
          return !demoVerifNames.contains(name);
        }).toList());
  }

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

  // ─── Reviews (two-way: provider ⇄ seeker, for ride & stay) ──
  static Future<List<Review>> getAllReviews() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_reviewsKey);
    if (raw == null) {
      // Seed a few demo reviews so lists aren't empty on first run.
      final seed = [
        Review(
          id: 'rv1',
          category: 'stay',
          subjectId: 's1',
          subjectName: 'Kaza Heights Homestay',
          authorRole: 'Guest',
          authorName: 'Ishita Rao',
          rating: 5.0,
          comment: 'Warm bukhari, amazing butter tea and the host treated us like family!',
          tags: ['Clean', 'Friendly', 'Would Recommend'],
          createdAt: DateTime.now().subtract(const Duration(days: 4)),
        ),
        Review(
          id: 'rv2',
          category: 'stay',
          subjectId: 's1',
          subjectName: 'Kaza Heights Homestay',
          authorRole: 'Guest',
          authorName: 'Karan Mehta',
          rating: 4.0,
          comment: 'Cozy rooms and great views. Water was a little cold in the morning.',
          tags: ['Comfortable', 'Good Value'],
          createdAt: DateTime.now().subtract(const Duration(days: 9)),
        ),
        Review(
          id: 'rv3',
          category: 'stay',
          subjectId: 's2',
          subjectName: 'Kibber Traditional Mud House',
          authorRole: 'Guest',
          authorName: 'Meera Nair',
          rating: 5.0,
          comment: 'Best stargazing of my life from the rooftop. Authentic mud house experience.',
          tags: ['As Described', 'Friendly'],
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];
      final rawList = seed.map((r) => jsonEncode(r.toJson())).toList();
      await prefs.setStringList(_reviewsKey, rawList);
      return seed;
    }
    return raw.map((s) => Review.fromJson(jsonDecode(s))).toList();
  }

  static Future<List<Review>> getReviews(String category, String subjectId) async {
    final all = await getAllReviews();
    final list = all
        .where((r) => r.category == category && r.subjectId == subjectId)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // newest first
    return list;
  }

  static Future<void> addReview(Review review) async {
    final prefs = await SharedPreferences.getInstance();
    await getAllReviews(); // ensure seeded
    final raw = prefs.getStringList(_reviewsKey) ?? [];
    raw.insert(0, jsonEncode(review.toJson()));
    await prefs.setStringList(_reviewsKey, raw);
    // Also push to the cloud so other users/devices see it (no-op if offline).
    FirebaseService().addReview(review);
  }

  /// Pull cloud reviews into the local cache (called once at startup).
  static Future<void> syncReviewsFromCloud() async {
    if (!FirebaseService.isInitialized) return;
    final cloud = await FirebaseService().fetchReviews();
    if (cloud.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await getAllReviews(); // ensure seeded
    final raw = prefs.getStringList(_reviewsKey) ?? [];
    final localIds = raw
        .map((s) => (jsonDecode(s) as Map<String, dynamic>)['id'] as String?)
        .whereType<String>()
        .toSet();
    var changed = false;
    for (final r in cloud) {
      if (!localIds.contains(r.id)) {
        raw.add(jsonEncode(r.toJson()));
        changed = true;
      }
    }
    if (changed) await prefs.setStringList(_reviewsKey, raw);
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
          'title': '🏡 Kaza Heights Homestay',
          'body': 'Stay with local families in Kaza. Authentic organic food & Spitian hospitality. Book now!',
          'imageUrl': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&q=80&w=400',
          'isActive': true,
          'link': '+91 98160 55443',
          'category': 'stay', // shown on ride & food screens
          'sponsor': 'Spiti Admin',
          'paid': true,
        },
        {
          'id': 'ad2',
          'title': '🚙 Kaza Local Jeep Union Specials',
          'body': '4x4 Offroad SUVs for Chandratal Lake, Pin Valley & Kibber. Safety verified drivers.',
          'imageUrl': 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&q=80&w=400',
          'isActive': true,
          'link': '+91 94180 22350',
          'category': 'ride', // shown on stay & food screens
          'sponsor': 'Spiti Admin',
          'paid': true,
        },
        {
          'id': 'ad3',
          'title': '🍲 Himalayan Cafe & Bakery',
          'body': 'Wood-fired pizza, apple pie & fresh coffee with a Kaza valley view. Open 7 AM – 10 PM.',
          'imageUrl': 'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&q=80&w=400',
          'isActive': true,
          'link': '+91 94591 22112',
          'category': 'food', // shown on ride & stay screens
          'sponsor': 'Spiti Admin',
          'paid': true,
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

  static Future<bool> hasAd(String id) async {
    final list = await getAds();
    return list.any((a) => a['id'] == id);
  }

  static Future<void> removeAd(String id) async {
    final list = await getAds();
    list.removeWhere((a) => a['id'] == id);
    await saveAds(list);
  }

  /// Add a single sponsored ad (used when a provider pays to promote).
  static Future<void> addAd(Map<String, dynamic> ad) async {
    final list = await getAds();
    // Replace an existing ad with the same id (re-promote) else add.
    final i = list.indexWhere((a) => a['id'] == ad['id']);
    if (i >= 0) {
      list[i] = ad;
    } else {
      list.insert(0, ad);
    }
    await saveAds(list);
  }

  // ─── Verifications Management ────────────────────────
  static Future<List<Map<String, dynamic>>> getVerifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_verifsKey);
    if (raw == null) {
      // Pre-seed one pending driver doc + one pending homestay host review
      final seed = [
        {
          'type': 'driver',
          'driverName': 'Ramesh Negi',
          'vehicleName': 'Mahindra Scorpio 4WD',
          'plateNumber': 'HP 03 T 7001',
          'phone': '+91 98165 44321',
          'isApproved': false,
          'vehicleType': 'suv',
        },
        {
          'type': 'host',
          'hostName': 'Padma Angmo',
          'propertyName': 'Langza Fossil View Homestay',
          'propertyType': 'Homestay',
          'rooms': 4,
          'phone': '+91 98170 33221',
          'isApproved': false,
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

  /// Append a single pending verification (used when a host/driver registers).
  static Future<void> addVerification(Map<String, dynamic> verification) async {
    final list = await getVerifications();
    list.insert(0, verification);
    await saveVerifications(list);
  }
}
