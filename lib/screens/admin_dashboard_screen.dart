import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ride_model.dart';
import '../models/passenger_request_model.dart';
import '../services/local_storage_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _ads = [];
  List<Map<String, dynamic>> _verifications = [];
  bool _loading = true;

  // New Ad controller
  final _adTitleController = TextEditingController();
  final _adBodyController = TextEditingController();
  final _adLinkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    final ads = await LocalStorageService.getAds();
    final verifs = await LocalStorageService.getVerifications();
    if (mounted) {
      setState(() {
        _ads = ads;
        _verifications = verifs;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _adTitleController.dispose();
    _adBodyController.dispose();
    _adLinkController.dispose();
    super.dispose();
  }

  // ─── Verification Actions ───────────────────────────
  Future<void> _approveDriverDoc(int index) async {
    setState(() => _loading = true);
    final list = List<Map<String, dynamic>>.from(_verifications);
    list[index]['isApproved'] = true;
    await LocalStorageService.saveVerifications(list);
    await _loadAdminData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Documents for ${list[index]['driverName']} verified successfully!"),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  // ─── Ads Actions ─────────────────────────────────────
  Future<void> _toggleAdStatus(int index, bool active) async {
    final list = List<Map<String, dynamic>>.from(_ads);
    list[index]['isActive'] = active;
    await LocalStorageService.saveAds(list);
    await _loadAdminData();
  }

  Future<void> _addNewAd() async {
    if (_adTitleController.text.trim().isEmpty || _adBodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Title and Body are required!"),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final newAd = {
      'id': 'ad_${DateTime.now().millisecondsSinceEpoch}',
      'title': _adTitleController.text.trim(),
      'body': _adBodyController.text.trim(),
      'imageUrl': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&q=80&w=400',
      'isActive': true,
      'link': _adLinkController.text.trim().isEmpty ? 'Contact Admin' : _adLinkController.text.trim(),
    };

    final list = List<Map<String, dynamic>>.from(_ads);
    list.add(newAd);
    await LocalStorageService.saveAds(list);

    _adTitleController.clear();
    _adBodyController.clear();
    _adLinkController.clear();

    await _loadAdminData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("📢 New Ad Campaign launched successfully!"),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  // ─── Safety Moderation Action ──────────────────────
  void _moderateUser(BuildContext context, String name, bool isDriver) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1F2937) : Colors.white;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text(
          "Safety Audit: $name",
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Flag safety concern or clear rating records for this user.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _flagUserAsBadmash(name, isDriver);
              },
              icon: const Icon(Icons.gpp_bad, color: Colors.white),
              label: const Text("Flag for Rash Driving / Bad Behavior"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 42),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _clearUserFlags(name, isDriver);
              },
              icon: const Icon(Icons.verified, color: Color(0xFF10B981)),
              label: const Text("Clear Flags & Mark Verified"),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF10B981),
                side: const BorderSide(color: Color(0xFF10B981)),
                minimumSize: const Size(double.infinity, 42),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _flagUserAsBadmash(String name, bool isDriver) async {
    if (isDriver) {
      Provider.of<RideProvider>(context, listen: false)
          .moderateDriver(name, flagAsBad: true);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🛑 Flagged $name for dangerous behavior! Rating adjusted down."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _clearUserFlags(String name, bool isDriver) async {
    if (isDriver) {
      Provider.of<RideProvider>(context, listen: false)
          .moderateDriver(name, flagAsBad: false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Cleared all community flags for $name. Status: Verified!"),
          backgroundColor: const Color(0xFF10B981),
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
        : Colors.black.withValues(alpha: 0.08);

    final rideProvider = Provider.of<RideProvider>(context);
    final requestProvider = Provider.of<PassengerRequestProvider>(context);

    final pendingCount = _verifications.where((v) => v['isApproved'] == false).length;
    final activeAdsCount = _ads.where((a) => a['isActive'] == true).length;

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: bg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: primaryText),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.only(left: 20, right: 20, top: 60, bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      "🛡️ Administrative Console",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Spiti Core Panel",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _metricCounter("Pending", "$pendingCount", Colors.orangeAccent),
                        const SizedBox(width: 8),
                        _metricCounter("Active Ads", "$activeAdsCount", const Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        _metricCounter("Total Rides", "${rideProvider.rides.length}", const Color(0xFF818CF8)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF6366F1),
                labelColor: const Color(0xFF6366F1),
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: "👥 Users & Safety"),
                  Tab(text: "🪪 Verification"),
                  Tab(text: "📢 Ads Toggle"),
                ],
              ),
              bg,
            ),
          ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Safety & Users Control
                  _buildUsersTab(rideProvider, requestProvider, cardBg, border, primaryText, subText),
                  // Tab 2: Document Verification
                  _buildVerificationTab(cardBg, border, primaryText, subText),
                  // Tab 3: Ads & Campaigns Manager
                  _buildAdsTab(cardBg, border, primaryText, subText),
                ],
              ),
      ),
    );
  }

  Widget _metricCounter(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            "$count $label",
            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab(
      RideProvider rideProvider,
      PassengerRequestProvider reqProvider,
      Color cardBg,
      Color border,
      Color primaryText,
      Color? subText) {
    final rides = rideProvider.rides;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length,
      itemBuilder: (context, index) {
        final r = rides[index];
        final isBanned = r.driverRating < 4.0;

        return Card(
          color: cardBg,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: border),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              backgroundColor: isBanned ? Colors.red.withValues(alpha: 0.1) : const Color(0xFF6366F1).withValues(alpha: 0.1),
              child: Text(
                isBanned ? "⚠️" : "👤",
                style: const TextStyle(fontSize: 16),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    r.driverName,
                    style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.star, color: Colors.amber, size: 14),
                const SizedBox(width: 2),
                Text(
                  r.driverRating.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 3),
                Text("Vehicle: ${r.vehicleName} (${r.plateNumber})", style: TextStyle(color: subText, fontSize: 11)),
                if (isBanned) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "🛑 FLAGGED / COMMUNITY WARNING ACTIVE",
                      style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.security_outlined, color: Color(0xFF6366F1)),
              onPressed: () => _moderateUser(context, r.driverName, true),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerificationTab(Color cardBg, Color border, Color primaryText, Color? subText) {
    if (_verifications.isEmpty) {
      return const Center(child: Text("No driver verifications found."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _verifications.length,
      itemBuilder: (context, index) {
        final v = _verifications[index];
        final approved = v['isApproved'] == true;

        return Card(
          color: cardBg,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      v['driverName'],
                      style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: approved ? Colors.green.withValues(alpha: 0.15) : Colors.orangeAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        approved ? "Verified" : "Pending Approval",
                        style: TextStyle(
                          color: approved ? Colors.green : Colors.orangeAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text("Vehicle: ${v['vehicleName']}", style: TextStyle(color: subText, fontSize: 12)),
                Text("Plate Number: ${v['plateNumber']}", style: TextStyle(color: subText, fontSize: 12)),
                Text("Phone Number: ${v['phone']}", style: TextStyle(color: subText, fontSize: 12)),
                const SizedBox(height: 12),
                if (!approved)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _approveDriverDoc(index),
                      icon: const Icon(Icons.verified, color: Colors.white, size: 16),
                      label: const Text("Approve Verifications & Badges"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  )
                else
                  const Row(
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                      SizedBox(width: 6),
                      Text(
                        "Rider credentials actively deployed",
                        style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdsTab(Color cardBg, Color border, Color primaryText, Color? subText) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Active Marketing Campaigns",
            style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          ...List.generate(_ads.length, (index) {
            final ad = _ads[index];
            final active = ad['isActive'] == true;

            return Card(
              color: cardBg,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        ad['imageUrl'],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey,
                          child: const Icon(Icons.image, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ad['title'],
                            style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ad['body'],
                            style: const TextStyle(color: Colors.grey, fontSize: 10.5),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: active,
                      activeColor: const Color(0xFF10B981),
                      onChanged: (val) => _toggleAdStatus(index, val),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            "➕ Launch New Tourism Banner",
            style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          _adminTextField(_adTitleController, "Campaign Title (e.g. Spiti Hotel Ad)"),
          const SizedBox(height: 10),
          _adminTextField(_adBodyController, "Ad Body / Description (Promo Text)"),
          const SizedBox(height: 10),
          _adminTextField(_adLinkController, "Contact / Target link (e.g. Phone Number)"),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addNewAd,
              icon: const Icon(Icons.campaign, color: Colors.white, size: 18),
              label: const Text("Launch Ad Campaign"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _adminTextField(TextEditingController controller, String hint) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF6366F1)),
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color _bgColor;

  _SliverAppBarDelegate(this._tabBar, this._bgColor);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _bgColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
