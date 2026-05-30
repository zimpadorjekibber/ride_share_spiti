import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/passenger_request_model.dart';
import '../services/local_storage_service.dart';
import '../models/booked_trip_model.dart';

class PostRequestScreen extends StatefulWidget {
  const PostRequestScreen({super.key});

  @override
  State<PostRequestScreen> createState() => _PostRequestScreenState();
}

class _PostRequestScreenState extends State<PostRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _noteController = TextEditingController();
  int _seatsNeeded = 1;
  DateTime _selectedDate = DateTime.now();
  bool _submitting = false;
  UserProfile _userProfile = UserProfile();

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

  final List<String> _spitiPlaces = [
    'Manali (Mall Road)', 'Kaza (Spiti)', 'Tabo Monastery', 'Reckong Peo',
    'Shimla', 'Gramphoo', 'Losar', 'Key Monastery', 'Kibber',
    'Hikkim', 'Komic', 'Langza', 'Chandratal Lake', 'Spiti River Bridge',
    'Kalpa', 'Sangla', 'Chitkul', 'Nako', 'Kinnaur', 'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _noteController.dispose();
    super.dispose();
  }

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
    if (picked != null) setState(() => _selectedDate = picked);
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

    final request = PassengerRequest(
      id: generateRequestId(),
      passengerName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      from: _fromController.text.trim(),
      to: _toController.text.trim(),
      date: _selectedDate.toString().split(' ')[0],
      seatsNeeded: _seatsNeeded,
      note: _noteController.text.trim(),
      createdAt: DateTime.now(),
      passengerRating: _userProfile.isRegistered ? _userProfile.rating : 5.0,
    );

    await Provider.of<PassengerRequestProvider>(context, listen: false)
        .addRequest(request);

    setState(() => _submitting = false);
    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📢 Ride request broadcast kar diya! Drivers contact karenge.'),
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
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.1);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Ride Request Broadcast',
            style: TextStyle(
                color: primaryText,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Info banner ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Text('📢', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Broadcast Your Ride Need',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14)),
                          const SizedBox(height: 3),
                          Text(
                            'Drivers will see your request and contact you directly on phone.',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Section: Your Details ──
              _sectionLabel('👤 Aapki Details', subText),
              const SizedBox(height: 10),
              if (_userProfile.isRegistered) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: Color(0xFF818CF8), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        "Broadcasting as: ${_userProfile.name} (${_userProfile.phone})",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                _field(_nameController, 'Aapka Naam (Your Name)', Icons.person_outline,
                    isDark, cardBg, border,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Naam zaroori hai' : null),
                const SizedBox(height: 12),
                _field(_phoneController, 'Phone Number', Icons.phone_outlined,
                    isDark, cardBg, border,
                    inputType: TextInputType.phone,
                    validator: (v) =>
                        v == null || v.length < 10 ? 'Valid phone dalein' : null),
              ],

              const SizedBox(height: 24),

              // ── Section: Journey ──
              _sectionLabel('🗺️ Journey Details', subText),
              const SizedBox(height: 10),

              // From dropdown
              _dropdownField('Kahan se (From)', Icons.trip_origin,
                  _fromController, _spitiPlaces, isDark, cardBg, border,
                  primaryText, subText),
              const SizedBox(height: 12),

              // To dropdown
              _dropdownField('Kahan tak (To)', Icons.location_on_outlined,
                  _toController, _spitiPlaces, isDark, cardBg, border,
                  primaryText, subText),
              const SizedBox(height: 12),

              // Date picker
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: Color(0xFF6366F1), size: 20),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Travel Date',
                              style:
                                  TextStyle(color: subText, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            _selectedDate.toString().split(' ')[0],
                            style: TextStyle(
                                color: primaryText,
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Icon(Icons.edit_calendar_outlined,
                          color: const Color(0xFF6366F1), size: 18),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Seats needed ──
              _sectionLabel('💺 Kitni Seats Chahiye?', subText),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Seats Needed',
                        style: TextStyle(
                            color: primaryText, fontWeight: FontWeight.w600)),
                    Row(
                      children: [
                        _counterBtn(Icons.remove, () {
                          if (_seatsNeeded > 1)
                            setState(() => _seatsNeeded--);
                        }, isDark),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '$_seatsNeeded',
                            style: TextStyle(
                                color: primaryText,
                                fontSize: 20,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                        _counterBtn(Icons.add, () {
                          if (_seatsNeeded < 8)
                            setState(() => _seatsNeeded++);
                        }, isDark),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Note ──
              _sectionLabel('📝 Extra Note (Optional)', subText),
              const SizedBox(height: 10),
              _field(_noteController, 'e.g. Morning only, have luggage, etc.',
                  Icons.note_outlined, isDark, cardBg, border,
                  maxLines: 3, required: false),

              const SizedBox(height: 32),

              // ── Submit ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.campaign, color: Colors.white),
                  label: Text(
                    _submitting ? 'Broadcasting...' : '📢 Broadcast Ride Request',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color? color) => Text(
        text,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w700, fontSize: 14),
      );

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      bool isDark, Color cardBg, Color border,
      {TextInputType inputType = TextInputType.text,
      String? Function(String?)? validator,
      int maxLines = 1,
      bool required = true}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: inputType,
      maxLines: maxLines,
      style: TextStyle(
          color: isDark ? Colors.white : Colors.black87, fontSize: 15),
      validator: required
          ? (validator ??
              (v) => v == null || v.isEmpty ? '$hint zaroori hai' : null)
          : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
        filled: true,
        fillColor: cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _dropdownField(String hint, IconData icon,
      TextEditingController ctrl, List<String> options, bool isDark,
      Color cardBg, Color border, Color primaryText, Color? subText) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6366F1), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value:
                    ctrl.text.isEmpty ? null : ctrl.text,
                hint: Text(hint,
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 13)),
                dropdownColor: isDark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                style: TextStyle(
                    color: primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
                isExpanded: true,
                items: options
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p,
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => ctrl.text = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF6366F1), size: 18),
      ),
    );
  }
}
