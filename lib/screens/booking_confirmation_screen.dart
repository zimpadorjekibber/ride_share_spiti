import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../models/booked_trip_model.dart';

class BookingConfirmationScreen extends StatefulWidget {
  final BookedTrip trip;

  const BookingConfirmationScreen({super.key, required this.trip});

  @override
  State<BookingConfirmationScreen> createState() =>
      _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends State<BookingConfirmationScreen>
    with TickerProviderStateMixin {
  late AnimationController _circleController;
  late AnimationController _tickController;
  late AnimationController _contentController;

  late Animation<double> _circleScale;
  late Animation<double> _tickDraw;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();

    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _circleScale = CurvedAnimation(
      parent: _circleController,
      curve: Curves.elasticOut,
    );
    _tickDraw = CurvedAnimation(
      parent: _tickController,
      curve: Curves.easeOut,
    );
    _contentFade = CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeIn,
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentController,
      curve: Curves.easeOut,
    ));

    // Staggered animation sequence
    _circleController.forward().then((_) {
      _tickController.forward().then((_) {
        _contentController.forward();
      });
    });
  }

  @override
  void dispose() {
    _circleController.dispose();
    _tickController.dispose();
    _contentController.dispose();
    super.dispose();
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryText),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        title: Text(
          'Booking Confirmed',
          style: TextStyle(
              color: primaryText, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // ── Animated success circle ──
            ScaleTransition(
              scale: _circleScale,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _tickDraw,
                  builder: (context, _) => CustomPaint(
                    painter: _TickPainter(_tickDraw.value),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Slide-up content ──
            SlideTransition(
              position: _contentSlide,
              child: FadeTransition(
                opacity: _contentFade,
                child: Column(
                  children: [
                    Text(
                      'Seats Booked! 🎉',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your ride to ${widget.trip.to} is confirmed.',
                      style: TextStyle(color: subText, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 28),

                    // ── Booking Reference ──
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: widget.trip.bookingRef));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Booking ref copied!'),
                              duration: Duration(seconds: 2)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6366F1),
                              Color(0xFF818CF8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  const Color(0xFF6366F1).withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.confirmation_number,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'BOOKING REFERENCE',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  widget.trip.bookingRef,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.copy,
                                color: Colors.white70, size: 14),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Trip Summary Card ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trip Summary',
                            style: TextStyle(
                              color: primaryText,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _infoRow(Icons.person_outline, 'Driver',
                              widget.trip.driverName, primaryText, subText),
                          _divider(border),
                          _infoRow(Icons.directions_car_outlined, 'Vehicle',
                              widget.trip.vehicleName, primaryText, subText),
                          _divider(border),
                          _infoRow(Icons.pin_outlined, 'Plate',
                              widget.trip.plateNumber, primaryText, subText),
                          _divider(border),
                          _infoRow(
                              Icons.my_location,
                              'From',
                              widget.trip.from,
                              primaryText,
                              subText),
                          _divider(border),
                          _infoRow(Icons.location_on_outlined, 'To',
                              widget.trip.to, primaryText, subText),
                          _divider(border),
                          _infoRow(Icons.calendar_today_outlined, 'Date',
                              widget.trip.date, primaryText, subText),
                          _divider(border),
                          _infoRow(Icons.access_time, 'Departure',
                              widget.trip.time, primaryText, subText),
                          _divider(border),
                          _infoRow(Icons.event_seat_outlined, 'Seats',
                              widget.trip.seatIds.join(', '), primaryText, subText),
                          _divider(border),
                          _infoRow(
                            Icons.currency_rupee,
                            'Total Paid',
                            '₹${widget.trip.totalPaid.toInt()}',
                            primaryText,
                            const Color(0xFF10B981),
                            valueStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Action Buttons ──
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // Launch phone call
                            },
                            icon: const Icon(Icons.phone,
                                color: Color(0xFF6366F1)),
                            label: const Text('Call Driver'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF6366F1),
                              side: const BorderSide(color: Color(0xFF6366F1)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                Navigator.of(context).popUntil((r) => r.isFirst),
                            icon: const Icon(Icons.home, color: Colors.white),
                            label: const Text('Done'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      Color primaryText, Color? subText,
      {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6366F1)),
          const SizedBox(width: 12),
          Text(
            '$label  ',
            style: TextStyle(color: subText, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: valueStyle ??
                  TextStyle(
                    color: primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(Color color) => Divider(color: color, height: 1, thickness: 1);
}

class _TickPainter extends CustomPainter {
  final double progress;
  _TickPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.28, size.height * 0.52);
    path.lineTo(size.width * 0.45, size.height * 0.68);
    path.lineTo(size.width * 0.72, size.height * 0.38);

    final totalLength = _pathLength(path);
    final drawLength = totalLength * progress;

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      canvas.drawPath(
          metric.extractPath(0, drawLength.clamp(0, metric.length)), paint);
    }
  }

  double _pathLength(Path path) {
    double length = 0;
    for (final metric in path.computeMetrics()) {
      length += metric.length;
    }
    return length;
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.progress != progress;
}

/// Helper to generate a random booking reference
String generateBookingRef() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rng = Random();
  return 'SPI-${List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join()}';
}
