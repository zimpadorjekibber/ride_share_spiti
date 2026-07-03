import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/local_storage_service.dart';
import '../services/phone_utils.dart';
import '../services/push_service.dart';

const List<String> kFoodTypes = [
  'Restaurant',
  'Cafe',
  'Dhaba',
  'Home Dining',
  'Cloud Kitchen',
];

const List<String> kCuisines = [
  'Spitian / Local',
  'North Indian',
  'Tibetan / Momos',
  'Chinese',
  'South Indian',
  'Continental',
  'Israeli',
  'Maggi & Snacks',
];

const List<String> kVegPrefs = ['Veg', 'Non-Veg', 'Both'];

/// Extra facilities a food place can offer.
const List<String> kFoodFacilities = [
  'WiFi',
  'Indoor Seating',
  'Rooftop',
  'Parking',
  'Washroom',
  'Bonfire',
  'Live Music',
  'Pure Veg Kitchen',
  'Card / UPI',
  'Pet Friendly',
  'Mountain View',
  'Power Backup',
];

/// A single dish on a food place's menu (different items, different prices).
class MenuItem {
  final String name;
  final double price;
  final bool available; // false = finished / sold out for today
  final int qtyLeft; // plates left; -1 = not tracked / unlimited
  MenuItem({required this.name, required this.price, this.available = true, this.qtyLeft = -1});

  /// True when this dish is unavailable (toggled off or 0 plates left).
  bool get isOut => !available || qtyLeft == 0;

  Map<String, dynamic> toMap() =>
      {'name': name, 'price': price, 'available': available, 'qtyLeft': qtyLeft};
  factory MenuItem.fromMap(Map<String, dynamic> m) => MenuItem(
        name: m['name'] ?? '',
        price: (m['price'] ?? 0).toDouble(),
        available: m['available'] ?? true,
        qtyLeft: ((m['qtyLeft'] ?? -1) as num).toInt(),
      );
}

/// A single table in a restaurant/cafe — Free or Occupied (live layout).
class TableUnit {
  final String id;
  final String name; // "Table 1" / "T4"
  final int seats; // capacity (0 = unset)
  final bool occupied;
  TableUnit({required this.id, required this.name, this.seats = 0, this.occupied = false});

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'seats': seats, 'occupied': occupied};
  factory TableUnit.fromMap(Map<String, dynamic> m) => TableUnit(
        id: m['id'] ?? '',
        name: m['name'] ?? '',
        seats: ((m['seats'] ?? 0) as num).toInt(),
        occupied: m['occupied'] ?? false,
      );
}

class FoodPlace {
  final String id;
  final String ownerName;
  final String phone;
  final String title;
  final String foodType; // Restaurant / Cafe / Dhaba / Home Dining / Cloud Kitchen
  final String cuisine;
  final String vegType; // Veg / Non-Veg / Both
  final String description;
  final double pricePerPlate; // legacy / fallback "from" price
  final String timings;
  final bool homeDelivery;
  final double deliveryRangeKm; // how far they deliver (0 = not set)
  final bool cookOnRequest; // local who cooks on request (may have no shop)
  final bool offMarket; // away from the main market
  final double lat;
  final double lng;
  final double rating;
  final List<String> safetyFlags;
  final int mockPhotoIndex;
  final String photoPath; // legacy single photo (kept for backward compat)
  final List<String> photos; // up to 10 photos (URLs or local paths)
  final List<String> seatingPhotos; // seating-area / table-view photos (shown in Table Layout)
  final List<MenuItem> menu; // per-item menu with individual prices
  final String menuLink; // QR menu / website / Google Maps link
  final List<String> facilities; // WiFi, Seating, Parking, etc.
  final List<TableUnit> tables; // live table layout (Free / Occupied)

  FoodPlace({
    required this.id,
    required this.ownerName,
    required this.phone,
    required this.title,
    required this.foodType,
    required this.cuisine,
    required this.vegType,
    required this.description,
    this.pricePerPlate = 0,
    required this.timings,
    this.homeDelivery = false,
    this.deliveryRangeKm = 0,
    this.cookOnRequest = false,
    this.offMarket = false,
    required this.lat,
    required this.lng,
    this.rating = 5.0,
    this.safetyFlags = const [],
    this.mockPhotoIndex = 0,
    this.photoPath = '',
    this.photos = const [],
    this.seatingPhotos = const [],
    this.menu = const [],
    this.menuLink = '',
    this.facilities = const [],
    this.tables = const [],
  });

  /// Number of free (unoccupied) tables.
  int get freeTables => tables.where((t) => !t.occupied).length;

