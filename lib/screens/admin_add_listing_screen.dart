import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/ride_model.dart';
import '../models/stay_model.dart';
import '../models/food_model.dart';
import '../services/local_storage_service.dart';
import '../services/verified_phones_service.dart';

/// Admin lists a property / food place / ride ON BEHALF of a local who can't
/// register themselves — and can mark their phone number as verified.
class AdminAddListingScreen extends StatefulWidget {
  final AppMode mode; // stay / food / ride
  const AdminAddListingScreen({super.key, required this.mode});

  @override
  State<AdminAddListingScreen> createState() => _AdminAddListingScreenState();
}

/// Approx coordinates for the main Spiti villages (admin listings get a sensible
/// location; the provider can fine-tune later by editing on the host screen).
const Map<String, List<double>> _villageCoords = {
  'Kaza': [32.2276, 78.0710],
  'Kibber': [32.3330, 78.0100],
  'Chicham': [32.3450, 77.9980],
  'Key (Kee)': [32.2970, 78.0130],
  'Langza': [32.2700, 78.0830],
  'Hikkim': [32.2840, 78.0640],
  'Komic': [32.2790, 78.1050],
  'Demul': [32.3000, 78.1200],
  'Rangrik': [32.2500, 78.0500],
  'Tabo': [32.0950, 78.3850],
  'Dhankar': [32.0870, 78.2150],
  'Lhalung': [32.1000, 78.2000],
  'Pin Valley (Mud)': [31.9500, 78.0500],
  'Sagnam': [32.0200, 78.1000],
  'Losar': [32.4300, 77.7800],
  'Mane': [32.0500, 78.3000],
  'Gette': [32.3400, 78.0200],
  'Tashigang': [32.3500, 78.0200],
};

