import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/booked_trip_model.dart';
import '../services/local_storage_service.dart';
import '../models/ride_model.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BookedTrip> _trips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final trips = await LocalStorageService.getTrips();
    if (mounted) {
      setState(() {
        _trips = trips;
        _loading = false;
      });
    }
  }

  Future<void> _cancelTrip(String bookingRef) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Trip?'),
        content: const Text(
            'Are you sure you want to cancel this booking? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await LocalStorageService.cancelTrip(bookingRef);
      _loadTrips();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final primaryText = isDark ? Colors.white : Colors.black87;

    final upcoming =
        _trips.where((t) => t.status == 'upcoming').toList();
    final past = _trips
        .where((t) => t.status == 'completed' || t.status == 'cancelled')
        .toList();

    final rideProvider = Provider.of<RideProvider>(context);
    final appMode = rideProvider.appMode;
    // Both Stay & Food use the simple "booked via direct call" placeholder.
    final isStayMode = appMode != AppMode.ride;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          appMode == AppMode.ride
              ? 'My Trips'
              : appMode == AppMode.stay
                  ? 'My Bookings'
                  : 'My Orders',
          style: TextStyle(
              color: primaryText, fontWeight: FontWeight.w800, fontSize: 22),
        ),
        bottom: isStayMode
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF6366F1),
                labelColor: const Color(0xFF6366F1),
                unselectedLabelColor: Colors.grey,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                tabs: [
                  Tab(text: 'Upcoming (${upcoming.length})'),
                  Tab(text: 'Past (${past.length})'),
                ],
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : isStayMode
              ? _buildCozyStaysPlaceholder(isDark, primaryText)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _TripList(
                      trips: upcoming,
                      onCancel: _cancelTrip,
                      onReviewCompleted: _loadTrips,
                      emptyMessage: 'No upcoming trips.\nBook a ride now!',
                      emptyIcon: Icons.luggage_outlined,
                ),
                _TripList(
                  trips: past,
                  onCancel: null,
                  onReviewCompleted: _loadTrips,
                  emptyMessage: 'No past trips yet.',
                  emptyIcon: Icons.history,
                ),
              ],
            ),
    );
  }

  Widget _buildCozyStaysPlaceholder(bool isDark, Color primaryText) {
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.villa_outlined, size: 84, color: Color(0xFF0D9488)),
          const SizedBox(height: 16),
          Text(
            "Spiti Booking Hub",
            textAlign: TextAlign.center,
            style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            "Stays & meals are arranged directly via one-click phone calls with local hosts and cooks. This keeps it fast and immune to internet cuts in high valleys!",
            textAlign: TextAlign.center,
            style: TextStyle(color: subText, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "🏔️ Homestay Booking Guide:",
                  style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 12),
                _guideItem("1. Choose Homestay", "Browse the FindStay tab, review rooms, budget, Bukhari, and Geyser filters."),
                const SizedBox(height: 10),
                _guideItem("2. Tap 'Contact Host'", "Directly call the Spitian family, confirm dates, and ask for fresh local food."),
                const SizedBox(height: 10),
                _guideItem("3. Broadcast Needs", "Can't find a room? Use 'FindStay Seeker' button to let hosts find and call you!"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _guideItem(String title, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0D9488))),
        const SizedBox(height: 2),
        Text(desc, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
      ],
    );
  }
}

class _TripList extends StatelessWidget {
  final List<BookedTrip> trips;
  final Future<void> Function(String)? onCancel;
  final VoidCallback? onReviewCompleted;
  final String emptyMessage;
  final IconData emptyIcon;

  const _TripList({
    required this.trips,
    required this.onCancel,
    this.onReviewCompleted,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];

    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 72, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: subText, fontSize: 16, height: 1.6),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trips.length,
        itemBuilder: (context, i) =>
            _TripCard(
              trip: trips[i], 
              onCancel: onCancel,
              onReviewCompleted: onReviewCompleted,
            ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final BookedTrip trip;
  final Future<void> Function(String)? onCancel;
  final VoidCallback? onReviewCompleted;

  const _TripCard({
    required this.trip, 
    required this.onCancel,
    this.onReviewCompleted,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'upcoming': return const Color(0xFF10B981);
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'upcoming': return 'Upcoming';
      case 'cancelled': return 'Cancelled';
      default: return 'Completed';
    }
  }

  void _showReviewBottomSheet(BuildContext context, BookedTrip trip) {
    double selectedRating = 5.0;
    List<String> selectedFlags = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF111827) : Colors.white;
        final textPrimary = isDark ? Colors.white : Colors.black87;
        final borderAccent = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1);

        final flagOptions = [
          {'key': 'gadi_gandi', 'text': 'गाड़ी खराब या गंदी हो (Dirty/Smelly Vehicle)'},
          {'key': 'rash_driving', 'text': 'ड्राइविंग रैश हो (Rash/Reckless Driving)'},
          {'key': 'bad_talk', 'text': 'बातचीत खराब हो (Rude Behavior/Poor Conduct)'},
          {'key': 'frequent_breakdown', 'text': 'बार-बार खराब होने वाली गाड़ी (Frequently Breaks Down)'},
        ];

