import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lost_found_model.dart';
import '../models/booked_trip_model.dart';
import '../services/local_storage_service.dart';
import '../services/phone_utils.dart';
import '../widgets/app_network_image.dart';
import 'post_lost_found_screen.dart';

/// Public Lost & Found board — anyone can browse, call the poster directly,
/// and the poster can mark an item "Reunited" or remove it.
class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({super.key});

  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  String _filter = 'all'; // all | lost | found | reunited
  UserProfile _profile = UserProfile();

  static const Color _red = Color(0xFFEF4444);
  static const Color _green = Color(0xFF10B981);
  static const Color _purple = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    LocalStorageService.getProfile().then((p) {
      if (mounted) setState(() => _profile = p);
    });
  }

  Future<void> _dial(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(' ', '')}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  List<LostFoundItem> _filtered(List<LostFoundItem> all) {
    switch (_filter) {
      case 'lost':
        return all.where((i) => i.isLost && !i.resolved).toList();
      case 'found':
        return all.where((i) => !i.isLost && !i.resolved).toList();
      case 'reunited':
        return all.where((i) => i.resolved).toList();
      default:
        return all;
    }
  }

  Widget _chip(String value, String label) {
    final selected = _filter == value;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _purple : _purple.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? _purple : onSurface.withValues(alpha: 0.12)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _photo(LostFoundItem item) {
    const double s = 74;
    if (item.photoPath.startsWith('http')) {
      return AppNetworkImage(item.photoPath, width: s, height: s);
    }
    if (item.photoPath.isNotEmpty && File(item.photoPath).existsSync()) {
      return Image.file(File(item.photoPath), width: s, height: s, fit: BoxFit.cover);
    }
    return Container(
      width: s,
      height: s,
      color: _purple.withValues(alpha: 0.1),
      child: Icon(item.isLost ? Icons.search : Icons.card_giftcard,
          color: _purple, size: 26),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
      );

  Widget _card(LostFoundItem item, bool isDark, Color primaryText, Color? subText) {
    final provider = context.read<LostFoundProvider>();
    final mine = samePhone(item.phone, _profile.phone);
    final typeColor = item.isLost ? _red : _green;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: item.resolved
                ? _green.withValues(alpha: 0.35)
                : typeColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: _photo(item)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _badge(item.isLost ? '🔍 LOST' : '🎒 FOUND', typeColor),
                        if (item.resolved) _badge('✓ REUNITED', _green),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: primaryText, fontWeight: FontWeight.w800, fontSize: 14.5)),
                    const SizedBox(height: 3),
                    Text('📍 ${item.location} · ${item.date}',
                        style: TextStyle(color: subText, fontSize: 11.5)),
                  ],
                ),
              ),
            ],
          ),
          if (item.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: subText, fontSize: 12.5, height: 1.35)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: subText),
              const SizedBox(width: 4),
              Expanded(
                child: Text(item.contactName.isEmpty ? 'Poster' : item.contactName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: subText, fontSize: 12)),
              ),
              if (mine) ...[
                if (!item.resolved)
                  TextButton.icon(
                    onPressed: () => provider.setResolved(item, true),
                    icon: const Icon(Icons.check_circle, size: 16, color: _green),
                    label: const Text('Mil gaya ✓',
                        style: TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                IconButton(
                  tooltip: 'Delete post',
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Remove this post?'),
                        content: Text('Delete "${item.title}" from Lost & Found?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            child: const Text('Delete', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) provider.delete(item.id);
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 19),
                ),
              ] else if (item.phone.trim().isNotEmpty && !item.resolved)
                ElevatedButton.icon(
                  onPressed: () => _dial(item.phone),
                  icon: const Icon(Icons.call, size: 15, color: Colors.white),
                  label: const Text('Call',
                      style: TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: typeColor,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final primaryText = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];

    final items = _filtered(context.watch<LostFoundProvider>().items);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryText),
        title: Text('Lost & Found 🎒',
            style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'lost_found_fab',
        backgroundColor: _purple,
        icon: const Icon(Icons.add_a_photo, color: Colors.white),
        label: const Text('Report Item',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostLostFoundScreen()),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip('all', 'All'),
                  _chip('lost', '🔍 Lost'),
                  _chip('found', '🎒 Found'),
                  _chip('reunited', '✓ Reunited'),
                ],
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.travel_explore,
                              size: 56, color: _purple.withValues(alpha: 0.4)),
                          const SizedBox(height: 14),
                          Text('Koi post nahi hai',
                              style: TextStyle(
                                  color: primaryText, fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(
                            'Kuch khoya ya mila hai? "Report Item" dabao — photo ke saath post karo, saare Spiti Setu users ko notification jayegi.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: subText, fontSize: 12.5, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _card(items[i], isDark, primaryText, subText),
                  ),
          ),
        ],
      ),
    );
  }
}
