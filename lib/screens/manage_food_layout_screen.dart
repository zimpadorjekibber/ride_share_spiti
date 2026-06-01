import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/food_model.dart';

/// Host screen to manage a food place's TABLE LAYOUT (Free/Occupied) and the
/// per-item STOCK ("kitne plate bache hain"). Shows a live tappable table grid.
class ManageFoodLayoutScreen extends StatefulWidget {
  final FoodPlace place;
  const ManageFoodLayoutScreen({super.key, required this.place});

  @override
  State<ManageFoodLayoutScreen> createState() => _ManageFoodLayoutScreenState();
}

class _TableDraft {
  String id;
  TextEditingController name;
  bool occupied;
  _TableDraft({required this.id, required this.name, this.occupied = false});
}

class _StockDraft {
  final String name;
  final double price;
  int qtyLeft; // -1 = not tracked / unlimited
  _StockDraft({required this.name, required this.price, this.qtyLeft = -1});
}

class _ManageFoodLayoutScreenState extends State<ManageFoodLayoutScreen> {
  final List<_TableDraft> _tables = [];
  final List<_StockDraft> _stock = [];
  bool _submitting = false;
  static const Color _amber = Color(0xFFF59E0B);

  /// Tables matter for sit-down Restaurants & Cafes (or if some already exist).
  bool get _showTables =>
      widget.place.foodType == 'Restaurant' ||
      widget.place.foodType == 'Cafe' ||
      _tables.isNotEmpty;

  @override
  void initState() {
    super.initState();
    for (final t in widget.place.tables) {
      _tables.add(_TableDraft(id: t.id, name: TextEditingController(text: t.name), occupied: t.occupied));
    }
    for (final m in widget.place.menu) {
      _stock.add(_StockDraft(name: m.name, price: m.price, qtyLeft: m.qtyLeft));
    }
  }

  void _addTable() {
    final n = _tables.length + 1;
    _tables.add(_TableDraft(
      id: 'tbl_${DateTime.now().millisecondsSinceEpoch}_$n',
      name: TextEditingController(text: 'Table $n'),
    ));
  }

  @override
  void dispose() {
    for (final t in _tables) {
      t.name.dispose();
    }
    super.dispose();
  }

