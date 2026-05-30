import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ride_model.dart';
import '../models/booked_trip_model.dart';
import '../services/local_storage_service.dart';
import '../screens/booking_confirmation_screen.dart';

class SeatSelectorModal extends StatefulWidget {
  final Ride ride;

  const SeatSelectorModal({super.key, required this.ride});

  @override
  State<SeatSelectorModal> createState() => _SeatSelectorModalState();
}

class _SeatSelectorModalState extends State<SeatSelectorModal> {
  final List<String> _selectedSeats = [];

  void _toggleSeat(String seatId, bool isBooked) {
    if (isBooked) return;
    setState(() {
      if (_selectedSeats.contains(seatId)) {
        _selectedSeats.remove(seatId);
      } else {
        _selectedSeats.add(seatId);
      }
    });
  }

  // Helper to build a single clickable seat container
  Widget _buildSeatItem(String seatId) {
    final isBooked = widget.ride.bookedSeats.contains(seatId);
    final isSelected = _selectedSeats.contains(seatId);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Color bg = isDarkMode ? const Color(0xFF1E293B) : Colors.grey[200]!;
    Color border = isDarkMode ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15);
    Color text = isDarkMode ? Colors.white : Colors.black;

    if (isBooked) {
      bg = Colors.red.withValues(alpha: 0.15);
      border = Colors.red.withValues(alpha: 0.3);
      text = Colors.red[300]!;
    } else if (isSelected) {
      bg = const Color(0xFF6366F1);
      border = const Color(0xFF6366F1);
      text = Colors.white;
    }

