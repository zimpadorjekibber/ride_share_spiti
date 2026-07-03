import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/food_model.dart';
import '../screens/host_food_screen.dart';
import '../services/proximity_service.dart';
import '../services/verified_phones_service.dart';
import 'photo_picker_field.dart';
import 'review_sheet.dart';
import 'verified_badge.dart';

class FoodCard extends StatelessWidget {
  final FoodPlace place;
  final bool isDark;
  final Color primaryText;
  final Color subText;
  final VoidCallback onContact;
  final String? myPhone; // if == place.phone, show Edit
  final double? userLat;
  final double? userLng;

  const FoodCard({
    super.key,
    required this.place,
    required this.isDark,
    required this.primaryText,
    required this.subText,
    required this.onContact,
    this.myPhone,
    this.userLat,
    this.userLng,
  });

  static const Color _accent = Color(0xFFF59E0B);

  Future<void> _openLink(BuildContext context) async {
    var link = place.menuLink.trim();
    if (link.isEmpty) return;
    if (!link.startsWith('http')) link = 'https://$link';
    try {
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;

    const mockImages = [
      'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=400&q=80',
      'https://images.unsplash.com/photo-1496116218417-1a781b1c416c?auto=format&fit=crop&w=400&q=80',
    ];
    final mockUrl = mockImages[place.mockPhotoIndex % mockImages.length];
    final hasWarnings = place.safetyFlags.isNotEmpty || place.rating < 4.0;
    final isMine = myPhone != null && myPhone!.isNotEmpty && myPhone == place.phone;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasWarnings ? const Color(0xFFEF4444).withValues(alpha: 0.5) : border,
          width: hasWarnings ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _PhotoCarousel(photos: place.allPhotos, mockUrl: mockUrl, height: 150),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(30)),
                        child: Row(
                          children: [
                            const Icon(Icons.restaurant, color: Colors.white, size: 10),
                            const SizedBox(width: 4),
                            Text(place.foodType.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (isMine)
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => HostFoodScreen(existing: place, onRegistered: () {})),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(30)),
                                child: const Row(children: [
                                  Icon(Icons.edit, color: Colors.white, size: 11),
                                  SizedBox(width: 3),
                                  Text('Edit', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ]),
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(30)),
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 12),
                                const SizedBox(width: 4),
                                Text(place.rating.toStringAsFixed(1),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            shadows: [Shadow(color: Colors.black54, offset: Offset(0, 1), blurRadius: 4)],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.account_circle, color: Colors.white70, size: 11),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text("By: ${place.ownerName}",
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            if (VerifiedPhonesService.isVerified(place.phone)) ...[
                              const SizedBox(width: 6),
                              const VerifiedBadge(light: true),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (userLat != null && userLng != null)
                        _chip(Icons.location_on,
                            "${ProximityService.calculateDistance(userLat!, userLng!, place.lat, place.lng).toStringAsFixed(1)} km away",
                            const Color(0xFF10B981)),
                      _chip(Icons.local_dining, place.cuisine, _accent),
                      _vegChip(place.vegType),
                      _chip(Icons.schedule, place.timings, Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(place.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: subText, fontSize: 11.5, height: 1.4)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (place.homeDelivery)
                        _featureTag(Icons.delivery_dining,
                            place.deliveryRangeKm > 0 ? 'Delivery ≤ ${place.deliveryRangeKm.toInt()} km' : 'Delivery'),
                      if (place.cookOnRequest) _featureTag(Icons.soup_kitchen, 'Cooks on request'),
                      if (place.offMarket) _featureTag(Icons.explore_off, 'Off-market spot'),
                    ],
                  ),
                  if (place.facilities.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: place.facilities.map((f) => _facilityChip(f)).toList(),
                    ),
                  ],

                  // ── Live table availability ──
                  if (place.tables.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.table_restaurant,
                            size: 14, color: place.freeTables > 0 ? const Color(0xFF10B981) : Colors.redAccent),
                        const SizedBox(width: 5),
                        Text(
                          place.freeTables > 0
                              ? "${place.freeTables} of ${place.tables.length} tables free now"
                              : "All tables occupied right now",
                          style: TextStyle(
                              color: place.freeTables > 0 ? const Color(0xFF10B981) : Colors.redAccent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ],

                  // ── Seating-area photos (every angle) ──
                  if (place.seatingPhotos.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SeatingPhotoStrip(photos: place.seatingPhotos, height: 72),
                  ],

                  // ── Menu (per-item prices + live stock) ──
                  if (place.menu.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text("MENU", style: TextStyle(color: subText, fontSize: 9, letterSpacing: 0.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    ...place.menu.take(4).map((m) {
                      final out = m.isOut;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(m.name,
                                  style: TextStyle(
                                      color: out ? subText : primaryText,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      decoration: out ? TextDecoration.lineThrough : null),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (out)
                              _stockBadge("SOLD OUT", Colors.redAccent)
                            else if (m.qtyLeft > 0)
                              _stockBadge("${m.qtyLeft} left", const Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            Text("₹${m.price.toInt()}",
                                style: TextStyle(
                                    color: out ? subText : _accent,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    decoration: out ? TextDecoration.lineThrough : null)),
                          ],
                        ),
                      );
                    }),
                    if (place.menu.length > 4)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text("+${place.menu.length - 4} more items",
                            style: TextStyle(color: subText, fontSize: 11, fontStyle: FontStyle.italic)),
                      ),
                  ],

                  if (hasWarnings) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              place.safetyFlags.isNotEmpty ? place.safetyFlags.first : "Low community rating reported.",
                              style: TextStyle(color: subText, fontSize: 9.5, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Builder(
                        builder: (context) => InkWell(
                          onTap: () => showReviewsSheet(
                            context,
                            category: 'food',
                            subjectId: place.id,
                            subjectName: place.title,
                            writeRole: 'Diner',
                            accent: _accent,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.reviews_outlined, size: 14, color: _accent),
                              const SizedBox(width: 5),
                              Text("Reviews",
                                  style: TextStyle(color: _accent, fontSize: 11.5, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: _accent.withValues(alpha: 0.4))),
                            ],
                          ),
                        ),
                      ),
                      if (place.menuLink.trim().isNotEmpty) ...[
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () => _openLink(context),
                          child: Row(
                            children: [
                              const Icon(Icons.menu_book, size: 14, color: _accent),
                              const SizedBox(width: 5),
                              Text("Menu / Site",
                                  style: TextStyle(color: _accent, fontSize: 11.5, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: _accent.withValues(alpha: 0.4))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: _priceBlock(place, primaryText, subText)),
                      ElevatedButton(
                        onPressed: onContact,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.phone, color: Colors.white, size: 13),
                            SizedBox(width: 6),
                            Text("Contact / Order", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _vegChip(String vegType) {
    final isVeg = vegType == 'Veg';
    final isBoth = vegType == 'Both';
    final color = isVeg ? const Color(0xFF10B981) : (isBoth ? const Color(0xFF0D9488) : const Color(0xFFEF4444));
    return _chip(Icons.circle, vegType.toUpperCase(), color);
  }

  IconData _facilityIcon(String f) {
    switch (f) {
      case 'WiFi':
        return Icons.wifi;
      case 'Indoor Seating':
        return Icons.event_seat;
      case 'Rooftop':
        return Icons.deck;
      case 'Parking':
        return Icons.local_parking;
      case 'Washroom':
        return Icons.wc;
      case 'Bonfire':
        return Icons.local_fire_department;
      case 'Live Music':
        return Icons.music_note;
      case 'Pure Veg Kitchen':
        return Icons.eco;
      case 'Card / UPI':
        return Icons.qr_code;
      case 'Pet Friendly':
        return Icons.pets;
      case 'Mountain View':
        return Icons.landscape;
      case 'Power Backup':
        return Icons.bolt;
      default:
        return Icons.check_circle_outline;
    }
  }

  /// Price display tuned to the kind of place:
  ///  • Restaurant / Cafe → à la carte (menu-based), never a per-plate "thali".
  ///  • Dhaba / Home Dining / Cloud Kitchen → per-plate approx (pre-cooked).
  Widget _priceBlock(FoodPlace place, Color primaryText, Color? subText) {
    final alaCarte = place.foodType == 'Restaurant' || place.foodType == 'Cafe';

    // Has a real menu with item prices → show the lowest item price.
    if (place.menu.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("MENU FROM", style: TextStyle(color: Colors.grey, fontSize: 8, letterSpacing: 0.5)),
          Row(
            children: [
              const Text("₹", style: TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(place.fromPrice.toInt().toString(),
                  style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 17)),
            ],
          ),
        ],
      );
    }

    // Restaurant / Cafe without an item list → no fake per-plate number.
    if (alaCarte) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant_menu, size: 15, color: subText),
          const SizedBox(width: 6),
          Flexible(
            child: Text("À la carte · see menu",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: subText, fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
          ),
        ],
      );
    }

    // Dhaba / Home Dining / Cloud Kitchen → per-plate approx (pre-cooked food).
    if (place.fromPrice > 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("APPROX / PLATE", style: TextStyle(color: Colors.grey, fontSize: 8, letterSpacing: 0.5)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text("₹", style: TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(place.fromPrice.toInt().toString(),
                  style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 17)),
              Text(" /plate", style: TextStyle(color: subText, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      );
    }

    return Text("Price on request",
        style: TextStyle(color: subText, fontSize: 12, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600));
  }

  Widget _stockBadge(String label, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: c)),
    );
  }

  Widget _facilityChip(String f) {
    const c = Color(0xFF14B8A6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_facilityIcon(f), size: 10, color: c),
          const SizedBox(width: 4),
          Text(f, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: c)),
        ],
      ),
    );
  }

  Widget _featureTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: _accent),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _accent)),
        ],
      ),
    );
  }
}

/// Swipeable photo carousel (network URLs or local files) with page dots.
class _PhotoCarousel extends StatefulWidget {
  final List<String> photos;
  final String mockUrl;
  final double height;
  const _PhotoCarousel({required this.photos, required this.mockUrl, required this.height});

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _img(String p) {
    if (p.startsWith('http')) {
      return Image.network(p, height: widget.height, width: double.infinity, fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback());
    }
    final f = File(p);
    if (f.existsSync()) {
      return Image.file(f, height: widget.height, width: double.infinity, fit: BoxFit.cover);
    }
    return _fallback();
  }

  Widget _fallback() => Container(
        height: widget.height,
        width: double.infinity,
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])),
        alignment: Alignment.center,
        child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 44),
      );

  @override
  Widget build(BuildContext context) {
    final imgs = widget.photos.isNotEmpty ? widget.photos : [widget.mockUrl];
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: imgs.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _img(imgs[i]),
          ),
          // bottom gradient for title readability
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
          ),
          if (imgs.length > 1)
            Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  imgs.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _index == i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _index == i ? Colors.white : Colors.white60,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
