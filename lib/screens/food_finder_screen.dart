import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/food_model.dart';
import '../widgets/food_card.dart';
import '../widgets/ad_carousel.dart';
import '../services/local_storage_service.dart';
import 'post_food_request_screen.dart';

class FoodFinderScreen extends StatefulWidget {
  const FoodFinderScreen({super.key});

  @override
  State<FoodFinderScreen> createState() => _FoodFinderScreenState();
}

class _FoodFinderScreenState extends State<FoodFinderScreen> {
  String _filter = 'All';
  String _myPhone = '';
  double? _myLat;
  double? _myLng;
  static const Color _accent = Color(0xFFF59E0B);

  final List<String> _filters = ['All', ...kFoodTypes];

  @override
  void initState() {
    super.initState();
    LocalStorageService.getProfile().then((p) {
      if (mounted) {
        setState(() {
          _myPhone = p.phone;
          if (p.locationPermissionGranted) {
            _myLat = p.currentLat;
            _myLng = p.currentLng;
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    final provider = Provider.of<FoodProvider>(context);
    final places = provider.places.where((p) => _filter == 'All' || p.foodType == _filter).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostFoodRequestScreen()),
        ),
        backgroundColor: _accent,
        icon: const Icon(Icons.campaign, color: Colors.white),
        label: const Text("Broadcast Food Need", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Text("🍲", style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Find Food & Local Dining",
                    style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "No kitchen at your stay? Find restaurants, cafes, dhabas & locals who cook fresh meals nearby.",
              style: TextStyle(color: subText, fontSize: 11.5, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final selected = _filter == f;
                return GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? _accent : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(f,
                        style: TextStyle(
                          color: selected ? Colors.white : subText,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AdCarousel(currentCategory: 'food'),
          ),
          Expanded(
            child: places.isEmpty
                ? Center(
                    child: Text("No food spots in this category.\nTry another filter!",
                        textAlign: TextAlign.center, style: TextStyle(color: subText)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    itemCount: places.length,
                    itemBuilder: (_, i) => FoodCard(
                      place: places[i],
                      isDark: isDark,
                      primaryText: primaryText,
                      subText: subText,
                      myPhone: _myPhone,
                      userLat: _myLat,
                      userLng: _myLng,
                      onContact: () {
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Calling ${places[i].ownerName} at ${places[i].phone}...'),
                            backgroundColor: _accent,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
