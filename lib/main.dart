import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'services/firebase_service.dart';
import 'services/verified_phones_service.dart';
import 'models/ride_model.dart';
import 'screens/passenger_screen.dart';
import 'screens/driver_screen.dart';
import 'screens/my_trips_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/food_finder_screen.dart';
import 'screens/host_food_screen.dart';
import 'services/local_storage_service.dart';
import 'models/passenger_request_model.dart';
import 'models/stay_model.dart';
import 'models/food_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  await LocalStorageService.loadFlags(); // demo-seeding on/off
  VerifiedPhonesService.init(); // sync admin-verified phone numbers
  // Pull any cloud reviews into the local cache (fire-and-forget, no-op offline).
  LocalStorageService.syncReviewsFromCloud();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => RideProvider()),
        ChangeNotifierProvider(create: (context) => PassengerRequestProvider()),
        ChangeNotifierProvider(create: (context) => StayProvider()),
        ChangeNotifierProvider(create: (context) => FoodProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final rideProvider = Provider.of<RideProvider>(context);
    final isDarkMode = rideProvider.isDarkMode;

    return MaterialApp(
      title: 'Spiti Setu',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4F46E5),
          secondary: Color(0xFF0D9488),
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
      ),
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090D16),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF111827),
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const SplashScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentTab = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _checkMyActiveRequests();
  }

  Future<void> _loadUnreadCount() async {
    final notifs = await LocalStorageService.getNotifications();
    final count = notifs.where((n) => n['read'] == false).length;
    if (mounted) setState(() => _unreadCount = count);
  }

  /// On app open, if the user has active broadcast requests, insist they update
  /// status — keep looking, or remove (so providers don't call them needlessly).
  Future<void> _checkMyActiveRequests() async {
    await Future.delayed(const Duration(milliseconds: 1800)); // let Firestore load
    if (!mounted) return;
    final profile = await LocalStorageService.getProfile();
    final phone = profile.phone;
    if (phone.isEmpty || !mounted) return;

    final stayP = context.read<StayProvider>();
    final foodP = context.read<FoodProvider>();
    final passP = context.read<PassengerRequestProvider>();
    final myStay = stayP.stayRequests.where((r) => r.phone == phone).toList();
    final myFood = foodP.requests.where((r) => r.phone == phone).toList();
    final myRide = passP.requests.where((r) => r.phone == phone).toList();
    if (myStay.isEmpty && myFood.isEmpty && myRide.isEmpty) return;

    final lines = <String>[
      ...myStay.map((r) => '🏠 Room in ${r.locationLooking}'),
      ...myFood.map((r) => '🍲 Food in ${r.locationLooking}'),
      ...myRide.map((r) => '🚗 Ride ${r.from} → ${r.to}'),
    ];

    if (!mounted) return;
    final keep = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update your status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You still have active request(s):'),
            const SizedBox(height: 8),
            ...lines.map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(l, style: const TextStyle(fontWeight: FontWeight.w600)),
                )),
            const SizedBox(height: 10),
            const Text('Found what you needed? Remove them so hosts/drivers don\'t call you for nothing.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Still looking')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('✓ Got it — remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (keep == false) {
      final fb = FirebaseService();
      for (final r in myStay) {
        await fb.deleteDoc('stay_requests', r.id);
      }
      for (final r in myFood) {
        await fb.deleteDoc('food_requests', r.id);
      }
      for (final r in myRide) {
        await fb.deleteDoc('passenger_requests', r.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Your requests cleared. Thanks for keeping Spiti Setu fresh!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    }
  }

  PopupMenuItem<AppMode> _modeMenuItem(AppMode mode, IconData icon, String title,
      String subtitle, Color color, AppMode current) {
    final selected = mode == current;
    return PopupMenuItem<AppMode>(
      value: mode,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
                Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
              ],
            ),
          ),
          if (selected) Icon(Icons.check_circle, size: 16, color: color),
        ],
      ),
    );
  }

  void _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    _loadUnreadCount(); // refresh badge after returning
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final rideProvider = Provider.of<RideProvider>(context);
    final appMode = rideProvider.appMode;
    final isDark = rideProvider.isDarkMode;

    // Per-mode styling (ride = indigo, stay = teal, food = amber)
    final Color modeColor = appMode == AppMode.ride
        ? const Color(0xFF6366F1)
        : appMode == AppMode.stay
            ? const Color(0xFF10B981)
            : const Color(0xFFF59E0B);
    final IconData modeIcon = appMode == AppMode.ride
        ? Icons.airport_shuttle
        : appMode == AppMode.stay
            ? Icons.house_rounded
            : Icons.restaurant;
    final String modeLabel = appMode == AppMode.ride
        ? "RideShare"
        : appMode == AppMode.stay
            ? "FindStay"
            : "FindFood";

    final List<Widget> screens = appMode == AppMode.food
        ? [
            const FoodFinderScreen(),
            HostFoodScreen(onRegistered: () => setState(() => _currentTab = 0)),
            const MyTripsScreen(),
            const ProfileScreen(),
          ]
        : [
            const PassengerScreen(),
            DriverScreen(
              onRegistrationSuccess: () => setState(() => _currentTab = 0),
            ),
            const MyTripsScreen(),
            const ProfileScreen(),
          ];
    final bgColor = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final onSurface = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor.withValues(alpha: 0.95),
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("⚡", style: TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                "Spiti Setu",
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: onSurface,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Mode selector — tap shows all three modes so users can jump
          // directly instead of blindly cycling through them.
          PopupMenuButton<AppMode>(
            tooltip: 'Switch mode',
            offset: const Offset(0, 42),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (mode) {
              rideProvider.setAppMode(mode);
              HapticFeedback.lightImpact();
            },
            itemBuilder: (ctx) => [
              _modeMenuItem(AppMode.ride, Icons.airport_shuttle, 'RideShare',
                  'Find & offer rides', const Color(0xFF6366F1), appMode),
              _modeMenuItem(AppMode.stay, Icons.house_rounded, 'FindStay',
                  'Homestays & rooms', const Color(0xFF10B981), appMode),
              _modeMenuItem(AppMode.food, Icons.restaurant, 'FindFood',
                  'Local food & dining', const Color(0xFFF59E0B), appMode),
            ],
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: modeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: modeColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(modeIcon, size: 14, color: modeColor),
                  const SizedBox(width: 4),
                  Text(
                    modeLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: modeColor,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.expand_more, size: 13, color: modeColor.withValues(alpha: 0.7)),
                ],
              ),
            ),
          ),
          // SOS button
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SosScreen()),
            ),
            icon: const Icon(Icons.sos_rounded, color: Color(0xFFEF4444)),
            tooltip: 'SOS Emergency',
          ),
          // Notifications bell with badge
          Stack(
            children: [
              IconButton(
                onPressed: _openNotifications,
                icon: Icon(Icons.notifications_outlined, color: onSurface),
                tooltip: 'Notifications',
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 8,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    height: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          // Theme toggle
          IconButton(
            onPressed: () => rideProvider.toggleTheme(),
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: onSurface,
            ),
            tooltip: 'Toggle Theme',
          ),
          if (!isMobile)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: onSurface.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: onSurface.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 6,
                    width: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Kaza Central Active",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: screens[_currentTab],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF090D16) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (index) => setState(() => _currentTab = index),
          backgroundColor:
              isDark ? const Color(0xFF111827).withValues(alpha: 0.95) : Colors.white,
          selectedItemColor: modeColor,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: Icon(appMode == AppMode.ride
                  ? Icons.airport_shuttle_outlined
                  : appMode == AppMode.stay
                      ? Icons.home_work_outlined
                      : Icons.restaurant_outlined),
              activeIcon: Icon(appMode == AppMode.ride
                  ? Icons.airport_shuttle
                  : appMode == AppMode.stay
                      ? Icons.home_work
                      : Icons.restaurant),
              label: appMode == AppMode.ride
                  ? 'Book Seats'
                  : appMode == AppMode.stay
                      ? 'Find Stays'
                      : 'Find Food',
            ),
            BottomNavigationBarItem(
              icon: Icon(appMode == AppMode.ride
                  ? Icons.drive_eta_outlined
                  : appMode == AppMode.stay
                      ? Icons.domain_add_outlined
                      : Icons.soup_kitchen_outlined),
              activeIcon: Icon(appMode == AppMode.ride
                  ? Icons.drive_eta
                  : appMode == AppMode.stay
                      ? Icons.domain_add
                      : Icons.soup_kitchen),
              label: appMode == AppMode.ride
                  ? 'Drive'
                  : appMode == AppMode.stay
                      ? 'Host Stay'
                      : 'Host Food',
            ),
            BottomNavigationBarItem(
              icon: Icon(appMode == AppMode.ride
                  ? Icons.confirmation_number_outlined
                  : appMode == AppMode.stay
                      ? Icons.hotel_outlined
                      : Icons.bookmark_border),
              activeIcon: Icon(appMode == AppMode.ride
                  ? Icons.confirmation_number
                  : appMode == AppMode.stay
                      ? Icons.hotel
                      : Icons.bookmark),
              label: appMode == AppMode.ride
                  ? 'My Trips'
                  : appMode == AppMode.stay
                      ? 'My Bookings'
                      : 'My Orders',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
