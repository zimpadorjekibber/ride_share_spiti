import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/phone_utils.dart';
import '../services/push_service.dart';

/// Extra amenities a host can offer / a seeker can request (beyond the core
/// Bukhari / Geyser / Food toggles).
const List<String> kExtraAmenities = [
  'WiFi',
  'Common Room',
  'Local Dining',
  'Hot Water',
  'Parking',
  'Bonfire',
  'Laundry',
  'Pet Friendly',
  'Room Heater',
  'Attached Bath',
  'Balcony',
  'Mountain View',
  'Power Backup',
];

/// Amenities worth a photo (a traveller wants to SEE these). Non-visual ones
/// like WiFi / Hot Water / Power Backup don't get a photo option.
const Set<String> kPhotoAmenities = {
  'Common Room',
  'Local Dining',
  'Parking',
  'Bonfire',
  'Laundry',
  'Room Heater',
  'Attached Bath',
  'Balcony',
  'Mountain View',
};

/// Type of property a seeker wants / a host offers.
const List<String> kPropertyTypes = [
  'Any',
  'Mud House',
  'Mud Igloo',
  'Tent',
  'Cloud House',
  'Homestay',
  'Guest House',
  'Hotel',
];

/// Spiti Valley villages / spots — shared across stay & food location pickers.
const List<String> kSpitiVillages = [
  'Kaza Center', 'Kibber', 'Key (Kee Monastery)', 'Langza', 'Komic', 'Hikkim',
  'Demul', 'Lhalung', 'Dhankar', 'Tabo', 'Mud (Pin Valley)', 'Sagnam',
  'Gulling', 'Kungri', 'Tashigang', 'Gette', 'Chicham', 'Rangrik', 'Pangmo',
  'Hull', 'Hansa', 'Losar', 'Kyato', 'Quiling', 'Poh', 'Shichling', 'Lari',
  'Hurling', 'Sumdo', 'Mane', 'Tangti', 'Chandratal', 'Batal', 'Kunzum Pass',
  'Other',
];

/// A single room in a homestay — its own photo, price & occupied/vacant status.
class RoomUnit {
  final String id;
  final String name; // "Room 1" / "Deluxe 101"
  final double price; // per night
  final String photoPath; // URL or local path
  final bool occupied; // true = booked/full

  RoomUnit({
    required this.id,
    required this.name,
    required this.price,
    this.photoPath = '',
    this.occupied = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'photoPath': photoPath,
        'occupied': occupied,
      };

  factory RoomUnit.fromMap(Map<String, dynamic> m) => RoomUnit(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        price: (m['price'] ?? 0).toDouble(),
        photoPath: m['photoPath'] ?? '',
        occupied: m['occupied'] ?? false,
      );
}

class Stay {
  final String id;
  final String hostName;
  final String phone;
  final String title;
  final String description;
  final double pricePerNight;
  final int roomsAvailable;
  final bool hasBukhari;
  final bool hasGeyser;
  final bool foodIncluded;
  final double lat;
  final double lng;
  final double rating;
  final List<String> safetyFlags;
  final int mockPhotoIndex;
  final String propertyType;
  final List<String> amenities;
  final String photoPath; // local file path of host-uploaded property photo
  final bool isFull; // host marked all rooms booked
  final List<RoomUnit> roomUnits; // per-room layout (photo/price/status)
  final Map<String, String> amenityPhotos; // amenity name → photo URL/path

  Stay({
    required this.id,
    required this.hostName,
    required this.phone,
    required this.title,
    required this.description,
    required this.pricePerNight,
    required this.roomsAvailable,
    required this.hasBukhari,
    required this.hasGeyser,
    required this.foodIncluded,
    required this.lat,
    required this.lng,
    this.rating = 5.0,
    this.safetyFlags = const [],
    this.mockPhotoIndex = 0,
    this.propertyType = 'Homestay',
    this.amenities = const [],
    this.photoPath = '',
    this.isFull = false,
    this.roomUnits = const [],
    this.amenityPhotos = const {},
  });