        return StatefulBuilder(
          builder: (sheetCtx, setState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 30,
              ),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: borderAccent),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Rate Your Experience",
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Feedback for ${trip.driverName} • ${trip.vehicleName}",
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // ⭐ Stars selector
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final score = index + 1.0;
                            final isSelected = selectedRating >= score;
                            return IconButton(
                              onPressed: () {
                                setState(() {
                                  selectedRating = score;
                                });
                              },
                              iconSize: 42,
                              icon: Icon(
                                isSelected ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          selectedRating == 5.0
                              ? "Excellent (शानदार सफर!)"
                              : selectedRating >= 4.0
                                  ? "Very Good (अच्छा था)"
                                  : selectedRating >= 3.0
                                      ? "Average (ठीक-ठाक)"
                                      : selectedRating >= 2.0
                                          ? "Poor (खराब अनुभव)"
                                          : "Very Bad (बहुत खराब)",
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Divider(color: borderAccent, height: 1),
                  const SizedBox(height: 16),

                  // Safety issues header
                  Row(
                    children: [
                      const Icon(Icons.security, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        "Flag Safety & Quality Issues",
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Select any issues you faced during the ride. Low safety ratings trigger high-contrast warning badges for future passengers.",
                    style: TextStyle(color: Colors.grey[500], fontSize: 11, height: 1.4),
                  ),
                  const SizedBox(height: 12),

                  // Checklist options
                  ...flagOptions.map((opt) {
                    final label = opt['text']!;
                    final isChecked = selectedFlags.contains(label);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isChecked
                            ? Colors.red.withValues(alpha: 0.05)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isChecked
                              ? Colors.red.withValues(alpha: 0.25)
                              : Colors.transparent,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isChecked,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              selectedFlags.add(label);
                            } else {
                              selectedFlags.remove(label);
                            }
                          });
                        },
                        title: Text(
                          label,
                          style: TextStyle(
                            color: isChecked ? Colors.redAccent : textPrimary,
                            fontSize: 13,
                            fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        activeColor: Colors.redAccent,
                        checkColor: Colors.white,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        dense: true,
                      ),
                    );
                  }),

                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(ctx);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);

                        // Save the review details using LocalStorage
                        await LocalStorageService.reviewTrip(
                          trip.bookingRef,
                          selectedRating,
                          selectedFlags,
                        );

                        // Pop bottom sheet
                        navigator.pop();

                        // Show success snackbar
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    selectedFlags.isNotEmpty
                                        ? "Review recorded. Safety flags logged for community audit!"
                                        : "Review submitted. Thank you for your feedback!",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: selectedFlags.isNotEmpty ? Colors.redAccent : const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );

                        // Callback to parent to reload trips
                        if (onReviewCompleted != null) {
                          onReviewCompleted!();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedFlags.isNotEmpty ? Colors.redAccent : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Submit Review (फीडबैक जमा करें)",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReviewedSection(BuildContext context, BookedTrip trip, Color border, Color primaryText, Color? subText) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
              const SizedBox(width: 6),
              Text(
                "Feedback Submitted",
                style: TextStyle(color: primaryText, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Spacer(),
              Row(
                children: List.generate(5, (starIdx) {
                  return Icon(
                    starIdx < (trip.ratingGiven ?? 5.0) ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 14,
                  );
                }),
              ),
            ],
          ),
          if (trip.safetyIssuesFlagged.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: trip.safetyIssuesFlagged.map((issue) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        issue.split('(').first.trim(),
                        style: const TextStyle(color: Colors.redAccent, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              "😊 Perfect ride! No safety concerns reported.",
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];
    final border = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _statusColor(trip.status).withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.confirmation_number,
                    color: _statusColor(trip.status), size: 16),
                const SizedBox(width: 8),
                Text(
                  trip.bookingRef,
                  style: TextStyle(
                    color: _statusColor(trip.status),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(trip.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(trip.status),
                    style: TextStyle(
                      color: _statusColor(trip.status),
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route
                Row(
                  children: [
                    const Icon(Icons.trip_origin,
                        color: Color(0xFF6366F1), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(trip.from,
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
                      child: Text(trip.to,
                          style: TextStyle(
                              color: primaryText,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Driver & vehicle
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: subText),
                    const SizedBox(width: 6),
                    Text(trip.driverName,
                        style: TextStyle(color: subText, fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(Icons.directions_car_outlined,
                        size: 14, color: subText),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(trip.vehicleName,
                          style: TextStyle(color: subText, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Date, seats, price
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _chip(Icons.calendar_today_outlined,
                        '${trip.date}  ${trip.time}', subText),
                    _chip(Icons.event_seat_outlined,
                        '${trip.seatIds.length} seat(s)', subText),
                    _chip(Icons.currency_rupee,
                        '₹${trip.totalPaid.toInt()}', subText),
                  ],
                ),
                if (trip.status == 'upcoming' && onCancel != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => onCancel!(trip.bookingRef),
                          icon: const Icon(Icons.cancel_outlined,
                              size: 16, color: Colors.red),
                          label: const Text('Cancel Booking'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.phone,
                              size: 16, color: Colors.white),
                          label: const Text('Call Driver'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (trip.status == 'completed') ...[
                  const SizedBox(height: 14),
                  if (trip.isReviewed)
                    _buildReviewedSection(context, trip, border, primaryText, subText)
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _showReviewBottomSheet(context, trip),
                        icon: const Icon(Icons.star_outline_rounded,
                            size: 18, color: Colors.white),
                        label: const Text('⭐ Rate & Flag Safety Issues'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color? color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

}
