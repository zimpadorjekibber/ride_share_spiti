import 'dart:convert';

class BookedTrip {
  final String bookingRef;
  final String rideId;
  final String driverName;
  final String driverPhone;
  final String vehicleName;
  final String plateNumber;
  final String from;
  final String to;
  final String date;
  final String time;
  final List<String> seatIds;
  final double totalPaid;
  final String status;
  final DateTime bookedAt;
  final double? ratingGiven;
  final List<String> safetyIssuesFlagged;
  final bool isReviewed;

  BookedTrip({
    required this.bookingRef,
    required this.rideId,
    required this.driverName,
    required this.driverPhone,
    required this.vehicleName,
    required this.plateNumber,
    required this.from,
    required this.to,
    required this.date,
    required this.time,
    required this.seatIds,
    required this.totalPaid,
    required this.status,
    required this.bookedAt,
    this.ratingGiven,
    this.safetyIssuesFlagged = const [],
    this.isReviewed = false,
  });

  Map<String, dynamic> toJson() => {
        'bookingRef': bookingRef,
        'rideId': rideId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'vehicleName': vehicleName,
        'plateNumber': plateNumber,
        'from': from,
        'to': to,
        'date': date,
        'time': time,
        'seatIds': seatIds,
        'totalPaid': totalPaid,
        'status': status,
        'bookedAt': bookedAt.toIso8601String(),
        'ratingGiven': ratingGiven,
        'safetyIssuesFlagged': safetyIssuesFlagged,
        'isReviewed': isReviewed,
      };

  factory BookedTrip.fromJson(Map<String, dynamic> json) => BookedTrip(
        bookingRef: json['bookingRef'],
        rideId: json['rideId'],
        driverName: json['driverName'],
        driverPhone: json['driverPhone'],
        vehicleName: json['vehicleName'],
        plateNumber: json['plateNumber'],
        from: json['from'],
        to: json['to'],
        date: json['date'],
        time: json['time'],
        seatIds: List<String>.from(json['seatIds']),
        totalPaid: (json['totalPaid'] as num).toDouble(),
        status: json['status'],
        bookedAt: DateTime.parse(json['bookedAt']),
        ratingGiven: json['ratingGiven'] != null ? (json['ratingGiven'] as num).toDouble() : null,
        safetyIssuesFlagged: json['safetyIssuesFlagged'] != null
            ? List<String>.from(json['safetyIssuesFlagged'])
            : const [],
        isReviewed: json['isReviewed'] ?? false,
      );

  String toJsonString() => jsonEncode(toJson());
}

class UserProfile {
  String name;
  String phone;
  String email;
  int tripsCount;
  double totalSpent;
  double rating;
  bool locationPermissionGranted;
  double currentLat;
  double currentLng;
  bool isRegistered;
  bool phoneVerified;
  bool emailVerified;
  bool isAdmin;
  String avatarPath; // profile photo (URL or local path)

  UserProfile({
    this.name = '',
    this.phone = '',
    this.email = '',
    this.tripsCount = 0,
    this.totalSpent = 0.0,
    this.rating = 5.0,
    this.locationPermissionGranted = false,
    this.currentLat = 32.2276,
    this.currentLng = 78.0710,
    this.isRegistered = false,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.isAdmin = false,
    this.avatarPath = '',
  });

  /// A user counts as verified once they have completed OTP for phone or email.
  bool get isVerified => isRegistered && (phoneVerified || emailVerified);

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'email': email,
        'tripsCount': tripsCount,
        'totalSpent': totalSpent,
        'rating': rating,
        'locationPermissionGranted': locationPermissionGranted,
        'currentLat': currentLat,
        'currentLng': currentLng,
        'isRegistered': isRegistered,
        'phoneVerified': phoneVerified,
        'emailVerified': emailVerified,
        'isAdmin': isAdmin,
        'avatarPath': avatarPath,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] ?? '',
        phone: json['phone'] ?? '',
        email: json['email'] ?? '',
        tripsCount: json['tripsCount'] ?? 0,
        totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
        rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
        locationPermissionGranted: json['locationPermissionGranted'] ?? false,
        currentLat: (json['currentLat'] as num?)?.toDouble() ?? 32.2276,
        currentLng: (json['currentLng'] as num?)?.toDouble() ?? 78.0710,
        isRegistered: json['isRegistered'] ?? false,
        phoneVerified: json['phoneVerified'] ?? false,
        emailVerified: json['emailVerified'] ?? false,
        isAdmin: json['isAdmin'] ?? false,
        avatarPath: json['avatarPath'] ?? '',
      );
}
