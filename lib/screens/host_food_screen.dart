import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_model.dart';
import '../services/local_storage_service.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';
import '../models/booked_trip_model.dart';
import '../widgets/photo_picker_field.dart';
import 'food_requests_screen.dart';
import 'manage_food_layout_screen.dart';
import '../widgets/app_network_image.dart';
import '../services/phone_utils.dart';

class HostFoodScreen extends StatefulWidget {
  final VoidCallback onRegistered;
  final FoodPlace? existing; // when set → edit mode
  final bool registerNew; // when true → show ONLY the registration form (opened via the + button)
  const HostFoodScreen({super.key, required this.onRegistered, this.existing, this.registerNew = false});

  @override
  State<HostFoodScreen> createState() => _HostFoodScreenState();
}

class _HostFoodScreenState extends State<HostFoodScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _cuisineController = TextEditingController();
  final _timingsController = TextEditingController(text: '8 AM – 9 PM');
  final _descController = TextEditingController();
  final _menuLinkController = TextEditingController();

  // Menu rows (each = dish name + price)
  final List<TextEditingController> _itemNames = [];
  final List<TextEditingController> _itemPrices = [];

  String _foodType = 'Home Dining';
  String _vegType = 'Veg';
  bool _delivery = false;
  double _deliveryKm = 5;
  final Set<String> _facilities = {};
  bool _cookOnRequest = true;
  bool _offMarket = false;
  bool _locationSet = false;
  bool _submitting = false;
  double _lat = 32.2276;
  double _lng = 78.0710;
  List<String> _photos = [];
  UserProfile _profile = UserProfile();

  bool get _isEdit => widget.existing != null;
  static const Color _accent = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e.title;
      _cuisineController.text = e.cuisine;
      _timingsController.text = e.timings;
      _descController.text = e.description;
      _menuLinkController.text = e.menuLink;
      _foodType = e.foodType;
      _vegType = e.vegType;
      _delivery = e.homeDelivery;
      _deliveryKm = e.deliveryRangeKm > 0 ? e.deliveryRangeKm : 5;
      _cookOnRequest = e.cookOnRequest;
      _offMarket = e.offMarket;
      _photos = List.from(e.allPhotos);
      _facilities.addAll(e.facilities);
      _lat = e.lat;
      _lng = e.lng;
      _locationSet = true;
      for (final m in e.menu) {
        _itemNames.add(TextEditingController(text: m.name));
        _itemPrices.add(TextEditingController(text: m.price.toInt().toString()));
      }
    }
    if (_itemNames.isEmpty) _addMenuRow();
    LocalStorageService.getProfile().then((p) {
      if (mounted) setState(() => _profile = p);
    });
  }

  void _addMenuRow() {
    _itemNames.add(TextEditingController());
    _itemPrices.add(TextEditingController());
  }

  bool _acquiringGps = false;

  /// Pin the kitchen at the device's real GPS position; falls back to the
  /// profile's saved coords (or Kaza Center) with an honest message.
  Future<void> _useMyLocation() async {
    if (_acquiringGps) return;
    setState(() => _acquiringGps = true);
    final messenger = ScaffoldMessenger.of(context);

    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;

    setState(() {
      _acquiringGps = false;
      _locationSet = true;
      if (pos != null) {
        _lat = pos.latitude;
        _lng = pos.longitude;
      } else {
        _lat = _profile.currentLat != 0.0 ? _profile.currentLat : 32.2276;
        _lng = _profile.currentLng != 0.0 ? _profile.currentLng : 78.0710;
      }
    });

    messenger.showSnackBar(
      pos != null
          ? const SnackBar(
              backgroundColor: Color(0xFF10B981),
              content: Text("📍 Live GPS position set!",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            )
          : const SnackBar(
              backgroundColor: Color(0xFFF59E0B),
              content: Text("GPS unavailable — used your saved area (Kaza default).",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _cuisineController.dispose();
    _timingsController.dispose();
    _descController.dispose();
    _menuLinkController.dispose();
    for (final c in _itemNames) {
      c.dispose();
    }
    for (final c in _itemPrices) {
      c.dispose();
    }
    super.dispose();
  }

  List<MenuItem> _collectMenu() {
    final items = <MenuItem>[];
    for (var i = 0; i < _itemNames.length; i++) {
      final name = _itemNames[i].text.trim();
      final price = double.tryParse(_itemPrices[i].text.trim());
      if (name.isNotEmpty && price != null) {
        // Preserve existing stock (qtyLeft / availability) when editing.
        final prev = widget.existing?.menu
            .where((m) => m.name == name)
            .cast<MenuItem?>()
            .firstWhere((_) => true, orElse: () => null);
        items.add(MenuItem(
          name: name,
          price: price,
          available: prev?.available ?? true,
          qtyLeft: prev?.qtyLeft ?? -1,
        ));
      }
    }
    return items;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_locationSet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please set your GPS location first!"), backgroundColor: Colors.red),
      );
      return;
    }
    final menu = _collectMenu(); // optional — a QR/menu link can replace it
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final e = widget.existing;

    // Prevent duplicate listings (same owner + same type + same name).
    if (e == null && foodProvider.isDuplicate(_profile.phone, _foodType, _titleController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${_titleController.text.trim()}" ($_foodType) is already registered. Edit it above, or use a different name.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);

    // Upload all photos to cloud (falls back to local paths if offline).
    final photoUrls = await StorageService.uploadPhotos(_photos, 'food');

    final place = FoodPlace(
      id: e?.id ?? 'f_${DateTime.now().millisecondsSinceEpoch}',
      ownerName: e?.ownerName ?? (_profile.isRegistered ? _profile.name : 'Local Cook'),
      phone: e?.phone ?? _profile.phone,
      title: _titleController.text.trim(),
      foodType: _foodType,
      cuisine: _cuisineController.text.trim().isEmpty ? 'Spitian / Local' : _cuisineController.text.trim(),
      vegType: _vegType,
      description: _descController.text.trim().isEmpty ? 'Fresh local food in Spiti.' : _descController.text.trim(),
      pricePerPlate: menu.isNotEmpty ? menu.first.price : (e?.pricePerPlate ?? 0),
      timings: _timingsController.text.trim(),
      homeDelivery: _delivery,
      deliveryRangeKm: _delivery ? _deliveryKm : 0,
      cookOnRequest: _cookOnRequest,
      offMarket: _offMarket,
      lat: _lat,
      lng: _lng,
      rating: e?.rating ?? 5.0,
      safetyFlags: e?.safetyFlags ?? const [],
      mockPhotoIndex: e?.mockPhotoIndex ?? (DateTime.now().millisecondsSinceEpoch % 4),
      photos: photoUrls,
      seatingPhotos: e?.seatingPhotos ?? const [], // managed in the table-layout screen
      menu: menu,
      menuLink: _menuLinkController.text.trim(),
      facilities: _facilities.toList(),
      tables: e?.tables ?? const [], // preserve table layout on edit
    );

    if (_isEdit) {
      foodProvider.updateFoodPlace(place);
    } else {
      foodProvider.registerFoodPlace(place);
      LocalStorageService.addVerification({
        'type': 'food',
        'ownerName': place.ownerName,
        'placeName': place.title,
        'foodType': place.foodType,
        'phone': place.phone,
        'isApproved': false,
      });
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(_isEdit ? "✅ Listing updated!" : "🍲 Food spot registered & sent for admin verification!"),
        backgroundColor: _accent,
      ),
    );
    if (_isEdit && mounted) {
      Navigator.pop(context);
    } else {
      widget.onRegistered();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final provider = Provider.of<FoodProvider>(context);

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isEdit ? "Edit Your Food Listing" : "Register a New Food Service",
                style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 4),
            Text("Restaurant, cafe, dhaba, or a home cook — even without rooms or a shop!",
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 18),

            _field(_titleController, "PLACE / KITCHEN NAME", "e.g. Dolkar's Spiti Kitchen", (v) => v!.trim().isEmpty ? "Required" : null),
            const SizedBox(height: 16),

            Text("Photos (up to 10)", style: TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            MultiPhotoPickerField(
              paths: _photos,
              accent: _accent,
              max: 10,
              onChanged: (list) => setState(() => _photos = list),
            ),
            const SizedBox(height: 16),

            Text("Type", style: TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: kFoodTypes.map((t) => _chip(t, _foodType == t, () => setState(() => _foodType = t))).toList()),
            const SizedBox(height: 16),

            Text("Veg / Non-Veg", style: TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: kVegPrefs.map((v) => _chip(v, _vegType == v, () => setState(() => _vegType = v))).toList()),
            const SizedBox(height: 16),

            _field(_cuisineController, "CUISINE", "e.g. Spitian, Momos, Continental", null),
            const SizedBox(height: 14),
            _field(_timingsController, "TIMINGS", "e.g. 8 AM – 9 PM", null),
            const SizedBox(height: 14),
            _field(_descController, "DESCRIPTION", "What do you serve?", null, maxLines: 2),
            const SizedBox(height: 16),

            // ── Facilities (WiFi, seating, etc.) ──
            Text("Facilities (tap to add)", style: TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kFoodFacilities.map((f) {
                final selected = _facilities.contains(f);
                return GestureDetector(
                  onTap: () => setState(() {
                    selected ? _facilities.remove(f) : _facilities.add(f);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? _accent : _accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? _accent : _accent.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(selected ? Icons.check_circle : Icons.add_circle_outline,
                            size: 13, color: selected ? Colors.white : Colors.grey),
                        const SizedBox(width: 5),
                        Text(f, style: TextStyle(color: selected ? Colors.white : _accent, fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Menu (per-item prices) ──
            Row(
              children: [
                Text("Menu & Prices", style: TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 6),
                Text("(har item ka apna rate)", style: TextStyle(color: onSurface.withValues(alpha: 0.5), fontSize: 10)),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_itemNames.length, (i) => _menuRow(i)),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => setState(_addMenuRow),
              icon: const Icon(Icons.add, size: 18, color: _accent),
              label: const Text("Add another item", style: TextStyle(color: _accent, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),

            // ── Menu link / QR / website ──
            _field(_menuLinkController, "MENU / WEBSITE / QR LINK (optional)", "https://... or Google Maps / menu link", null),
            const SizedBox(height: 16),

            _toggle("Home delivery available", _delivery, (v) => setState(() => _delivery = v), Icons.delivery_dining),
            if (_delivery)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.social_distance, size: 16, color: _accent),
                        const SizedBox(width: 6),
                        Text("Delivery distance", style: TextStyle(color: onSurface, fontSize: 13)),
                        const Spacer(),
                        Text("up to ${_deliveryKm.toInt()} km",
                            style: const TextStyle(color: _accent, fontWeight: FontWeight.w800, fontSize: 13)),
                      ],
                    ),
                    Slider(
                      value: _deliveryKm,
                      min: 1,
                      max: 30,
                      divisions: 29,
                      activeColor: _accent,
                      label: "${_deliveryKm.toInt()} km",
                      onChanged: (v) => setState(() => _deliveryKm = v),
                    ),
                  ],
                ),
              ),
            _toggle("I cook on request (no fixed shop)", _cookOnRequest, (v) => setState(() => _cookOnRequest = v), Icons.soup_kitchen),
            _toggle("Off-market / away from main bazaar", _offMarket, (v) => setState(() => _offMarket = v), Icons.explore_off),
            const SizedBox(height: 16),

            const Text("GPS LOCATION", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _useMyLocation,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _locationSet ? const Color(0xFF10B981) : onSurface.withValues(alpha: 0.1)),
                ),
                child: Text(
                  _acquiringGps
                      ? "⏳ Getting GPS fix..."
                      : _locationSet
                          ? "📍 Location Set"
                          : "⚠️ Tap to set my GPS location",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _locationSet ? const Color(0xFF10B981) : Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: _accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_isEdit ? "💾 Save Changes" : "🍲 Broadcast & Host Food",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );

    // Host "home" view: a dashboard of My Food Listings with live table layout
    // and per-item stock, plus a + button to register a new food service.
    final isFoodHostHome = !_isEdit && !widget.registerNew;
    if (isFoodHostHome) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        floatingActionButton: FloatingActionButton.extended(
          heroTag: "add_food_fab",
          backgroundColor: _accent,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text("Add Food Service", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => HostFoodScreen(
                registerNew: true,
                onRegistered: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        ),
        body: _buildFoodDashboard(context, provider, primaryText, subText),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(_isEdit ? "Edit Listing" : "Register a New Food Service",
            style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 16)),
        iconTheme: IconThemeData(color: primaryText),
      ),
      body: body,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HOST DASHBOARD — My Food Listings with a live table layout + per-item stock
  // under each place. The + button (FAB) opens the registration form.
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFoodDashboard(BuildContext context, FoodProvider provider, Color primaryText, Color? subText) {
    final mine = provider.places.where((p) => samePhone(p.phone, _profile.phone)).toList();
    final reqCount = provider.requests.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 96), // bottom pad for FAB
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Travellers looking for food
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodRequestsScreen())),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accent.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(backgroundColor: Color(0x22F59E0B), child: Icon(Icons.ramen_dining, color: _accent, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Travellers Looking for Food", style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text("$reqCount active food requests", style: const TextStyle(color: _accent, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: _accent),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          if (_profile.isRegistered)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accent.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: _accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("Hosting as: ${_profile.name} (${_profile.phone})",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryText)),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              const Icon(Icons.storefront, color: _accent, size: 20),
              const SizedBox(width: 6),
              Text("My Food Listings", style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 4),
          Text("Tap a table to mark free/busy · use − + to update plates left",
              style: TextStyle(color: subText, fontSize: 11)),
          const SizedBox(height: 14),

          if (mine.isEmpty)
            _buildFoodEmptyState(context, primaryText, subText)
          else
            ...mine.map((p) => _foodDashboardCard(context, provider, p, primaryText, subText)),
        ],
      ),
    );
  }

  Widget _buildFoodEmptyState(BuildContext context, Color primaryText, Color? subText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.storefront_outlined, size: 54, color: _accent.withValues(alpha: 0.5)),
          const SizedBox(height: 14),
          Text("No food service yet", style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            "Register your restaurant, cafe, dhaba or home kitchen — then set up tables and show what's left on the menu.",
            textAlign: TextAlign.center,
            style: TextStyle(color: subText, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => HostFoodScreen(registerNew: true, onRegistered: () => Navigator.of(ctx).pop()),
              ),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("Register your first food service", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _foodDashboardCard(BuildContext context, FoodProvider provider, FoodPlace p, Color primaryText, Color? subText) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photo = p.allPhotos.isNotEmpty ? p.allPhotos.first : '';
    Widget thumb;
    if (photo.startsWith('http')) {
      thumb = AppNetworkImage(photo, width: 44, height: 44);
    } else if (photo.isNotEmpty && File(photo).existsSync()) {
      thumb = Image.file(File(photo), width: 44, height: 44, fit: BoxFit.cover);
    } else {
      thumb = Container(width: 44, height: 44, color: _accent.withValues(alpha: 0.15), child: const Icon(Icons.restaurant, color: _accent, size: 20));
    }

    // Tables make sense for sit-down Restaurants & Cafes (some cafes are big).
    // Dhabas, Chinese corners, home kitchens etc. just need stock management.
    final dineIn = p.foodType == 'Restaurant' || p.foodType == 'Cafe';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: thumb),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text("${p.foodType} · ${p.cuisine} · ⭐ ${p.rating.toStringAsFixed(1)}",
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
                  MaterialPageRoute(builder: (_) => HostFoodScreen(existing: p, onRegistered: () {})),
                ),
                icon: const Icon(Icons.edit, color: _accent, size: 19),
              ),
              IconButton(
                tooltip: 'Promote (Ad)',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () => _promoteFood(context, p),
                icon: const Icon(Icons.campaign, color: Color(0xFF10B981), size: 20),
              ),
              IconButton(
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () => _confirmDeleteFood(context, p),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 19),
              ),
            ],
          ),
          if (dineIn || p.tables.isNotEmpty) ...[
            const SizedBox(height: 12),
            _tableLayoutGrid(context, provider, p, primaryText, subText),
          ],
          const SizedBox(height: 12),
          _menuStockSection(context, provider, p, primaryText, subText),
        ],
      ),
    );
  }

  /// Live, tappable table layout shown under a dine-in food place.
  Widget _tableLayoutGrid(BuildContext context, FoodProvider provider, FoodPlace p, Color primaryText, Color? subText) {
    if (p.tables.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ManageFoodLayoutScreen(place: p)),
          ),
          icon: const Icon(Icons.table_restaurant, color: _accent, size: 18),
          label: const Text("Set up table layout", style: TextStyle(color: _accent, fontWeight: FontWeight.w800)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: _accent)),
        ),
      );
    }

    final free = p.freeTables;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_restaurant, color: _accent, size: 16),
              const SizedBox(width: 6),
              Text("Table Layout", style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 13)),
              const Spacer(),
              Text("$free free / ${p.tables.length}",
                  style: TextStyle(color: free == 0 ? Colors.redAccent : const Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManageFoodLayoutScreen(place: p)),
                ),
                child: const Text("Manage »",
                    style: TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(p.tables.length, (i) {
              final t = p.tables[i];
              final c = t.occupied ? Colors.redAccent : const Color(0xFF10B981);
              return GestureDetector(
                onTap: () => _toggleTableOccupied(provider, p, i),
                child: Container(
                  width: 64,
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c, width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t.occupied ? Icons.event_seat : Icons.event_seat_outlined, color: c, size: 18),
                      const SizedBox(height: 2),
                      Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c, fontSize: 8.5, height: 1.1, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text("🟢 free · 🔴 busy — tap a table to change",
              style: TextStyle(color: subText, fontSize: 10.5)),
          if (p.seatingPhotos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text("Seating area", style: TextStyle(color: subText, fontSize: 10, letterSpacing: 0.4, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            SeatingPhotoStrip(photos: p.seatingPhotos, height: 76),
          ],
        ],
      ),
    );
  }

  /// Per-item stock ("kitne plate bache hain") with quick − / + steppers.
  Widget _menuStockSection(BuildContext context, FoodProvider provider, FoodPlace p, Color primaryText, Color? subText) {
    if (p.menu.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => HostFoodScreen(existing: p, onRegistered: () {})),
          ),
          icon: const Icon(Icons.restaurant_menu, color: _accent, size: 18),
          label: const Text("Add menu items (Edit)", style: TextStyle(color: _accent, fontWeight: FontWeight.w800)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: _accent)),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2, color: _accent, size: 16),
              const SizedBox(width: 6),
              Text("Today's Menu Stock", style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 13)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManageFoodLayoutScreen(place: p)),
                ),
                child: const Text("Manage »",
                    style: TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(p.menu.length, (i) => _stockRow(provider, p, i, primaryText, subText)),
          const SizedBox(height: 2),
          Text("− / + = plates left · 0 = sold out · ∞ = always available",
              style: TextStyle(color: subText, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _stockRow(FoodProvider provider, FoodPlace p, int i, Color primaryText, Color? subText) {
    final m = p.menu[i];
    final out = m.qtyLeft == 0;
    final tracked = m.qtyLeft >= 0;
    final statusColor = out ? Colors.redAccent : (tracked ? const Color(0xFF10B981) : subText);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: out ? subText : primaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        decoration: out ? TextDecoration.lineThrough : null)),
                Text(
                    out
                        ? "SOLD OUT"
                        : tracked
                            ? "${m.qtyLeft} plates left · ₹${m.price.toInt()}"
                            : "Available · ₹${m.price.toInt()}",
                    style: TextStyle(color: statusColor, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: () => _changeStock(provider, p, i, -1),
            icon: const Icon(Icons.remove_circle_outline, color: _accent, size: 22),
          ),
          SizedBox(
            width: 26,
            child: Text(tracked ? "${m.qtyLeft}" : "∞",
                textAlign: TextAlign.center,
                style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 14)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            onPressed: () => _changeStock(provider, p, i, 1),
            icon: const Icon(Icons.add_circle_outline, color: _accent, size: 22),
          ),
        ],
      ),
    );
  }

  /// Flip one table's occupied flag and persist.
  void _toggleTableOccupied(FoodProvider provider, FoodPlace p, int index) {
    final tables = List<TableUnit>.from(p.tables);
    final t = tables[index];
    tables[index] = TableUnit(id: t.id, name: t.name, seats: t.seats, occupied: !t.occupied);
    provider.updateFoodPlace(p.copyWith(tables: tables));
  }

  /// Adjust plates-left for one menu item. delta +1 / -1. Untracked (∞) → first
  /// "+" sets 1, first "−" sets 0 (sold out).
  void _changeStock(FoodProvider provider, FoodPlace p, int index, int delta) {
    final menu = List<MenuItem>.from(p.menu);
    final m = menu[index];
    int q = m.qtyLeft;
    if (delta > 0) {
      q = q < 0 ? 1 : q + 1;
    } else {
      q = q < 0 ? 0 : (q > 0 ? q - 1 : 0);
    }
    menu[index] = MenuItem(name: m.name, price: m.price, available: q != 0, qtyLeft: q);
    provider.updateFoodPlace(p.copyWith(menu: menu));
  }

  Future<void> _promoteFood(BuildContext context, FoodPlace p) async {
    final messenger = ScaffoldMessenger.of(context);
    final adId = 'sponsor_${p.id}';

    // If an ad is already live for this listing → offer to stop it.
    if (await LocalStorageService.hasAd(adId)) {
      if (!context.mounted) return;
      final stop = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('📣 Ad is live'),
          content: Text('"${p.title}" is currently advertised across Spiti Setu. Stop this ad?'),
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
          'Feature "${p.title}" as a sponsored ad on the Ride, Stay & Food screens for all travellers.\n\n₹199 / week.',
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

    // Use an uploaded URL photo for the ad if available (local paths won't load
    // on other devices); else a default food image.
    final urlPhoto = p.allPhotos.firstWhere((x) => x.startsWith('http'), orElse: () => '');
    await LocalStorageService.addAd({
      'id': 'sponsor_${p.id}',
      'title': '🍲 ${p.title}',
      'body': p.menu.isNotEmpty ? '${p.cuisine} · from ₹${p.fromPrice.toInt()}' : p.description,
      'imageUrl': urlPhoto.isNotEmpty
          ? urlPhoto
          : 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&q=80&w=400',
      'isActive': true,
      'link': p.phone,
      'category': 'food',
      'sponsor': p.phone,
      'paid': true,
    });
    messenger.showSnackBar(
      const SnackBar(
        content: Text('🎉 Payment received — your ad is now live across Spiti Setu!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  Future<void> _confirmDeleteFood(BuildContext context, FoodPlace p) async {
    final provider = Provider.of<FoodProvider>(context, listen: false);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete listing?'),
        content: Text('Remove "${p.title}" permanently? This cannot be undone.'),
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
      provider.deleteFoodPlace(p.id);
      LocalStorageService.removeAd('sponsor_${p.id}'); // clean up its ad too
    }
  }

  Widget _menuRow(int i) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _field(_itemNames[i], "ITEM", "e.g. Veg Thukpa", null),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _field(_itemPrices[i], "₹ PRICE", "120", null, isNumber: true),
          ),
          IconButton(
            onPressed: _itemNames.length == 1
                ? null
                : () => setState(() {
                      _itemNames.removeAt(i).dispose();
                      _itemPrices.removeAt(i).dispose();
                    }),
            icon: Icon(Icons.remove_circle_outline, color: _itemNames.length == 1 ? Colors.grey : Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _accent : _accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _accent : _accent.withValues(alpha: 0.25)),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : _accent, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged, IconData icon) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: _accent,
      contentPadding: EdgeInsets.zero,
      dense: true,
      secondary: Icon(icon, color: _accent, size: 20),
      title: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13)),
    );
  }

  Widget _field(TextEditingController c, String label, String hint, String? Function(String?)? validator,
      {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: c,
      validator: validator,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 9),
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _accent),
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
