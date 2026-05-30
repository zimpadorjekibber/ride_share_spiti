import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/ride_model.dart';

class LiveTrackingScreen extends StatefulWidget {
  final Ride ride;

  const LiveTrackingScreen({super.key, required this.ride});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF111827) : Colors.white;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];
    final driverPos = LatLng(widget.ride.lat, widget.ride.lng);

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen map ──
          FlutterMap(
            options: MapOptions(
              initialCenter: driverPos,
              initialZoom: 13.0,
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
                    width: 80,
                    height: 80,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Pulse ring
                            Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF6366F1)
                                      .withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                            // Inner dot
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF6366F1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x556366F1),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                getVehicleEmoji(widget.ride.vehicleType),
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Back Button ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircleAvatar(
                backgroundColor:
                    isDark ? const Color(0xFF1E293B) : Colors.white,
                child: IconButton(
                  icon: Icon(Icons.arrow_back,
                      color: isDark ? Colors.white : Colors.black87),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),

          // ── Live indicator badge ──
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (ctx, _) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white
                                .withValues(alpha: _pulseAnimation.value),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom driver info sheet ──
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 30,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          getVehicleEmoji(widget.ride.vehicleType),
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.ride.driverName,
                              style: TextStyle(
                                color: primaryText,
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.ride.vehicleName,
                              style: TextStyle(color: subText, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.ride.plateNumber,
                              style: const TextStyle(
                                color: Color(0xFF818CF8),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Route
                  Row(
                    children: [
                      const Icon(Icons.trip_origin,
                          color: Color(0xFF6366F1), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.ride.from,
                          style: TextStyle(
                              color: primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.arrow_forward,
                          color: Colors.grey, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.ride.to,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ETA row
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statItem(Icons.access_time, widget.ride.time,
                            'Departs', primaryText, subText),
                        Container(height: 30, width: 1, color: Colors.grey[600]),
                        _statItem(Icons.event_seat, '${widget.ride.availableSeats}',
                            'Seats Left', primaryText, subText),
                        Container(height: 30, width: 1, color: Colors.grey[600]),
                        _statItem(Icons.currency_rupee,
                            '${widget.ride.price.toInt()}', 'Per Seat',
                            primaryText, subText),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label,
      Color primaryText, Color? subText) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF6366F1), size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: primaryText, fontWeight: FontWeight.w700, fontSize: 14)),
        Text(label, style: TextStyle(color: subText, fontSize: 10)),
      ],
    );
  }
}
