import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/food_model.dart';
import '../widgets/review_sheet.dart';
import '../services/local_storage_service.dart';

class FoodRequestsScreen extends StatefulWidget {
  const FoodRequestsScreen({super.key});

  @override
  State<FoodRequestsScreen> createState() => _FoodRequestsScreenState();
}

class _FoodRequestsScreenState extends State<FoodRequestsScreen> {
  final Map<String, String> _decisions = {};
  static const Color _accent = Color(0xFFF59E0B);

  void _decide(FoodRequest req, String decision) {
    HapticFeedback.mediumImpact();
    setState(() => _decisions[req.id] = decision);
    if (decision == 'accepted') {
      LocalStorageService.addNotification(
        'Food request accepted',
        'You accepted ${req.seekerName}\'s food request (${req.locationLooking}). Call to confirm the meal.',
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(decision == 'accepted'
            ? '✅ Accepted ${req.seekerName}. Ab call karke khana confirm karein!'
            : '❌ Rejected ${req.seekerName}\'s request.'),
        backgroundColor: decision == 'accepted' ? const Color(0xFF10B981) : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final primaryText = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];

    final provider = Provider.of<FoodProvider>(context);
    final requests = provider.requests
        .where((r) => DateTime.now().difference(r.createdAt) <= LocalStorageService.requestValidity)
        .toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: primaryText), onPressed: () => Navigator.pop(context)),
        title: Text('Food Requests', style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: requests.isEmpty
          ? Center(child: Text("No food requests right now.", style: TextStyle(color: subText)))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _FoodRequestCard(
                request: requests[i],
                timeAgo: _timeAgo(requests[i].createdAt),
                isDark: isDark,
                primaryText: primaryText,
                subText: subText,
                status: _decisions[requests[i].id],
                onAccept: () => _decide(requests[i], 'accepted'),
                onReject: () => _decide(requests[i], 'rejected'),
                onContact: () {
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Calling ${requests[i].seekerName} at ${requests[i].phone}...'),
                      backgroundColor: _accent,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _FoodRequestCard extends StatelessWidget {
  final FoodRequest request;
  final String timeAgo;
  final bool isDark;
  final Color primaryText;
  final Color? subText;
  final String? status;
  final VoidCallback onContact;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _FoodRequestCard({
    required this.request,
    required this.timeAgo,
    required this.isDark,
    required this.primaryText,
    required this.subText,
    required this.status,
    required this.onContact,
    required this.onAccept,
    required this.onReject,
  });

  static const Color _accent = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _accent,
                  child: Text(request.seekerName.isNotEmpty ? request.seekerName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(request.seekerName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: primaryText, fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                            child: Text("${request.peopleCount} ppl",
                                style: const TextStyle(color: _accent, fontSize: 8.5, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      Text(request.whenNeeded, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                Text(timeAgo, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text("Diner rating: ", style: TextStyle(color: subText, fontSize: 12, fontWeight: FontWeight.bold)),
                    RatingBadge(
                      category: 'food',
                      subjectId: request.phone,
                      subjectName: request.seekerName,
                      writeRole: 'Cook',
                      accent: _accent,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _infoRow(Icons.location_on, "Location: ", request.locationLooking),
                const SizedBox(height: 6),
                _infoRow(Icons.restaurant_menu, "Wants: ", "${request.cuisineWanted} · ${request.vegPref}"),
                const SizedBox(height: 6),
                _infoRow(Icons.payments, "Budget: ", "₹${request.budgetPerPlate.toInt()}/plate"),
                if (request.note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("\"${request.note}\"", style: TextStyle(color: subText, fontSize: 11, fontStyle: FontStyle.italic)),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          onPressed: onContact,
                          icon: const Icon(Icons.phone, color: Colors.white, size: 14),
                          label: Text("Call (${request.phone})",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 38,
                      child: OutlinedButton(
                        onPressed: () => showWriteReviewSheet(
                          context,
                          category: 'food',
                          subjectId: request.phone,
                          subjectName: request.seekerName,
                          authorRole: 'Cook',
                          accent: _accent,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _accent,
                          side: const BorderSide(color: _accent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Icon(Icons.star_outline, size: 14), SizedBox(width: 5), Text("Rate", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (status == null)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onAccept,
                          icon: const Icon(Icons.check, size: 16, color: Colors.white),
                          label: const Text("Accept", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: (status == 'accepted' ? const Color(0xFF10B981) : Colors.redAccent).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      status == 'accepted' ? "✓ Accepted — call to confirm" : "✗ Rejected",
                      style: TextStyle(
                        color: status == 'accepted' ? const Color(0xFF10B981) : Colors.redAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _accent),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: subText, fontSize: 12, fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(value, style: TextStyle(color: primaryText, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
