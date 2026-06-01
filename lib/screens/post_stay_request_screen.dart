import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stay_model.dart';
import '../services/local_storage_service.dart';
import '../models/booked_trip_model.dart';

class PostStayRequestScreen extends StatefulWidget {
  const PostStayRequestScreen({super.key});

  @override
  State<PostStayRequestScreen> createState() => _PostStayRequestScreenState();
}

class _PostStayRequestScreenState extends State<PostStayRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();
  final _datesController = TextEditingController();
  int _guestsCount = 2;
  double _budgetPerNight = 1200.0;
  bool _submitting = false;
  UserProfile _userProfile = UserProfile();
  String _propertyType = 'Any';
  final Set<String> _desiredAmenities = {};

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

  final List<String> _spitiPlaces = kSpitiVillages;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    _datesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    if (!_userProfile.isRegistered) {
      _userProfile.name = _nameController.text.trim();
      _userProfile.phone = _phoneController.text.trim();
      _userProfile.isRegistered = true;
      await LocalStorageService.saveProfile(_userProfile);
    }

    if (!mounted) return;

    final request = StayRequest(
      id: "sr_${DateTime.now().millisecondsSinceEpoch}",
      seekerName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      locationLooking: _locationController.text.trim(),
      guestsCount: _guestsCount,
      budgetPerNight: _budgetPerNight,
      dates: _datesController.text.trim().isEmpty ? "Next Week" : _datesController.text.trim(),
      note: _noteController.text.trim(),
      lat: _userProfile.currentLat != 0.0 ? _userProfile.currentLat : 32.2276,
      lng: _userProfile.currentLng != 0.0 ? _userProfile.currentLng : 78.0710,
      createdAt: DateTime.now(),
      propertyType: _propertyType,
      desiredAmenities: _desiredAmenities.toList(),
    );

    Provider.of<StayProvider>(context, listen: false).postStayRequest(request);

    setState(() => _submitting = false);
    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📢 Room requirement post kar diya! Spiti hosts details check karenge.'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final border = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'FindStay Seeker Request',
          style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      body: _submitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Heading Info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF0D9488), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Post your requirements, local mud-house hosts in Spiti will view and call you directly to offer rooms!",
                              style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 11, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Prefilled Profile Info / Registration
                    Text(
                      "Your Contact Details",
                      style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: _userProfile.isRegistered
                          ? Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.verified_user, color: Color(0xFF10B981), size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Broadcasting as: ${_userProfile.name}",
                                        style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Phone: ${_userProfile.phone}",
                                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _inputField(_nameController, "Your Full Name", Icons.person, (val) => val!.trim().isEmpty ? "Name matches verify field" : null),
                                const SizedBox(height: 12),
                                _inputField(_phoneController, "Phone Number", Icons.phone, (val) => val!.trim().length < 10 ? "Enter active mobile number" : null, keyboardType: TextInputType.phone),
                              ],
                            ),
                    ),
                    const SizedBox(height: 24),

                    // Stay Requirements Card
                    Text(
                      "Stay Preferences",
                      style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        children: [
                          // Destination Location AutoComplete
                          Autocomplete<String>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<String>.empty();
                              }
                              return _spitiPlaces.where((place) => place.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                            },
                            onSelected: (selection) => _locationController.text = selection,
                            fieldViewBuilder: (ctx, controller, focus, onSubmit) {
                              if (_locationController.text.isNotEmpty && controller.text.isEmpty) {
                                controller.text = _locationController.text;
                              }
                              return _inputField(controller, "LOCATION LOOKING IN (e.g. Kaza, Kibber)", Icons.location_searching, (val) {
                                _locationController.text = val!;
                                return val.trim().isEmpty ? "Specify target Spiti village" : null;
                              });
                            },
                          ),
                          const SizedBox(height: 14),

                          // Travel dates
                          _inputField(_datesController, "TRAVEL DATES (e.g. 5 June - 8 June)", Icons.calendar_month, (val) => val!.trim().isEmpty ? "Specify travel dates" : null),
                          const SizedBox(height: 20),

                          // Guests selector
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Guests Count', style: TextStyle(color: primaryText, fontWeight: FontWeight.w600, fontSize: 13)),
                              Row(
                                children: [
                                  _counterBtn(Icons.remove, () {
                                    if (_guestsCount > 1) {
                                      setState(() => _guestsCount--);
                                    }
                                  }, isDark),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      '$_guestsCount',
                                      style: TextStyle(color: primaryText, fontSize: 16, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  _counterBtn(Icons.add, () {
                                    if (_guestsCount < 10) {
                                      setState(() => _guestsCount++);
                                    }
                                  }, isDark),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Budget slider
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Max Budget (Per Night)', style: TextStyle(color: primaryText, fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text(
                                    '₹${_budgetPerNight.toInt()}',
                                    style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              Slider(
                                value: _budgetPerNight,
                                min: 400.0,
                                max: 5000.0,
                                divisions: 46,
                                activeColor: const Color(0xFF0D9488),
                                inactiveColor: border,
                                label: '₹${_budgetPerNight.toInt()}',
                                onChanged: (val) => setState(() => _budgetPerNight = val),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Property type selector
                    Text(
                      "Which type of stay?",
                      style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kPropertyTypes.map((type) {
                        final selected = _propertyType == type;
                        return GestureDetector(
                          onTap: () => setState(() => _propertyType = type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFF0D9488) : const Color(0xFF0D9488).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: selected ? const Color(0xFF0D9488) : const Color(0xFF0D9488).withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              type == 'Any' ? 'Any / No Preference' : type,
                              style: TextStyle(
                                color: selected ? Colors.white : const Color(0xFF0D9488),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Desired services / amenities
                    Text(
                      "Services you need",
                      style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Hosts who offer these will be able to find and call you.",
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kExtraAmenities.map((a) {
                        final selected = _desiredAmenities.contains(a);
                        return GestureDetector(
                          onTap: () => setState(() {
                            selected ? _desiredAmenities.remove(a) : _desiredAmenities.add(a);
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? const Color(0xFF14B8A6) : cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: selected ? const Color(0xFF14B8A6) : border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  selected ? Icons.check_circle : Icons.add_circle_outline,
                                  size: 14,
                                  color: selected ? Colors.white : Colors.grey,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  a,
                                  style: TextStyle(
                                    color: selected ? Colors.white : primaryText,
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
                    const SizedBox(height: 24),

                    // Additional note
                    _inputField(_noteController, "Special Requirements / Notes (e.g. Bukhari or geyser needed)", Icons.notes, null, maxLines: 3),
                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.campaign, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text(
                              "Broadcast Stay Need",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _inputField(
    TextEditingController controller,
    String label,
    IconData icon,
    String? Function(String?)? validator, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 10),
        prefixIcon: Icon(icon, color: const Color(0xFF0D9488), size: 18),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF0D9488), size: 18),
      ),
    );
  }
}
