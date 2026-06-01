import 'dart:io';
import 'package:flutter/material.dart';
import '../models/ride_model.dart';
import '../screens/live_tracking_screen.dart';
import '../screens/ride_detail_screen.dart';
import '../services/proximity_service.dart';
import '../services/verified_phones_service.dart';
import 'seat_selector.dart';
import 'review_sheet.dart';
import 'verified_badge.dart';

class RideCard extends StatelessWidget {
  final Ride ride;
  final double? userLat;
  final double? userLng;
  final String? matchNote; // e.g. "Passes near your route" for along-the-way matches

  const RideCard({
    super.key,
    required this.ride,
    this.userLat,
    this.userLng,
    this.matchNote,
  });

  String getVehicleIcon(VehicleType type) {
    switch (type) {
      case VehicleType.taxi:
        return "🚕";
      case VehicleType.tempo:
        return "🚐";
      case VehicleType.private:
        return "🚗";
      case VehicleType.suv:
        return "🚙";
      case VehicleType.bus:
        return "🚌";
      case VehicleType.bike:
        return "🏍️";
    }
  }

  String getVehicleName(VehicleType type) {
    switch (type) {
      case VehicleType.taxi:
        return "Taxi (Cab)";
      case VehicleType.tempo:
        return "Tempo Traveler";
      case VehicleType.private:
        return "Private Car";
      case VehicleType.suv:
        return "SUV / 4x4";
      case VehicleType.bus:
        return "Local Bus";
      case VehicleType.bike:
        return "Motorcycle / Bike";
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableSeats = ride.availableSeats;
    Color seatColor = Colors.green;
    if (availableSeats == 0) {
      seatColor = Colors.red;
    } else if (availableSeats <= 2) {
      seatColor = Colors.amber;
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDarkMode ? const Color(0xFF1E293B).withValues(alpha: 0.7) : Colors.white;
    final cardBorderColor = isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final cardShadowColor = isDarkMode ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05);

    final primaryTextColor = isDarkMode ? Colors.white : Colors.black;
    final secondaryTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final headerBgColor = isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03);
    final tagBgColor = isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RideDetailScreen(ride: ride)),
      ),
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cardBorderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: cardShadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Along the way" hint for corridor / nearby matches
          if (matchNote != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alt_route, size: 14, color: Color(0xFFB45309)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(matchNote!,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309))),
                  ),
                ],
              ),
            ),
          ],
          // Header Row
          Row(
            children: [
              (ride.photoPath.startsWith('http') || (ride.photoPath.isNotEmpty && File(ride.photoPath).existsSync()))
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ride.photoPath.startsWith('http')
                          ? Image.network(ride.photoPath, width: 50, height: 50, fit: BoxFit.cover)
                          : Image.file(
                              File(ride.photoPath),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                    )
                  : Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: headerBgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorderColor),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        getVehicleIcon(ride.vehicleType),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            ride.driverName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          ride.driverRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                        if (VerifiedPhonesService.isVerified(ride.phone)) ...[
                          const SizedBox(width: 6),
                          const VerifiedBadge(),
                        ],
                      ],
                    ),
                     const SizedBox(height: 4),
                     Wrap(
                       spacing: 8,
                       runSpacing: 4,
                       crossAxisAlignment: WrapCrossAlignment.center,
                       children: [
                         Text(
                           ride.plateNumber,
                           style: const TextStyle(
                             fontSize: 12,
                             color: Color(0xFF818CF8),
                             fontWeight: FontWeight.w700,
                           ),
                         ),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                           decoration: BoxDecoration(
                             color: tagBgColor,
                             borderRadius: BorderRadius.circular(4),
                           ),
                           child: Text(
                             getVehicleName(ride.vehicleType).toUpperCase(),
                             style: TextStyle(
                               fontSize: 9,
                               fontWeight: FontWeight.bold,
                               color: secondaryTextColor,
                             ),
                           ),
                         ),
                       ],
                     ),
                    if (userLat != null && userLng != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 12, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            "${ProximityService.calculateDistance(userLat!, userLng!, ride.lat, ride.lng).toStringAsFixed(1)} km away",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$availableSeats / ${ride.totalSeats}",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: seatColor,
                    ),
                  ),
                  Text(
                    "Seats Empty",
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (ride.driverRating < 4.0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gpp_bad, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ride.safetyFlags.isNotEmpty 
                          ? ride.safetyFlags.first 
                          : "⚠️ Warning: Low community safety rating!",
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Route Details
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF6366F1),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ride.from,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: primaryTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ride.to,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Date, Time, Phone, and Price Info
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(ride.date, style: TextStyle(fontSize: 11, color: secondaryTextColor)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(ride.time, style: TextStyle(fontSize: 11, color: secondaryTextColor)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(ride.phone, style: TextStyle(fontSize: 11, color: secondaryTextColor)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Reviews entry point (passengers review the driver)
          InkWell(
            onTap: () => showReviewsSheet(
              context,
              category: 'ride',
              subjectId: ride.phone,
              subjectName: ride.driverName,
              writeRole: 'Passenger',
              accent: const Color(0xFF6366F1),
            ),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.reviews_outlined, size: 14, color: Color(0xFF818CF8)),
                  const SizedBox(width: 6),
                  Text(
                    "Read & write driver reviews",
                    style: TextStyle(
                      color: const Color(0xFF818CF8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: const Color(0xFF818CF8).withValues(alpha: 0.4),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFF818CF8)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Actions
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(
                "₹${ride.price.toInt()} / seat",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LiveTrackingScreen(ride: ride),
                    ),
                  );
                },
                icon: const Icon(Icons.location_on, size: 14),
                label: const Text("Track Live", style: TextStyle(color: Color(0xFF818CF8))),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF818CF8),
                  backgroundColor: isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: cardBorderColor),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: availableSeats == 0
                    ? null
                    : () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => SeatSelectorModal(ride: ride),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  disabledBackgroundColor: isDarkMode ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Book Seats",
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    ), // closes Container
    ); // closes GestureDetector
  }
}
