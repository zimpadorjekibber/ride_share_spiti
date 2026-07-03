import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../models/ride_model.dart';
import '../models/stay_model.dart';
import '../models/passenger_request_model.dart';
import '../services/local_storage_service.dart';
import '../services/storage_service.dart';
import '../models/booked_trip_model.dart';
import 'passenger_requests_screen.dart';
import 'stay_requests_screen.dart';
import 'manage_rooms_screen.dart';
import '../widgets/photo_picker_field.dart';
import '../widgets/place_autocomplete_field.dart';

class DriverScreen extends StatefulWidget {
  final VoidCallback onRegistrationSuccess;
  final Stay? editStay; // when set → edit an existing homestay listing
  final Ride? editRide; // when set → edit an existing ride
  final bool registerNew; // when true → show ONLY the registration form (opened via the + button)

  const DriverScreen({super.key, required this.onRegistrationSuccess, this.editStay, this.editRide, this.registerNew = false});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleNameController = TextEditingController(); // Reused as stayTitle
  final _plateController = TextEditingController();       // Reused as stayDescription
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _priceController = TextEditingController();       // Reused as pricePerNight
  final _capacityController = TextEditingController(text: "4 Seats"); // Reused as roomsAvailable

  VehicleType _selectedType = VehicleType.taxi;
  int _totalSeats = 4; // Reused as roomsAvailableCount
  LatLng? _selectedLocation;
  final MapController _mapController = MapController();
  UserProfile _userProfile = UserProfile();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);

  /// Picker theme that follows the app's current light/dark mode (previously
  /// it forced a dark palette, which looked broken in light mode).
  Widget _pickerTheme(BuildContext ctx, Widget? child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: const Color(0xFF6366F1),
              ),
        ),
        child: child!,
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: _pickerTheme,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: _pickerTheme,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  // Guards against double-submit: rapid taps during the slow photo upload
  // were creating multiple identical listings.
  bool _registering = false;

  // Verification uploads (reused as Amenities checks in stay mode)
  bool _exteriorUploaded = false; // Bukhari
  bool _interiorUploaded = false; // Geyser
  bool _licenseUploaded = false;  // Food
  bool _rcUploaded = false;       // Photos

  bool _loadingExterior = false;
  bool _loadingInterior = false;
  bool _loadingLicense = false;
  bool _loadingRc = false;

  // Stay-host extras
  final Set<String> _stayAmenities = {};
  final Map<String, String> _amenityPhotoPaths = {}; // amenity → local path / URL
  String _stayPropertyType = 'Homestay';
  String _stayPhotoPath = '';
  String _vehiclePhotoPath = '';
  String _licensePath = '';
  String _rcPath = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    final s = widget.editStay;
    if (s != null) {
      _vehicleNameController.text = s.title;
      _plateController.text = s.description;
      _priceController.text = s.pricePerNight.toInt().toString();
      _totalSeats = s.roomsAvailable;
      _exteriorUploaded = s.hasBukhari;
      _interiorUploaded = s.hasGeyser;
      _licenseUploaded = s.foodIncluded;
      _stayPropertyType = s.propertyType;
      _stayAmenities.addAll(s.amenities);
      _amenityPhotoPaths.addAll(s.amenityPhotos);
      _stayPhotoPath = s.photoPath;
      _selectedLocation = LatLng(s.lat, s.lng);
    }

    final r = widget.editRide;
    if (r != null) {
      _selectedType = r.vehicleType;
      _vehicleNameController.text = r.vehicleName;
      _plateController.text = r.plateNumber;
      _totalSeats = r.totalSeats;
      _capacityController.text = "${r.totalSeats} Seats";
      _fromController.text = r.from;
      _toController.text = r.to;
      _priceController.text = r.price.toInt().toString();
      _vehiclePhotoPath = r.photoPath;
      _selectedLocation = LatLng(r.lat, r.lng);
    }
  }

  /// Pre-fill the vehicle details from the driver's most recent ride so that
  /// broadcasting another ride is quick (they only change route / time / price).
  void _prefillVehicleFromLastRide(RideProvider rideProvider) {
    if (widget.editRide != null || _vehicleNameController.text.isNotEmpty) return;
    final mine = rideProvider.allRides.where((r) => r.phone == _userProfile.phone).toList();
    if (mine.isEmpty) return;
    final last = mine.first;
    _selectedType = last.vehicleType;
    _vehicleNameController.text = last.vehicleName;
    _plateController.text = last.plateNumber;
    _totalSeats = last.totalSeats;
    _capacityController.text = "${last.totalSeats} Seats";
    if (last.photoPath.isNotEmpty) _vehiclePhotoPath = last.photoPath;
  }

  Future<void> _loadProfile() async {
    final profile = await LocalStorageService.getProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
        if (profile.isRegistered) {
          _nameController.text = profile.name;
          _phoneController.text = profile.phone;
        }
      });
      // Easy re-broadcast: when adding a new ride, pre-fill the vehicle details
      // from the driver's last ride so they only set route / time / price.
      if (widget.registerNew && widget.editRide == null && widget.editStay == null) {
        final rideProvider = Provider.of<RideProvider>(context, listen: false);
        if (rideProvider.appMode == AppMode.ride) {
          setState(() => _prefillVehicleFromLastRide(rideProvider));
        }
      }
    }
  }

  Widget _buildUploadSection(bool isStayMode) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _uploadButton(
                isStayMode ? "Bukhari Heater" : "Exterior Photo",
                _exteriorUploaded,
                _loadingExterior,
                () => _simulateUpload('ext', isStayMode),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _uploadButton(
                isStayMode ? "Hot Geyser" : "Interior Photo",
                _interiorUploaded,
                _loadingInterior,
                () => _simulateUpload('int', isStayMode),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _uploadButton(
                isStayMode ? "Local Food Incl." : "Driving License",
                _licenseUploaded,
                _loadingLicense,
                () => _simulateUpload('lic', isStayMode),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _uploadButton(
                isStayMode ? "Homestay Photos" : "RC Registration",
                _rcUploaded,
                _loadingRc,
                () => _simulateUpload('rc', isStayMode),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _uploadButton(String label, bool isUploaded, bool isLoading, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final activeColor = rideProvider.appMode == AppMode.ride ? const Color(0xFF6366F1) : const Color(0xFF0D9488);
    final successColor = const Color(0xFF10B981);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isUploaded 
                ? successColor 
                : (isLoading ? activeColor : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1))),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isUploaded ? Icons.check_circle : (isLoading ? Icons.hourglass_top : Icons.add_circle_outline),
              color: isUploaded ? successColor : (isLoading ? activeColor : Colors.grey),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    isUploaded 
                        ? "Active / Attached" 
                        : (isLoading ? "Adding..." : "Tap to Toggle"),
                    style: TextStyle(
                      fontSize: 8.5,
                      color: isUploaded ? successColor : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _simulateUpload(String type, bool isStayMode) {
    setState(() {
      if (type == 'ext') _loadingExterior = true;
      if (type == 'int') _loadingInterior = true;
      if (type == 'lic') _loadingLicense = true;
      if (type == 'rc') _loadingRc = true;
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          if (type == 'ext') {
            _loadingExterior = false;
            _exteriorUploaded = !_exteriorUploaded;
          }
          if (type == 'int') {
            _loadingInterior = false;
            _interiorUploaded = !_interiorUploaded;
          }
          if (type == 'lic') {
            _loadingLicense = false;
            _licenseUploaded = !_licenseUploaded;
          }
          if (type == 'rc') {
            _loadingRc = false;
            _rcUploaded = !_rcUploaded;
          }
        });
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isStayMode 
                ? "🏨 Amenity state updated successfully!"
                : "✅ Document uploaded and verified successfully!"),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleNameController.dispose();
    _plateController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  void _adjustCapacity(VehicleType type) {
    setState(() {
      _selectedType = type;
      switch (type) {
        case VehicleType.tempo:
          _totalSeats = 12;
          break;
        case VehicleType.bus:
          _totalSeats = 30;
          break;
        case VehicleType.suv:
          _totalSeats = 6;
          break;
        case VehicleType.bike:
          _totalSeats = 1;
          break;
        default:
          _totalSeats = 4;
      }
      _capacityController.text = "$_totalSeats Seats";
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HOST DASHBOARD — My Homestays with a live room layout under each property.
  // The + button (FAB) opens the registration form for a new property.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStayDashboard(BuildContext context, StayProvider stayProvider, Color themeColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];
    const teal = Color(0xFF0D9488);

    final mine = stayProvider.stays.where((s) => s.phone.isNotEmpty && s.phone == _userProfile.phone).toList();
    final reqCount = stayProvider.stayRequests.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 96), // extra bottom pad for FAB
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tourists looking for rooms
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StayRequestsScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0x2610B981), shape: BoxShape.circle),
                    child: const Icon(Icons.houseboat, color: Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Tourists Looking for Rooms",
                            style: TextStyle(color: primaryText, fontSize: 12.5, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text("$reqCount active broadcasted requests waiting",
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Color(0xFF10B981), size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Broadcasting-as chip
          if (_userProfile.isRegistered)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: themeColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified, color: themeColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("Broadcasting as: ${_userProfile.name} (${_userProfile.phone})",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryText)),
                  ),
                ],
              ),
            ),

          // Header
          Row(
            children: [
              const Icon(Icons.home_work, color: teal, size: 20),
              const SizedBox(width: 6),
              Text("My Homestays", style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 4),
          Text("Tap a room box to mark it free / occupied",
              style: TextStyle(color: subText, fontSize: 11)),
          const SizedBox(height: 14),

          if (mine.isEmpty)
            _buildStayEmptyState(context, themeColor, primaryText, subText)
          else
            ...mine.map((s) => _stayDashboardCard(context, stayProvider, s, isDark, primaryText, subText)),
        ],
      ),
    );
  }

  Widget _buildStayEmptyState(BuildContext context, Color themeColor, Color primaryText, Color? subText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.home_work_outlined, size: 54, color: themeColor.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Text("No properties yet",
              style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            "Register your homestay, guest house, hotel, mud house or tent — then set up each room with its own photo, price & status.",
            textAlign: TextAlign.center,
            style: TextStyle(color: subText, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => DriverScreen(
                  registerNew: true,
                  onRegistrationSuccess: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("Register your first property", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stayDashboardCard(BuildContext context, StayProvider stayProvider, Stay s, bool isDark, Color primaryText, Color? subText) {
    const teal = Color(0xFF0D9488);
    final available = !s.effectivelyFull;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: teal.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: icon + title/meta + actions
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: teal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.cabin, color: teal, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text("${s.propertyType} · ₹${s.pricePerNight.toInt()}/night · ⭐ ${s.rating.toStringAsFixed(1)}",
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: subText, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DriverScreen(editStay: s, onRegistrationSuccess: () {})),
                ),
                icon: const Icon(Icons.edit, color: teal, size: 19),
              ),
              IconButton(
                tooltip: 'Promote (Ad)',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () => _promoteStay(context, s),
                icon: const Icon(Icons.campaign, color: Color(0xFF10B981), size: 20),
              ),
              IconButton(
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () => _confirmDeleteStay(context, stayProvider, s),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Overall availability quick toggle (used when no per-room layout)
          GestureDetector(
            onTap: () => stayProvider.setStayFull(s, available),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (available ? const Color(0xFF10B981) : Colors.redAccent).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (available ? const Color(0xFF10B981) : Colors.redAccent).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(available ? Icons.check_circle : Icons.do_not_disturb_on,
                      size: 13, color: available ? const Color(0xFF10B981) : Colors.redAccent),
                  const SizedBox(width: 5),
                  Text(available ? "AVAILABLE · tap to mark full" : "FULL · tap to reopen",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                          color: available ? const Color(0xFF10B981) : Colors.redAccent)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Live room layout
          _roomLayoutGrid(context, stayProvider, s, primaryText, subText),
        ],
      ),
    );
  }

  /// Live, tappable room layout shown directly under each property.
  Widget _roomLayoutGrid(BuildContext context, StayProvider stayProvider, Stay s, Color primaryText, Color? subText) {
    const teal = Color(0xFF0D9488);

    if (s.roomUnits.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ManageRoomsScreen(stay: s)),
          ),
          icon: const Icon(Icons.grid_view_rounded, color: teal, size: 18),
          label: const Text("Set up room layout", style: TextStyle(color: teal, fontWeight: FontWeight.w800)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: teal)),
        ),
      );
    }

    final vacant = s.vacantRooms;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: teal.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_view_rounded, color: teal, size: 16),
              const SizedBox(width: 6),
              Text("Room Layout", style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 13)),
              const Spacer(),
              Text("$vacant free / ${s.roomUnits.length}",
                  style: TextStyle(color: vacant == 0 ? Colors.redAccent : const Color(0xFF10B981),
                      fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManageRoomsScreen(stay: s)),
                ),
                child: const Text("Manage »",
                    style: TextStyle(color: teal, fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(s.roomUnits.length, (i) {
              final r = s.roomUnits[i];
              final c = r.occupied ? Colors.redAccent : const Color(0xFF10B981);
              return GestureDetector(
                onTap: () => _toggleRoomOccupied(stayProvider, s, i),
                child: Container(
                  width: 72,
                  height: 62,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c, width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(r.occupied ? Icons.bed : Icons.bed_outlined, color: c, size: 18),
                      const SizedBox(height: 3),
                      Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c, fontSize: 8.5, height: 1.1, fontWeight: FontWeight.bold)),
                      Text(r.occupied ? "BUSY" : "FREE",
                          style: TextStyle(color: c, fontSize: 7.5, height: 1.1, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text("🟢 free · 🔴 occupied — tap a room to change",
              style: TextStyle(color: subText, fontSize: 10.5)),
        ],
      ),
    );
  }

  Future<void> _pickAmenityPhoto(String amenity) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (x == null) return;
    setState(() => _amenityPhotoPaths[amenity] = x.path);
  }

  Widget _amenityPhotoCard(String amenity, Color themeColor) {
    final path = _amenityPhotoPaths[amenity] ?? '';
    final isUrl = path.startsWith('http');
    final hasLocal = path.isNotEmpty && !isUrl && File(path).existsSync();
    final subText = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return GestureDetector(
      onTap: () => _pickAmenityPhoto(amenity),
      child: SizedBox(
        width: 100,
        child: Column(
          children: [
            Container(
              width: 100,
              height: 76,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: themeColor.withValues(alpha: 0.3)),
              ),
              child: isUrl
                  ? Image.network(path, fit: BoxFit.cover)
                  : hasLocal
                      ? Image.file(File(path), fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, color: themeColor, size: 20),
                            const SizedBox(height: 3),
                            Text('Add', style: TextStyle(color: themeColor, fontSize: 10, fontWeight: FontWeight.w800)),
                          ],
                        ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(amenity,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subText, fontSize: 9.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  /// Flip one room's occupied flag and keep the listing's availability in sync.
  void _toggleRoomOccupied(StayProvider provider, Stay s, int index) {
    final units = List<RoomUnit>.from(s.roomUnits);
    final r = units[index];
    units[index] = RoomUnit(
      id: r.id, name: r.name, price: r.price, photoPath: r.photoPath, occupied: !r.occupied,
    );
    final allOccupied = units.isNotEmpty && units.every((u) => u.occupied);
    provider.updateStay(s.copyWith(
      roomsAvailable: units.where((u) => !u.occupied).length,
      isFull: allOccupied,
      roomUnits: units,
    ));
  }

  Future<void> _promoteStay(BuildContext context, Stay s) async {
    final messenger = ScaffoldMessenger.of(context);
    final adId = 'sponsor_${s.id}';

    // If an ad is already live for this listing → offer to stop it.
    if (await LocalStorageService.hasAd(adId)) {
      if (!context.mounted) return;
      final stop = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('📣 Ad is live'),
          content: Text('"${s.title}" is currently advertised across Spiti Setu. Stop this ad?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep running')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Stop Ad', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (stop == true) {
        await LocalStorageService.removeAd(adId);
        messenger.showSnackBar(const SnackBar(content: Text('🛑 Ad stopped & removed.'), backgroundColor: Colors.redAccent));
      }
      return;
    }

    if (!context.mounted) return;
    final pay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📣 Promote across Spiti Setu'),
        content: Text(
          'Feature "${s.title}" as a sponsored ad on the Ride, Stay & Food screens for all travellers.\n\n₹199 / week.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.payments, size: 16, color: Colors.white),
            label: const Text('Pay ₹199', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          ),
        ],
      ),
    );
    if (pay != true) return;

    final photo = s.photoPath.startsWith('http')
        ? s.photoPath
        : 'https://images.unsplash.com/photo-1585545267156-f156f082e6d6?auto=format&fit=crop&q=80&w=400';
    await LocalStorageService.addAd({
      'id': 'sponsor_${s.id}',
      'title': '🏡 ${s.title}',
      'body': '${s.propertyType} · ${s.roomsAvailable} rooms · ₹${s.pricePerNight.toInt()}/night',
      'imageUrl': photo,
      'isActive': true,
      'link': s.phone,
      'category': 'stay',
      'sponsor': s.phone,
      'paid': true,
    });
    messenger.showSnackBar(
      const SnackBar(
        content: Text('🎉 Payment received — your homestay ad is now live across Spiti Setu!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  Future<void> _confirmDeleteStay(BuildContext context, StayProvider stayProvider, Stay s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete homestay?'),
        content: Text('Remove "${s.title}" permanently? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      stayProvider.deleteStay(s.id);
      LocalStorageService.removeAd('sponsor_${s.id}'); // clean up its ad too
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RIDE DASHBOARD — My Rides with a live, tappable seat map under each ride.
  // The + button (FAB) opens the (pre-filled) broadcast form.
  // ─────────────────────────────────────────────────────────────────────────
  static const Color _indigo = Color(0xFF6366F1);

  IconData _vehicleIcon(VehicleType t) {
    switch (t) {
      case VehicleType.bike:
        return Icons.two_wheeler;
      case VehicleType.bus:
        return Icons.directions_bus;
      case VehicleType.tempo:
        return Icons.airport_shuttle;
      case VehicleType.suv:
      case VehicleType.private:
      case VehicleType.taxi:
        return Icons.directions_car;
    }
  }

  Widget _buildRideDashboard(BuildContext context, RideProvider rideProvider, Color themeColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];

    // Use the unfiltered list so search filters don't hide the driver's rides.
    final mine = rideProvider.allRides.where((r) => r.phone.isNotEmpty && r.phone == _userProfile.phone).toList();
    final reqCount = Provider.of<PassengerRequestProvider>(context).requests.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Passengers looking for rides
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerRequestsScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0x2610B981), shape: BoxShape.circle),
                    child: const Icon(Icons.people_alt, color: Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Passengers Looking for Rides",
                            style: TextStyle(color: primaryText, fontSize: 12.5, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text("$reqCount active broadcasted requests waiting",
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Color(0xFF10B981), size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          if (_userProfile.isRegistered)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: themeColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified, color: themeColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("Driving as: ${_userProfile.name} (${_userProfile.phone})",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryText)),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              const Icon(Icons.directions_car, color: _indigo, size: 20),
              const SizedBox(width: 6),
              Text("My Rides", style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 4),
          Text("Tap a seat to see who booked it · block seats for phone bookings",
              style: TextStyle(color: subText, fontSize: 11)),
          const SizedBox(height: 14),

          if (mine.isEmpty)
            _buildRideEmptyState(context, themeColor, primaryText, subText)
          else
            ...mine.map((r) => _rideDashboardCard(context, rideProvider, r, isDark, primaryText, subText)),
        ],
      ),
    );
  }

  Widget _buildRideEmptyState(BuildContext context, Color themeColor, Color primaryText, Color? subText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.directions_car_filled_outlined, size: 54, color: themeColor.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Text("No rides yet", style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            "Broadcast a ride in seconds — set your route, time, seats & price. Your vehicle details are remembered for next time.",
            textAlign: TextAlign.center,
            style: TextStyle(color: subText, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => DriverScreen(registerNew: true, onRegistrationSuccess: () => Navigator.of(ctx).pop()),
              ),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("Broadcast your first ride", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rideDashboardCard(BuildContext context, RideProvider rideProvider, Ride r, bool isDark, Color primaryText, Color? subText) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _indigo.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: _indigo.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(_vehicleIcon(r.vehicleType), color: _indigo, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${r.from} → ${r.to}", maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text("${r.vehicleName} · ₹${r.price.toInt()} · ${r.time}",
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: subText, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DriverScreen(editRide: r, onRegistrationSuccess: () {})),
                ),
                icon: const Icon(Icons.edit, color: _indigo, size: 19),
              ),
              IconButton(
                tooltip: 'Promote (Ad)',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () => _promoteRide(context, r),
                icon: const Icon(Icons.campaign, color: Color(0xFF10B981), size: 20),
              ),
              IconButton(
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () => _confirmDeleteRide(context, rideProvider, r),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _seatLayoutGrid(context, rideProvider, r, primaryText, subText),
        ],
      ),
    );
  }

  /// Live, tappable seat map shown directly under each ride.
  Widget _seatLayoutGrid(BuildContext context, RideProvider rideProvider, Ride r, Color primaryText, Color? subText) {
    final free = r.availableSeats;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _indigo.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _indigo.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_seat, color: _indigo, size: 16),
              const SizedBox(width: 6),
              Text("Seat Map", style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 13)),
              const Spacer(),
              Text("$free free / ${r.totalSeats}",
                  style: TextStyle(color: free == 0 ? Colors.redAccent : const Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(r.totalSeats, (i) {
              final seatNum = i + 1;
              final booked = r.bookedSeats.contains("S$seatNum");
              final c = booked ? Colors.redAccent : const Color(0xFF10B981);
              return GestureDetector(
                onTap: () => _openSeatSheet(context, rideProvider, r, seatNum),
                child: Container(
                  width: 52,
                  height: 50,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c, width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(booked ? Icons.event_seat : Icons.event_seat_outlined, color: c, size: 18),
                      const SizedBox(height: 1),
                      Text("S$seatNum",
                          style: TextStyle(color: c, fontSize: 8.5, height: 1.1, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text("🟢 free · 🔴 booked — tap a seat to see who booked it / manage",
              style: TextStyle(color: subText, fontSize: 10.5)),
        ],
      ),
    );
  }

  /// Tap a seat → details & actions. An accidental tap can NO LONGER unbook a
  /// seat: booked seats open an info sheet (free needs explicit confirmation).
  void _openSeatSheet(BuildContext context, RideProvider provider, Ride r, int seatNum) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SeatActionSheet(provider: provider, ride: r, seatNum: seatNum),
    );
  }

  Future<void> _promoteRide(BuildContext context, Ride r) async {
    final messenger = ScaffoldMessenger.of(context);
    final adId = 'sponsor_${r.id}';

    if (await LocalStorageService.hasAd(adId)) {
      if (!context.mounted) return;
      final stop = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('📣 Ad is live'),
          content: Text('"${r.from} → ${r.to}" is currently advertised across Spiti Setu. Stop this ad?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep running')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Stop Ad', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (stop == true) {
        await LocalStorageService.removeAd(adId);
        messenger.showSnackBar(const SnackBar(content: Text('🛑 Ad stopped & removed.'), backgroundColor: Colors.redAccent));
      }
      return;
    }

    if (!context.mounted) return;
    final pay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('📣 Promote across Spiti Setu'),
        content: Text('Feature "${r.from} → ${r.to}" as a sponsored ad on the Ride, Stay & Food screens for all travellers.\n\n₹199 / week.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.payments, size: 16, color: Colors.white),
            label: const Text('Pay ₹199', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          ),
        ],
      ),
    );
    if (pay != true) return;

    final urlPhoto = r.photoPath.startsWith('http') ? r.photoPath : '';
    await LocalStorageService.addAd({
      'id': adId,
      'title': '🚗 ${r.from} → ${r.to}',
      'body': '${r.vehicleName} · ${r.time} · ₹${r.price.toInt()}',
      'imageUrl': urlPhoto.isNotEmpty
          ? urlPhoto
          : 'https://images.unsplash.com/photo-1502877338535-766e1452684a?auto=format&fit=crop&q=80&w=400',
      'isActive': true,
      'link': r.phone,
      'category': 'ride',
      'sponsor': r.phone,
      'paid': true,
    });
    messenger.showSnackBar(
      const SnackBar(
        content: Text('🎉 Payment received — your ad is now live across Spiti Setu!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  Future<void> _confirmDeleteRide(BuildContext context, RideProvider rideProvider, Ride r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete ride?'),
        content: Text('Remove "${r.from} → ${r.to}" permanently? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      rideProvider.deleteRide(r.id);
      LocalStorageService.removeAd('sponsor_${r.id}');
    }
  }

  void _registerRide() async {
    if (_registering) return; // ignore rapid double-taps
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("Please select a live position on the map first!", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
      return;
    }

    setState(() => _registering = true);
    try {
    // Capture context-dependent objects BEFORE any await to avoid using
    // BuildContext across async gaps.
    final messenger = ScaffoldMessenger.of(context);
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final stayProvider = Provider.of<StayProvider>(context, listen: false);

    if (!_userProfile.isRegistered) {
      _userProfile.name = _nameController.text.trim();
      _userProfile.phone = _phoneController.text.trim();
      _userProfile.isRegistered = true;
      await LocalStorageService.saveProfile(_userProfile);
    }

    final edit = widget.editStay;
    if (edit != null || rideProvider.appMode == AppMode.stay) {
      // Prevent duplicate homestays (same host + same type + same name).
      if (edit == null &&
          stayProvider.isDuplicate(_phoneController.text.trim(), _stayPropertyType, _vehicleNameController.text)) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('"${_vehicleNameController.text.trim()}" ($_stayPropertyType) is already registered. Edit it above, or use a different name.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Stay submission — upload photo to cloud (falls back to local path)
      final stayPhoto = await StorageService.uploadPhoto(_stayPhotoPath, 'stays');
      // Upload per-amenity photos (existing URLs pass through unchanged).
      final amenityPhotoUrls = <String, String>{};
      for (final a in _stayAmenities) {
        final p = _amenityPhotoPaths[a];
        if (p == null || p.isEmpty) continue;
        final url = await StorageService.uploadPhoto(p, 'amenities');
        if (url.isNotEmpty) amenityPhotoUrls[a] = url;
      }
      final newStay = Stay(
        id: edit?.id ?? "s_${DateTime.now().millisecondsSinceEpoch}",
        hostName: edit?.hostName ?? _nameController.text.trim(),
        phone: edit?.phone ?? _phoneController.text.trim(),
        title: _vehicleNameController.text.trim(),
        description: _plateController.text.trim().isEmpty
            ? "Traditional mud-brick Spiti homestay."
            : _plateController.text.trim(),
        pricePerNight: double.tryParse(_priceController.text) ?? 1200.0,
        roomsAvailable: _totalSeats, // Reused capacity as room count
        hasBukhari: _exteriorUploaded,
        hasGeyser: _interiorUploaded,
        foodIncluded: _licenseUploaded,
        lat: _selectedLocation!.latitude,
        lng: _selectedLocation!.longitude,
        rating: edit?.rating ?? 5.0,
        safetyFlags: edit?.safetyFlags ?? [],
        mockPhotoIndex: edit?.mockPhotoIndex ?? (DateTime.now().millisecondsSinceEpoch % 4),
        propertyType: _stayPropertyType,
        amenities: _stayAmenities.toList(),
        photoPath: stayPhoto,
        isFull: edit?.isFull ?? false,
        roomUnits: edit?.roomUnits ?? const [],
        amenityPhotos: amenityPhotoUrls,
      );

      if (edit != null) {
        stayProvider.updateStay(newStay);
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text("Homestay updated!", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
        if (mounted) Navigator.pop(context);
        return;
      }

      stayProvider.registerStay(newStay);

      // Queue a pending host verification for the admin console.
      LocalStorageService.addVerification({
        'type': 'host',
        'hostName': newStay.hostName,
        'propertyName': newStay.title,
        'propertyType': newStay.propertyType,
        'rooms': newStay.roomsAvailable,
        'phone': newStay.phone,
        'isApproved': false,
      });

      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text("Homestay registered & sent for admin verification!", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
    } else {
      // Ride mode submission — upload vehicle photo to cloud (falls back to local)
      final editR = widget.editRide;
      final vehiclePhoto = _vehiclePhotoPath.isEmpty && editR != null
          ? editR.photoPath
          : await StorageService.uploadPhoto(_vehiclePhotoPath, 'vehicles');
      final formattedTime = "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}";
      final newRide = Ride(
        id: editR?.id ?? "d_${DateTime.now().millisecondsSinceEpoch}",
        driverName: editR?.driverName ?? _nameController.text,
        phone: editR?.phone ?? _phoneController.text,
        vehicleType: _selectedType,
        vehicleName: _vehicleNameController.text,
        plateNumber: _plateController.text,
        totalSeats: _totalSeats,
        bookedSeats: editR?.bookedSeats ?? [],
        from: _fromController.text,
        to: _toController.text,
        date: editR != null ? editR.date : _selectedDate.toString().split(' ')[0],
        time: formattedTime,
        price: double.tryParse(_priceController.text) ?? 500.0,
        lat: _selectedLocation!.latitude,
        lng: _selectedLocation!.longitude,
        driverRating: editR?.driverRating ?? (_userProfile.isRegistered ? _userProfile.rating : 5.0),
        safetyFlags: editR?.safetyFlags ?? const [],
        photoPath: vehiclePhoto,
      );

      if (editR != null) {
        rideProvider.updateRide(newRide);
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text("Ride updated!", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
        if (mounted) Navigator.pop(context);
        return;
      }

      rideProvider.registerRide(newRide);

      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF10B981),
          content: Text("Ride registered and broadcasted successfully in Spiti!", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
    }

    widget.onRegistrationSuccess();
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = LatLng(32.2276, 78.0710);
    final size = MediaQuery.of(context).size;
    // Short screens (phone landscape) also need the stacked scrollable layout.
    final isMobile = size.width < 750 || size.height < 600;
    final rideProvider = Provider.of<RideProvider>(context);
    final stayProvider = Provider.of<StayProvider>(context);
    final isDarkMode = rideProvider.isDarkMode;
    
    final isStayMode = widget.editStay != null || rideProvider.appMode == AppMode.stay;
    final activeRequestsCount = isStayMode 
        ? stayProvider.stayRequests.length 
        : Provider.of<PassengerRequestProvider>(context).requests.length;

    final themeColor = isStayMode ? const Color(0xFF0D9488) : const Color(0xFF6366F1);

    final mapOverlayBg = isDarkMode ? const Color(0xFF090D16).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85);
    final mapOverlayBorder = isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1);
    final mapOverlayText = isDarkMode ? Colors.white : Colors.black;

    // The map location picker widget
    Widget mapPickerWidget = Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 11.0,
            onTap: (tapPosition, latLng) {
              setState(() {
                _selectedLocation = latLng;
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: isDarkMode
                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                  : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              retinaMode: RetinaMode.isHighDensity(context),
            ),
            if (_selectedLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    width: 45.0,
                    height: 45.0,
                    point: _selectedLocation!,
                    child: Icon(
                      Icons.location_on,
                      color: themeColor,
                      size: 45,
                    ),
                  )
                ],
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
                Icon(Icons.touch_app, size: 14, color: themeColor),
                const SizedBox(width: 6),
                Text(
                  isStayMode ? "Tap to Pin Homestay GPS Position" : "Tap on Map to Pin Live Route Position",
                  style: TextStyle(color: mapOverlayText, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            heroTag: "gps_fab",
            backgroundColor: themeColor,
            onPressed: () {
              setState(() {
                _selectedLocation = LatLng(32.2276, 78.0710); // Kaza Center
              });
              _mapController.move(LatLng(32.2276, 78.0710), 12.0);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF10B981),
                  content: Text("📍 GPS coordinates acquired successfully!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              );
            },
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ),
      ],
    );

    // Form input layout deck
    Widget formInputsWidget = SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isStayMode
                  ? "Host Stay / Register Homestay"
                  : (widget.editRide != null ? "Edit Your Ride" : "Broadcast a Ride"),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // Passengers / Seekers waiting banner
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => isStayMode 
                        ? const StayRequestsScreen() 
                        : const PassengerRequestsScreen(),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(isStayMode ? Icons.houseboat : Icons.people_alt, color: const Color(0xFF10B981), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isStayMode ? "Tourists Looking for Rooms" : "Passengers Looking for Rides",
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black87,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$activeRequestsCount active broadcasted requests waiting",
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Color(0xFF10B981), size: 14),
                  ],
                ),
              ),
            ),

            // User Info
            if (_userProfile.isRegistered) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: themeColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.verified, color: themeColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Broadcasting as: ${_userProfile.name} (${_userProfile.phone})",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(_nameController, "AAPKA NAAM (FULL NAME)", "Enter name"),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(_phoneController, "PHONE NUMBER", "Enter phone number", isPhone: true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            if (!isStayMode) ...[
              // Vehicle photo first
              Text(
                "Vehicle Photo",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: themeColor),
              ),
              const SizedBox(height: 10),
              PhotoPickerField(
                path: _vehiclePhotoPath,
                accent: themeColor,
                label: 'Add Vehicle Photo',
                onPicked: (p) => setState(() => _vehiclePhotoPath = p),
              ),
              const SizedBox(height: 16),
              // Vehicle details
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<VehicleType>(
                      initialValue: _selectedType,
                      isExpanded: true,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: "VEHICLE TYPE",
                        labelStyle: const TextStyle(color: Colors.grey, fontSize: 9),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: themeColor),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(value: VehicleType.taxi, child: Text("🚕 Taxi")),
                        DropdownMenuItem(value: VehicleType.private, child: Text("🚗 Private")),
                        DropdownMenuItem(value: VehicleType.suv, child: Text("🚙 SUV")),
                        DropdownMenuItem(value: VehicleType.tempo, child: Text("🚐 Tempo")),
                        DropdownMenuItem(value: VehicleType.bus, child: Text("🚌 Bus")),
                        DropdownMenuItem(value: VehicleType.bike, child: Text("🏍️ Bike")),
                      ],
                      onChanged: (value) => _adjustCapacity(value!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(_vehicleNameController, "VEHICLE MODEL NAME", "e.g. Scorpio, Dzire"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(_plateController, "PLATE NUMBER", "e.g. HP 01 T 1234"),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      _capacityController,
                      "TOTAL CAPACITY",
                      "",
                      enabled: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "Verification Documents",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 4),
              Text(
                "Upload clear photos of your documents for verification & a trusted badge.",
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(height: 10),
              PhotoPickerField(
                path: _licensePath,
                accent: themeColor,
                label: 'Add Driving License',
                onPicked: (p) => setState(() => _licensePath = p),
              ),
              const SizedBox(height: 12),
              PhotoPickerField(
                path: _rcPath,
                accent: themeColor,
                label: 'Add RC Registration',
                onPicked: (p) => setState(() => _rcPath = p),
              ),
              const SizedBox(height: 16),
              Text(
                "Journey Details",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildPlaceField(_fromController, "FROM LOCATION", "Starting point"),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPlaceField(_toController, "TO LOCATION", "Destination point"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(_priceController, "KIRAYA / FARE PER SEAT (₹)", "e.g. ₹500", isNumber: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "LIVE POSITION STATUS",
                          style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedLocation = LatLng(32.2276, 78.0710); // Kaza Center
                            });
                            _mapController.move(LatLng(32.2276, 78.0710), 12.0);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedLocation != null ? const Color(0xFF10B981) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              _selectedLocation != null ? "📍 Position Set" : "⚠️ Tap here to Auto-GPS",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _selectedLocation != null ? const Color(0xFF10B981) : Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "DEPARTURE DATE",
                          style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14, color: Color(0xFF6366F1)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedDate.toString().split(' ')[0],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "DEPARTURE TIME",
                          style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _pickTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 14, color: Color(0xFF6366F1)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedTime.format(context),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Stay Host Mode Inputs (reached via + Add Property, or Edit)
              Text(
                widget.editStay == null ? "Register a New Property" : "Edit Homestay",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: themeColor),
              ),
              const SizedBox(height: 12),
              Text(
                "Property Photo",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: themeColor),
              ),
              const SizedBox(height: 10),
              PhotoPickerField(
                path: _stayPhotoPath,
                accent: themeColor,
                label: 'Add Property Photo',
                onPicked: (p) => setState(() => _stayPhotoPath = p),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextField(_vehicleNameController, "HOMESTAY / HOTEL TITLE", "e.g. Kaza Heights Homestay"),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(_priceController, "ROOM PRICE PER NIGHT (₹)", "e.g. 1200", isNumber: true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(_plateController, "DESCRIPTION / PROMO NOTE", "e.g. Cozy mud-brick rooms, hot food..."),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _totalSeats > 10 ? 3 : _totalSeats,
                      isExpanded: true,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: "ROOMS AVAILABLE TODAY",
                        labelStyle: const TextStyle(color: Colors.grey, fontSize: 9),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF0D9488)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: List.generate(10, (i) => i + 1)
                          .map((val) => DropdownMenuItem(value: val, child: Text("🏡 $val Rooms Free")))
                          .toList(),
                      onChanged: (value) => setState(() => _totalSeats = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                "Property Type",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: themeColor),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kPropertyTypes.where((t) => t != 'Any').map((type) {
                  final selected = _stayPropertyType == type;
                  return GestureDetector(
                    onTap: () => setState(() => _stayPropertyType = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? themeColor : themeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? themeColor : themeColor.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: selected ? Colors.white : themeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text(
                "High-Altitude Stay Amenities",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: themeColor),
              ),
              const SizedBox(height: 10),
              _buildUploadSection(true),
              const SizedBox(height: 16),
              Text(
                "More Facilities (tap to add)",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: themeColor),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kExtraAmenities.map((a) {
                  final selected = _stayAmenities.contains(a);
                  final needsPhoto = kPhotoAmenities.contains(a);
                  return GestureDetector(
                    onTap: () async {
                      if (selected) {
                        setState(() {
                          _stayAmenities.remove(a);
                          _amenityPhotoPaths.remove(a);
                        });
                        return;
                      }
                      if (needsPhoto) {
                        // Photo is mandatory: pick first, add only if a photo was chosen.
                        final messenger = ScaffoldMessenger.of(context);
                        await _pickAmenityPhoto(a);
                        if ((_amenityPhotoPaths[a] ?? '').isNotEmpty) {
                          setState(() => _stayAmenities.add(a));
                        } else {
                          messenger.showSnackBar(SnackBar(
                            content: Text('Add a photo to include "$a".'),
                            backgroundColor: const Color(0xFFF59E0B),
                          ));
                        }
                      } else {
                        setState(() => _stayAmenities.add(a));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF14B8A6) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? const Color(0xFF14B8A6) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selected ? Icons.check_circle : (needsPhoto ? Icons.add_a_photo : Icons.add_circle_outline),
                            size: 13,
                            color: selected ? Colors.white : Colors.grey,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            a,
                            style: TextStyle(
                              color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Per-amenity photos (only for selected "visual" amenities)
              if (_stayAmenities.any((a) => kPhotoAmenities.contains(a))) ...[
                const SizedBox(height: 16),
                Text(
                  "📷 Amenity Photos",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: themeColor),
                ),
                const SizedBox(height: 2),
                Text(
                  "These amenities need a photo. Tap to change.",
                  style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _stayAmenities
                      .where((a) => kPhotoAmenities.contains(a))
                      .map((a) => _amenityPhotoCard(a, themeColor))
                      .toList(),
                ),
              ],
              const SizedBox(height: 20),
              // Location status picker
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "GPS HOMESTAY COORDINATES",
                          style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedLocation = LatLng(32.2276, 78.0710); // Kaza Center
                            });
                            _mapController.move(LatLng(32.2276, 78.0710), 12.0);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedLocation != null ? const Color(0xFF10B981) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              _selectedLocation != null ? "📍 Position Set" : "⚠️ Tap here to Auto-GPS",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _selectedLocation != null ? const Color(0xFF10B981) : Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: _registering ? null : _registerRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  disabledBackgroundColor: themeColor.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _registering
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        widget.editStay != null
                            ? "💾 Save Changes"
                            : isStayMode
                                ? "🏡 Broadcast & Host Stay"
                                : "🚀 Broadcast & Register Ride",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            )
          ],
        ),
      ),
    );

    // Host "home" dashboards: My Homestays (stay) or My Rides (ride), each with
    // a live layout + a + button. The form only appears via + / Edit.
    final isStayHostHome = isStayMode && widget.editStay == null && !widget.registerNew;
    final isRideHostHome = !isStayMode && widget.editRide == null && !widget.registerNew;
    final isHome = isStayHostHome || isRideHostHome;

    final showAppBar = widget.editStay != null || widget.editRide != null || widget.registerNew;
    String appBarTitle;
    if (widget.editStay != null) {
      appBarTitle = "Edit Homestay";
    } else if (widget.editRide != null) {
      appBarTitle = "Edit Ride";
    } else if (isStayMode) {
      appBarTitle = "Register a New Property";
    } else {
      appBarTitle = "Broadcast a Ride";
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black87),
              title: Text(appBarTitle,
                  style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            )
          : null,
      floatingActionButton: isHome
          ? FloatingActionButton.extended(
              heroTag: "add_listing_fab",
              backgroundColor: themeColor,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(isStayHostHome ? "Add Property" : "Broadcast a Ride",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => DriverScreen(
                    registerNew: true,
                    onRegistrationSuccess: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            )
          : null,
      body: isStayHostHome
          ? _buildStayDashboard(context, stayProvider, themeColor)
          : isRideHostHome
              ? _buildRideDashboard(context, rideProvider, themeColor)
              : isMobile
                  ? Column(
                      children: [
                        // Top Map location picker
                        SizedBox(
                          height: 220,
                          child: mapPickerWidget,
                        ),
                        // Bottom Input fields
                        Expanded(
                          child: formInputsWidget,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          flex: 11,
                          child: formInputsWidget,
                        ),
                        Expanded(
                          flex: 9,
                          child: mapPickerWidget,
                        ),
                      ],
                    ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
      filled: true,
      fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: Provider.of<RideProvider>(context, listen: false).appMode == AppMode.ride
              ? const Color(0xFF6366F1)
              : const Color(0xFF0D9488),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      disabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(10),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(10),
      ),
      errorStyle: const TextStyle(fontSize: 10, height: 0.8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    bool enabled = true,
    bool isPhone = false,
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
          keyboardType: isPhone
              ? TextInputType.phone
              : isNumber
                  ? TextInputType.number
                  : TextInputType.text,
          decoration: _fieldDecoration(hint),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return "Field required";
            }
            return null;
          },
        ),
      ],
    );
  }

  /// From/To field with Spiti place suggestions — canonical spellings keep
  /// the broadcast findable by the corridor matcher.
  Widget _buildPlaceField(TextEditingController controller, String label, String hint) {
    final isRideMode = Provider.of<RideProvider>(context, listen: false).appMode == AppMode.ride;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        PlaceAutocompleteField(
          controller: controller,
          accent: isRideMode ? const Color(0xFF6366F1) : const Color(0xFF0D9488),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
          decoration: _fieldDecoration(hint),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return "Field required";
            }
            return null;
          },
        ),
      ],
    );
  }
}