  void _save() {
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<FoodProvider>(context, listen: false);

    final tableUnits = _tables
        .where((t) => t.name.text.trim().isNotEmpty)
        .map((t) => TableUnit(id: t.id, name: t.name.text.trim(), occupied: t.occupied))
        .toList();

    // Merge stock back into the existing menu (match by name + price).
    final newMenu = widget.place.menu.map((m) {
      final s = _stock.firstWhere(
        (x) => x.name == m.name && x.price == m.price,
        orElse: () => _StockDraft(name: m.name, price: m.price, qtyLeft: m.qtyLeft),
      );
      return MenuItem(name: m.name, price: m.price, available: s.qtyLeft != 0, qtyLeft: s.qtyLeft);
    }).toList();

    final p = widget.place;
    provider.updateFoodPlace(FoodPlace(
      id: p.id, ownerName: p.ownerName, phone: p.phone, title: p.title,
      foodType: p.foodType, cuisine: p.cuisine, vegType: p.vegType,
      description: p.description, pricePerPlate: p.pricePerPlate, timings: p.timings,
      homeDelivery: p.homeDelivery, deliveryRangeKm: p.deliveryRangeKm,
      cookOnRequest: p.cookOnRequest, offMarket: p.offMarket, lat: p.lat, lng: p.lng,
      rating: p.rating, safetyFlags: p.safetyFlags, mockPhotoIndex: p.mockPhotoIndex,
      photoPath: p.photoPath, photos: p.photos, menu: newMenu, menuLink: p.menuLink,
      facilities: p.facilities, tables: tableUnits,
    ));

    messenger.showSnackBar(
      const SnackBar(content: Text('✅ Layout & stock saved!'), backgroundColor: _amber),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];
    final free = _tables.where((t) => !t.occupied).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryText),
        title: Text('${_showTables ? 'Tables & Stock' : 'Menu Stock'} — ${widget.place.title}',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 15)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Live table layout (Restaurant only) ──
            if (_showTables) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _amber.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _amber.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.table_restaurant, color: _amber, size: 18),
                      const SizedBox(width: 6),
                      Text('Table Layout', style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 15)),
                      const Spacer(),
                      Text(_tables.isEmpty ? 'no tables' : '$free free / ${_tables.length}',
                          style: TextStyle(color: free == 0 && _tables.isNotEmpty ? Colors.redAccent : const Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_tables.isEmpty)
                    Text('No tables yet — add some below for your sit-down restaurant / cafe.',
                        style: TextStyle(color: subText, fontSize: 12))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_tables.length, (i) {
                        final t = _tables[i];
                        final c = t.occupied ? Colors.redAccent : const Color(0xFF10B981);
                        return GestureDetector(
                          onTap: () => setState(() => t.occupied = !t.occupied),
                          child: Container(
                            width: 64,
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: c, width: 1.5),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(t.occupied ? Icons.event_seat : Icons.event_seat_outlined, color: c, size: 18),
                                const SizedBox(height: 2),
                                Text(t.name.text.isEmpty ? '—' : t.name.text,
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: c, fontSize: 8.5, height: 1.1, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  const SizedBox(height: 6),
                  Text('🟢 free · 🔴 occupied — tap a table to toggle',
                      style: TextStyle(color: subText, fontSize: 10.5)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Table editors ──
            ...List.generate(_tables.length, (i) => _tableCard(i, isDark, primaryText)),
            OutlinedButton.icon(
              onPressed: () => setState(_addTable),
              icon: const Icon(Icons.add, color: _amber),
              label: const Text('Add Table', style: TextStyle(color: _amber, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: _amber)),
            ),
            const SizedBox(height: 24),
            ], // end if (_showTables)

            // ── Menu stock ("kitne plate bache hain") ──
            Row(
              children: [
                const Icon(Icons.inventory_2, color: _amber, size: 18),
                const SizedBox(width: 6),
                Text('Today\'s Stock', style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Set how many plates are left. "—" means unlimited / not tracked. 0 = sold out.',
                style: TextStyle(color: subText, fontSize: 11)),
            const SizedBox(height: 12),
            if (_stock.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _amber.withValues(alpha: 0.2)),
                ),
                child: Text('No menu items yet. Add dishes via Edit first, then set plates here.',
                    style: TextStyle(color: subText, fontSize: 12)),
              )
            else
              ...List.generate(_stock.length, (i) => _stockRow(i, isDark, primaryText, subText)),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: _amber, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_showTables ? '💾 Save Tables & Stock' : '💾 Save Menu Stock',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _tableCard(int i, bool isDark, Color primaryText) {
    final t = _tables[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (t.occupied ? Colors.redAccent : _amber).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: t.name,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: primaryText, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Table name / number',
                labelStyle: TextStyle(color: Colors.grey, fontSize: 10),
                border: InputBorder.none,
              ),
            ),
          ),
          // occupied toggle
          GestureDetector(
            onTap: () => setState(() => t.occupied = !t.occupied),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (t.occupied ? Colors.redAccent : const Color(0xFF10B981)).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(t.occupied ? '🔴 Busy' : '🟢 Free',
                  style: TextStyle(color: t.occupied ? Colors.redAccent : const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _tables.removeAt(i)..name.dispose()),
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _stockRow(int i, bool isDark, Color primaryText, Color? subText) {
    final s = _stock[i];
    final out = s.qtyLeft == 0;
    final tracked = s.qtyLeft >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (out ? Colors.redAccent : _amber).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: primaryText, fontWeight: FontWeight.w700, fontSize: 13)),
                Text(out ? 'SOLD OUT' : (tracked ? '${s.qtyLeft} plates left' : 'Unlimited / not tracked'),
                    style: TextStyle(color: out ? Colors.redAccent : (tracked ? const Color(0xFF10B981) : subText), fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          // − stepper
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() {
              if (s.qtyLeft < 0) {
                s.qtyLeft = 0; // untracked → sold out
              } else if (s.qtyLeft > 0) {
                s.qtyLeft--;
              }
            }),
            icon: const Icon(Icons.remove_circle_outline, color: _amber),
          ),
          Text(tracked ? '${s.qtyLeft}' : '—',
              style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, fontSize: 15)),
          // + stepper
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => s.qtyLeft = (s.qtyLeft < 0 ? 1 : s.qtyLeft + 1)),
            icon: const Icon(Icons.add_circle_outline, color: _amber),
          ),
          // reset to untracked
          IconButton(
            tooltip: 'Not tracked / unlimited',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => s.qtyLeft = -1),
            icon: Icon(Icons.all_inclusive, color: tracked ? Colors.grey : const Color(0xFF10B981), size: 18),
          ),
        ],
      ),
    );
  }
}
