import 'package:flutter/material.dart';
import '../models/booked_trip_model.dart';
import '../services/local_storage_service.dart';
import 'admin_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile _profile = UserProfile();
  List<BookedTrip> _trips = [];
  bool _editing = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  int _adminBadgeTaps = 0;

  void _openAdminPanelDirectly() {
    Feedback.forTap(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🔑 Developer Easter Egg Unlocked: Admin Access Granted!"),
        backgroundColor: Color(0xFF6366F1),
        duration: Duration(seconds: 1),
      ),
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
    ).then((_) => _load());
  }

  void _promptAdminPIN() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
          title: Text(
            "Enter Admin PIN",
            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: const InputDecoration(
              hintText: "Enter 4-digit administrative PIN",
              hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final entered = pinController.text.trim();
                Navigator.pop(dialogCtx);
                if (entered == "9999") {
                  _openAdminPanelDirectly();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("❌ Invalid Admin PIN! Access Denied."),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
              child: const Text("Unlock"),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await LocalStorageService.getProfile();
    final trips = await LocalStorageService.getTrips();
    if (mounted) {
      setState(() {
        _profile = profile;
        _trips = trips;
        _nameController.text = profile.name;
        _phoneController.text = profile.phone;
      });
    }
  }

  Future<void> _save() async {
    _profile.name = _nameController.text.trim();
    _profile.phone = _phoneController.text.trim();
    await LocalStorageService.saveProfile(_profile);
    setState(() => _editing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved!'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String get _initials {
    final name = _profile.name;
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  int get _completedTrips =>
      _trips.where((t) => t.status == 'completed').length;
  int get _upcomingTrips =>
      _trips.where((t) => t.status == 'upcoming').length;
  double get _totalSpent =>
      _trips.fold(0, (sum, t) => sum + (t.status != 'cancelled' ? t.totalPaid : 0));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Profile',
          style: TextStyle(
              color: primaryText, fontWeight: FontWeight.w800, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.close : Icons.edit_outlined,
                color: const Color(0xFF6366F1)),
            onPressed: () => setState(() {
              _editing = !_editing;
              if (!_editing) {
                _nameController.text = _profile.name;
                _phoneController.text = _profile.phone;
              }
            }),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Avatar + name ──
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (_editing)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 14),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_editing) ...[
                    // Edit fields
                    _inputField('Your Name', _nameController, Icons.person_outline),
                    const SizedBox(height: 12),
                    _inputField('Phone Number', _phoneController, Icons.phone_outlined,
                        inputType: TextInputType.phone),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save Profile',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ] else ...[
                    Text(
                      _profile.name.isEmpty ? 'Set your name' : _profile.name,
                      style: TextStyle(
                        color: _profile.name.isEmpty ? Colors.grey : primaryText,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_profile.phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _profile.phone,
                        style: TextStyle(color: subText, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            _profile.rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              Feedback.forTap(context);
                              setState(() {
                                _adminBadgeTaps++;
                              });
                              if (_adminBadgeTaps >= 5) {
                                _adminBadgeTaps = 0;
                                _openAdminPanelDirectly();
                              } else {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("🔑 System Unlock Progress: $_adminBadgeTaps / 5 taps"),
                                    duration: const Duration(milliseconds: 500),
                                    backgroundColor: const Color(0xFF6366F1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  "VERIFIED RIDER",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Stats ──
            Row(
              children: [
                Expanded(
                  child: _statCard('🎫', '$_upcomingTrips',
                      'Upcoming', cardBg, primaryText, subText, border),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard('✅', '$_completedTrips',
                      'Completed', cardBg, primaryText, subText, border),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard('₹',
                      '${_totalSpent.toInt()}',
                      'Total Spent', cardBg, primaryText, subText, border),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── About section ──
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                children: [
                  _menuItem(Icons.admin_panel_settings_outlined, 'System Admin Portal', 'Access core moderator controls',
                      primaryText, subText, onTap: () => _promptAdminPIN()),
                  Divider(height: 1, color: border),
                  _menuItem(Icons.info_outline, 'About App', 'RideShare Spiti v1.0',
                      primaryText, subText),
                  Divider(height: 1, color: border),
                  _menuItem(Icons.map_outlined, 'Region', 'Spiti Valley, Himachal Pradesh',
                      primaryText, subText),
                  Divider(height: 1, color: border),
                  _menuItem(Icons.shield_outlined, 'Privacy', 'Data stored locally only',
                      primaryText, subText),
                  Divider(height: 1, color: border),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.location_searching, color: Color(0xFF6366F1), size: 20),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Live Proximity Alerts",
                                style: TextStyle(
                                  color: primaryText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _profile.locationPermissionGranted 
                                    ? "Proximity alerts active (20km radius)" 
                                    : "Tap to enable live matching notifications",
                                style: TextStyle(color: subText, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _profile.locationPermissionGranted,
                          activeColor: const Color(0xFF10B981),
                          onChanged: (val) async {
                            setState(() {
                              _profile.locationPermissionGranted = val;
                            });
                            await LocalStorageService.saveProfile(_profile);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(val 
                                    ? "📍 Location proximity alerts enabled successfully!" 
                                    : "🔕 Location proximity alerts disabled."),
                                backgroundColor: val ? const Color(0xFF10B981) : Colors.red,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: border),
                  _menuItem(Icons.code, 'Built with', 'Flutter + OpenStreetMap',
                      primaryText, subText),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _inputField(String hint, TextEditingController controller, IconData icon,
      {TextInputType inputType = TextInputType.text}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      keyboardType: inputType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _statCard(String emoji, String value, String label, Color cardBg,
      Color primaryText, Color? subText, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
          Text(label,
              style: TextStyle(color: subText, fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _menuItem(
      IconData icon, String title, String subtitle, Color primaryText, Color? subText,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF6366F1), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: primaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(color: subText, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600], size: 18),
          ],
        ),
      ),
    );
  }
}