    return GestureDetector(
      onTap: () => _toggleSeat(seatId, isBooked),
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Text(
          seatId,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: text,
          ),
        ),
      ),
    );
  }

  // Driver seat representation (non-clickable)
  Widget _buildDriverSeat() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
      ),
      child: const Text(
        "📢\nDRV",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold),
      ),
    );
  }

  // Empty placeholder representing the central aisle
  Widget _buildAisle() {
    return const SizedBox(
      width: 24,
      height: 42,
    );
  }

  // Main custom rendering engine for different vehicles
  Widget _buildPhysicalSeatingChart() {
    switch (widget.ride.vehicleType) {
      case VehicleType.bike:
        return Column(
          children: [
            _buildDriverSeat(), // Rider
            const SizedBox(height: 16),
            _buildSeatItem("S1"), // Pillion passenger
          ],
        );

      case VehicleType.taxi:
      case VehicleType.private:
        return Column(
          children: [
            // Row 1: Driver | Passenger
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDriverSeat(),
                const SizedBox(width: 42),
                _buildSeatItem("S1"),
              ],
            ),
            const SizedBox(height: 16),
            // Row 2: S2 | S3 | S4 (Back bench)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSeatItem("S2"),
                const SizedBox(width: 12),
                _buildSeatItem("S3"),
                const SizedBox(width: 12),
                _buildSeatItem("S4"),
              ],
            ),
          ],
        );

      case VehicleType.suv:
        return Column(
          children: [
            // Row 1: Driver | Front Pass
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDriverSeat(),
                const SizedBox(width: 42),
                _buildSeatItem("S1"),
              ],
            ),
            const SizedBox(height: 16),
            // Row 2: S2 | S3 | S4 (Middle row)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSeatItem("S2"),
                const SizedBox(width: 12),
                _buildSeatItem("S3"),
                const SizedBox(width: 12),
                _buildSeatItem("S4"),
              ],
            ),
            const SizedBox(height: 16),
            // Row 3: S5 | Aisle | S6 (Back row)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSeatItem("S5"),
                const SizedBox(width: 42),
                _buildSeatItem("S6"),
              ],
            ),
          ],
        );

      case VehicleType.tempo:
        return Column(
          children: [
            // Row 1: Driver | Passenger
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDriverSeat(),
                _buildAisle(),
                const SizedBox(width: 42),
                _buildSeatItem("S1"),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: S2 | Aisle | S3, S4
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSeatItem("S2"),
                _buildAisle(),
                _buildSeatItem("S3"),
                const SizedBox(width: 8),
                _buildSeatItem("S4"),
              ],
            ),
            const SizedBox(height: 12),
            // Row 3: S5 | Aisle | S6, S7
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSeatItem("S5"),
                _buildAisle(),
                _buildSeatItem("S6"),
                const SizedBox(width: 8),
                _buildSeatItem("S7"),
              ],
            ),
            const SizedBox(height: 12),
            // Row 4: S8 | Aisle | S9, S10
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSeatItem("S8"),
                _buildAisle(),
                _buildSeatItem("S9"),
                const SizedBox(width: 8),
                _buildSeatItem("S10"),
              ],
            ),
            const SizedBox(height: 12),
            // Row 5: S11 | S12 (Last full back row)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSeatItem("S11"),
                const SizedBox(width: 24),
                _buildSeatItem("S12"),
              ],
            ),
          ],
        );

      case VehicleType.bus:
        List<Widget> busRows = [];

        // Driver Row
        busRows.add(
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDriverSeat(),
              _buildAisle(),
              const SizedBox(width: 92), // Spacing representing driver cabin
            ],
          ),
        );
        busRows.add(const SizedBox(height: 16));

        // 2x2 rows with aisle down the center
        int seatCounter = 1;
        for (int row = 0; row < 7; row++) {
          final s1 = "S${seatCounter++}";
          final s2 = "S${seatCounter++}";
          final s3 = "S${seatCounter++}";
          final s4 = "S${seatCounter++}";

          busRows.add(
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSeatItem(s1),
                const SizedBox(width: 8),
                _buildSeatItem(s2),
                _buildAisle(),
                _buildSeatItem(s3),
                const SizedBox(width: 8),
                _buildSeatItem(s4),
              ],
            ),
          );
          busRows.add(const SizedBox(height: 10));
        }

        // Back Bench row (S29, S30)
        busRows.add(
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSeatItem("S29"),
              const SizedBox(width: 24),
              _buildSeatItem("S30"),
            ],
          ),
        );

        return Column(children: busRows);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double totalPrice = _selectedSeats.length * widget.ride.price;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final modalBgColor = isDarkMode ? const Color(0xFF0F172A) : Colors.white;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: modalBgColor,
        borderRadius: BorderRadius.vertical(top: const Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Select Seats & Book",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                )
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Driver Name: ${widget.ride.driverName}",
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            Text(
              "Route: ${widget.ride.from} ➔ ${widget.ride.to}",
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            // Seating Map
            Center(
              child: Column(
                children: [
                  Text(
                    "FRONT ROW / AISLE SCHEMATIC",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 160,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]),
                  ),
                  const SizedBox(height: 20),
                  // Custom Seating Chart
                  _buildPhysicalSeatingChart(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem("Empty", isDarkMode ? const Color(0xFF1E293B) : Colors.grey[200]!),
                const SizedBox(width: 16),
                _buildLegendItem("Selected", const Color(0xFF6366F1)),
                const SizedBox(width: 16),
                _buildLegendItem("Booked", Colors.red.withValues(alpha: 0.3)),
              ],
            ),
            const SizedBox(height: 24),
            // Footer / Booking Button
            Container(
              padding: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TOTAL PRICE",
                        style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "₹${totalPrice.toInt()}",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: _selectedSeats.isEmpty
                        ? null
                        : () async {
                            // 1. Update ride in provider / Firebase
                            Provider.of<RideProvider>(context, listen: false)
                                .bookSeats(widget.ride.id, List.from(_selectedSeats));

                            // 2. Build BookedTrip and save locally
                            final trip = BookedTrip(
                              bookingRef: generateBookingRef(),
                              rideId: widget.ride.id,
                              driverName: widget.ride.driverName,
                              driverPhone: widget.ride.phone,
                              vehicleName: widget.ride.vehicleName,
                              plateNumber: widget.ride.plateNumber,
                              from: widget.ride.from,
                              to: widget.ride.to,
                              date: widget.ride.date,
                              time: widget.ride.time,
                              seatIds: List.from(_selectedSeats),
                              totalPaid: _selectedSeats.length * widget.ride.price,
                              status: 'upcoming',
                              bookedAt: DateTime.now(),
                            );
                            await LocalStorageService.saveTrip(trip);
                            await LocalStorageService.addNotification(
                              '🎫 Seats Confirmed — ${trip.bookingRef}',
                              '${_selectedSeats.length} seat(s) booked on ${widget.ride.vehicleName} from ${widget.ride.from} → ${widget.ride.to}',
                            );

                            // 3. Navigate to confirmation
                            if (context.mounted) {
                              Navigator.pop(context); // close modal
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      BookingConfirmationScreen(trip: trip),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      disabledBackgroundColor: Colors.grey.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Confirm & Book",
                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
