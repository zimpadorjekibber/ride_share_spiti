import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/local_storage_service.dart';

/// Auto-sliding sponsored-ad carousel.
///
/// Cross-promotion: pass the CURRENT screen's category ('ride' / 'stay' /
/// 'food'). The carousel then shows ads from the OTHER categories (and any
/// 'all' ads) — so the ride screen advertises stays & food, etc. Only active,
/// paid ads are shown (that's the revenue model).
class AdCarousel extends StatefulWidget {
  final String currentCategory;
  const AdCarousel({super.key, required this.currentCategory});

  @override
  State<AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<AdCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _index = 0;
  List<Map<String, dynamic>> _ads = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await LocalStorageService.getAds();
    final ads = all.where((a) {
      final active = a['isActive'] == true;
      final paid = a['paid'] != false; // legacy ads (no flag) treated as paid
      final cat = (a['category'] ?? 'all').toString();
      final crossPromo = cat == 'all' || cat != widget.currentCategory;
      return active && paid && crossPromo;
    }).toList();
    if (!mounted) return;
    setState(() => _ads = ads);
    _timer?.cancel();
    if (ads.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted || !_controller.hasClients) return;
        final next = (_index + 1) % _ads.length;
        _controller.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openAd(Map<String, dynamic> ad) async {
    final link = (ad['link'] ?? '').toString().trim();
    if (link.isEmpty) return;
    Uri uri;
    if (link.startsWith('http')) {
      uri = Uri.parse(link);
    } else {
      // treat as phone number
      uri = Uri.parse('tel:${link.replaceAll(RegExp(r'[^0-9+]'), '')}');
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Contact: $link')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ads.isEmpty) return const SizedBox.shrink();
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text("✨ Sponsored across Spiti",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: onSurface),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: const Text("AD", style: TextStyle(fontSize: 8, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _controller,
            itemCount: _ads.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _adCard(_ads[i]),
          ),
        ),
        if (_ads.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _ads.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _index == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _index == i ? const Color(0xFF6366F1) : Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _adCard(Map<String, dynamic> ad) {
    final cat = (ad['category'] ?? 'all').toString();
    final catLabel = cat == 'ride'
        ? '🚗 Ride'
        : cat == 'stay'
            ? '🏠 Stay'
            : cat == 'food'
                ? '🍲 Food'
                : '✦ Spiti';
    return GestureDetector(
      onTap: () => _openAd(ad),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  ad['imageUrl'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)]),
                    ),
                    child: const Icon(Icons.image, color: Colors.white24, size: 40),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.85), Colors.black.withValues(alpha: 0.3), Colors.transparent],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
                  child: Text(catLabel, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(ad['title'] ?? 'Promotion',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1))])),
                    const SizedBox(height: 3),
                    Text(ad['body'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11, height: 1.2)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.call, color: Colors.white, size: 12),
                          const SizedBox(width: 5),
                          Text(ad['link'] ?? 'Contact',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
