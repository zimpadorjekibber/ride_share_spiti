import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ride_model.dart';
import '../models/stay_model.dart';
import '../models/food_model.dart';
import '../models/passenger_request_model.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_service.dart';
import 'admin_add_listing_screen.dart';

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
  AppMode _adminMode = AppMode.ride; // ride / stay / food admin view

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
      final name = list[index]['driverName'] ?? list[index]['hostName'] ?? 'User';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Documents for $name verified successfully!"),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  // ─── Clear Demo / Sample Data (keep real) ───────────
  Future<void> _clearDemoData() async {
    final messenger = ScaffoldMessenger.of(context);
    final rideP = Provider.of<RideProvider>(context, listen: false);
    final stayP = Provider.of<StayProvider>(context, listen: false);
    final foodP = Provider.of<FoodProvider>(context, listen: false);
    final passP = Provider.of<PassengerRequestProvider>(context, listen: false);
    final fb = FirebaseService();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🧹 Clear Demo Data?'),
        content: const Text(
          'This permanently removes ALL sample/demo listings, requests, reviews & ads.\n\n'
          'Your REAL data (added by you & real users) is kept. Demo data will not come back.\n\n'
          'Do this just before going live.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Clear Demo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await LocalStorageService.disableDemoSeeding();

    // Cloud demo docs (demo id = no underscore)
    bool demo(String id) => LocalStorageService.isDemoId(id);
    for (final r in rideP.rides) {
      if (demo(r.id)) await fb.deleteDoc('rides', r.id);
    }
    for (final s in stayP.stays) {
      if (demo(s.id)) await fb.deleteDoc('stays', s.id);
    }
    for (final p in foodP.places) {
      if (demo(p.id)) await fb.deleteDoc('food_places', p.id);
    }
    for (final r in stayP.stayRequests) {
      if (demo(r.id)) await fb.deleteDoc('stay_requests', r.id);
    }
    for (final r in foodP.requests) {
      if (demo(r.id)) await fb.deleteDoc('food_requests', r.id);
    }
    for (final r in passP.requests) {
      if (demo(r.id)) await fb.deleteDoc('passenger_requests', r.id);
    }
    final reviews = await fb.fetchReviews();
    for (final rv in reviews) {
      if (demo(rv.id)) await fb.deleteDoc('reviews', rv.id);
    }

    await LocalStorageService.clearDemoLocalData();
    await _loadAdminData();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('🧹 Demo data cleared. Only real data remains — app is launch-ready!'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 4),
      ),
    );
  }

  // ─── Ads Actions ─────────────────────────────────────
  Future<void> _deleteAd(int index) async {
    final list = List<Map<String, dynamic>>.from(_ads);
    final removed = list.removeAt(index);
    await LocalStorageService.saveAds(list);
    await _loadAdminData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🗑️ Removed ad: ${removed['title'] ?? ''}'), backgroundColor: Colors.redAccent),
      );
    }
  }

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
  void _moderateUser(BuildContext context, String name) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1F2937) : Colors.white;
    final flagLabel = _adminMode == AppMode.ride
        ? "Flag for Rash Driving / Bad Behavior"
        : _adminMode == AppMode.stay
            ? "Flag for Overcharging / Bad Conduct"
            : "Flag for Hygiene / Overcharging";

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
                _flagUser(name);
              },
              icon: const Icon(Icons.gpp_bad, color: Colors.white),
              label: Text(flagLabel),
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
                _clearFlags(name);
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

  void _moderate(String name, bool flagAsBad) {
    switch (_adminMode) {
      case AppMode.ride:
        Provider.of<RideProvider>(context, listen: false).moderateDriver(name, flagAsBad: flagAsBad);
        break;
      case AppMode.stay:
        Provider.of<StayProvider>(context, listen: false).moderateStay(name, flagAsBad: flagAsBad);
        break;
      case AppMode.food:
        Provider.of<FoodProvider>(context, listen: false).moderateFoodPlace(name, flagAsBad: flagAsBad);
        break;
    }
  }

  void _flagUser(String name) {
    _moderate(name, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("🛑 Flagged $name! Rating adjusted down & community warning active."),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _clearFlags(String name) {
    _moderate(name, false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✅ Cleared all community flags for $name. Status: Verified!"),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
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
    final stayProvider = Provider.of<StayProvider>(context);
    final foodProvider = Provider.of<FoodProvider>(context);

    final pendingCount = _verifications.where((v) => v['isApproved'] == false).length;
    final activeAdsCount = _ads.where((a) => a['isActive'] == true).length;

    final List<Color> headerGradient = _adminMode == AppMode.ride
        ? const [Color(0xFF4F46E5), Color(0xFF6366F1)]
        : _adminMode == AppMode.stay
            ? const [Color(0xFF0D9488), Color(0xFF14B8A6)]
            : const [Color(0xFFD97706), Color(0xFFF59E0B)];

    final addLabel = _adminMode == AppMode.ride
        ? "List a Ride"
        : _adminMode == AppMode.stay
            ? "List a Property"
            : "List Food Service";

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: "admin_add_listing",
        backgroundColor: headerGradient.last,
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: Text(addLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminAddListingScreen(mode: _adminMode)),
        ),
      ),
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
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(child: _buildModeToggle()),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: headerGradient,
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _metricCounter("Pending", "$pendingCount", Colors.orangeAccent),
                        _metricCounter("Ads", "$activeAdsCount", const Color(0xFF10B981)),
                        _metricCounter("Rides", "${rideProvider.rides.length}", const Color(0xFF818CF8)),
                        _metricCounter("Stays", "${stayProvider.stays.length}", const Color(0xFF14B8A6)),
                        _metricCounter("Food", "${foodProvider.places.length}", const Color(0xFFF59E0B)),
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
                  _buildUsersTab(rideProvider, stayProvider, foodProvider, cardBg, border, primaryText, subText),
                  // Tab 2: Document Verification
                  _buildVerificationTab(cardBg, border, primaryText, subText),
                  // Tab 3: Ads & Campaigns Manager
                  _buildAdsTab(cardBg, border, primaryText, subText),
                ],
              ),
      ),
    );
  }

  Widget _buildModeToggle() {
    final icon = _adminMode == AppMode.ride
        ? Icons.airport_shuttle
        : _adminMode == AppMode.stay
            ? Icons.house_rounded
            : Icons.restaurant;
    final label = _adminMode == AppMode.ride
        ? "RideShare"
        : _adminMode == AppMode.stay
            ? "FindStay"
            : "FindFood";
    return GestureDetector(
      onTap: () => setState(() {
        // Cycle ride → stay → food → ride
        _adminMode = AppMode.values[(_adminMode.index + 1) % AppMode.values.length];
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
            const SizedBox(width: 5),
            const Icon(Icons.swap_horiz, size: 13, color: Colors.white70),
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
      StayProvider stayProvider,
      FoodProvider foodProvider,
      Color cardBg,
      Color border,
      Color primaryText,
      Color? subText) {
    if (_adminMode == AppMode.stay) {
      final stays = stayProvider.stays;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel("🏠 Homestay Hosts (FindStay)", primaryText, stays.length),
          const SizedBox(height: 10),
          if (stays.isEmpty)
            Text("No homestays registered yet.", style: TextStyle(color: subText, fontSize: 12)),
          ...stays.map((s) => _moderationCard(
                name: s.hostName,
                subtitle: "${s.propertyType} · ${s.title} · ${s.roomsAvailable} rooms",
                rating: s.rating,
                accent: const Color(0xFF14B8A6),
                emoji: "🏠",
                cardBg: cardBg,
                border: border,
                primaryText: primaryText,
                subText: subText,
              )),
          const SizedBox(height: 30),
        ],
      );
    }

    if (_adminMode == AppMode.food) {
      final places = foodProvider.places;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel("🍲 Food Hosts (FindFood)", primaryText, places.length),
          const SizedBox(height: 10),
          if (places.isEmpty)
            Text("No food spots registered yet.", style: TextStyle(color: subText, fontSize: 12)),
          ...places.map((p) => _moderationCard(
                name: p.ownerName,
                subtitle: "${p.foodType} · ${p.title} · ${p.cuisine}",
                rating: p.rating,
                accent: const Color(0xFFF59E0B),
                emoji: "🍲",
                cardBg: cardBg,
                border: border,
                primaryText: primaryText,
                subText: subText,
              )),
          const SizedBox(height: 30),
        ],
      );
    }

    final rides = rideProvider.rides;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionLabel("🚗 Drivers (RideShare)", primaryText, rides.length),
        const SizedBox(height: 10),
        if (rides.isEmpty)
          Text("No drivers registered yet.", style: TextStyle(color: subText, fontSize: 12)),
        ...rides.map((r) => _moderationCard(
              name: r.driverName,
              subtitle: "Vehicle: ${r.vehicleName} (${r.plateNumber})",
              rating: r.driverRating,
              accent: const Color(0xFF6366F1),
              emoji: "👤",
              cardBg: cardBg,
              border: border,
              primaryText: primaryText,
              subText: subText,
            )),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _sectionLabel(String text, Color primaryText, int count) {
    return Row(
      children: [
        Text(text, style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 14)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text("$count",
              style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _moderationCard({
    required String name,
    required String subtitle,
    required double rating,
    required Color accent,
    required String emoji,
    required Color cardBg,
    required Color border,
    required Color primaryText,
    required Color? subText,
  }) {
    final isBanned = rating < 4.0;

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
          backgroundColor: isBanned ? Colors.red.withValues(alpha: 0.1) : accent.withValues(alpha: 0.1),
          child: Text(
            isBanned ? "⚠️" : emoji,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.star, color: Colors.amber, size: 14),
            const SizedBox(width: 2),
            Text(
              rating.toStringAsFixed(1),
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(color: subText, fontSize: 11)),
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
          icon: Icon(Icons.security_outlined, color: accent),
          onPressed: () => _moderateUser(context, name),
        ),
      ),
    );
  }

  Widget _buildVerificationTab(Color cardBg, Color border, Color primaryText, Color? subText) {
    // Filter to the active mode, but remember each item's original index so
    // approval still updates the correct entry in the full list.
    final targetType = _adminMode == AppMode.stay
        ? 'host'
        : _adminMode == AppMode.food
            ? 'food'
            : 'driver';
    final entries = <MapEntry<int, Map<String, dynamic>>>[];
    for (var i = 0; i < _verifications.length; i++) {
      final t = _verifications[i]['type'] ?? 'driver'; // legacy entries = driver
      if (t == targetType) entries.add(MapEntry(i, _verifications[i]));
    }

    if (entries.isEmpty) {
      return Center(
        child: Text(
          _adminMode == AppMode.stay
              ? "No pending homestay verifications."
              : _adminMode == AppMode.food
                  ? "No pending food verifications."
                  : "No pending driver verifications.",
          style: TextStyle(color: subText),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (context, idx) {
        final originalIndex = entries[idx].key;
        final v = entries[idx].value;
        final approved = v['isApproved'] == true;
        final type = v['type'] ?? 'driver';
        final isHost = type == 'host';
        final isFood = type == 'food';
        final name = isHost
            ? (v['hostName'] ?? 'Host')
            : isFood
                ? (v['ownerName'] ?? 'Cook')
                : (v['driverName'] ?? 'Driver');
        final badgeColor = isHost
            ? const Color(0xFF14B8A6)
            : isFood
                ? const Color(0xFFF59E0B)
                : const Color(0xFF6366F1);
        final badgeText = isHost ? "🏠 HOST" : isFood ? "🍲 FOOD" : "🚗 DRIVER";

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
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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
                if (isHost) ...[
                  Text("Property: ${v['propertyName']} (${v['propertyType']})", style: TextStyle(color: subText, fontSize: 12)),
                  Text("Rooms: ${v['rooms']}", style: TextStyle(color: subText, fontSize: 12)),
                  Text("Phone Number: ${v['phone']}", style: TextStyle(color: subText, fontSize: 12)),
                ] else if (isFood) ...[
                  Text("Place: ${v['placeName']}", style: TextStyle(color: subText, fontSize: 12)),
                  Text("Type: ${v['foodType']}", style: TextStyle(color: subText, fontSize: 12)),
                  Text("Phone Number: ${v['phone']}", style: TextStyle(color: subText, fontSize: 12)),
                ] else ...[
                  Text("Vehicle: ${v['vehicleName']}", style: TextStyle(color: subText, fontSize: 12)),
                  Text("Plate Number: ${v['plateNumber']}", style: TextStyle(color: subText, fontSize: 12)),
                  Text("Phone Number: ${v['phone']}", style: TextStyle(color: subText, fontSize: 12)),
                ],
                const SizedBox(height: 12),
                if (!approved)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _approveDriverDoc(originalIndex),
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
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        isHost
                            ? "Homestay verified & badge deployed"
                            : isFood
                                ? "Food spot verified & badge deployed"
                                : "Rider credentials actively deployed",
                        style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
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
                    const SizedBox(width: 4),
                    Switch(
                      value: active,
                      activeThumbColor: const Color(0xFF10B981),
                      onChanged: (val) => _toggleAdStatus(index, val),
                    ),
                    IconButton(
                      tooltip: 'Delete ad',
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => _deleteAd(index),
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
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 12),
          Text("⚠️ Danger Zone", style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            "Before going live, remove all sample/demo data. Your real listings, reviews & ads are kept; demo data won't reappear.",
            style: TextStyle(color: subText, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearDemoData,
              icon: const Icon(Icons.cleaning_services, color: Colors.redAccent, size: 18),
              label: const Text("🧹 Clear Demo Data (keep real)",
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