  /// Copy with selected fields changed — keeps everything else (incl. photos).
  Stay copyWith({
    int? roomsAvailable,
    bool? isFull,
    List<RoomUnit>? roomUnits,
    double? rating,
    List<String>? safetyFlags,
  }) =>
      Stay(
        id: id,
        hostName: hostName,
        phone: phone,
        title: title,
        description: description,
        pricePerNight: pricePerNight,
        roomsAvailable: roomsAvailable ?? this.roomsAvailable,
        hasBukhari: hasBukhari,
        hasGeyser: hasGeyser,
        foodIncluded: foodIncluded,
        lat: lat,
        lng: lng,
        rating: rating ?? this.rating,
        safetyFlags: safetyFlags ?? this.safetyFlags,
        mockPhotoIndex: mockPhotoIndex,
        propertyType: propertyType,
        amenities: amenities,
        photoPath: photoPath,
        isFull: isFull ?? this.isFull,
        roomUnits: roomUnits ?? this.roomUnits,
        amenityPhotos: amenityPhotos,
      );

  /// Number of vacant rooms when a per-room layout exists.
  int get vacantRooms => roomUnits.where((r) => !r.occupied).length;

  /// Effective availability: explicit isFull, or every room occupied.
  bool get effectivelyFull =>
      isFull || (roomUnits.isNotEmpty && vacantRooms == 0);

  Map<String, dynamic> toMap() {
    return {
      'hostName': hostName,
      'phone': phone,
      'title': title,
      'description': description,
      'pricePerNight': pricePerNight,
      'roomsAvailable': roomsAvailable,
      'hasBukhari': hasBukhari,
      'hasGeyser': hasGeyser,
      'foodIncluded': foodIncluded,
      'lat': lat,
      'lng': lng,
      'rating': rating,
      'safetyFlags': safetyFlags,
      'mockPhotoIndex': mockPhotoIndex,
      'propertyType': propertyType,
      'amenities': amenities,
      'photoPath': photoPath,
      'isFull': isFull,
      'roomUnits': roomUnits.map((r) => r.toMap()).toList(),
      'amenityPhotos': amenityPhotos,
    };
  }

