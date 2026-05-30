import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

enum VehicleType { taxi, tempo, private, suv, bus, bike }

class Ride {
  final String id;
  final String driverName;
  final String phone;
  final VehicleType vehicleType;
  final String vehicleName;
  final String plateNumber;
  final int totalSeats;
  final List<String> bookedSeats;
  final String from;
  final String to;
  final String date;
  final String time;
  final double price;
  double lat;
  double lng;
  final double driverRating;
  final List<String> safetyFlags;

  Ride({
    required this.id,
    required this.driverName,
    required this.phone,
    required this.vehicleType,
    required this.vehicleName,
    required this.plateNumber,
    required this.totalSeats,
    required this.bookedSeats,
    required this.from,
    required this.to,
    required this.date,
    required this.time,
    required this.price,
    required this.lat,
    required this.lng,
    this.driverRating = 5.0,
    this.safetyFlags = const [],
  });

  int get availableSeats => totalSeats - bookedSeats.length;
}

class RideProvider extends ChangeNotifier {
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  List<Ride> _rides = [];
  final FirebaseService _firebaseService = FirebaseService();

  static final List<Ride> _mockRides = [
    Ride(
      id: "d1",
      driverName: "Tenzin Dorje",
      phone: "+91 98160 12345",
      vehicleType: VehicleType.tempo,
      vehicleName: "Force Traveller 4x4",
      plateNumber: "HP 01 T 4562",
      totalSeats: 12,
      bookedSeats: ["S1", "S2", "S5"],
      from: "Manali (Mall Road)",
      to: "Kaza (Spiti)",
      date: DateTime.now().toString().split(' ')[0],
      time: "05:00",
      price: 1200.0,
      lat: 32.2396,
      lng: 77.1887,
      driverRating: 4.8,
    ),
    Ride(
      id: "d2",
      driverName: "Lobzang Bodh",
      phone: "+91 94180 76655",
      vehicleType: VehicleType.taxi,
      vehicleName: "Mahindra Scorpio 4WD",
      plateNumber: "HP 02 A 7890",
      totalSeats: 4,
      bookedSeats: ["S3"],
      from: "Kaza",
      to: "Tabo Monastery",
      date: DateTime.now().add(const Duration(days: 1)).toString().split(' ')[0],
      time: "09:00",
      price: 350.0,
      lat: 32.2276,
      lng: 78.0710,
      driverRating: 4.7,
    ),
    Ride(
      id: "d3",
      driverName: "Amit Negi",
      phone: "+91 98055 56789",
      vehicleType: VehicleType.private,
      vehicleName: "Tata Safari",
      plateNumber: "HP 03 B 9912",
      totalSeats: 4,
      bookedSeats: [],
      from: "Shimla Bypass",
      to: "Reckong Peo",
      date: DateTime.now().add(const Duration(days: 2)).toString().split(' ')[0],
      time: "06:00",
      price: 1500.0,
      lat: 31.1048,
      lng: 77.1734,
      driverRating: 4.6,
    ),
    Ride(
      id: "d4",
      driverName: "Tashi Namgyal",
      phone: "+91 98165 99887",
      vehicleType: VehicleType.suv,
      vehicleName: "Scorpio SUV 4x4",
      plateNumber: "HP 01 S 5512",
      totalSeats: 6,
      bookedSeats: ["S1", "S4"],
      from: "Kaza",
      to: "Manali",
      date: DateTime.now().toString().split(' ')[0],
      time: "06:00",
      price: 1400.0,
      lat: 32.2276,
      lng: 78.0710,
      driverRating: 4.9,
    ),
    Ride(
      id: "d5",
      driverName: "HRTC Depot Driver",
      phone: "+91 19022 22350",
      vehicleType: VehicleType.bus,
      vehicleName: "HRTC Local Bus",
      plateNumber: "HP 02 B 3012",
      totalSeats: 30,
      bookedSeats: ["S1", "S2", "S5", "S6", "S9", "S10", "S17", "S18"],
      from: "Reckong Peo",
      to: "Kaza",
      date: DateTime.now().add(const Duration(days: 1)).toString().split(' ')[0],
      time: "05:30",
      price: 450.0,
      lat: 31.5401,
      lng: 78.2713,
      driverRating: 4.5,
    ),
    Ride(
      id: "d6",
      driverName: "Rigzin Dorje",
      phone: "+91 94595 11223",
      vehicleType: VehicleType.bike,
      vehicleName: "Royal Enfield Himalayan",
      plateNumber: "HP 03 M 0099",
      totalSeats: 1,
      bookedSeats: [],
      from: "Kaza",
      to: "Key Monastery",
      date: DateTime.now().toString().split(' ')[0],
      time: "10:00",
      price: 200.0,
      lat: 32.2276,
      lng: 78.0710,
      driverRating: 5.0,
    ),
    Ride(
      id: "d7",
      driverName: "Sunny 'Badmash' Singh",
      phone: "+91 99999 12345",
      vehicleType: VehicleType.suv,
      vehicleName: "Modified Offroad Gypsy",
      plateNumber: "DL 01 C 9999",
      totalSeats: 4,
      bookedSeats: [],
      from: "Manali",
      to: "Kaza",
      date: DateTime.now().toString().split(' ')[0],
      time: "12:00",
      price: 1800.0,
      lat: 32.2396,
      lng: 77.1887,
      driverRating: 2.8,
      safetyFlags: ["⚠️ Flagged: Rash driving on Spiti cliffs", "⚠️ Low safety score: Overcharging complaints"],
    )
  ];

