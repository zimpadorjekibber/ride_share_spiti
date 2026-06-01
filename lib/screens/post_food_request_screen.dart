import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_model.dart';
import '../models/stay_model.dart';
import '../services/local_storage_service.dart';
import '../models/booked_trip_model.dart';

class PostFoodRequestScreen extends StatefulWidget {
  const PostFoodRequestScreen({super.key});

  @override
  State<PostFoodRequestScreen> createState() => _PostFoodRequestScreenState();
}

class _PostFoodRequestScreenState extends State<PostFoodRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _whenController = TextEditingController();
  final _noteController = TextEditingController();

  int _people = 2;
  double _budget = 200;
  String _vegPref = 'Both';
  String _cuisine = 'Spitian / Local';
  bool _submitting = false;
  UserProfile _profile = UserProfile();

  static const Color _accent = Color(0xFFF59E0B);

  final List<String> _places = kSpitiVillages;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await LocalStorageService.getProfile();
    if (mounted) {
      setState(() {
        _profile = p;
        if (p.isRegistered) {
          _nameController.text = p.name;
          _phoneController.text = p.phone;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _whenController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final req = FoodRequest(
      id: 'fr_${DateTime.now().millisecondsSinceEpoch}',
      seekerName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      locationLooking: _locationController.text.trim(),
      peopleCount: _people,
      vegPref: _vegPref,
      cuisineWanted: _cuisine,
      budgetPerPlate: _budget,
      whenNeeded: _whenController.text.trim().isEmpty ? 'ASAP' : _whenController.text.trim(),
      note: _noteController.text.trim(),
      lat: _profile.currentLat != 0.0 ? _profile.currentLat : 32.2276,
      lng: _profile.currentLng != 0.0 ? _profile.currentLng : 78.0710,
      createdAt: DateTime.now(),
    );

    Provider.of<FoodProvider>(context, listen: false).postFoodRequest(req);
    setState(() => _submitting = false);
    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📢 Food need broadcast! Local cooks & dhabas will call you.'),
          backgroundColor: _accent,
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
        leading: IconButton(icon: Icon(Icons.arrow_back, color: primaryText), onPressed: () => Navigator.pop(context)),
        title: Text('Broadcast Food Need', style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 16)),
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
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _accent.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: _accent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Tell local cooks, dhabas & cafes what you need — they'll reach out to feed you!",
                              style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 11, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text("Your Contact", style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
                      child: _profile.isRegistered
                          ? Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.12), shape: BoxShape.circle),
                                  child: const Icon(Icons.verified_user, color: Color(0xFF10B981), size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Broadcasting as: ${_profile.name}",
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text("Phone: ${_profile.phone}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _field(_nameController, "Your Name", Icons.person, (v) => v!.trim().isEmpty ? "Enter name" : null),
                                const SizedBox(height: 12),
                                _field(_phoneController, "Phone", Icons.phone, (v) => v!.trim().length < 10 ? "Enter valid phone" : null, type: TextInputType.phone),
                              ],
                            ),
                    ),
                    const SizedBox(height: 20),
                    Text("What & Where", style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
                      child: Column(
                        children: [
                          Autocomplete<String>(
                            optionsBuilder: (v) => v.text.isEmpty
                                ? const Iterable<String>.empty()
                                : _places.where((p) => p.toLowerCase().contains(v.text.toLowerCase())),
                            onSelected: (s) => _locationController.text = s,
                            fieldViewBuilder: (ctx, controller, focus, onSubmit) {
                              if (_locationController.text.isNotEmpty && controller.text.isEmpty) {
                                controller.text = _locationController.text;
                              }
                              return _field(controller, "LOCATION (e.g. Kaza, Kibber)", Icons.location_on, (v) {
                                _locationController.text = v!;
                                return v.trim().isEmpty ? "Where are you?" : null;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          _field(_whenController, "WHEN (e.g. Tonight 8 PM)", Icons.schedule, null),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('People', style: TextStyle(color: primaryText, fontWeight: FontWeight.w600, fontSize: 13)),
                              Row(
                                children: [
                                  _counter(Icons.remove, () { if (_people > 1) setState(() => _people--); }, isDark),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text('$_people', style: TextStyle(color: primaryText, fontSize: 16, fontWeight: FontWeight.w800)),
                                  ),
                                  _counter(Icons.add, () { if (_people < 20) setState(() => _people++); }, isDark),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Max budget / plate', style: TextStyle(color: primaryText, fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text('₹${_budget.toInt()}', style: const TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                              Slider(
                                value: _budget,
                                min: 50,
                                max: 800,
                                divisions: 15,
                                activeColor: _accent,
                                inactiveColor: border,
                                label: '₹${_budget.toInt()}',
                                onChanged: (v) => setState(() => _budget = v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text("Veg preference", style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, children: kVegPrefs.map((v) => _selectChip(v, _vegPref == v, () => setState(() => _vegPref = v))).toList()),
                    const SizedBox(height: 20),
                    Text("Cuisine you want", style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: kCuisines.map((c) => _selectChip(c, _cuisine == c, () => setState(() => _cuisine = c))).toList()),
                    const SizedBox(height: 20),
                    _field(_noteController, "Notes (e.g. need delivery, allergies)", Icons.notes, null, maxLines: 3),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.campaign, color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text("Broadcast Food Need", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
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

  Widget _selectChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _accent : _accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _accent : _accent.withValues(alpha: 0.25)),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : _accent, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon, String? Function(String?)? validator,
      {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return TextFormField(
      controller: c,
      validator: validator,
      keyboardType: type,
      maxLines: maxLines,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 10),
        prefixIcon: Icon(icon, color: _accent, size: 18),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _accent, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _counter(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _accent, size: 18),
      ),
    );
  }
}