  FoodPlace copyWith({
    List<MenuItem>? menu,
    List<TableUnit>? tables,
    double? rating,
    List<String>? safetyFlags,
  }) =>
      FoodPlace(
        id: id, ownerName: ownerName, phone: phone, title: title,
        foodType: foodType, cuisine: cuisine, vegType: vegType,
        description: description, pricePerPlate: pricePerPlate, timings: timings,
        homeDelivery: homeDelivery, deliveryRangeKm: deliveryRangeKm,
        cookOnRequest: cookOnRequest, offMarket: offMarket, lat: lat, lng: lng,
        rating: rating ?? this.rating, safetyFlags: safetyFlags ?? this.safetyFlags,
        mockPhotoIndex: mockPhotoIndex, photoPath: photoPath, photos: photos,
        seatingPhotos: seatingPhotos,
        menu: menu ?? this.menu, menuLink: menuLink, facilities: facilities,
        tables: tables ?? this.tables,
      );

  /// All photos to show (new list first, else legacy single).
  List<String> get allPhotos => photos.isNotEmpty
      ? photos
      : (photoPath.isNotEmpty ? [photoPath] : const []);

  /// Lowest menu price, else legacy per-plate. 0 if nothing set.
  double get fromPrice {
    if (menu.isNotEmpty) {
      return menu.map((m) => m.price).reduce((a, b) => a < b ? a : b);
    }
    return pricePerPlate;
  }

  Map<String, dynamic> toMap() => {
        'ownerName': ownerName,
        'phone': phone,
        'title': title,
        'foodType': foodType,
        'cuisine': cuisine,
        'vegType': vegType,
        'description': description,
        'pricePerPlate': pricePerPlate,
        'timings': timings,
        'homeDelivery': homeDelivery,
        'deliveryRangeKm': deliveryRangeKm,
        'cookOnRequest': cookOnRequest,
        'offMarket': offMarket,
        'lat': lat,
        'lng': lng,
        'rating': rating,
        'safetyFlags': safetyFlags,
        'mockPhotoIndex': mockPhotoIndex,
        'photoPath': photoPath,
        'photos': photos,
        'seatingPhotos': seatingPhotos,
        'menu': menu.map((m) => m.toMap()).toList(),
        'menuLink': menuLink,
        'facilities': facilities,
        'tables': tables.map((t) => t.toMap()).toList(),
      };