  RideProvider() {
    _initFirestoreSync();
  }

  void _initFirestoreSync() {
    if (FirebaseService.isInitialized) {
      _firebaseService.streamRides().listen((freshRides) async {
        if (freshRides.isEmpty) {
          // Pre-seed Firestore if collection is empty
          for (var ride in _mockRides) {
            await _firebaseService.addRide(ride);
          }
        } else {
          _rides = freshRides;
          notifyListeners();
        }
      });
    } else {
      // Offline / Fallback Mock Mode
      _rides = List.from(_mockRides);
    }
  }

  String _searchFrom = "";
  String _searchTo = "";
  String _filterVehicleType = "all";

  List<Ride> get rides {
    return _rides.where((ride) {
      final matchesFrom = ride.from.toLowerCase().contains(_searchFrom.toLowerCase());
      final matchesTo = ride.to.toLowerCase().contains(_searchTo.toLowerCase());
      
      bool matchesType = true;
      if (_filterVehicleType != "all") {
        matchesType = ride.vehicleType.name == _filterVehicleType;
      }
      
      return matchesFrom && matchesTo && matchesType;
    }).toList();
  }

  void setFilters(String from, String to, String vehicleType) {
    _searchFrom = from;
    _searchTo = to;
    _filterVehicleType = vehicleType;
    notifyListeners();
  }

  void resetFilters() {
    _searchFrom = "";
    _searchTo = "";
    _filterVehicleType = "all";
    notifyListeners();
  }

  void registerRide(Ride newRide) async {
    if (FirebaseService.isInitialized) {
      await _firebaseService.addRide(newRide);
    } else {
      _rides.insert(0, newRide);
      notifyListeners();
    }
  }

  void bookSeats(String rideId, List<String> seatIds) async {
    if (FirebaseService.isInitialized) {
      try {
        await _firebaseService.bookSeats(rideId, seatIds);
      } catch (e) {
        debugPrint("Booking error: $e");
      }
    } else {
      final rideIndex = _rides.indexWhere((r) => r.id == rideId);
      if (rideIndex != -1) {
        _rides[rideIndex].bookedSeats.addAll(seatIds);
        notifyListeners();
      }
    }
  }

  void moderateDriver(String driverName, {required bool flagAsBad}) {
    final updated = _rides.map((ride) {
      if (ride.driverName == driverName) {
        return Ride(
          id: ride.id,
          driverName: ride.driverName,
          phone: ride.phone,
          vehicleType: ride.vehicleType,
          vehicleName: ride.vehicleName,
          plateNumber: ride.plateNumber,
          totalSeats: ride.totalSeats,
          bookedSeats: ride.bookedSeats,
          from: ride.from,
          to: ride.to,
          date: ride.date,
          time: ride.time,
          price: ride.price,
          lat: ride.lat,
          lng: ride.lng,
          driverRating: flagAsBad ? 2.8 : 5.0,
          safetyFlags: flagAsBad ? ["⚠️ Flagged: Rash driving on Spiti cliffs", "⚠️ Low safety score: Overcharging complaints"] : [],
        );
      }
      return ride;
    }).toList();
    _rides = updated;
    notifyListeners();
  }
}
