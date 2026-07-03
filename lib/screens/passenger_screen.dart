import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/ride_model.dart';
import '../models/stay_model.dart';
import '../widgets/ride_card.dart';
import '../widgets/stay_card.dart';
import '../widgets/ad_carousel.dart';
import '../services/local_storage_service.dart';
import '../models/booked_trip_model.dart';
import '../services/proximity_service.dart';
import 'post_request_screen.dart';
import 'post_stay_request_screen.dart';

class PassengerScreen extends StatefulWidget {
  const PassengerScreen({super.key});

  @override
  State<PassengerScreen> createState() => _PassengerScreenState();
}

class _PassengerScreenState extends State<PassengerScreen> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  String _selectedType = "all";
  RangeValues _budgetRange = const RangeValues(500.0, 5000.0);
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
    // Ride proximity alerts belong only on the Ride finder — not on Stay/Food.
    if (rideProvider.appMode != AppMode.ride) return;
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

  /// Returns a hint if this ride matched as an "along the way" ride (passes
  /// near/in-between), rather than a direct from→to match. Null = direct/none.
  String? _rideMatchNote(Ride ride) {
    final from = _fromController.text.trim();
    final to = _toController.text.trim();
    if (from.isEmpty && to.isEmpty) return null;
    final directFrom = from.isEmpty || ride.from.toLowerCase().contains(from.toLowerCase());
    final directTo = to.isEmpty || ride.to.toLowerCase().contains(to.toLowerCase());
    if (directFrom && directTo) return null; // exact route match — no hint needed
    return "Passes near your route — reach the pickup point if a seat is free";
  }

  void _resetFilters() {
    _fromController.clear();
    _toController.clear();
    setState(() {
      _selectedType = "all";
      _budgetRange = const RangeValues(500.0, 5000.0);
    });
    _applyFilters();
  }

  /// Friendly empty state with an icon and a one-tap "Reset Filters" action.
  Widget _emptyState({required IconData icon, required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.8))),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text("Reset Filters"),
            ),
          ],
        ),
      ),
    );
  }

  void _focusOnLocation(double lat, double lng) {
    _mapController.move(LatLng(lat, lng), 13.5);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final rideProvider = Provider.of<RideProvider>(context);
    final stayProvider = Provider.of<StayProvider>(context);
    // Pin the viewer's own rides to the top so a freshly-broadcast ride is
    // always immediately visible (a pending server timestamp can otherwise
    // sort it to the bottom for a few seconds).
    final allActiveRides = rideProvider.rides;
    final activeRides = _userProfile.phone.isEmpty
        ? allActiveRides
        : [
            ...allActiveRides.where((r) => r.phone == _userProfile.phone),
            ...allActiveRides.where((r) => r.phone != _userProfile.phone),
          ];

    // Stays list based on budget and search keyword
    final activeStays = stayProvider.stays.where((stay) {
      final query = _fromController.text.toLowerCase();
      final matchesSearch = stay.title.toLowerCase().contains(query) ||
          stay.description.toLowerCase().contains(query) ||
          stay.hostName.toLowerCase().contains(query);
      final matchesBudget = stay.pricePerNight >= _budgetRange.start &&
          stay.pricePerNight <= _budgetRange.end;
      return matchesSearch && matchesBudget;
    }).toList();

    final size = MediaQuery.of(context).size;
    // Short screens (phone landscape) must also use the scrollable single-column
    // layout — the side-by-side desktop layout needs vertical room and overflows.
    final isMobile = size.width < 750 || size.height < 600;

    final scaffoldBg = isDarkMode ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final cardBgColor = isDarkMode ? const Color(0xFF111827) : Colors.white;
    final cardBorderColor = isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final activeTagColor = isDarkMode ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
    final alertBg = isDarkMode ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF);
    final alertText = isDarkMode ? const Color(0xFFC7D2FE) : const Color(0xFF3730A3);
    final alertSubtext = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    final mapOverlayBg = isDarkMode ? const Color(0xFF090D16).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85);
    final mapOverlayBorder = isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1);
    final mapOverlayText = isDarkMode ? Colors.white : Colors.black;

    // Center Kaza coordinates
    final initialCenter = LatLng(32.2276, 78.0710);

    // Map configuration
    final mapWidget = Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 11.5,
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
              markers: rideProvider.appMode == AppMode.ride
                  ? activeRides.map((ride) {
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
                          onTap: () => _focusOnLocation(ride.lat, ride.lng),
                          child: Container(
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
                            child: Text(emoji, style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                      );
                    }).toList()
                  : activeStays.map((stay) {
                      return Marker(
                        width: 45.0,
                        height: 45.0,
                        point: LatLng(stay.lat, stay.lng),
                        child: GestureDetector(
                          onTap: () => _focusOnLocation(stay.lat, stay.lng),
                          child: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0D9488).withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Text("🏡", style: TextStyle(fontSize: 18)),
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
                Icon(Icons.map, size: 14, color: rideProvider.appMode == AppMode.ride ? const Color(0xFF818CF8) : const Color(0xFF14B8A6)),
                const SizedBox(width: 6),
                Text(
                  rideProvider.appMode == AppMode.ride ? "Live Spiti Tracking Map" : "Spiti Homestay & Guest House Map",
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
        // Extra bottom padding so the "Broadcast Need" FAB never covers the
        // last card in the list.
        padding: isMobile
            ? const EdgeInsets.fromLTRB(16, 16, 16, 96)
            : const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMobile) ...[
              Text(
                rideProvider.appMode == AppMode.ride ? "RideShare to Spiti" : "FindStay Spiti",
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
                  if (rideProvider.appMode == AppMode.ride) ...[
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
                        // Swap From ↔ To (quick return-journey search)
                        IconButton(
                          tooltip: "Swap From/To",
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.swap_horiz, size: 20, color: Color(0xFF6366F1)),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            final tmp = _fromController.text;
                            _fromController.text = _toController.text;
                            _toController.text = tmp;
                            _applyFilters();
                          },
                        ),
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
                  ] else ...[
                    // Stay Filters
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _fromController, // reuse this controller for homestay location searches
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: "SEARCH VILLAGE / KEYWORD (e.g. Kaza, Kibber)",
                              labelStyle: const TextStyle(color: Colors.grey, fontSize: 9),
                              prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF0D9488)),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.15)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Color(0xFF0D9488)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Price/Night Range", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  Text("₹${_budgetRange.start.toInt()} - ₹${_budgetRange.end.toInt()}", style: const TextStyle(fontSize: 11, color: Color(0xFF0D9488), fontWeight: FontWeight.bold)),
                                ],
                              ),
                              RangeSlider(
                                values: _budgetRange,
                                min: 500.0,
                                max: 5000.0,
                                divisions: 18,
                                activeColor: const Color(0xFF0D9488),
                                inactiveColor: isDarkMode ? Colors.white10 : Colors.black12,
                                labels: RangeLabels(
                                  '₹${_budgetRange.start.toInt()}',
                                  '₹${_budgetRange.end.toInt()}',
                                ),
                                onChanged: (val) => setState(() => _budgetRange = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _resetFilters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: const Text("Reset", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    )
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Broadcast Need Banner
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => rideProvider.appMode == AppMode.ride
                        ? const PostRequestScreen()
                        : const PostStayRequestScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: rideProvider.appMode == AppMode.ride
                        ? [const Color(0xFF4F46E5), const Color(0xFF6366F1)]
                        : [const Color(0xFF0D9488), const Color(0xFF14B8A6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (rideProvider.appMode == AppMode.ride ? const Color(0xFF4F46E5) : const Color(0xFF0D9488)).withValues(alpha: 0.25),
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
                          Text(
                            rideProvider.appMode == AppMode.ride ? "Can't find a direct ride?" : "Looking for rooms in Spiti?",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rideProvider.appMode == AppMode.ride 
                                ? "📢 Broadcast your travel details so drivers can contact you!"
                                : "📢 Broadcast your stay requirements so local hosts can call you!",
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

            // Location permission card
            if (!_userProfile.locationPermissionGranted) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: alertBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (rideProvider.appMode == AppMode.ride ? const Color(0xFF6366F1) : const Color(0xFF0D9488)).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_searching, 
                      color: rideProvider.appMode == AppMode.ride ? const Color(0xFF6366F1) : const Color(0xFF0D9488), 
                      size: 24,
                    ),
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
                            rideProvider.appMode == AppMode.ride
                                ? "Get auto-alerts about nearby drivers & matching rides within 20 km!"
                                : "Get auto-alerts when matching stay requests or hosts are active within 20 km!",
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
                        backgroundColor: rideProvider.appMode == AppMode.ride ? const Color(0xFF6366F1) : const Color(0xFF0D9488),
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

            // Sponsored ads carousel — cross-promoted across modes
            AdCarousel(currentCategory: rideProvider.appMode == AppMode.ride ? 'ride' : 'stay'),

            // Active Rides / Stays Label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rideProvider.appMode == AppMode.ride ? "Available Rides" : "Available Homestays",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (rideProvider.appMode == AppMode.ride ? const Color(0xFF6366F1) : const Color(0xFF0D9488)).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (rideProvider.appMode == AppMode.ride ? const Color(0xFF6366F1) : const Color(0xFF0D9488)).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    rideProvider.appMode == AppMode.ride
                        ? "${activeRides.length} active"
                        : "${activeStays.length} active",
                    style: TextStyle(
                      fontSize: 11, 
                      color: rideProvider.appMode == AppMode.ride ? activeTagColor : const Color(0xFF10B981), 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),

            // Stays / Rides Grid / List
            useScrollableList
                ? (rideProvider.appMode == AppMode.ride
                    ? (activeRides.isEmpty
                        ? _emptyState(
                            icon: Icons.directions_car_outlined,
                            title: "No Rides Active",
                            subtitle: "Koi ride nahi mili — filters reset karke dekhein,\nya 'Broadcast Need' se drivers ko batayein.",
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: activeRides.length,
                            itemBuilder: (context, index) {
                              final ride = activeRides[index];
                              return RideCard(
                                ride: ride,
                                matchNote: _rideMatchNote(ride),
                                userLat: _userProfile.locationPermissionGranted ? _userProfile.currentLat : null,
                                userLng: _userProfile.locationPermissionGranted ? _userProfile.currentLng : null,
                              );
                            },
                          ))
                    : (activeStays.isEmpty
                        ? _emptyState(
                            icon: Icons.cottage_outlined,
                            title: "No Homestays Found",
                            subtitle: "Budget badha kar ya search badal kar dekhein.",
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: activeStays.length,
                            itemBuilder: (context, index) {
                              final stay = activeStays[index];
                              return StayCard(
                                stay: stay,
                                isDark: isDarkMode,
                                primaryText: Theme.of(context).colorScheme.onSurface,
                                subText: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                myPhone: _userProfile.phone,
                                userLat: _userProfile.locationPermissionGranted ? _userProfile.currentLat : null,
                                userLng: _userProfile.locationPermissionGranted ? _userProfile.currentLng : null,
                                onBook: () {
                                  HapticFeedback.mediumImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Calling host ${stay.hostName} at ${stay.phone}..."), backgroundColor: const Color(0xFF0D9488)),
                                  );
                                },
                                onTrack: () => _focusOnLocation(stay.lat, stay.lng),
                              );
                            },
                          )))
                : Expanded(
                    child: rideProvider.appMode == AppMode.ride
                        ? (activeRides.isEmpty
                            ? Center(
                                child: _emptyState(
                                  icon: Icons.directions_car_outlined,
                                  title: "No Rides Active",
                                  subtitle: "Koi ride nahi mili — filters reset karke dekhein,\nya 'Broadcast Need' se drivers ko batayein.",
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 90),
                                itemCount: activeRides.length,
                                itemBuilder: (context, index) {
                                  final ride = activeRides[index];
                                  return RideCard(
                                    ride: ride,
                                    matchNote: _rideMatchNote(ride),
                                    userLat: _userProfile.locationPermissionGranted ? _userProfile.currentLat : null,
                                    userLng: _userProfile.locationPermissionGranted ? _userProfile.currentLng : null,
                                  );
                                },
                              ))
                        : (activeStays.isEmpty
                            ? Center(
                                child: _emptyState(
                                  icon: Icons.cottage_outlined,
                                  title: "No Homestays Found",
                                  subtitle: "Budget badha kar ya search badal kar dekhein.",
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 90),
                                itemCount: activeStays.length,
                                itemBuilder: (context, index) {
                                  final stay = activeStays[index];
                                  return StayCard(
                                    stay: stay,
                                    isDark: isDarkMode,
                                    primaryText: Theme.of(context).colorScheme.onSurface,
                                    subText: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    myPhone: _userProfile.phone,
                                    userLat: _userProfile.locationPermissionGranted ? _userProfile.currentLat : null,
                                    userLng: _userProfile.locationPermissionGranted ? _userProfile.currentLng : null,
                                    onBook: () {
                                      HapticFeedback.mediumImpact();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text("Calling host ${stay.hostName} at ${stay.phone}..."), backgroundColor: const Color(0xFF0D9488)),
                                      );
                                    },
                                    onTrack: () => _focusOnLocation(stay.lat, stay.lng),
                                  );
                                },
                              )),
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
            MaterialPageRoute(
              builder: (_) => rideProvider.appMode == AppMode.ride
                  ? const PostRequestScreen()
                  : const PostStayRequestScreen(),
            ),
          );
        },
        backgroundColor: rideProvider.appMode == AppMode.ride ? const Color(0xFF6366F1) : const Color(0xFF0D9488),
        icon: const Icon(Icons.campaign, color: Colors.white),
        label: Text(
          rideProvider.appMode == AppMode.ride ? "Broadcast Need" : "FindStay Seeker",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

}
