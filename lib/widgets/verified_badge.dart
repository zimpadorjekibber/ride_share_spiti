import 'package:flutter/material.dart';

/// Small "✓ Verified" chip shown next to a provider whose phone an admin has
/// verified. Use [light] on dark/coloured headers (white-on-colour).
class VerifiedBadge extends StatelessWidget {
  final bool light;
  const VerifiedBadge({super.key, this.light = false});

  @override
  Widget build(BuildContext context) {
    final c = light ? Colors.white : const Color(0xFF059669);
    final bg = light ? Colors.white.withValues(alpha: 0.22) : const Color(0xFF10B981).withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 11, color: c),
          const SizedBox(width: 3),
          Text('Verified', style: TextStyle(color: c, fontSize: 8.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