  factory Stay.fromMap(String id, Map<String, dynamic> map) {
    return Stay(
      id: id,
      hostName: map['hostName'] ?? '',
      phone: map['phone'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      pricePerNight: (map['pricePerNight'] ?? 0.0).toDouble(),
      roomsAvailable: map['roomsAvailable'] ?? 1,
      hasBukhari: map['hasBukhari'] ?? false,
      hasGeyser: map['hasGeyser'] ?? false,
      foodIncluded: map['foodIncluded'] ?? false,
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      rating: (map['rating'] ?? 5.0).toDouble(),
      safetyFlags: List<String>.from(map['safetyFlags'] ?? []),
      mockPhotoIndex: map['mockPhotoIndex'] ?? 0,
      propertyType: map['propertyType'] ?? 'Homestay',
      amenities: List<String>.from(map['amenities'] ?? []),
      photoPath: map['photoPath'] ?? '',
      isFull: map['isFull'] ?? false,
      roomUnits: ((map['roomUnits'] ?? const []) as List)
          .map((e) => RoomUnit.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      amenityPhotos: Map<String, String>.from(map['amenityPhotos'] ?? const {}),
    );
  }
}

class StayRequest {
  final String id;
  final String seekerName;
  final String phone;
  final String locationLooking;
  final int guestsCount;
  final double budgetPerNight;
  final String dates;
  final String note;
  final double lat;
  final double lng;
  final DateTime createdAt;
  final String propertyType;
  final List<String> desiredAmenities;

  StayRequest({
    required this.id,
    required this.seekerName,
    required this.phone,
    required this.locationLooking,
    required this.guestsCount,
    required this.budgetPerNight,
    required this.dates,
    required this.note,
    required this.lat,
    required this.lng,
    required this.createdAt,
    this.propertyType = 'Any',
    this.desiredAmenities = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'seekerName': seekerName,
      'phone': phone,
      'locationLooking': locationLooking,
      'guestsCount': guestsCount,
      'budgetPerNight': budgetPerNight,
      'dates': dates,
      'note': note,
      'lat': lat,
      'lng': lng,
      'createdAt': createdAt.toIso8601String(),
      'propertyType': propertyType,
      'desiredAmenities': desiredAmenities,
    };
  }

  factory StayRequest.fromMap(String id, Map<String, dynamic> map) {
    return StayRequest(
      id: id,
      seekerName: map['seekerName'] ?? '',
      phone: map['phone'] ?? '',
      locationLooking: map['locationLooking'] ?? '',
      guestsCount: map['guestsCount'] ?? 1,
      budgetPerNight: (map['budgetPerNight'] ?? 0.0).toDouble(),
      dates: map['dates'] ?? '',
      note: map['note'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      propertyType: map['propertyType'] ?? 'Any',
      desiredAmenities: List<String>.from(map['desiredAmenities'] ?? []),
    );
  }
}

class StayProvider extends ChangeNotifier {
  List<Stay> _stays = [];
  List<StayRequest> _stayRequests = [];
  final FirebaseService _firebaseService = FirebaseService();

  static final List<Stay> _mockStays = [
    Stay(
      id: "s1",
      hostName: "Tsering Angdu",
      phone: "+91 98160 55443",
      title: "Kaza Heights Homestay",
      description: "Cozy traditional mud-brick homestay in the heart of Kaza. Panoramic mountain views, local Spiti butter tea, and organic farming experience.",
      pricePerNight: 1200.0,
      roomsAvailable: 3,
      hasBukhari: true,
      hasGeyser: true,
      foodIncluded: true,
      lat: 32.2276,
      lng: 78.0710,
      rating: 4.9,
      mockPhotoIndex: 0,
      propertyType: 'Homestay',
      amenities: ['WiFi', 'Local Dining', 'Hot Water', 'Mountain View', 'Common Room'],
    ),
    Stay(
      id: "s2",
      hostName: "Dolma Lhamo",
      phone: "+91 94590 12121",
      title: "Kibber Traditional Mud House",
      description: "Experience living in one of Asia's highest villages. Authentic Spitian style bedrooms, flat roof access for breathtaking stargazing, and home-cooked meals.",
      pricePerNight: 900.0,
      roomsAvailable: 2,
      hasBukhari: true,
      hasGeyser: false,
      foodIncluded: true,
      lat: 32.2533,
      lng: 78.0125,
      rating: 4.8,
      mockPhotoIndex: 1,
      propertyType: 'Mud House',
      amenities: ['Local Dining', 'Bonfire', 'Mountain View', 'Power Backup'],
    ),
    Stay(
      id: "s3",
      hostName: "Sunny 'Badmash' Singh",
      phone: "+91 99999 12345",
      title: "Spiti Valley Luxury Alpine Lodge",
      description: "Premium modern luxury hotel in Kaza with full amenities. High prices, but scenic views.",
      pricePerNight: 4500.0,
      roomsAvailable: 5,
      hasBukhari: false,
      hasGeyser: true,
      foodIncluded: false,
      lat: 32.2276,
      lng: 78.0710,
      rating: 2.9,
      safetyFlags: ["🛑 Flagged: Water geyser not working in winter", "🛑 High-risk: Overcharged tourists and rude service"],
      mockPhotoIndex: 2,
      propertyType: 'Hotel',
      amenities: ['WiFi', 'Parking', 'Hot Water', 'Attached Bath', 'Power Backup'],
    ),
    Stay(
      id: "s4",
      hostName: "Rigzin Namgyal",
      phone: "+91 98055 99001",
      title: "Dhankar Castle View Guest House",
      description: "Right next to the historic Dhankar Monastery. Cliffside balconies overlooking the confluence of Spiti and Pin rivers.",
      pricePerNight: 1500.0,
      roomsAvailable: 4,
      hasBukhari: true,
      hasGeyser: true,
      foodIncluded: false,
      lat: 32.1215,
      lng: 78.2144,
      rating: 4.7,
      mockPhotoIndex: 3,
      propertyType: 'Guest House',
      amenities: ['Parking', 'Hot Water', 'Mountain View', 'Attached Bath', 'Laundry'],
    )
  ];

  static final List<StayRequest> _mockRequests = [
    StayRequest(
      id: "sr1",
      seekerName: "Ananya Sharma",
      phone: "+91 98765 43210",
      locationLooking: "Kaza Center",
      guestsCount: 2,
      budgetPerNight: 1500.0,
      dates: "June 2 - June 5",
      note: "Looking for a warm room with hot water geyser and a heater. Local food preferred.",
      lat: 32.2276,
      lng: 78.0710,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      propertyType: 'Homestay',
      desiredAmenities: ['Hot Water', 'Room Heater', 'Local Dining', 'WiFi'],
    ),
    StayRequest(
      id: "sr2",
      seekerName: "Rohan Varma",
      phone: "+91 99011 22334",
      locationLooking: "Kibber Village",
      guestsCount: 4,
      budgetPerNight: 1000.0,
      dates: "June 4 - June 6",
      note: "Group of backpackers looking for a cozy homestay to experience local life. Stargazing is a must!",
      lat: 32.2533,
      lng: 78.0125,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      propertyType: 'Mud House',
      desiredAmenities: ['Bonfire', 'Local Dining', 'Common Room', 'Mountain View'],
    )
  ];

  StayProvider() {
    _initFirestoreSync();
  }

  void _initFirestoreSync() {
    if (FirebaseService.isInitialized) {
      // Live data only — never auto-seed; in launch mode hide demo-id records.
      _firebaseService.streamStays().listen((freshStays) {
        _stays = LocalStorageService.demoSeedingDisabled
            ? freshStays.where((s) => s.id.contains('_')).toList()
            : freshStays;
        notifyListeners();
      });
      _firebaseService.streamStayRequests().listen((freshReqs) {
        _stayRequests = LocalStorageService.demoSeedingDisabled
            ? freshReqs.where((r) => r.id.contains('_')).toList()
            : freshReqs;
        notifyListeners();
      });
    } else if (!LocalStorageService.demoSeedingDisabled) {
      // Offline demo fallback (only when explicitly enabled).
      _stays = List.from(_mockStays);
      _stayRequests = List.from(_mockRequests);
    }
  }

  List<Stay> get stays => _stays;
  List<StayRequest> get stayRequests => _stayRequests;

  void registerStay(Stay newStay) async {
    if (FirebaseService.isInitialized) {
      await _firebaseService.addStay(newStay);
    } else {
      _stays.insert(0, newStay);
      notifyListeners();
    }
    // Host now gets pushes for new room-seeker broadcasts.
    PushService.subscribeForPhone(newStay.phone);
    PushService.subscribeProviders('stay');
  }

  void postStayRequest(StayRequest req) async {
    if (FirebaseService.isInitialized) {
      await _firebaseService.addStayRequest(req);
    } else {
      _stayRequests.insert(0, req);
      notifyListeners();
    }
  }

  void deleteStay(String id) async {
    if (FirebaseService.isInitialized) {
      await _firebaseService.deleteStay(id);
    } else {
      _stays.removeWhere((s) => s.id == id);
      notifyListeners();
    }
  }

  /// True if this host already has a listing with the same type + title.
  bool isDuplicate(String phone, String propertyType, String title) {
    final t = title.trim().toLowerCase();
    return _stays.any((s) =>
        samePhone(s.phone, phone) && s.propertyType == propertyType && s.title.trim().toLowerCase() == t);
  }

  /// Quick one-tap toggle: mark a homestay Full / Available (no full edit).
  void setStayFull(Stay s, bool full) {
    updateStay(s.copyWith(isFull: full));
  }

  /// Update an existing stay (host editing their own listing).
  void updateStay(Stay updated) async {
    if (FirebaseService.isInitialized) {
      await _firebaseService.addStay(updated); // same id → overwrite
    } else {
      final i = _stays.indexWhere((s) => s.id == updated.id);
      if (i >= 0) {
        _stays[i] = updated;
      } else {
        _stays.insert(0, updated);
      }
      notifyListeners();
    }
  }

  void moderateStay(String hostName, {required bool flagAsBad}) {
    final updated = _stays.map((stay) {
      if (stay.hostName == hostName) {
        return stay.copyWith(
          rating: flagAsBad ? 2.5 : 5.0,
          safetyFlags: flagAsBad ? ["🛑 Flagged: Water geyser not working in winter", "🛑 High-risk: Overcharged tourists and rude service"] : [],
        );
      }
      return stay;
    }).toList();
    _stays = updated;
    notifyListeners();
  }
}
