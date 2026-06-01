import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/spiti_routes.dart';

enum VehicleType { taxi, tempo, private, suv, bus, bike }

/// Who holds a specific seat. Recorded when a passenger books online or when
/// the driver blocks a seat manually (phone/walk-in booking).
class SeatBooking {
  final String seatId; // "S1", "S2"…
  final String name; // passenger name
  final String phone; // passenger contact
  final bool byDriver; // true = driver blocked it manually
  SeatBooking({required this.seatId, this.name = '', this.phone = '', this.byDriver = false});

  Map<String, dynamic> toMap() =>
      {'seatId': seatId, 'name': name, 'phone': phone, 'byDriver': byDriver};
  factory SeatBooking.fromMap(Map<String, dynamic> m) => SeatBooking(
        seatId: m['seatId'] ?? '',
        name: m['name'] ?? '',
        phone: m['phone'] ?? '',
        byDriver: m['byDriver'] ?? false,
      );
}

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
  final String photoPath; // local file path of driver-uploaded vehicle photo
  final List<SeatBooking> seatBookings; // who holds each booked seat

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
    this.photoPath = '',
    this.seatBookings = const [],
  });

  int get availableSeats => totalSeats - bookedSeats.length;
  bool get isFull => bookedSeats.length >= totalSeats;

  /// Booking details for a given seat id, if recorded.
  SeatBooking? bookingFor(String seatId) {
    for (final b in seatBookings) {
      if (b.seatId == seatId) return b;
    }
    return null;
  }

  Ride copyWith({
    int? totalSeats,
    List<String>? bookedSeats,
    double? price,
    String? from,
    String? to,
    String? date,
    String? time,
    double? driverRating,
    List<String>? safetyFlags,
    List<SeatBooking>? seatBookings,
  }) =>
      Ride(
        id: id,
        driverName: driverName,
        phone: phone,
        vehicleType: vehicleType,
        vehicleName: vehicleName,
        plateNumber: plateNumber,
        totalSeats: totalSeats ?? this.totalSeats,
        bookedSeats: bookedSeats ?? this.bookedSeats,
        from: from ?? this.from,
        to: to ?? this.to,
        date: date ?? this.date,
        time: time ?? this.time,
        price: price ?? this.price,
        lat: lat,
        lng: lng,
        driverRating: driverRating ?? this.driverRating,
        safetyFlags: safetyFlags ?? this.safetyFlags,
        photoPath: photoPath,
        seatBookings: seatBookings ?? this.seatBookings,
      );
}

// Mode order = toggle cycle order: Stay → Food → Ride → Stay
enum AppMode { stay, food, ride }

class RideProvider extends ChangeNotifier {
  static const String _themeKey = 'dark_mode';

  bool _isDarkMode = false; // default: light mode
  bool get isDarkMode => _isDarkMode;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false; // light unless user chose dark
    notifyListeners();
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode); // remember choice across restarts
  }

  AppMode _appMode = AppMode.stay; // app opens in Stay by default
  AppMode get appMode => _appMode;

  void toggleAppMode() {
    // Cycle: ride → stay → food → ride
    _appMode = AppMode.values[(_appMode.index + 1) % AppMode.values.length];
    notifyListeners();
  }

  void setAppMode(AppMode mode) {
    _appMode = mode;
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
    _loadTheme();
    _initFirestoreSync();
  }

  void _initFirestoreSync() {
    if (FirebaseService.isInitialized) {
      _firebaseService.streamRides().listen((freshRides) {
        // Live data only — never auto-seed; and in launch mode hide any demo-id
        // (no-underscore) records that a stale client may have re-seeded.
        _rides = LocalStorageService.demoSeedingDisabled
            ? freshRides.where((r) => r.id.contains('_')).toList()
            : freshRides;
        notifyListeners();
      });
    } else if (!LocalStorageService.demoSeedingDisabled) {
      // Offline demo fallback (only when explicitly enabled).
      _rides = List.from(_mockRides);
    }
  }

  String _searchFrom = "";
  String _searchTo = "";
  String _filterVehicleType = "all";

  /// Unfiltered list — used by the driver's own "My Rides" dashboard so that
  /// search filters on the Find Rides screen never hide their listings.
  List<Ride> get allRides => _rides;

  List<Ride> get rides {
    final from = _searchFrom.trim();
    final to = _searchTo.trim();
    return _rides.where((ride) {
      if (_filterVehicleType != "all" && ride.vehicleType.name != _filterVehicleType) {
        return false;
      }
      if (from.isEmpty && to.isEmpty) return true;

      // 1) Direct text match on the ride's own from/to.
      final subFrom = from.isEmpty || ride.from.toLowerCase().contains(from.toLowerCase());
      final subTo = to.isEmpty || ride.to.toLowerCase().contains(to.toLowerCase());
      if (subFrom && subTo) return true;

      // 2) "Along the way" — ride passes near & in-between the seeker's points.
      return SpitiRoutes.rideServesTrip(ride.from, ride.to, from, to);
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

  /// Update an existing ride (driver editing / managing their own ride).
  void updateRide(Ride updated) async {
    if (FirebaseService.isInitialized) {
      await _firebaseService.addRide(updated); // same id → overwrite
    } else {
      final i = _rides.indexWhere((r) => r.id == updated.id);
      if (i >= 0) {
        _rides[i] = updated;
      } else {
        _rides.insert(0, updated);
      }
      notifyListeners();
    }
  }

  void deleteRide(String id) async {
    if (FirebaseService.isInitialized) {
      await _firebaseService.deleteDoc('rides', id);
    } else {
      _rides.removeWhere((r) => r.id == id);
      notifyListeners();
    }
  }

  void bookSeats(String rideId, List<String> seatIds, {String name = '', String phone = ''}) async {
    if (FirebaseService.isInitialized) {
      try {
        await _firebaseService.bookSeats(rideId, seatIds, name: name, phone: phone);
      } catch (e) {
        debugPrint("Booking error: $e");
      }
    } else {
      final i = _rides.indexWhere((r) => r.id == rideId);
      if (i != -1) {
        final r = _rides[i];
        _rides[i] = r.copyWith(
          bookedSeats: [...r.bookedSeats, ...seatIds],
          seatBookings: [
            ...r.seatBookings,
            ...seatIds.map((s) => SeatBooking(seatId: s, name: name, phone: phone)),
          ],
        );
        notifyListeners();
      }
    }
  }

  /// Driver manually blocks a seat (e.g. a phone / walk-in booking).
  void setSeatBooked(Ride ride, String seatId, {String name = '', String phone = '', bool byDriver = true}) {
    if (ride.bookedSeats.contains(seatId)) return;
    updateRide(ride.copyWith(
      bookedSeats: [...ride.bookedSeats, seatId],
      seatBookings: [...ride.seatBookings, SeatBooking(seatId: seatId, name: name, phone: phone, byDriver: byDriver)],
    ));
  }

  /// Driver frees a seat (confirmed action — never an accidental tap).
  void freeSeat(Ride ride, String seatId) {
    updateRide(ride.copyWith(
      bookedSeats: ride.bookedSeats.where((s) => s != seatId).toList(),
      seatBookings: ride.seatBookings.where((b) => b.seatId != seatId).toList(),
    ));
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
