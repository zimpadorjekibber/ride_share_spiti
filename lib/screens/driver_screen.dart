import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/ride_model.dart';
import '../models/passenger_request_model.dart';
import '../services/local_storage_service.dart';
import '../models/booked_trip_model.dart';
import 'passenger_requests_screen.dart';

class DriverScreen extends StatefulWidget {
  final VoidCallback onRegistrationSuccess;

  const DriverScreen({super.key, required this.onRegistrationSuccess});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleNameController = TextEditingController();
  final _plateController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController(text: "4 Seats");

  VehicleType _selectedType = VehicleType.taxi;
  int _totalSeats = 4;
  LatLng? _selectedLocation;
  final MapController _mapController = MapController();
  UserProfile _userProfile = UserProfile();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6366F1),
            surface: Color(0xFF111827),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6366F1),
            surface: Color(0xFF111827),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  bool _exteriorUploaded = false;
  bool _interiorUploaded = false;
  bool _licenseUploaded = false;
  bool _rcUploaded = false;

  bool _loadingExterior = false;
  bool _loadingInterior = false;
  bool _loadingLicense = false;
  bool _loadingRc = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
    }
  }

  Widget _buildUploadSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _uploadButton("Exterior Photo", _exteriorUploaded, _loadingExterior, () => _simulateUpload('ext'))),
            const SizedBox(width: 10),
            Expanded(child: _uploadButton("Interior Photo", _interiorUploaded, _loadingInterior, () => _simulateUpload('int'))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _uploadButton("Driving License", _licenseUploaded, _loadingLicense, () => _simulateUpload('lic'))),
            const SizedBox(width: 10),
            Expanded(child: _uploadButton("RC Registration", _rcUploaded, _loadingRc, () => _simulateUpload('rc'))),
          ],
        ),
      ],
    );
  }

  Widget _uploadButton(String label, bool isUploaded, bool isLoading, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                ? const Color(0xFF10B981) 
                : (isLoading ? const Color(0xFF6366F1) : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1))),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isUploaded ? Icons.check_circle : (isLoading ? Icons.hourglass_top : Icons.cloud_upload_outlined),
              color: isUploaded ? const Color(0xFF10B981) : (isLoading ? const Color(0xFF6366F1) : Colors.grey),
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
                    isUploaded ? "Verified Attached" : (isLoading ? "Uploading..." : "Tap to Upload"),
                    style: TextStyle(
                      fontSize: 8.5,
                      color: isUploaded ? const Color(0xFF10B981) : Colors.grey,
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

  void _simulateUpload(String type) {
    setState(() {
      if (type == 'ext') _loadingExterior = true;
      if (type == 'int') _loadingInterior = true;
      if (type == 'lic') _loadingLicense = true;
      if (type == 'rc') _loadingRc = true;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          if (type == 'ext') {
            _loadingExterior = false;
            _exteriorUploaded = true;
          }
          if (type == 'int') {
            _loadingInterior = false;
            _interiorUploaded = true;
          }
          if (type == 'lic') {
            _loadingLicense = false;
            _licenseUploaded = true;
          }
          if (type == 'rc') {
            _loadingRc = false;
            _rcUploaded = true;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ ${type.toUpperCase()} verified and compiled successfully!"),
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

  void _registerRide() async {
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

    if (!_exteriorUploaded || !_interiorUploaded || !_licenseUploaded || !_rcUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.amber,
          content: Text("⚠️ Verifying documents... Attached mock photos successfully!", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      );
      setState(() {
        _exteriorUploaded = true;
        _interiorUploaded = true;
        _licenseUploaded = true;
        _rcUploaded = true;
      });
      return;
    }

    if (!_userProfile.isRegistered) {
      _userProfile.name = _nameController.text.trim();
      _userProfile.phone = _phoneController.text.trim();
      _userProfile.isRegistered = true;
      await LocalStorageService.saveProfile(_userProfile);
    }

    if (!mounted) return;

    final formattedTime = "${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}";
    final newRide = Ride(
      id: "d_${DateTime.now().millisecondsSinceEpoch}",
      driverName: _nameController.text,
      phone: _phoneController.text,
      vehicleType: _selectedType,
      vehicleName: _vehicleNameController.text,
      plateNumber: _plateController.text,
      totalSeats: _totalSeats,
      bookedSeats: [],
      from: _fromController.text,
      to: _toController.text,
      date: _selectedDate.toString().split(' ')[0],
      time: formattedTime,
      price: double.tryParse(_priceController.text) ?? 500.0,
      lat: _selectedLocation!.latitude,
      lng: _selectedLocation!.longitude,
      driverRating: _userProfile.isRegistered ? _userProfile.rating : 5.0,
    );

    Provider.of<RideProvider>(context, listen: false).registerRide(newRide);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF10B981),
        content: Text("Ride registered and broadcasted successfully in Spiti!", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );

    widget.onRegistrationSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = LatLng(32.2276, 78.0710);
    final isMobile = MediaQuery.of(context).size.width < 750;
    final isDarkMode = Provider.of<RideProvider>(context).isDarkMode;
    final requestsCount = Provider.of<PassengerRequestProvider>(context).requests.length;

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
            initialZoom: 8.0,
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
                    child: const Icon(
                      Icons.location_on,
                      color: Color(0xFF10B981),
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
                const Icon(Icons.touch_app, size: 14, color: Color(0xFF10B981)),
                const SizedBox(width: 6),
                Text(
                  "Tap on Map to Pin Live Position",
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
            backgroundColor: const Color(0xFF6366F1),
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
              "Register Vehicle & Route",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            // Passengers waiting banner
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PassengerRequestsScreen()),
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
                      child: const Icon(Icons.people_alt, color: Color(0xFF10B981), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Passengers Looking for Rides",
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black87,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$requestsCount active broadcasted requests waiting",
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
            // Driver info
            if (_userProfile.isRegistered) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: Color(0xFF818CF8), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "Broadcasting as: ${_userProfile.name} (${_userProfile.phone})",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(_nameController, "DRIVER NAME (AAPKA NAAM)", "Enter name"),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(_phoneController, "PHONE NUMBER", "Enter phone number", isPhone: true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
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
                        borderSide: const BorderSide(color: Color(0xFF6366F1)),
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
              "Vehicle Photos & Verification Documents",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 10),
            _buildUploadSection(),
            const SizedBox(height: 16),
            Text(
              "Journey Details",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(_fromController, "FROM LOCATION", "Starting point"),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(_toController, "TO LOCATION", "Destination point"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(_priceController, "KIRAYA / FARE PER SEAT (₹)", "e.g. ₹500 (Kiraya)", isNumber: true),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF10B981),
                              content: Text("📍 GPS coordinates acquired successfully!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          );
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
                            _selectedLocation != null
                                ? "📍 Position Set"
                                : "⚠️ Tap here to Auto-GPS",
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: _registerRide,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "🚀 Broadcast & Register Ride",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            )
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: isMobile
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
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
            filled: true,
            fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF6366F1)),
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
          ),
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