  factory FoodPlace.fromMap(String id, Map<String, dynamic> map) => FoodPlace(
        id: id,
        ownerName: map['ownerName'] ?? '',
        phone: map['phone'] ?? '',
        title: map['title'] ?? '',
        foodType: map['foodType'] ?? 'Home Dining',
        cuisine: map['cuisine'] ?? 'Spitian / Local',
        vegType: map['vegType'] ?? 'Both',
        description: map['description'] ?? '',
        pricePerPlate: (map['pricePerPlate'] ?? 0.0).toDouble(),
        timings: map['timings'] ?? '',
        homeDelivery: map['homeDelivery'] ?? false,
        deliveryRangeKm: (map['deliveryRangeKm'] ?? 0).toDouble(),
        cookOnRequest: map['cookOnRequest'] ?? false,
        offMarket: map['offMarket'] ?? false,
        lat: (map['lat'] ?? 0.0).toDouble(),
        lng: (map['lng'] ?? 0.0).toDouble(),
        rating: (map['rating'] ?? 5.0).toDouble(),
        safetyFlags: List<String>.from(map['safetyFlags'] ?? []),
        mockPhotoIndex: map['mockPhotoIndex'] ?? 0,
        photoPath: map['photoPath'] ?? '',
        photos: List<String>.from(map['photos'] ?? const []),
        seatingPhotos: List<String>.from(map['seatingPhotos'] ?? const []),
        menu: ((map['menu'] ?? const []) as List)
            .map((e) => MenuItem.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        menuLink: map['menuLink'] ?? '',
        facilities: List<String>.from(map['facilities'] ?? const []),
        tables: ((map['tables'] ?? const []) as List)
            .map((e) => TableUnit.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class FoodRequest {
  final String id;
  final String seekerName;
  final String phone;
  final String locationLooking;
  final int peopleCount;
  final String vegPref;
  final String cuisineWanted;
  final double budgetPerPlate;
  final String whenNeeded;
  final String note;
  final double lat;
  final double lng;
  final DateTime createdAt;

  FoodRequest({
    required this.id,
    required this.seekerName,
    required this.phone,
    required this.locationLooking,
    required this.peopleCount,
    required this.vegPref,
    required this.cuisineWanted,
    required this.budgetPerPlate,
    required this.whenNeeded,
    required this.note,
    required this.lat,
    required this.lng,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'seekerName': seekerName,
        'phone': phone,
        'locationLooking': locationLooking,
        'peopleCount': peopleCount,
        'vegPref': vegPref,
        'cuisineWanted': cuisineWanted,
        'budgetPerPlate': budgetPerPlate,
        'whenNeeded': whenNeeded,
        'note': note,
        'lat': lat,
        'lng': lng,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FoodRequest.fromMap(String id, Map<String, dynamic> map) => FoodRequest(
        id: id,
        seekerName: map['seekerName'] ?? '',
        phone: map['phone'] ?? '',
        locationLooking: map['locationLooking'] ?? '',
        peopleCount: map['peopleCount'] ?? 1,
        vegPref: map['vegPref'] ?? 'Both',
        cuisineWanted: map['cuisineWanted'] ?? '',
        budgetPerPlate: (map['budgetPerPlate'] ?? 0.0).toDouble(),
        whenNeeded: map['whenNeeded'] ?? '',
        note: map['note'] ?? '',
        lat: (map['lat'] ?? 0.0).toDouble(),
        lng: (map['lng'] ?? 0.0).toDouble(),
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      );
}

class FoodProvider extends ChangeNotifier {
  List<FoodPlace> _places = [];
  List<FoodRequest> _requests = [];
  final FirebaseService _firebaseService = FirebaseService();

  static final List<FoodPlace> _mockPlaces = [
    FoodPlace(
      id: 'f1',
      ownerName: 'Chering Dolkar',
      phone: '+91 98160 77881',
      title: "Dolkar's Spiti Kitchen (Home Dining)",
      foodType: 'Home Dining',
      cuisine: 'Spitian / Local',
      vegType: 'Veg',
      description: 'Authentic home-cooked Spitian thukpa, momos and chhang in a warm mud-house kitchen. No rooms — just great local food!',
      pricePerPlate: 180,
      timings: '8 AM – 9 PM',
      homeDelivery: true,
      cookOnRequest: true,
      offMarket: true,
      lat: 32.2290,
      lng: 78.0735,
      rating: 4.9,
      mockPhotoIndex: 0,
    ),
    FoodPlace(
      id: 'f2',
      ownerName: 'Tashi Norbu',
      phone: '+91 94591 22112',
      title: 'Himalayan Cafe & Bakery',
      foodType: 'Cafe',
      cuisine: 'Continental',
      vegType: 'Both',
      description: 'Wood-fired pizzas, apple pie, fresh coffee and a sunny rooftop overlooking Kaza.',
      pricePerPlate: 320,
      timings: '7 AM – 10 PM',
      homeDelivery: false,
      cookOnRequest: false,
      offMarket: false,
      lat: 32.2265,
      lng: 78.0712,
      rating: 4.6,
      mockPhotoIndex: 1,
    ),
    FoodPlace(
      id: 'f3',
      ownerName: 'Sonam Highway Dhaba',
      phone: '+91 98055 44667',
      title: 'Sonam Highway Dhaba',
      foodType: 'Dhaba',
      cuisine: 'North Indian',
      vegType: 'Both',
      description: 'Hot dal, roti, rice and chai right on the Kaza–Tabo road. Quick, cheap and filling for travellers.',
      pricePerPlate: 150,
      timings: '6 AM – 11 PM',
      homeDelivery: false,
      cookOnRequest: false,
      offMarket: false,
      lat: 32.0950,
      lng: 78.3850,
      rating: 4.3,
      mockPhotoIndex: 2,
    ),
    FoodPlace(
      id: 'f4',
      ownerName: 'Padma Lhamo',
      phone: '+91 98170 90901',
      title: 'Langza Momo Corner (Home)',
      foodType: 'Home Dining',
      cuisine: 'Tibetan / Momos',
      vegType: 'Veg',
      description: 'Family kitchen in Langza serving steaming veg momos and butter tea. Located off the main market, call before coming.',
      pricePerPlate: 120,
      timings: '9 AM – 8 PM',
      homeDelivery: true,
      cookOnRequest: true,
      offMarket: true,
      lat: 32.2700,
      lng: 78.0830,
      rating: 4.8,
      mockPhotoIndex: 3,
    ),
  ];

  static final List<FoodRequest> _mockRequests = [
    FoodRequest(
      id: 'fr1',
      seekerName: 'Ankit Saxena',
      phone: '+91 98765 11223',
      locationLooking: 'Kaza Center',
      peopleCount: 3,
      vegPref: 'Veg',
      cuisineWanted: 'Spitian / Local',
      budgetPerPlate: 200,
      whenNeeded: 'Tonight, 8 PM',
      note: 'Staying at a homestay with no kitchen. Need hot local dinner for 3, can pick up or delivery.',
      lat: 32.2276,
      lng: 78.0710,
      createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
    ),
    FoodRequest(
      id: 'fr2',
      seekerName: 'Sara Cohen',
      phone: '+91 99011 55667',
      locationLooking: 'Kibber Village',
      peopleCount: 2,
      vegPref: 'Both',
      cuisineWanted: 'Israeli',
      budgetPerPlate: 350,
      whenNeeded: 'Tomorrow lunch',
      note: 'Looking for shakshuka / hummus or any home cooked meal in Kibber.',
      lat: 32.2533,
      lng: 78.0125,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  FoodProvider() {
    _initFirestoreSync();
  }

  void _initFirestoreSync() {
    if (FirebaseService.isInitialized) {
      // Live data only — never auto-seed; in launch mode hide demo-id records.
      _firebaseService.streamFoodPlaces().listen((fresh) {
        _places = LocalStorageService.demoSeedingDisabled
            ? fresh.where((p) => p.id.contains('_')).toList()
            : fresh;
        notifyListeners();
      });
      _firebaseService.streamFoodRequests().listen((fresh) {
        _requests = LocalStorageService.demoSeedingDisabled
            ? fresh.where((r) => r.id.contains('_')).toList()
            : fresh;
        notifyListeners();
      });
    } else if (!LocalStorageService.demoSeedingDisabled) {
      // Offline demo fallback (only when explicitly enabled).
      _places = List.from(_mockPlaces);
      _requests = List.from(_mockRequests);
    }
  }

  List<FoodPlace> get places => _places;
  List<FoodRequest> get requests => _requests;

  void registerFoodPlace(FoodPlace place) async {
    if (FirebaseService.isInitialized) {
      await _firebaseService.addFoodPlace(place);
    } else {
      _places.insert(0, place);
      notifyListeners();
    }
    // Cook now gets pushes for new food-seeker broadcasts.
    PushService.subscribeForPhone(place.phone);
    PushService.subscribeProviders('food');
  }

  void postFoodRequest(FoodRequest req) async {
    if (FirebaseService.isInitialized) {
      await _firebaseService.addFoodRequest(req);
    } else {
      _requests.insert(0, req);
      notifyListeners();
    }
  }

  void moderateFoodPlace(String ownerName, {required bool flagAsBad}) {
    for (var i = 0; i < _places.length; i++) {
      final p = _places[i];
      if (p.ownerName == ownerName) {
        _places[i] = FoodPlace(
          id: p.id,
          ownerName: p.ownerName,
          phone: p.phone,
          title: p.title,
          foodType: p.foodType,
          cuisine: p.cuisine,
          vegType: p.vegType,
          description: p.description,
          pricePerPlate: p.pricePerPlate,
          timings: p.timings,
          homeDelivery: p.homeDelivery,
          deliveryRangeKm: p.deliveryRangeKm,
          cookOnRequest: p.cookOnRequest,
          offMarket: p.offMarket,
          lat: p.lat,
          lng: p.lng,
          rating: flagAsBad ? 2.5 : 5.0,
          safetyFlags: flagAsBad
              ? ["🛑 Flagged: Hygiene / overcharging complaints reported"]
              : [],
          mockPhotoIndex: p.mockPhotoIndex,
          photoPath: p.photoPath,
          photos: p.photos,
          seatingPhotos: p.seatingPhotos,
          menu: p.menu,
          menuLink: p.menuLink,
          facilities: p.facilities,
          tables: p.tables,
        );
      }
    }
    notifyListeners();
  }

  void deleteFoodPlace(String id) async {
    if (FirebaseService.isInitialized) {
      await _firebaseService.deleteFoodPlace(id);
    } else {
      _places.removeWhere((p) => p.id == id);
      notifyListeners();
    }
  }

  /// True if this owner already has a listing with the same type + name.
  bool isDuplicate(String phone, String foodType, String title) {
    final t = title.trim().toLowerCase();
    return _places.any((p) =>
        samePhone(p.phone, phone) && p.foodType == foodType && p.title.trim().toLowerCase() == t);
  }

  /// Update an existing food place (host editing their own listing).
  void updateFoodPlace(FoodPlace updated) async {
    if (FirebaseService.isInitialized) {
      await _firebaseService.addFoodPlace(updated); // same id → overwrite
    } else {
      final i = _places.indexWhere((p) => p.id == updated.id);
      if (i >= 0) {
        _places[i] = updated;
      } else {
        _places.insert(0, updated);
      }
      notifyListeners();
    }
  }
}