class _AdminAddListingScreenState extends State<AdminAddListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _cuisine = TextEditingController();
  final _timings = TextEditingController(text: '8 AM – 9 PM');
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _vehicleName = TextEditingController();
  final _plate = TextEditingController();
  final _time = TextEditingController(text: '06:00');

  String _village = 'Kaza';
  String _propertyType = 'Homestay';
  String _foodType = 'Dhaba';
  String _vegType = 'Both';
  VehicleType _vehicleType = VehicleType.taxi;
  int _count = 4; // rooms / seats
  bool _verifyPhone = true;
  bool _submitting = false;

  // Cross-platform photos (no dart:io → works in the web admin console too).
  XFile? _photo;
  Uint8List? _photoBytes;
  // Per-room photos for stays, keyed by room index.
  final Map<int, XFile> _roomFiles = {};
  final Map<int, Uint8List> _roomBytes = {};

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (mounted) setState(() { _photo = x; _photoBytes = bytes; });
  }

  Future<void> _pickRoomPhoto(int i) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (mounted) setState(() { _roomFiles[i] = x; _roomBytes[i] = bytes; });
  }

  /// Upload raw bytes to Storage; returns the download URL ('' on failure).
  Future<String> _uploadBytes(Uint8List? bytes, String fileName, String folder) async {
    if (bytes == null) return '';
    try {
      final ref = FirebaseStorage.instance.ref().child('$folder/${DateTime.now().millisecondsSinceEpoch}_$fileName');
      await ref.putData(bytes).timeout(const Duration(seconds: 25));
      return await ref.getDownloadURL().timeout(const Duration(seconds: 10));
    } catch (_) {
      return ''; // upload failed → listing still saves without a photo
    }
  }

  Future<String> _uploadPhoto() => _uploadBytes(_photoBytes, _photo?.name ?? 'photo.jpg', 'admin_listings');

  Color get _accent => widget.mode == AppMode.ride
      ? const Color(0xFF6366F1)
      : widget.mode == AppMode.stay
          ? const Color(0xFF0D9488)
          : const Color(0xFFF59E0B);

  String get _modeLabel => widget.mode == AppMode.ride
      ? 'Ride'
      : widget.mode == AppMode.stay
          ? 'Property / Stay'
          : 'Food Service';

  @override
  void dispose() {
    for (final c in [_name, _phone, _title, _desc, _price, _cuisine, _timings, _from, _to, _vehicleName, _plate, _time]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final stayProvider = Provider.of<StayProvider>(context, listen: false);
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final rideProvider = Provider.of<RideProvider>(context, listen: false);
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final coords = _villageCoords[_village] ?? const [32.2276, 78.0710];
    final lat = coords[0];
    final lng = coords[1];
    final ts = DateTime.now().millisecondsSinceEpoch;
    final photoUrl = await _uploadPhoto();

    if (widget.mode == AppMode.stay) {
      final nightly = double.tryParse(_price.text.trim()) ?? 1200;
      // Build the room layout, uploading each room's photo (if added).
      final units = <RoomUnit>[];
      for (var i = 0; i < _count; i++) {
        final url = await _uploadBytes(_roomBytes[i], _roomFiles[i]?.name ?? 'room.jpg', 'rooms');
        units.add(RoomUnit(
          id: 'room_${ts}_$i',
          name: 'Room ${i + 1}',
          price: nightly,
          photoPath: url,
          occupied: false,
        ));
      }
      final stay = Stay(
        id: 's_$ts',
        hostName: name,
        phone: phone,
        title: _title.text.trim(),
        description: _desc.text.trim().isEmpty ? 'Listed by Spiti Setu admin on behalf of the host.' : _desc.text.trim(),
        pricePerNight: nightly,
        roomsAvailable: _count,
        hasBukhari: true,
        hasGeyser: false,
        foodIncluded: false,
        lat: lat,
        lng: lng,
        propertyType: _propertyType,
        amenities: const [],
        photoPath: photoUrl,
        roomUnits: units,
      );
      stayProvider.registerStay(stay);
      LocalStorageService.addVerification({
        'type': 'host',
        'hostName': name,
        'propertyName': stay.title,
        'propertyType': stay.propertyType,
        'rooms': stay.roomsAvailable,
        'phone': phone,
        'isApproved': _verifyPhone,
      });
    } else if (widget.mode == AppMode.food) {
      final place = FoodPlace(
        id: 'f_$ts',
        ownerName: name,
        phone: phone,
        title: _title.text.trim(),
        foodType: _foodType,
        cuisine: _cuisine.text.trim().isEmpty ? 'Spitian / Local' : _cuisine.text.trim(),
        vegType: _vegType,
        description: _desc.text.trim().isEmpty ? 'Listed by Spiti Setu admin on behalf of the cook.' : _desc.text.trim(),
        pricePerPlate: double.tryParse(_price.text.trim()) ?? 0,
        timings: _timings.text.trim(),
        lat: lat,
        lng: lng,
        photos: photoUrl.isNotEmpty ? [photoUrl] : const [],
      );
      foodProvider.registerFoodPlace(place);
      LocalStorageService.addVerification({
        'type': 'food',
        'ownerName': name,
        'placeName': place.title,
        'foodType': place.foodType,
        'phone': phone,
        'isApproved': _verifyPhone,
      });
    } else {
      final ride = Ride(
        id: 'd_$ts',
        driverName: name,
        phone: phone,
        vehicleType: _vehicleType,
        vehicleName: _vehicleName.text.trim().isEmpty ? 'Vehicle' : _vehicleName.text.trim(),
        plateNumber: _plate.text.trim(),
        totalSeats: _count,
        bookedSeats: const [],
        from: _from.text.trim(),
        to: _to.text.trim(),
        date: DateTime.now().toString().split(' ')[0],
        time: _time.text.trim().isEmpty ? '06:00' : _time.text.trim(),
        price: double.tryParse(_price.text.trim()) ?? 500,
        lat: lat,
        lng: lng,
        photoPath: photoUrl,
      );
      rideProvider.registerRide(ride);
      LocalStorageService.addVerification({
        'type': 'driver',
        'driverName': name,
        'vehicle': ride.vehicleName,
        'route': '${ride.from} → ${ride.to}',
        'phone': phone,
        'isApproved': _verifyPhone,
      });
    }

    // Mark the phone verified by admin (shows a ✓ Verified badge on the card).
    if (_verifyPhone) {
      VerifiedPhonesService.add(phone, name);
    }

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        content: Text('✅ $_modeLabel listed${_verifyPhone ? ' & phone verified' : ''} for $name'),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final primaryText = Theme.of(context).colorScheme.onSurface;
    final subText = primaryText.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryText),
        title: Text('Admin · List $_modeLabel',
            style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.support_agent, color: _accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('List on behalf of a local who can\'t register themselves.',
                          style: TextStyle(color: subText, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _label('PHOTO (optional)', subText),
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _accent.withValues(alpha: 0.3)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _photoBytes != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(_photoBytes!, fit: BoxFit.cover),
                            Positioned(
                              right: 8, top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.edit, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, color: _accent, size: 30),
                            const SizedBox(height: 6),
                            Text('Add a photo', style: TextStyle(color: _accent, fontWeight: FontWeight.w800)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              _label('PROVIDER NAME', subText),
              _field(_name, 'e.g. Tenzin Dorje', req: true),
              const SizedBox(height: 12),
              _label('PHONE NUMBER', subText),
              _field(_phone, '10-digit mobile', req: true, number: true),
              const SizedBox(height: 12),

              _label(widget.mode == AppMode.ride ? 'ROUTE' : '${_modeLabel.toUpperCase()} NAME', subText),
              if (widget.mode == AppMode.ride) ...[
                Row(children: [
                  Expanded(child: _field(_from, 'From', req: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_to, 'To', req: true)),
                ]),
              ] else
                _field(_title, widget.mode == AppMode.stay ? 'e.g. Kaza Mud House' : 'e.g. Sonam Dhaba', req: true),
              const SizedBox(height: 12),

              // Mode-specific
              if (widget.mode == AppMode.stay) ...[
                _label('PROPERTY TYPE', subText),
                _dropdown<String>(_propertyType, kPropertyTypes.where((t) => t != 'Any').toList(), (v) => setState(() => _propertyType = v!)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('₹ / NIGHT', subText), _field(_price, '1200', number: true)])),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('ROOMS', subText), _counter()])),
                ]),
                const SizedBox(height: 14),
                _label('ROOM PHOTOS (optional — one per room)', subText),
                Text('Tap a room to add its photo. Builds the room layout the host sees.',
                    style: TextStyle(color: subText, fontSize: 10.5)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_count, (i) => _roomPhotoCard(i, subText)),
                ),
              ] else if (widget.mode == AppMode.food) ...[
                _label('FOOD TYPE', subText),
                _dropdown<String>(_foodType, kFoodTypes, (v) => setState(() => _foodType = v!)),
                const SizedBox(height: 12),
                _label('CUISINE', subText),
                _field(_cuisine, 'e.g. Tibetan / Momos'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('VEG / NON-VEG', subText), _dropdown<String>(_vegType, kVegPrefs, (v) => setState(() => _vegType = v!))])),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('₹ / PLATE (approx)', subText), _field(_price, 'optional', number: true)])),
                ]),
                const SizedBox(height: 12),
                _label('TIMINGS', subText),
                _field(_timings, '8 AM – 9 PM'),
              ] else ...[
                _label('VEHICLE', subText),
                _dropdown<VehicleType>(_vehicleType, VehicleType.values, (v) => setState(() => _vehicleType = v!), labeler: (t) => t.name),
                const SizedBox(height: 12),
                _field(_vehicleName, 'Vehicle name (e.g. Force Traveller)'),
                const SizedBox(height: 12),
                _field(_plate, 'Plate number (e.g. HP 01 T 4562)'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('₹ FARE', subText), _field(_price, '500', number: true)])),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('SEATS', subText), _counter()])),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('TIME', subText), _field(_time, '06:00')])),
                ]),
              ],
              const SizedBox(height: 12),

              _label('VILLAGE / AREA', subText),
              _dropdown<String>(_village, _villageCoords.keys.toList(), (v) => setState(() => _village = v!)),
              const SizedBox(height: 12),

              _label('NOTE / DESCRIPTION (optional)', subText),
              _field(_desc, 'Anything useful for travellers', maxLines: 2),
              const SizedBox(height: 16),

              // Verify phone toggle
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: SwitchListTile(
                  value: _verifyPhone,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (v) => setState(() => _verifyPhone = v),
                  title: const Text('Verify this phone number', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('Adds a "✓ Verified" badge — use for trusted locals you confirmed.',
                      style: TextStyle(color: subText, fontSize: 11)),
                  secondary: const Icon(Icons.verified, color: Color(0xFF10B981)),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.add_business, color: Colors.white),
                  label: Text('List $_modeLabel', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t, Color? c) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(t, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
      );

  Widget _field(TextEditingController c, String hint, {bool req = false, bool number = false, int maxLines = 1}) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
      validator: req ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _accent),
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _dropdown<T>(T value, List<T> items, ValueChanged<T?> onChanged, {String Function(T)? labeler}) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: Theme.of(context).colorScheme.surface,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _accent),
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(labeler != null ? labeler(e) : e.toString()))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _roomPhotoCard(int i, Color? subText) {
    final bytes = _roomBytes[i];
    return GestureDetector(
      onTap: () => _pickRoomPhoto(i),
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            Container(
              width: 92,
              height: 76,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accent.withValues(alpha: 0.3)),
              ),
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, color: _accent, size: 20),
                        const SizedBox(height: 3),
                        Text('Room ${i + 1}', style: TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w800)),
                      ],
                    ),
            ),
            if (bytes != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('Room ${i + 1} ✓', style: TextStyle(color: subText, fontSize: 9.5, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _counter() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _count = _count > 1 ? _count - 1 : 1),
            icon: Icon(Icons.remove, color: _accent, size: 18),
          ),
          Text('$_count', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16)),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _count = _count < 30 ? _count + 1 : 30),
            icon: Icon(Icons.add, color: _accent, size: 18),
          ),
        ],
      ),
    );
  }
}
