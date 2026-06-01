import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';
import '../models/ride_model.dart';
import '../models/stay_model.dart';
import '../models/food_model.dart';
import '../models/review_model.dart';

class FirebaseService {
  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  // Initialize Firebase and enable offline persistent caching
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      // Configure Firestore settings for persistent cache
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      _initialized = true;
      debugPrint("Firebase successfully initialized with offline persistence enabled!");
    } catch (e) {
      debugPrint("Firebase initialization failed (probably missing google-services.json): $e");
      _initialized = false;
    }
  }

  // Get firestore instance
  static FirebaseFirestore get firestore {
    if (!_initialized) {
      throw StateError("Firebase not initialized");
    }
    return FirebaseFirestore.instance;
  }

  // Stream all rides from Firestore
  Stream<List<Ride>> streamRides() {
    if (!_initialized) {
      return const Stream.empty();
    }
    return firestore
        .collection('rides')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Ride(
          id: doc.id,
          driverName: data['driverName'] ?? '',
          phone: data['phone'] ?? '',
          vehicleType: VehicleType.values.firstWhere(
            (e) => e.name == (data['vehicleType'] ?? 'taxi'),
            orElse: () => VehicleType.taxi,
          ),
          vehicleName: data['vehicleName'] ?? '',
          plateNumber: data['plateNumber'] ?? '',
          totalSeats: data['totalSeats'] ?? 4,
          bookedSeats: List<String>.from(data['bookedSeats'] ?? []),
          from: data['from'] ?? '',
          to: data['to'] ?? '',
          date: data['date'] ?? '',
          time: data['time'] ?? '',
          price: (data['price'] ?? 0.0).toDouble(),
          lat: (data['lat'] ?? 0.0).toDouble(),
          lng: (data['lng'] ?? 0.0).toDouble(),
          photoPath: data['photoPath'] ?? '',
          seatBookings: ((data['seatBookings'] ?? const []) as List)
              .map((e) => SeatBooking.fromMap(Map<String, dynamic>.from(e)))
              .toList(),
        );
      }).toList();
    });
  }

  // Add new ride to Firestore
  Future<void> addRide(Ride ride) async {
    if (!_initialized) return;
    await firestore.collection('rides').doc(ride.id).set({
      'driverName': ride.driverName,
      'phone': ride.phone,
      'vehicleType': ride.vehicleType.name,
      'vehicleName': ride.vehicleName,
      'plateNumber': ride.plateNumber,
      'totalSeats': ride.totalSeats,
      'bookedSeats': ride.bookedSeats,
      'from': ride.from,
      'to': ride.to,
      'date': ride.date,
      'time': ride.time,
      'price': ride.price,
      'lat': ride.lat,
      'lng': ride.lng,
      'photoPath': ride.photoPath,
      'seatBookings': ride.seatBookings.map((b) => b.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Book seats using Firestore Transaction (records who booked each seat)
  Future<void> bookSeats(String rideId, List<String> seatIds, {String name = '', String phone = ''}) async {
    if (!_initialized) return;
    final docRef = firestore.collection('rides').doc(rideId);

    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception("Ride not found!");
      }

      final currentBooked = List<String>.from(snapshot.get('bookedSeats') ?? []);
      for (var seat in seatIds) {
        if (currentBooked.contains(seat)) {
          throw Exception("Seat $seat is already booked!");
        }
      }

      transaction.update(docRef, {
        'bookedSeats': FieldValue.arrayUnion(seatIds),
        'seatBookings': FieldValue.arrayUnion(
          seatIds.map((s) => {'seatId': s, 'name': name, 'phone': phone, 'byDriver': false}).toList(),
        ),
      });
    });
  }

  // ── Passenger Requests ──────────────────────────────────
  Stream<List<dynamic>> streamPassengerRequests() {
    if (!_initialized) return const Stream.empty();
    return firestore
        .collection('passenger_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  Future<void> addPassengerRequest(dynamic request) async {
    if (!_initialized) return;
    await firestore
        .collection('passenger_requests')
        .doc(request.id)
        .set(request.toMap()..['createdAt'] = FieldValue.serverTimestamp());
  }

  Future<void> cancelPassengerRequest(String id) async {
    if (!_initialized) return;
    await firestore
        .collection('passenger_requests')
        .doc(id)
        .update({'isActive': false});
  }

  // ── Stays ──────────────────────────────────────────────
  Stream<List<Stay>> streamStays() {
    if (!_initialized) return const Stream.empty();
    return firestore
        .collection('stays')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Stay.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Future<void> addStay(Stay stay) async {
    if (!_initialized) return;
    await firestore.collection('stays').doc(stay.id).set(stay.toMap()..['createdAt'] = FieldValue.serverTimestamp());
  }

  Future<void> deleteStay(String id) async {
    if (!_initialized) return;
    await firestore.collection('stays').doc(id).delete();
  }

  // ── Stay Requests ──────────────────────────────────────
  Stream<List<StayRequest>> streamStayRequests() {
    if (!_initialized) return const Stream.empty();
    return firestore
        .collection('stay_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return StayRequest.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  Future<void> addStayRequest(StayRequest req) async {
    if (!_initialized) return;
    await firestore.collection('stay_requests').doc(req.id).set(req.toMap());
  }

  Future<void> deleteDoc(String collection, String id) async {
    if (!_initialized) return;
    await firestore.collection(collection).doc(id).delete();
  }

  // ── Food Places ────────────────────────────────────────
  Stream<List<FoodPlace>> streamFoodPlaces() {
    if (!_initialized) return const Stream.empty();
    return firestore
        .collection('food_places')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => FoodPlace.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> addFoodPlace(FoodPlace place) async {
    if (!_initialized) return;
    await firestore.collection('food_places').doc(place.id).set(place.toMap()..['createdAt'] = FieldValue.serverTimestamp());
  }

  Future<void> deleteFoodPlace(String id) async {
    if (!_initialized) return;
    await firestore.collection('food_places').doc(id).delete();
  }

  // ── Food Requests ──────────────────────────────────────
  Stream<List<FoodRequest>> streamFoodRequests() {
    if (!_initialized) return const Stream.empty();
    return firestore
        .collection('food_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => FoodRequest.fromMap(doc.id, doc.data())).toList());
  }

  Future<void> addFoodRequest(FoodRequest req) async {
    if (!_initialized) return;
    await firestore.collection('food_requests').doc(req.id).set(req.toMap());
  }

  // ── Reviews ────────────────────────────────────────────
  Future<void> addReview(Review review) async {
    if (!_initialized) return;
    await firestore.collection('reviews').doc(review.id).set(review.toJson());
  }

  Future<List<Review>> fetchReviews() async {
    if (!_initialized) return [];
    try {
      final snap = await firestore.collection('reviews').get();
      return snap.docs.map((d) => Review.fromJson(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Admin-verified phones ──────────────────────────────
  Stream<List<String>> streamVerifiedPhones() {
    if (!_initialized) return const Stream.empty();
    return firestore.collection('verified_phones').snapshots().map(
          (s) => s.docs.map((d) => (d.data()['phone'] ?? d.id).toString()).toList(),
        );
  }

  Future<void> addVerifiedPhone(String phone, String name) async {
    if (!_initialized) return;
    final id = phone.replaceAll(RegExp(r'\D'), '');
    if (id.isEmpty) return;
    await firestore.collection('verified_phones').doc(id).set({
      'phone': phone,
      'name': name,
      'verifiedBy': 'admin',
      'verifiedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeVerifiedPhone(String phone) async {
    if (!_initialized) return;
    final id = phone.replaceAll(RegExp(r'\D'), '');
    if (id.isEmpty) return;
    await firestore.collection('verified_phones').doc(id).delete();
  }
}
