// Unit tests for RideShare/FindStay/FindFood Spiti core models.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ride_share_spiti/models/review_model.dart';
import 'package:ride_share_spiti/models/booked_trip_model.dart';
import 'package:ride_share_spiti/models/ride_model.dart';
import 'package:ride_share_spiti/models/stay_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Review', () {
    test('toJson/fromJson round-trip preserves data', () {
      final r = Review(
        id: 'rv_test',
        category: 'stay',
        subjectId: 's1',
        subjectName: 'Test Homestay',
        authorRole: 'Guest',
        authorName: 'Test User',
        rating: 4.0,
        comment: 'Nice place',
        tags: ['Clean', 'Friendly'],
        createdAt: DateTime.parse('2026-01-01T10:00:00.000'),
      );
      final back = Review.fromJson(r.toJson());
      expect(back.id, 'rv_test');
      expect(back.category, 'stay');
      expect(back.rating, 4.0);
      expect(back.tags, ['Clean', 'Friendly']);
      expect(back.createdAt, r.createdAt);
    });
  });

  group('UserProfile.isVerified', () {
    test('unregistered is not verified', () {
      expect(UserProfile().isVerified, isFalse);
    });
    test('registered + phone OR email verified is verified', () {
      final p = UserProfile(isRegistered: true, phoneVerified: true);
      expect(p.isVerified, isTrue);
      final p2 = UserProfile(isRegistered: true, emailVerified: true);
      expect(p2.isVerified, isTrue);
    });
    test('registered but unverified contacts is not verified', () {
      expect(UserProfile(isRegistered: true).isVerified, isFalse);
    });
    test('json round-trip keeps verification flags + email', () {
      final p = UserProfile(
        name: 'A', phone: '123', email: 'a@b.com',
        isRegistered: true, phoneVerified: true, emailVerified: true,
      );
      final back = UserProfile.fromJson(p.toJson());
      expect(back.email, 'a@b.com');
      expect(back.phoneVerified, isTrue);
      expect(back.isVerified, isTrue);
    });
  });

  group('AppMode cycling', () {
    test('default is stay; toggle cycles stay -> food -> ride -> stay', () {
      final provider = RideProvider();
      expect(provider.appMode, AppMode.stay);
      provider.toggleAppMode();
      expect(provider.appMode, AppMode.food);
      provider.toggleAppMode();
      expect(provider.appMode, AppMode.ride);
      provider.toggleAppMode();
      expect(provider.appMode, AppMode.stay);
    });
  });

  group('Stay.fromMap', () {
    test('applies safe defaults for missing new fields', () {
      final stay = Stay.fromMap('s_x', {
        'hostName': 'H',
        'phone': '999',
        'title': 'T',
        'pricePerNight': 1000,
        'roomsAvailable': 2,
      });
      expect(stay.propertyType, 'Homestay');
      expect(stay.amenities, isEmpty);
      expect(stay.photoPath, '');
      expect(stay.pricePerNight, 1000.0);
    });
  });
}