/// Bottom sheet for a single seat: shows who booked it (with call), lets the
/// driver block a free seat, and requires confirmation to free a booked seat.
/// Owns its own text controllers so they dispose at the correct lifecycle point
/// (avoids the framework `_dependents.isEmpty` assertion seen with whenComplete).
class SeatActionSheet extends StatefulWidget {
  final RideProvider provider;
  final Ride ride;
  final int seatNum;
  const SeatActionSheet({super.key, required this.provider, required this.ride, required this.seatNum});

  @override
  State<SeatActionSheet> createState() => _SeatActionSheetState();
}

class _SeatActionSheetState extends State<SeatActionSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  static const Color _indigo = Color(0xFF6366F1);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _dial(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Widget _infoRow(IconData icon, String text, Color primaryText, Color subText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: subText),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: primaryText, fontSize: 14, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = "S${widget.seatNum}";
    final r = widget.ride;
    final booked = r.bookedSeats.contains(id);
    final info = r.bookingFor(id);
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final subText = primaryText.withValues(alpha: 0.6);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: (booked ? Colors.redAccent : const Color(0xFF10B981)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(booked ? Icons.event_seat : Icons.event_seat_outlined,
                    color: booked ? Colors.redAccent : const Color(0xFF10B981)),
              ),
              const SizedBox(width: 12),
              Text("Seat $id — ${booked ? 'Booked' : 'Free'}",
                  style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 16),
          if (booked) ...[
            if (info != null && (info.name.isNotEmpty || info.phone.isNotEmpty)) ...[
              _infoRow(Icons.person, info.name.isEmpty ? 'Passenger' : info.name, primaryText, subText),
              if (info.phone.isNotEmpty) _infoRow(Icons.phone, info.phone, primaryText, subText),
              _infoRow(
                  info.byDriver ? Icons.app_blocking : Icons.verified,
                  info.byDriver ? 'Blocked by you (phone / walk-in)' : 'Booked online by passenger',
                  primaryText, subText),
              if (info.phone.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _dial(info.phone),
                    icon: const Icon(Icons.call, color: Color(0xFF10B981)),
                    label: const Text('Call passenger', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF10B981))),
                  ),
                ),
              ],
            ] else
              Text('This seat is booked. No passenger details were recorded (older booking).',
                  style: TextStyle(color: subText, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Free a seat only if the passenger cancelled — they may have already paid.',
                        style: TextStyle(color: subText, fontSize: 11.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      title: Text('Free seat $id?'),
                      content: const Text('This marks the seat available again. Do this only if the booking was cancelled.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(d, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                          child: const Text('Free seat', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    widget.provider.freeSeat(r, id);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.lock_open, color: Colors.white),
                label: const Text('Free this seat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ] else ...[
            Text('Block this seat for a phone / walk-in booking. Passengers can still book free seats themselves.',
                style: TextStyle(color: subText, fontSize: 12.5)),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              style: TextStyle(color: primaryText),
              decoration: InputDecoration(labelText: 'Passenger name (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: primaryText),
              decoration: InputDecoration(labelText: 'Phone (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.provider.setSeatBooked(r, id, name: _nameCtrl.text.trim(), phone: _phoneCtrl.text.trim(), byDriver: true);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.event_seat, color: Colors.white),
                label: Text('Block seat $id', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: _indigo, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
