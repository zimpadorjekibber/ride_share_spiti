import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Add some seed notifications if none exist
    final existing = await LocalStorageService.getNotifications();
    if (existing.isEmpty) {
      await LocalStorageService.addNotification(
          '🎫 Welcome to Spiti Setu!',
          'Stays, food & rides across Spiti Valley — all in one place.');
      await LocalStorageService.addNotification(
          '🗺️ Tip: Use the map to track live driver location',
          'Tap "Track Live" on any ride card to see the driver on the map.');
      await LocalStorageService.addNotification(
          '⚡ New rides added!',
          'Tenzin Dorje just listed a Tempo from Manali → Kaza departing at 05:00 today.');
    }
    final notifs = await LocalStorageService.getNotifications();
    await LocalStorageService.markAllNotificationsRead();
    if (mounted) {
      setState(() {
        _notifications = notifs;
        _loading = false;
      });
    }
  }

  String _timeAgo(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Notifications',
          style: TextStyle(
              color: primaryText, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 72, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text('No notifications yet',
                          style: TextStyle(color: subText, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final n = _notifications[i];
                    final isRead = n['read'] as bool? ?? true;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isRead
                              ? border
                              : const Color(0xFF6366F1).withValues(alpha: 0.4),
                          width: isRead ? 1 : 1.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.notifications_outlined,
                                color: Color(0xFF6366F1), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n['title'] ?? '',
                                  style: TextStyle(
                                    color: primaryText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  n['body'] ?? '',
                                  style: TextStyle(
                                      color: subText, fontSize: 12, height: 1.4),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _timeAgo(n['time'] ?? ''),
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
