import 'package:flutter_test/flutter_test.dart';
import 'package:ride_share_spiti/services/spiti_routes.dart';

void main() {
  group('SpitiRoutes.position', () {
    test('exact match', () {
      expect(SpitiRoutes.position('Kaza'), 200);
      expect(SpitiRoutes.position('  MANALI '), 0);
    });
    test('fuzzy match', () {
      expect(SpitiRoutes.position('Kaza Bus Stand'), 200);
      expect(SpitiRoutes.position('Tabo Monastery'), 250);
    });
    test('unknown place', () {
      expect(SpitiRoutes.position('Mumbai'), isNull);
      expect(SpitiRoutes.position(''), isNull);
    });
    test('poo vs pooh longest-key rule', () {
      expect(SpitiRoutes.position('pooh'), 360);
      expect(SpitiRoutes.position('poo'), 360);
    });
  });

  group('SpitiRoutes.rideServesTrip', () {
    test('ride covers an inner sub-trip same direction', () {
      // Manali→Tabo ride serves Kaza→Tabo seeker
      expect(SpitiRoutes.rideServesTrip('Manali', 'Tabo', 'Kaza', 'Tabo'), isTrue);
    });
    test('nearby spur village within tolerance', () {
      // Chicham→Rampur serves Kibber→Tabo (doc example)
      expect(SpitiRoutes.rideServesTrip('Chicham', 'Rampur', 'Kibber', 'Tabo'), isTrue);
    });
    test('opposite direction rejected', () {
      expect(SpitiRoutes.rideServesTrip('Manali', 'Kaza', 'Kaza', 'Manali'), isFalse);
      expect(SpitiRoutes.rideServesTrip('Tabo', 'Manali', 'Losar', 'Kaza'), isFalse);
    });
    test('seeker outside corridor rejected', () {
      // Manali→Losar ride should not serve Kaza→Tabo
      expect(SpitiRoutes.rideServesTrip('Manali', 'Losar', 'Kaza', 'Tabo'), isFalse);
      // Shimla beyond a Kaza→Tabo ride
      expect(SpitiRoutes.rideServesTrip('Kaza', 'Tabo', 'Kaza', 'Shimla'), isFalse);
    });
    test('only one end typed', () {
      expect(SpitiRoutes.rideServesTrip('Manali', 'Tabo', 'Kaza', ''), isTrue);
      expect(SpitiRoutes.rideServesTrip('Manali', 'Losar', '', 'Shimla'), isFalse);
    });
    test('unknown places fall back to false', () {
      expect(SpitiRoutes.rideServesTrip('Mumbai', 'Pune', 'Kaza', 'Tabo'), isFalse);
      expect(SpitiRoutes.rideServesTrip('Manali', 'Tabo', 'Mumbai', 'Pune'), isFalse);
    });
  });
}
