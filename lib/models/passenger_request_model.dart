import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'dart:math';

// ─────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────
class PassengerRequest {
  final String id;
  final String passengerName;
  final String phone;
  final String from;
  final String to;
  final String date;
  final int seatsNeeded;
  final String note;
  final DateTime createdAt;
  bool isActive;
  final double passengerRating;
  final List<String> safetyFlags;

  PassengerRequest({
    required this.id,
    required this.passengerName,
    required this.phone,
    required this.from,
    required this.to,
    required this.date,
    required this.seatsNeeded,
    this.note = '',
    required this.createdAt,
    this.isActive = true,
    this.passengerRating = 5.0,
    this.safetyFlags = const [],
  });

  Map<String, dynamic> toMap() => {
        'passengerName': passengerName,
        'phone': phone,
        'from': from,
        'to': to,
        'date': date,
        'seatsNeeded': seatsNeeded,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
        'isActive': isActive,
        'passengerRating': passengerRating,
        'safetyFlags': safetyFlags,
      };

  factory PassengerRequest.fromMap(String id, Map<String, dynamic> map) =>
      PassengerRequest(
        id: id,
        passengerName: map['passengerName'] ?? '',
        phone: map['phone'] ?? '',
        from: map['from'] ?? '',
        to: map['to'] ?? '',
        date: map['date'] ?? '',
        seatsNeeded: map['seatsNeeded'] ?? 1,
        note: map['note'] ?? '',
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
            : DateTime.now(),
        isActive: map['isActive'] ?? true,
        passengerRating: (map['passengerRating'] as num?)?.toDouble() ?? 5.0,
        safetyFlags: List<String>.from(map['safetyFlags'] ?? []),
      );
}

// ─────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────
class PassengerRequestProvider extends ChangeNotifier {
  List<PassengerRequest> _requests = [];
  final FirebaseService _firebaseService = FirebaseService();

  // Seed mock requests
  static final List<PassengerRequest> _mockRequests = [
    PassengerRequest(
      id: 'pr1',
      passengerName: 'Ravi Kumar',
      phone: '+91 98765 43210',
      from: 'Manali',
      to: 'Kaza (Spiti)',
      date: DateTime.now().toString().split(' ')[0],
      seatsNeeded: 2,
      note: 'Need early morning ride, have luggage',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      passengerRating: 4.8,
    ),
    PassengerRequest(
      id: 'pr2',
      passengerName: 'Priya Sharma',
      phone: '+91 87654 32109',
      from: 'Kaza',
      to: 'Manali',
      date: DateTime.now().add(const Duration(days: 1)).toString().split(' ')[0],
      seatsNeeded: 1,
      note: 'Solo traveller, flexible on time',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      passengerRating: 4.9,
    ),
    PassengerRequest(
      id: 'pr3',
      passengerName: 'Arjun & Family',
      phone: '+91 76543 21098',
      from: 'Shimla',
      to: 'Reckong Peo',
      date: DateTime.now().add(const Duration(days: 2)).toString().split(' ')[0],
      seatsNeeded: 3,
      note: 'Family of 3 with child seat needed',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      passengerRating: 4.7,
    ),
    PassengerRequest(
      id: 'pr4',
      passengerName: 'Solo Backpacker',
      phone: '+91 65432 10987',
      from: 'Kaza',
      to: 'Key Monastery',
      date: DateTime.now().toString().split(' ')[0],
      seatsNeeded: 1,
      note: 'Morning only, returning same day',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      passengerRating: 4.9,
    ),
    PassengerRequest(
      id: 'pr5',
      passengerName: "Ramesh 'Badmash' Verma",
      phone: "+91 99999 54321",
      from: "Kaza",
      to: "Manali",
      date: DateTime.now().toString().split(' ')[0],
      seatsNeeded: 4,
      note: "No advance payment, cash only",
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      passengerRating: 1.9,
      safetyFlags: ["🛑 Flagged: Booked 4 seats & cancelled last-minute", "⚠️ Misbehavior reported"],
    )
  ];

  PassengerRequestProvider() {
    _initSync();
  }

  void _initSync() {
    if (FirebaseService.isInitialized) {
      _firebaseService.streamPassengerRequests().listen((fresh) {
        if (fresh.isEmpty) {
          for (var r in _mockRequests) {
            _firebaseService.addPassengerRequest(r);
          }
        } else {
          _requests = fresh.map((item) {
            final map = item as Map<String, dynamic>;
            final id = map['id'] as String;
            return PassengerRequest.fromMap(id, map);
          }).toList();
          notifyListeners();
        }
      });
    } else {
      _requests = List.from(_mockRequests);
    }
  }

  List<PassengerRequest> get requests =>
      _requests.where((r) => r.isActive).toList();

  Future<void> addRequest(PassengerRequest request) async {
    if (FirebaseService.isInitialized) {
      await _firebaseService.addPassengerRequest(request);
    } else {
      _requests.insert(0, request);
      notifyListeners();
    }
  }

  Future<void> cancelRequest(String id) async {
    if (FirebaseService.isInitialized) {
      await _firebaseService.cancelPassengerRequest(id);
    } else {
      final i = _requests.indexWhere((r) => r.id == id);
      if (i != -1) {
        _requests[i].isActive = false;
        notifyListeners();
      }
    }
  }
}

// Helper
String generateRequestId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rng = Random();
  return 'preq_${List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join()}';
}
