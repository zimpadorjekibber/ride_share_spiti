import 'package:flutter_test/flutter_test.dart';
import 'package:ride_share_spiti/models/ride_model.dart';

Ride _ride(String date) => Ride(
      id: 'r_test',
      driverName: 'Test Driver',
      phone: '9999999999',
      vehicleType: VehicleType.taxi,
      vehicleName: 'Alto',
      plateNumber: 'HP 01 T 1234',
      totalSeats: 4,
      bookedSeats: const [],
      from: 'Kaza',
      to: 'Manali',
      date: date,
      time: '06:00',
      price: 1500,
      lat: 0,
      lng: 0,
    );

void main() {
  group('Ride.isExpired', () {
    test('past date is expired', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final d =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      expect(_ride(d).isExpired, isTrue);
      expect(_ride('2026-06-06').isExpired, isTrue); // the reported case
    });

    test('today is NOT expired (visible all departure day)', () {
      final now = DateTime.now();
      final d =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      expect(_ride(d).isExpired, isFalse);
    });

    test('future date is not expired', () {
      final t = DateTime.now().add(const Duration(days: 3));
      final d =
          '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
      expect(_ride(d).isExpired, isFalse);
    });

    test('unparseable or empty date never expires', () {
      expect(_ride('').isExpired, isFalse);
      expect(_ride('kal subah').isExpired, isFalse);
    });
  });
}
