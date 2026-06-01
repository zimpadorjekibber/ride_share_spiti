import 'dart:io';
import 'package:flutter/material.dart';
import '../models/stay_model.dart';
import '../screens/driver_screen.dart';
import '../services/proximity_service.dart';
import '../services/verified_phones_service.dart';
import 'review_sheet.dart';
import 'verified_badge.dart';

class StayCard extends StatelessWidget {
  final Stay stay;
  final bool isDark;
  final Color primaryText;
  final Color subText;
  final VoidCallback onBook;
  final VoidCallback onTrack;
  final String? myPhone; // if == stay.phone, show Edit
  final double? userLat;
  final double? userLng;

  const StayCard({
    super.key,
    required this.stay,
    required this.isDark,
    required this.primaryText,
    required this.subText,
    required this.onBook,
    required this.onTrack,
    this.myPhone,
    this.userLat,
    this.userLng,
  });

  @override
  Widget build(BuildContext context) {
    final border = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;

    final List<String> mockImages = [
      'https://images.unsplash.com/photo-1585545267156-f156f082e6d6?auto=format&fit=crop&w=400&q=80', // snowy village
      'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=400&q=80', // cozy hotel room
      'https://images.unsplash.com/photo-1566073771259-6a8506099945?auto=format&fit=crop&w=400&q=80', // mountain cottage
      'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?auto=format&fit=crop&w=400&q=80', // high altitude wooden room
    ];

    final imageUrl = mockImages[stay.mockPhotoIndex % mockImages.length];
    final isPhotoUrl = stay.photoPath.startsWith('http');
    final hasUploadedPhoto = isPhotoUrl || (stay.photoPath.isNotEmpty && File(stay.photoPath).existsSync());

    final hasWarnings = stay.safetyFlags.isNotEmpty || stay.rating < 4.0;
    final isMine = myPhone != null && myPhone!.isNotEmpty && myPhone == stay.phone;
    final full = stay.effectivelyFull;
    final freeCount = stay.roomUnits.isNotEmpty ? stay.vacantRooms : stay.roomsAvailable;

    return Opacity(
      opacity: full ? 0.55 : 1.0,
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasWarnings ? const Color(0xFFEF4444).withValues(alpha: 0.5) : border,
          width: hasWarnings ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image & Availability Badge
            Stack(
              children: [
                hasUploadedPhoto
                    ? (isPhotoUrl
                        ? Image.network(stay.photoPath, height: 140, width: double.infinity, fit: BoxFit.cover)
                        : Image.file(
                            File(stay.photoPath),
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ))
                    : Image.network(
                        imageUrl,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 140,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.cabin, color: Colors.white, size: 48),
                          );
                        },
                      ),
                // Cover gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
                // Top Badges Row
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: full ? Colors.redAccent : const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            Icon(full ? Icons.do_not_disturb_on : Icons.hotel, color: Colors.white, size: 10),
                            const SizedBox(width: 4),
                            Text(
                              full ? "FULLY BOOKED" : "$freeCount Rooms Free Today",
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (isMine)
                            Builder(
                              builder: (context) => GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DriverScreen(editStay: stay, onRegistrationSuccess: () {}),
                                  ),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const Row(children: [
                                    Icon(Icons.edit, color: Colors.white, size: 11),
                                    SizedBox(width: 3),
                                    Text('Edit', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ]),
                                ),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  stay.rating.toStringAsFixed(1),
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Bottom title on image
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stay.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 1),
                              blurRadius: 4,
                            )
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.account_circle, color: Colors.white70, size: 11),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              "Host: ${stay.hostName}",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (VerifiedPhonesService.isVerified(stay.phone)) ...[
                            const SizedBox(width: 6),
                            const VerifiedBadge(light: true),
                          ],
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              stay.propertyType.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Middle Description and Badmash warning
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stay.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: subText, fontSize: 11.5, height: 1.4),
                  ),
                  const SizedBox(height: 12),

                  if (userLat != null && userLng != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, size: 11, color: Color(0xFF10B981)),
                          const SizedBox(width: 4),
                          Text(
                            "${ProximityService.calculateDistance(userLat!, userLng!, stay.lat, stay.lng).toStringAsFixed(1)} km away",
                            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Bukhari/Geyser/Food Amenities Row
                  Row(
                    children: [
                      _amenityTag(Icons.fireplace, "BUKHARI", stay.hasBukhari),
                      const SizedBox(width: 6),
                      _amenityTag(Icons.water_drop, "GEYSER", stay.hasGeyser),
                      const SizedBox(width: 6),
                      _amenityTag(Icons.restaurant, "FOOD INCL.", stay.foodIncluded),
                    ],
                  ),

                  // Extra amenities (WiFi, Common Room, Local Dining, etc.)
                  if (stay.amenities.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: stay.amenities
                          .map((a) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF14B8A6).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.25)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_amenityIcon(a), size: 10, color: const Color(0xFF14B8A6)),
                                    const SizedBox(width: 4),
                                    Text(a, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF14B8A6))),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ],

                  // Amenity photos (Attached Bath, Balcony, View…) with labels
                  if (stay.amenityPhotos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text("AMENITY PHOTOS", style: TextStyle(color: subText, fontSize: 9, letterSpacing: 0.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: stay.amenityPhotos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final e = stay.amenityPhotos.entries.elementAt(i);
                          return _amenityPhotoThumb(e.key, e.value);
                        },
                      ),
                    ),
                  ],

                  // Render Badmash community warning
                  if (hasWarnings) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                "🛑 Flagged: Safety / Conduct Warn",
                                style: TextStyle(color: const Color(0xFFEF4444).withValues(alpha: 0.9), fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ...stay.safetyFlags.map((flag) => Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  flag,
                                  style: TextStyle(color: subText, fontSize: 9.5, height: 1.3),
                                ),
                              )),
                          if (stay.rating < 4.0 && stay.safetyFlags.isEmpty)
                            Text(
                              "Poor traveler ratings (⭐ ${stay.rating.toStringAsFixed(1)}) reported recently.",
                              style: TextStyle(color: subText, fontSize: 9.5),
                            ),
                        ],
                      ),
                    ),
                  ],
                  // Per-room layout (photo + price + vacant/occupied)
                  if (stay.roomUnits.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text("ROOMS", style: TextStyle(color: subText, fontSize: 9, letterSpacing: 0.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 104,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: stay.roomUnits.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => _roomThumb(stay.roomUnits[i]),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Reviews entry point (guests review the host/stay)
                  Builder(
                    builder: (context) => InkWell(
                      onTap: () => showReviewsSheet(
                        context,
                        category: 'stay',
                        subjectId: stay.id,
                        subjectName: stay.title,
                        writeRole: 'Guest',
                        accent: const Color(0xFF0D9488),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.reviews_outlined, size: 14, color: Color(0xFF0D9488)),
                            const SizedBox(width: 6),
                            Text(
                              "Read & write guest reviews",
                              style: TextStyle(
                                color: const Color(0xFF0D9488),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: const Color(0xFF0D9488).withValues(alpha: 0.4),
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF0D9488)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Bottom Price and CTA row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "PRICE PER NIGHT",
                            style: TextStyle(color: Colors.grey, fontSize: 8, letterSpacing: 0.5),
                          ),
                          Row(
                            children: [
                              const Text(
                                "₹",
                                style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                stay.pricePerNight.toInt().toString(),
                                style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 17),
                              ),
                              Text(
                                "/room",
                                style: TextStyle(color: subText, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // CTA Actions Row
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: onTrack,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0D9488),
                              side: const BorderSide(color: Color(0xFF0D9488)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.my_location, size: 12),
                                SizedBox(width: 4),
                                Text("Map", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: full ? null : onBook,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D9488),
                              disabledBackgroundColor: Colors.grey.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            child: Row(
                              children: [
                                Icon(full ? Icons.block : Icons.phone, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(full ? "Full" : "Contact",
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _roomThumb(RoomUnit r) {
    final isUrl = r.photoPath.startsWith('http');
    final hasPhoto = isUrl || (r.photoPath.isNotEmpty && File(r.photoPath).existsSync());
    final statusColor = r.occupied ? Colors.redAccent : const Color(0xFF10B981);
    return Opacity(
      opacity: r.occupied ? 0.55 : 1.0,
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: hasPhoto
                      ? (isUrl
                          ? Image.network(r.photoPath, width: 120, height: 60, fit: BoxFit.cover)
                          : Image.file(File(r.photoPath), width: 120, height: 60, fit: BoxFit.cover))
                      : Container(
                          width: 120, height: 60,
                          color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                          child: const Icon(Icons.bed, color: Color(0xFF0D9488), size: 22)),
                ),
                Positioned(
                  top: 4, left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
                    child: Text(r.occupied ? "BOOKED" : "FREE",
                        style: const TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: primaryText, fontSize: 11, height: 1.15, fontWeight: FontWeight.w700)),
            Text("₹${r.price.toInt()}/night",
                style: const TextStyle(color: Color(0xFF0D9488), fontSize: 10.5, height: 1.15, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _amenityPhotoThumb(String label, String path) {
    final isUrl = path.startsWith('http');
    final hasLocal = !isUrl && path.isNotEmpty && File(path).existsSync();
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isUrl
                ? Image.network(path, width: 120, height: 64, fit: BoxFit.cover)
                : hasLocal
                    ? Image.file(File(path), width: 120, height: 64, fit: BoxFit.cover)
                    : Container(
                        width: 120, height: 64,
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                        child: const Icon(Icons.photo, color: Color(0xFF14B8A6), size: 22)),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(_amenityIcon(label), size: 11, color: const Color(0xFF14B8A6)),
              const SizedBox(width: 3),
              Expanded(
                child: Text(label,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: primaryText, fontSize: 10, height: 1.1, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _amenityIcon(String name) {
    switch (name) {
      case 'WiFi':
        return Icons.wifi;
      case 'Common Room':
        return Icons.weekend;
      case 'Local Dining':
        return Icons.dinner_dining;
      case 'Hot Water':
        return Icons.hot_tub;
      case 'Parking':
        return Icons.local_parking;
      case 'Bonfire':
        return Icons.local_fire_department;
      case 'Laundry':
        return Icons.local_laundry_service;
      case 'Pet Friendly':
        return Icons.pets;
      case 'Room Heater':
        return Icons.heat_pump;
      case 'Attached Bath':
        return Icons.bathtub;
      case 'Balcony':
        return Icons.balcony;
      case 'Mountain View':
        return Icons.landscape;
      case 'Power Backup':
        return Icons.bolt;
      default:
        return Icons.check_circle_outline;
    }
  }

  Widget _amenityTag(IconData icon, String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF0D9488).withValues(alpha: 0.1)
            : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: active
              ? const Color(0xFF0D9488).withValues(alpha: 0.25)
              : (isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 11,
            color: active ? const Color(0xFF14B8A6) : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: active ? const Color(0xFF14B8A6) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
