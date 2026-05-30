import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../models/ride_model.dart';

class FirebaseService {
  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  // Initialize Firebase and enable offline persistent caching
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
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
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Book seats using Firestore Transaction
  Future<void> bookSeats(String rideId, List<String> seatIds) async {
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
}
