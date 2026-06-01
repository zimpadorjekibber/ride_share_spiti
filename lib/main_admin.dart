// Admin-only entry point — for managing the app from a desktop browser.
// Run with:  flutter run -d chrome -t lib/main_admin.dart
//
// This boots ONLY the Admin Dashboard (no seeker/host UI), so it avoids the
// dart:io photo code that blocks the full app on web. Firebase works on web.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/firebase_service.dart';
import 'services/local_storage_service.dart';
import 'services/verified_phones_service.dart';
import 'models/ride_model.dart';
import 'models/passenger_request_model.dart';
import 'models/stay_model.dart';
import 'models/food_model.dart';
import 'screens/admin_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  await LocalStorageService.loadFlags();
  VerifiedPhonesService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RideProvider()),
        ChangeNotifierProvider(create: (_) => PassengerRequestProvider()),
        ChangeNotifierProvider(create: (_) => StayProvider()),
        ChangeNotifierProvider(create: (_) => FoodProvider()),
      ],
      child: const AdminConsoleApp(),
    ),
  );
}

class AdminConsoleApp extends StatelessWidget {
  const AdminConsoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spiti Setu — Admin Console',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: const ColorScheme.light(primary: Color(0xFF4F46E5), secondary: Color(0xFF0D9488)),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
      ),
      home: const _AdminGate(),
    );
  }
}

class _AdminGate extends StatefulWidget {
  const _AdminGate();
  @override
  State<_AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<_AdminGate> {
  final _pinController = TextEditingController();
  String? _error;
  static const _indigo = Color(0xFF6366F1);

  void _unlock() {
    if (_pinController.text.trim() == '9999') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } else {
      setState(() => _error = 'Invalid admin PIN. Access denied.');
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            margin: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [_indigo, Color(0xFF0D9488)]),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.shield_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 18),
                  const Text('Spiti Setu — Admin Console',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text('Desktop management panel',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _unlock(),
                    decoration: InputDecoration(
                      labelText: 'Admin PIN',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      errorText: _error,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _unlock,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _indigo,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Unlock Console',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
