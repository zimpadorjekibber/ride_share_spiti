import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/ride_model.dart';
import '../widgets/ride_card.dart';
import '../services/local_storage_service.dart';
import '../models/booked_trip_model.dart';
import '../services/proximity_service.dart';
import 'post_request_screen.dart';

class PassengerScreen extends StatefulWidget {
  const PassengerScreen({super.key});

  @override
  State<PassengerScreen> createState() => _PassengerScreenState();
}

class _PassengerScreenState extends State<PassengerScreen> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  String _selectedType = "all";
  final MapController _mapController = MapController();
  UserProfile _userProfile = UserProfile();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await LocalStorageService.getProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
      });
      if (profile.locationPermissionGranted) {
        _checkNearbyAlerts();
      }
    }
  }

  void _checkNearbyAlerts() {
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final rides = rideProvider.rides;
    for (var ride in rides) {
      final distance = ProximityService.calculateDistance(
        _userProfile.currentLat, 
        _userProfile.currentLng, 
        ride.lat, 
        ride.lng
      );
      if (distance < 20.0 && ride.driverRating >= 4.0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "🔔 Nearby Ride Available!\n${ride.driverName} is departing from nearby (${distance.toStringAsFixed(1)} km away)",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF1E293B),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        });
        break;
      }
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    Provider.of<RideProvider>(context, listen: false).setFilters(
      _fromController.text,
      _toController.text,
      _selectedType,
    );
  }

  void _resetFilters() {
    _fromController.clear();
    _toController.clear();
    setState(() {
      _selectedType = "all";
    });
    Provider.of<RideProvider>(context, listen: false).resetFilters();
  }

  void _focusOnLocation(double lat, double lng) {
    _mapController.move(LatLng(lat, lng), 12.0);
  }

  @override
  Widget build(BuildContext context) {
    final rideProvider = Provider.of<RideProvider>(context);
    final activeRides = rideProvider.rides;
    final centerLatLng = LatLng(32.2276, 78.0710);
    final isMobile = MediaQuery.of(context).size.width < 750;

    final isDarkMode = rideProvider.isDarkMode;
    final mapOverlayBg = isDarkMode ? const Color(0xFF090D16).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85);
    final mapOverlayBorder = isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1);
    final mapOverlayText = isDarkMode ? Colors.white : Colors.black;

    final cardBgColor = isDarkMode ? const Color(0xFF111827).withValues(alpha: 0.7) : Colors.white;
    final cardBorderColor = isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    final scaffoldBg = isDarkMode ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final alertBg = isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFEEF2F6);
    final alertText = isDarkMode ? Colors.white : Colors.black87;
    final alertSubtext = isDarkMode ? Colors.grey : Colors.grey[700];
    final activeTagColor = isDarkMode ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1);

    // The live tracking map layer widget
    Widget mapWidget = Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: centerLatLng,
            initialZoom: 8.0,
          ),
          children: [
            TileLayer(
              urlTemplate: isDarkMode
                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                  : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              retinaMode: RetinaMode.isHighDensity(context),
            ),
            MarkerLayer(
              markers: activeRides.map((ride) {
                String emoji = "🚕";
                Color markerColor = const Color(0xFF6366F1);
                if (ride.vehicleType == VehicleType.tempo) {
                  emoji = "🚐";
                  markerColor = const Color(0xFFA855F7);
                } else if (ride.vehicleType == VehicleType.private) {
                  emoji = "🚗";
                  markerColor = const Color(0xFF06B6D4);
                }

                return Marker(
                  width: 45.0,
                  height: 45.0,
                  point: LatLng(ride.lat, ride.lng),
                  child: GestureDetector(
                    onTap: () {
                      _focusOnLocation(ride.lat, ride.lng);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: markerColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: markerColor.withValues(alpha: 0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: mapOverlayBg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: mapOverlayBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.map, size: 14, color: Color(0xFF818CF8)),
                const SizedBox(width: 6),
                Text(
                  "Live Spiti Tracking Map",
                  style: TextStyle(color: mapOverlayText, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    // Built content helper to handle scrollable lists on mobile vs fixed lists on desktop
    Widget buildSearchListContent(bool useScrollableList) {
      return Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMobile) ...[
              Text(
                "RideShare to Spiti",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Search & Filters Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorderColor),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fromController,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: "FROM (KAHAN SE)",
                            labelStyle: const TextStyle(color: Colors.grey, fontSize: 9),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.15)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFF6366F1)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (_) => _applyFilters(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _toController,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: "TO (KAHAN TAK)",
                            labelStyle: const TextStyle(color: Colors.grey, fontSize: 9),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.15)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Color(0xFF6366F1)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          onChanged: (_) => _applyFilters(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedType,
                            isExpanded: true,
                            dropdownColor: Theme.of(context).colorScheme.surface,
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
                            decoration: InputDecoration(
                              labelText: "VEHICLE TYPE",
                              labelStyle: const TextStyle(color: Colors.grey, fontSize: 8),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.15)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                            items: const [
                              DropdownMenuItem(value: "all", child: Text("All Vehicles")),
                              DropdownMenuItem(value: "taxi", child: Text("🚕 Taxi")),
                              DropdownMenuItem(value: "tempo", child: Text("🚐 Tempo")),
                              DropdownMenuItem(value: "private", child: Text("🚗 Private")),
                              DropdownMenuItem(value: "suv", child: Text("🚙 SUV / 4x4")),
                              DropdownMenuItem(value: "bus", child: Text("🚌 Local Bus")),
                              DropdownMenuItem(value: "bike", child: Text("🏍️ Motorcycle")),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedType = value!;
                              });
                              _applyFilters();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _resetFilters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text("Reset", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Broadcast travel need banner
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PostRequestScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.campaign, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Can't find a direct ride?",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "📢 Broadcast your travel details so drivers can contact you!",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_userProfile.locationPermissionGranted) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: alertBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_searching, color: Color(0xFF6366F1), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Enable Live Location Alerts",
                            style: TextStyle(
                              color: alertText,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Get auto-alerts about nearby drivers & matching rides within 20 km!",
                            style: TextStyle(
                              color: alertSubtext,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        _userProfile.locationPermissionGranted = true;
                        await LocalStorageService.saveProfile(_userProfile);
                        setState(() {});
                        _checkNearbyAlerts();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text("📍 Location permission granted! Auto-alerts are active."),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Allow",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Local Ads Banner Carousel (FutureBuilder)
            FutureBuilder<List<Map<String, dynamic>>>(
              future: LocalStorageService.getAds(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final activeAds = snapshot.data!
                    .where((ad) => ad['isActive'] == true)
                    .toList();
                if (activeAds.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "🌟 Local Tourism Promotions",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "SPITI ADMIN APPROVED",
                            style: TextStyle(
                              fontSize: 8,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 135,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: activeAds.length,
                        itemBuilder: (context, index) {
                          final ad = activeAds[index];
                          return _buildAdCard(context, ad, isDarkMode);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
            // Active Rides Label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Available Rides",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    "${activeRides.length} active",
                    style: TextStyle(fontSize: 11, color: activeTagColor, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),
            // Rides Grid / List
            useScrollableList
                ? (activeRides.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: Text(
                            "No Rides Active.\nTry resetting filters!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: activeRides.length,
                        itemBuilder: (context, index) {
                          final ride = activeRides[index];
                          return RideCard(
                            ride: ride,
                            userLat: _userProfile.locationPermissionGranted ? _userProfile.currentLat : null,
                            userLng: _userProfile.locationPermissionGranted ? _userProfile.currentLng : null,
                          );
                        },
                      ))
                : Expanded(
                    child: activeRides.isEmpty
                        ? const Center(
                            child: Text(
                              "No Rides Active.\nTry resetting filters!",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: activeRides.length,
                            itemBuilder: (context, index) {
                              final ride = activeRides[index];
                              return RideCard(
                                ride: ride,
                                userLat: _userProfile.locationPermissionGranted ? _userProfile.currentLat : null,
                                userLng: _userProfile.locationPermissionGranted ? _userProfile.currentLng : null,
                              );
                            },
                          ),
                  ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: isMobile
          ? SingleChildScrollView(
              child: Column(
                children: [
                  // Top Map
                  SizedBox(
                    height: 240,
                    child: mapWidget,
                  ),
                  // Bottom List View
                  buildSearchListContent(true),
                ],
              ),
            )
          : Row(
              children: [
                Expanded(
                  flex: 11,
                  child: buildSearchListContent(false),
                ),
                Expanded(
                  flex: 9,
                  child: mapWidget,
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PostRequestScreen()),
          );
        },
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.campaign, color: Colors.white),
        label: const Text("Broadcast Need", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAdCard(BuildContext context, Map<String, dynamic> ad, bool isDarkMode) {
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width < 600 ? width - 48 : 360.0;

    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.network(
                ad['imageUrl'] ?? 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&q=80&w=400',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(Icons.image, color: Colors.white24, size: 40),
                  );
                },
              ),
            ),
            // Gradient Overlay for legibility
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                ),
              ),
            ),
            // Text & Button Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    ad['title'] ?? 'Promotion',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    ad['body'] ?? '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 10.5,
                      height: 1.2,
                      shadows: const [
                        Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Call to action pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone, color: Colors.white, size: 10),
                            const SizedBox(width: 4),
                            Text(
                              ad['link'] ?? 'Call Now',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Small indicator arrow
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
