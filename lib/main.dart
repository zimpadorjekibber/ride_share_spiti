import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'services/firebase_service.dart';
import 'models/ride_model.dart';
import 'screens/passenger_screen.dart';
import 'screens/driver_screen.dart';
import 'screens/my_trips_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/sos_screen.dart';
import 'services/local_storage_service.dart';
import 'models/passenger_request_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => RideProvider()),
        ChangeNotifierProvider(create: (context) => PassengerRequestProvider()),
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
      title: 'RideShare to Spiti',
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
  }

  Future<void> _loadUnreadCount() async {
    final notifs = await LocalStorageService.getNotifications();
    final count = notifs.where((n) => n['read'] == false).length;
    if (mounted) setState(() => _unreadCount = count);
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
    final List<Widget> screens = [
      const PassengerScreen(),
      DriverScreen(
        onRegistrationSuccess: () {
          setState(() {
            _currentTab = 0;
          });
        },
      ),
      const MyTripsScreen(),
      const ProfileScreen(),
    ];

    final isMobile = MediaQuery.of(context).size.width < 600;
    final rideProvider = Provider.of<RideProvider>(context);
    final isDark = rideProvider.isDarkMode;
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
                "RideShare Spiti",
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
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$_unreadCount',
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
          selectedItemColor: const Color(0xFF6366F1),
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.airport_shuttle_outlined),
              activeIcon: Icon(Icons.airport_shuttle),
              label: 'Book Seats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.drive_eta_outlined),
              activeIcon: Icon(Icons.drive_eta),
              label: 'Drive',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.confirmation_number_outlined),
              activeIcon: Icon(Icons.confirmation_number),
              label: 'My Trips',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
