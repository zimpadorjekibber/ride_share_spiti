import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/ride_model.dart';
import '../widgets/seat_selector.dart';

class RideDetailScreen extends StatelessWidget {
  final Ride ride;

  const RideDetailScreen({super.key, required this.ride});

  String getVehicleEmoji(VehicleType type) {
    switch (type) {
      case VehicleType.taxi: return '🚕';
      case VehicleType.tempo: return '🚐';
      case VehicleType.private: return '🚗';
      case VehicleType.suv: return '🚙';
      case VehicleType.bus: return '🚌';
      case VehicleType.bike: return '🏍️';
    }
  }

  String getVehicleName(VehicleType type) {
    switch (type) {
      case VehicleType.taxi: return 'Taxi (Cab)';
      case VehicleType.tempo: return 'Tempo Traveler';
      case VehicleType.private: return 'Private Car';
      case VehicleType.suv: return 'SUV / 4x4';
      case VehicleType.bus: return 'Local Bus';
      case VehicleType.bike: return 'Motorcycle';
    }
  }

  Color _seatColor(int available) {
    if (available == 0) return Colors.red;
    if (available <= 2) return Colors.amber;
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final driverPos = LatLng(ride.lat, ride.lng);
    final available = ride.availableSeats;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── Collapsible header with map ──
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF090D16) : Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: cardBg,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: primaryText, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: cardBg,
                  child: IconButton(
                    icon: const Icon(Icons.share_outlined,
                        color: Color(0xFF6366F1), size: 18),
                    onPressed: () {},
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: FlutterMap(
                options: MapOptions(
                  initialCenter: driverPos,
                  initialZoom: 11.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.rideshare.spiti',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: driverPos,
                        width: 48,
                        height: 48,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF6366F1),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            getVehicleEmoji(ride.vehicleType),
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 📸 Verified Gallery Carousel
                const Text(
                  "📸 Verified Vehicle & Driver Credentials",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildPhotoThumbnail("Exterior Photo", "https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&q=80&w=400", cardBg, border, primaryText),
                      const SizedBox(width: 10),
                      _buildPhotoThumbnail("Interior Photo", "https://images.unsplash.com/photo-1617814076367-b759c7d7e738?auto=format&fit=crop&q=80&w=400", cardBg, border, primaryText),
                      const SizedBox(width: 10),
                      _buildDocStatusCard("🪪 Driver License", "License Verified HP", Colors.green, cardBg, border, primaryText, subText),
                      const SizedBox(width: 10),
                      _buildDocStatusCard("📝 Vehicle RC Book", "RC Card Verified", Colors.green, cardBg, border, primaryText, subText),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // ── Header card ──
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: Text(getVehicleEmoji(ride.vehicleType),
                                style: const TextStyle(fontSize: 28)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ride.driverName,
                                  style: TextStyle(
                                    color: primaryText,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  ride.vehicleName,
                                  style: TextStyle(
                                      color: subText, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    ride.plateNumber,
                                    style: const TextStyle(
                                      color: Color(0xFF818CF8),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$available/${ride.totalSeats}',
                                style: TextStyle(
                                  color: _seatColor(available),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                ),
                              ),
                              Text('seats free',
                                  style:
                                      TextStyle(color: subText, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Route
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Column(
                              children: [
                                Icon(Icons.trip_origin,
                                    color: Color(0xFF6366F1), size: 16),
                                SizedBox(height: 2),
                                SizedBox(
                                  height: 20,
                                  child: VerticalDivider(
                                      color: Color(0xFF6366F1), width: 1),
                                ),
                                Icon(Icons.location_on,
                                    color: Color(0xFF10B981), size: 16),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ride.from,
                                      style: TextStyle(
                                          color: primaryText,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                  const SizedBox(height: 12),
                                  Text(ride.to,
                                      style: TextStyle(
                                          color: primaryText,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Info grid ──
                Row(
                  children: [
                    Expanded(
                        child: _infoCard(Icons.calendar_today_outlined,
                            'Date', ride.date, cardBg, primaryText, subText, border)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _infoCard(Icons.access_time, 'Departs',
                            ride.time, cardBg, primaryText, subText, border)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _infoCard(
                            Icons.directions_car,
                            'Type',
                            getVehicleName(ride.vehicleType).split(' ').first,
                            cardBg,
                            primaryText,
                            subText,
                            border)),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: _infoCard(Icons.phone_outlined, 'Driver Phone',
                          ride.phone, cardBg, primaryText, subText, border),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _infoCard(
                          Icons.currency_rupee,
                          'Per Seat',
                          '₹${ride.price.toInt()}',
                          cardBg,
                          primaryText,
                          const Color(0xFF10B981),
                          border,
                          valueColor: const Color(0xFF10B981)),
                    ),
                  ],
                ),

                if (ride.vehicleType == VehicleType.private) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_gas_station_rounded, color: Colors.orangeAccent, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "⛽ Fuel Sharing Advisory",
                                style: TextStyle(
                                  color: primaryText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "यह एक Private गाड़ी है। गाड़ी वाला fuel के लिए contribution ले भी सकता है और नहीं भी। इसलिए सीट बुक करने से पहले फोन करके बात कर लें!\n(Private car owners may or may not request a fuel contribution. Please call the driver to confirm details before booking!)",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // ── CTA ──
                if (available == 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      '❌ Fully Booked — No seats available',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => SeatSelectorModal(ride: ride),
                        );
                      },
                      icon: const Icon(Icons.event_seat, color: Colors.white),
                      label: Text(
                        'Choose Seats & Book — ₹${ride.price.toInt()}/seat',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value, Color cardBg,
      Color primaryText, Color? subText, Color border,
      {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF6366F1), size: 16),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(color: subText, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(String label, String url, Color cardBg, Color border, Color primaryText) {
    return Container(
      width: 115,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
        image: DecorationImage(
          image: NetworkImage(url),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.15), BlendMode.darken),
        ),
      ),
      padding: const EdgeInsets.all(8),
      alignment: Alignment.bottomLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildDocStatusCard(String label, String status, Color color, Color cardBg, Color border, Color primaryText, Color? subText) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: primaryText, fontSize: 10, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: const TextStyle(color: Colors.grey, fontSize: 8),
          ),
          const SizedBox(height: 2),
          Text(
            "VERIFIED & SECURE",
            style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
