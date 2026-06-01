import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/stay_model.dart';
import '../widgets/review_sheet.dart';
import '../services/local_storage_service.dart';

class StayRequestsScreen extends StatefulWidget {
  const StayRequestsScreen({super.key});

  @override
  State<StayRequestsScreen> createState() => _StayRequestsScreenState();
}

class _StayRequestsScreenState extends State<StayRequestsScreen> {
  String _filterLocation = 'All';
  final Map<String, String> _decisions = {}; // requestId -> 'accepted' | 'rejected'

  void _decide(StayRequest req, String decision) {
    HapticFeedback.mediumImpact();
    setState(() => _decisions[req.id] = decision);
    if (decision == 'accepted') {
      LocalStorageService.addNotification(
        'Stay request accepted',
        'You accepted ${req.seekerName}\'s request for ${req.locationLooking}. Call them to confirm the room.',
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(decision == 'accepted'
            ? '✅ Accepted ${req.seekerName}. Ab call karke room confirm karein!'
            : '❌ Rejected ${req.seekerName}\'s request.'),
        backgroundColor: decision == 'accepted' ? const Color(0xFF10B981) : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  final List<String> _locationFilters = [
    'All', 'Kaza', 'Kibber', 'Tabo', 'Pin Valley', 'Other'
  ];

  bool _matchesFilter(StayRequest r) {
    if (_filterLocation == 'All') return true;
    final loc = r.locationLooking.toLowerCase();
    if (_filterLocation == 'Kaza') return loc.contains('kaza');
    if (_filterLocation == 'Kibber') return loc.contains('kibber');
    if (_filterLocation == 'Tabo') return loc.contains('tabo');
    if (_filterLocation == 'Pin Valley') return loc.contains('pin') || loc.contains('mud');
    if (_filterLocation == 'Other') {
      return !loc.contains('kaza') && !loc.contains('kibber') && !loc.contains('tabo') && !loc.contains('pin') && !loc.contains('mud');
    }
    return true;
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

    final provider = Provider.of<StayProvider>(context);
    final filtered = provider.stayRequests
        .where((r) => _matchesFilter(r) && DateTime.now().difference(r.createdAt) <= LocalStorageService.requestValidity)
        .toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Room Requirements',
          style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 16),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981)),
                ),
                const SizedBox(width: 6),
                Text(
                  '${filtered.length} Active',
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              "Tourists currently looking for homestays in Spiti. Tap any card to call and invite them directly!",
              style: TextStyle(color: subText, fontSize: 11.5, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),

          // Filters list
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _locationFilters.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _locationFilters[i];
                final selected = _filterLocation == f;
                return GestureDetector(
                  onTap: () => setState(() => _filterLocation = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF0D9488)
                          : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        color: selected ? Colors.white : subText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Requests list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.houseboat_outlined, size: 72, color: Colors.grey[600]),
                        const SizedBox(height: 12),
                        Text(
                          'No active room searches found.\nTry a different filter!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: subText, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _StayRequestCard(
                      request: filtered[i],
                      timeAgo: _timeAgo(filtered[i].createdAt),
                      isDark: isDark,
                      primaryText: primaryText,
                      subText: subText,
                      status: _decisions[filtered[i].id],
                      onAccept: () => _decide(filtered[i], 'accepted'),
                      onReject: () => _decide(filtered[i], 'rejected'),
                      onContact: () {
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Calling tourist ${filtered[i].seekerName} at ${filtered[i].phone}...'),
                            backgroundColor: const Color(0xFF0D9488),
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

class _StayRequestCard extends StatelessWidget {
  final StayRequest request;
  final String timeAgo;
  final bool isDark;
  final Color primaryText;
  final Color? subText;
  final VoidCallback onContact;
  final String? status; // null | 'accepted' | 'rejected'
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _StayRequestCard({
    required this.request,
    required this.timeAgo,
    required this.isDark,
    required this.primaryText,
    required this.subText,
    required this.onContact,
    required this.status,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF14B8A6)]),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    request.seekerName.isNotEmpty ? request.seekerName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              request.seekerName,
                              style: TextStyle(color: primaryText, fontWeight: FontWeight.w700, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.people, size: 10, color: Color(0xFF0D9488)),
                                const SizedBox(width: 3),
                                Text(
                                  "${request.guestsCount} Guests",
                                  style: const TextStyle(color: Color(0xFF0D9488), fontSize: 8.5, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text("Date: ${request.dates}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                Text(
                  timeAgo,
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text("Seeker rating: ",
                        style: TextStyle(color: subText, fontSize: 12, fontWeight: FontWeight.bold)),
                    RatingBadge(
                      category: 'stay',
                      subjectId: request.phone,
                      subjectName: request.seekerName,
                      writeRole: 'Host',
                      accent: const Color(0xFF0D9488),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.pin_drop, size: 14, color: Color(0xFF0D9488)),
                    const SizedBox(width: 6),
                    Text(
                      "Looking in: ",
                      style: TextStyle(color: subText, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(
                        request.locationLooking,
                        style: TextStyle(color: primaryText, fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.payments, size: 14, color: Color(0xFF0D9488)),
                    const SizedBox(width: 6),
                    Text(
                      "Budget limit: ",
                      style: TextStyle(color: subText, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "₹${request.budgetPerNight.toInt()}/night max",
                      style: const TextStyle(color: Color(0xFF0D9488), fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.home_work_outlined, size: 14, color: Color(0xFF0D9488)),
                    const SizedBox(width: 6),
                    Text(
                      "Wants: ",
                      style: TextStyle(color: subText, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        request.propertyType,
                        style: const TextStyle(color: Color(0xFF0D9488), fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                if (request.desiredAmenities.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    "Services needed:",
                    style: TextStyle(color: subText, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: request.desiredAmenities
                        .map((a) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14B8A6).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF14B8A6).withValues(alpha: 0.25)),
                              ),
                              child: Text(a,
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF14B8A6))),
                            ))
                        .toList(),
                  ),
                ],
                if (request.note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "\"${request.note}\"",
                      style: TextStyle(color: subText, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Contact + Rate CTA Buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          onPressed: onContact,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.phone, color: Colors.white, size: 14),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "Call (${request.phone})",
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
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
                          category: 'stay',
                          subjectId: request.phone,
                          subjectName: request.seekerName,
                          authorRole: 'Host',
                          accent: const Color(0xFF0D9488),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D9488),
                          side: const BorderSide(color: Color(0xFF0D9488)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_outline, size: 14),
                            SizedBox(width: 5),
                            Text("Rate", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Accept / Reject decision
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
}
