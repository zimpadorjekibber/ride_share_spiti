import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lost_found_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  bool _sosSent = false;

  final List<_EmergencyContact> _contacts = [
    _EmergencyContact(
      name: 'Spiti Police Control Room',
      number: '01906-222222',
      icon: Icons.local_police_outlined,
      color: Color(0xFF6366F1),
      category: 'POLICE',
    ),
    _EmergencyContact(
      name: 'Kaza Hospital',
      number: '01906-222223',
      icon: Icons.local_hospital_outlined,
      color: Color(0xFF10B981),
      category: 'MEDICAL',
    ),
    _EmergencyContact(
      name: 'BRO (Road Emergency)',
      number: '01906-222224',
      icon: Icons.add_road,
      color: Color(0xFFF59E0B),
      category: 'ROAD RESCUE',
    ),
    _EmergencyContact(
      name: 'ITBP Mountain Rescue',
      number: '01906-222225',
      icon: Icons.hiking,
      color: Color(0xFFEF4444),
      category: 'MOUNTAIN RESCUE',
    ),
    _EmergencyContact(
      name: 'HP Tourist Helpline',
      number: '1800-180-8080',
      icon: Icons.support_agent,
      color: Color(0xFF8B5CF6),
      category: 'TOURISM',
    ),
    _EmergencyContact(
      name: 'National Emergency',
      number: '112',
      icon: Icons.emergency,
      color: Color(0xFFEF4444),
      category: 'NATIONAL',
    ),
  ];

  final List<_SpitiTip> _tips = [
    _SpitiTip(
        icon: '🏔️',
        tip: 'Rohtang Pass (3,978m) — closed Oct to May. Check BRO updates.'),
    _SpitiTip(
        icon: '🌊',
        tip: 'Flash floods possible June–Aug. Never camp near riverbeds.'),
    _SpitiTip(
        icon: '📶',
        tip: 'No mobile signal in many areas. Download offline maps before entering.'),
    _SpitiTip(
        icon: '⛽',
        tip: 'Last fuel station at Gramphoo. Fill up before entering Spiti.'),
    _SpitiTip(
        icon: '🧊',
        tip: 'Black ice on roads Oct–April. Drive slow, use 4WD.'),
    _SpitiTip(
        icon: '🏥',
        tip: 'Nearest full hospital: Kaza CHC. Carry personal medications.'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerSOS() {
    HapticFeedback.heavyImpact();
    setState(() => _sosSent = true);
    Future.delayed(const Duration(seconds: 3),
        () => setState(() => _sosSent = false));
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SOS & Emergency',
          style: TextStyle(
              color: primaryText, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '🆘 EMERGENCY',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Big SOS Button ──
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _triggerSOS,
                    child: AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context, child) => Transform.scale(
                        scale: _sosSent ? 0.9 : _pulseAnim.value,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: _sosSent
                                  ? [
                                      const Color(0xFF10B981),
                                      const Color(0xFF059669)
                                    ]
                                  : [
                                      const Color(0xFFFF3B30),
                                      const Color(0xFFCC2200)
                                    ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_sosSent
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFFF3B30))
                                    .withValues(alpha: 0.5),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _sosSent
                                    ? Icons.check_circle
                                    : Icons.sos_rounded,
                                color: Colors.white,
                                size: 52,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _sosSent ? 'SENT!' : 'SOS',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _sosSent
                        ? '✅ Alert sent to emergency contacts!'
                        : 'Tap to send SOS alert',
                    style: TextStyle(
                      color: _sosSent ? const Color(0xFF10B981) : subText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Your location ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location,
                      color: Color(0xFF6366F1), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SHARE YOUR LOCATION',
                          style: TextStyle(
                            color: Color(0xFF818CF8),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Spiti Valley, Himachal Pradesh, India',
                          style: TextStyle(
                              color: primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF6366F1)),
                      foregroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Share',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Lost & Found board ──
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LostFoundScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.travel_explore,
                          color: Color(0xFF8B5CF6), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lost & Found 🎒',
                            style: TextStyle(
                                color: primaryText,
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bag, camera ya purse khoya / mila? Photo ke saath post karo — sab users ko notification jayegi.',
                            style: TextStyle(
                                color: subText, fontSize: 11, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        color: Color(0xFF8B5CF6), size: 15),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Emergency Contacts ──
            Text(
              'Emergency Contacts',
              style: TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.w800,
                  fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap a card to call directly',
              style: TextStyle(color: subText, fontSize: 12),
            ),
            const SizedBox(height: 14),

            ...List.generate(
              (_contacts.length / 2).ceil(),
              (rowIndex) {
                final a = rowIndex * 2;
                final b = a + 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                          child: _contactCard(
                              _contacts[a], cardBg, primaryText, border)),
                      const SizedBox(width: 12),
                      if (b < _contacts.length)
                        Expanded(
                            child: _contactCard(
                                _contacts[b], cardBg, primaryText, border))
                      else
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Safety Tips ──
            Text(
              '⚠️ Spiti Safety Tips',
              style: TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.w800,
                  fontSize: 18),
            ),
            const SizedBox(height: 14),

            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                children: List.generate(
                  _tips.length,
                  (i) => Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_tips[i].icon,
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _tips[i].tip,
                                style: TextStyle(
                                  color: subText,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < _tips.length - 1)
                        Divider(height: 1, color: border),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(_EmergencyContact contact, Color cardBg,
      Color primaryText, Color border) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Calling ${contact.name}...'),
            backgroundColor: contact.color,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: contact.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(contact.icon, color: contact.color, size: 18),
            ),
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: contact.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                contact.category,
                style: TextStyle(
                    color: contact.color,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              contact.name,
              style: TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone, size: 11, color: contact.color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    contact.number,
                    style: TextStyle(
                        color: contact.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyContact {
  final String name;
  final String number;
  final IconData icon;
  final Color color;
  final String category;

  const _EmergencyContact({
    required this.name,
    required this.number,
    required this.icon,
    required this.color,
    required this.category,
  });
}

class _SpitiTip {
  final String icon;
  final String tip;
  const _SpitiTip({required this.icon, required this.tip});
}
