import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stay_model.dart';
import '../services/storage_service.dart';
import '../widgets/photo_picker_field.dart';

/// Host screen to manage a homestay's individual rooms — each with its own
/// photo, price, and Occupied/Vacant status. Shows a live layout grid.
class ManageRoomsScreen extends StatefulWidget {
  final Stay stay;
  const ManageRoomsScreen({super.key, required this.stay});

  @override
  State<ManageRoomsScreen> createState() => _ManageRoomsScreenState();
}

class _RoomDraft {
  String id;
  TextEditingController name;
  TextEditingController price;
  String photoPath;
  bool occupied;
  _RoomDraft({required this.id, required this.name, required this.price, this.photoPath = '', this.occupied = false});
}

class _ManageRoomsScreenState extends State<ManageRoomsScreen> {
  final List<_RoomDraft> _rooms = [];
  bool _submitting = false;
  static const Color _teal = Color(0xFF0D9488);

  @override
  void initState() {
    super.initState();
    for (final r in widget.stay.roomUnits) {
      _rooms.add(_RoomDraft(
        id: r.id,
        name: TextEditingController(text: r.name),
        price: TextEditingController(text: r.price.toInt().toString()),
        photoPath: r.photoPath,
        occupied: r.occupied,
      ));
    }
    if (_rooms.isEmpty) _addRoom();
  }

  void _addRoom() {
    final n = _rooms.length + 1;
    _rooms.add(_RoomDraft(
      id: 'room_${DateTime.now().millisecondsSinceEpoch}_$n',
      name: TextEditingController(text: 'Room $n'),
      price: TextEditingController(text: widget.stay.pricePerNight.toInt().toString()),
    ));
  }

  @override
  void dispose() {
    for (final r in _rooms) {
      r.name.dispose();
      r.price.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final valid = _rooms.where((r) => r.name.text.trim().isNotEmpty).toList();
    if (valid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one room with a name.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<StayProvider>(context, listen: false);

    try {
      // Upload all room photos in PARALLEL so total wait ≈ the slowest single
      // photo, not the sum. uploadPhoto never throws (falls back to local path).
      final urls = await Future.wait(
        valid.map((r) => StorageService.uploadPhoto(r.photoPath, 'rooms')),
      );

      final units = <RoomUnit>[];
      for (var i = 0; i < valid.length; i++) {
        final r = valid[i];
        units.add(RoomUnit(
          id: r.id,
          name: r.name.text.trim(),
          price: double.tryParse(r.price.text.trim()) ?? widget.stay.pricePerNight,
          photoPath: urls[i],
          occupied: r.occupied,
        ));
      }

      // Rebuild the stay with updated rooms (and keep listing availability in sync).
      final s = widget.stay;
      final allOccupied = units.every((u) => u.occupied);
      provider.updateStay(s.copyWith(
        roomsAvailable: units.where((u) => !u.occupied).length,
        isFull: allOccupied,
        roomUnits: units,
      ));

      messenger.showSnackBar(
        const SnackBar(content: Text('✅ Rooms saved!'), backgroundColor: _teal),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save rooms: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];
    final vacant = _rooms.where((r) => !r.occupied).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryText),
        title: Text('Manage Rooms — ${widget.stay.title}',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 15)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Live layout ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _teal.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _teal.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.grid_view_rounded, color: _teal, size: 18),
                      const SizedBox(width: 6),
                      Text('Room Layout', style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 15)),
                      const Spacer(),
                      Text('$vacant vacant / ${_rooms.length}',
                          style: TextStyle(color: vacant == 0 ? Colors.redAccent : const Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_rooms.length, (i) {
                      final r = _rooms[i];
                      final c = r.occupied ? Colors.redAccent : const Color(0xFF10B981);
                      return GestureDetector(
                        onTap: () => setState(() => r.occupied = !r.occupied),
                        child: Container(
                          width: 64,
                          height: 56,
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c, width: 1.5),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(r.occupied ? Icons.bed : Icons.bed_outlined, color: c, size: 18),
                              const SizedBox(height: 2),
                              Text(
                                r.name.text.isEmpty ? '—' : r.name.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: c, fontSize: 8.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 6),
                  Text('🟢 vacant · 🔴 occupied — tap a box to toggle quickly',
                      style: TextStyle(color: subText, fontSize: 10.5)),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Room editors ──
            ...List.generate(_rooms.length, (i) => _roomCard(i, isDark, primaryText, subText)),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => setState(_addRoom),
              icon: const Icon(Icons.add, color: _teal),
              label: const Text('Add Room', style: TextStyle(color: _teal, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: _teal)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: _teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('💾 Save Rooms', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _roomCard(int i, bool isDark, Color primaryText, Color? subText) {
    final r = _rooms[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: (r.occupied ? Colors.redAccent : _teal).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _field(r.name, 'Room name / number')),
              const SizedBox(width: 8),
              SizedBox(width: 110, child: _field(r.price, '₹ price/night', isNumber: true)),
              IconButton(
                onPressed: _rooms.length == 1
                    ? null
                    : () => setState(() {
                          _rooms.removeAt(i)
                            ..name.dispose()
                            ..price.dispose();
                        }),
                icon: Icon(Icons.delete_outline, color: _rooms.length == 1 ? Colors.grey : Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PhotoPickerField(
            path: r.photoPath,
            accent: _teal,
            label: 'Add Room Photo',
            onPicked: (p) => setState(() => r.photoPath = p),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: r.occupied,
            onChanged: (v) => setState(() => r.occupied = v),
            activeThumbColor: Colors.redAccent,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(r.occupied ? '🔴 Occupied (booked)' : '🟢 Vacant (available)',
                style: TextStyle(color: primaryText, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool isNumber = false}) {
    return TextField(
      controller: c,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: (_) => setState(() {}), // refresh layout labels
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 10),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _teal),
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
