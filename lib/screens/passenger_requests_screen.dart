import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/passenger_request_model.dart';

class PassengerRequestsScreen extends StatefulWidget {
  const PassengerRequestsScreen({super.key});

  @override
  State<PassengerRequestsScreen> createState() =>
      _PassengerRequestsScreenState();
}

class _PassengerRequestsScreenState extends State<PassengerRequestsScreen> {
  String _filterRoute = 'All';

  final List<String> _routeFilters = [
    'All', 'To Spiti', 'From Spiti', 'Within Spiti', 'Other'
  ];

  bool _matchesFilter(PassengerRequest r) {
    if (_filterRoute == 'All') return true;
    final from = r.from.toLowerCase();
    final to = r.to.toLowerCase();
    if (_filterRoute == 'To Spiti') {
      return to.contains('kaza') ||
          to.contains('spiti') ||
          to.contains('key') ||
          to.contains('kibber') ||
          to.contains('hikkim');
    }
    if (_filterRoute == 'From Spiti') {
      return from.contains('kaza') ||
          from.contains('spiti') ||
          from.contains('key') ||
          from.contains('kibber');
    }
    if (_filterRoute == 'Within Spiti') {
      return (from.contains('kaza') || from.contains('spiti')) &&
          (to.contains('kaza') ||
              to.contains('spiti') ||
              to.contains('key') ||
              to.contains('monastery'));
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

    final provider = Provider.of<PassengerRequestProvider>(context);
    final filtered =
        provider.requests.where(_matchesFilter).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Passenger Requests',
            style: TextStyle(
                color: primaryText,
                fontWeight: FontWeight.w800,
                fontSize: 18)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981))),
                const SizedBox(width: 6),
                Text('${filtered.length} Active',
                    style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips ──
          SizedBox(
            height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _routeFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _routeFilters[i];
                final selected = _filterRoute == f;
                return GestureDetector(
                  onTap: () => setState(() => _filterRoute = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF6366F1)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        color: selected ? Colors.white : subText,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // ── List ──
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search,
                            size: 72, color: Colors.grey[600]),
                        const SizedBox(height: 12),
                        Text('No passengers looking\nfor rides right now.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: subText, fontSize: 15)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _RequestCard(
                      request: filtered[i],
                      timeAgo: _timeAgo(filtered[i].createdAt),
                      isDark: isDark,
                      primaryText: primaryText,
                      subText: subText,
                      onContact: () {
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Calling ${filtered[i].passengerName}...'),
                            backgroundColor: const Color(0xFF6366F1),
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

class _RequestCard extends StatelessWidget {
  final PassengerRequest request;
  final String timeAgo;
  final bool isDark;
  final Color primaryText;
  final Color? subText;
  final VoidCallback onContact;

  const _RequestCard({
    required this.request,
    required this.timeAgo,
    required this.isDark,
    required this.primaryText,
    required this.subText,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    request.passengerName.isNotEmpty
                        ? request.passengerName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16),
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
                            child: Text(request.passengerName,
                                style: TextStyle(
                                    color: primaryText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            request.passengerRating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        ],
                      ),
                      Text(request.phone,
                          style: TextStyle(
                              color: const Color(0xFF6366F1),
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_seat,
                              color: Color(0xFF10B981), size: 12),
                          const SizedBox(width: 4),
                          Text('${request.seatsNeeded} seat(s)',
                              style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(timeAgo,
                        style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                          Row(
                  children: [
                    const Icon(Icons.trip_origin,
                        color: Color(0xFF6366F1), size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(request.from,
                          style: TextStyle(
                              color: primaryText,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward,
                          color: Colors.grey, size: 14),
                    ),
                    Expanded(
                      child: Text(request.to,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              color: primaryText,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                if (request.passengerRating < 4.0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.gpp_bad, color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request.safetyFlags.isNotEmpty 
                                ? request.safetyFlags.first 
                                : "⚠️ Flagged: Low safety score!",
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                // Date + note
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 12, color: subText),
                    const SizedBox(width: 5),
                    Text(request.date,
                        style: TextStyle(color: subText, fontSize: 12)),
                    if (request.note.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.info_outline, size: 12, color: subText),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(request.note,
                            style: TextStyle(
                                color: subText,
                                fontSize: 12,
                                fontStyle: FontStyle.italic),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Copy phone
                          Clipboard.setData(
                              ClipboardData(text: request.phone));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Phone number copied!'),
                                duration: Duration(seconds: 1)),
                          );
                        },
                        icon: const Icon(Icons.copy,
                            size: 14, color: Color(0xFF6366F1)),
                        label: const Text('Copy Number'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6366F1),
                          side: const BorderSide(color: Color(0xFF6366F1)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onContact,
                        icon: const Icon(Icons.phone,
                            size: 14, color: Colors.white),
                        label: const Text('Call Passenger'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
