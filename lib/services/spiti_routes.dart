/// Spiti "route corridor" matcher.
///
/// Spiti's road network is essentially ONE long highway:
///   Manali ── Kunzum ── Losar ── KAZA ── Tabo ── Nako ── Reckong Peo ── Shimla
/// with short spurs (Kibber/Chicham, the Langza–Hikkim–Komic loop, Pin Valley,
/// Dhankar). We give every known place an approximate position (km) along this
/// single axis. A ride from A→B then "covers" every place whose position lies
/// between A and B (± a tolerance for nearby villages).
///
/// This lets a seeker find rides that pass NEAR and IN-BETWEEN their points —
/// e.g. a Chicham→Rampur ride is offered to a Kibber→Tabo seeker (Kibber is
/// ~2 km from Chicham, and Tabo lies on the way), as long as a seat is free.
class SpitiRoutes {
  /// Slack (km) so nearby villages / spurs still count as "on the way".
  static const double tolerance = 20.0;

  /// place (lowercase) → approx km from Manali along the Spiti highway axis.
  static const Map<String, double> _milestone = {
    // ── Manali → Kunzum (west arm) ──
    'manali': 0,
    'solang': 12,
    'atal tunnel': 25,
    'sissu': 40,
    'gramphu': 60,
    'grampu': 60,
    'chhatru': 75,
    'chatru': 75,
    'chhota dhara': 90,
    'batal': 110,
    'chandratal': 118,
    'chandra taal': 118,
    'kunzum': 122,
    'kunzum pass': 122,
    'kunzum la': 122,
    // ── Losar → Kaza ──
    'losar': 140,
    'lossar': 140,
    'kiato': 158,
    'hansa': 165,
    'rangrik': 190,
    'rangrich': 190,
    // ── North spur: Kibber / Chicham / highland loop (all exit via Kaza) ──
    'kibber': 196,
    'kibbar': 196,
    'chicham': 197,
    'gette': 198,
    'tashigang': 198,
    'langza': 202,
    'langja': 202,
    'hikkim': 202,
    'komic': 203,
    'komik': 203,
    'kaumik': 203,
    'demul': 204,
    'dem-ul': 204,
    // ── Hub ──
    'kaza': 200,
    'kaja': 200,
    'kaze': 200,
    // ── Kaza → Tabo (south/east arm) ──
    'shichling': 212,
    'lingti': 214,
    'lhalung': 218,
    'lalung': 218,
    'attargo': 216,
    'dhankar': 222,
    'dhankhar': 222,
    'sichling': 212,
    // Pin Valley spur (branches near Attargo)
    'pin valley': 228,
    'pin': 228,
    'mud': 232,
    'mudh': 232,
    'sagnam': 230,
    'gulling': 226,
    'mikkim': 233,
    'kungri': 229,
    // Tabo onward
    'tabo': 250,
    'poh': 268,
    'sumdo': 280,
    'hurling': 286,
    'nako': 305,
    'chango': 320,
    'shalkhar': 330,
    'yangthang': 340,
    'pooh': 360,
    'poo': 360,
    'khab': 372,
    'spillow': 378,
    'spello': 378,
    'akpa': 388,
    'jangi': 396,
    'spillo': 378,
    'karcham': 405,
    'sangla': 425,
    'chitkul': 445,
    'powari': 415,
    'reckong peo': 420,
    'reckongpeo': 420,
    'recong peo': 420,
    'peo': 420,
    'kalpa': 423,
    'wangtu': 432,
    'tapri': 440,
    'jeori': 455,
    'sarahan': 470,
    'rampur': 480,
    'rampur bushahr': 480,
    'jhakri': 492,
    'narkanda': 520,
    'kumarsain': 535,
    'theog': 555,
    'shimla': 580,
    'kufri': 568,
    // Beyond
    'chandigarh': 690,
    'delhi': 900,
  };

  /// Alternate spellings kept in [_milestone] only for fuzzy matching — these
  /// should never be shown as autocomplete suggestions.
  static const Set<String> _altSpellings = {
    'grampu', 'chatru', 'chandra taal', 'kunzum', 'kunzum la', 'lossar',
    'rangrich', 'kibbar', 'langja', 'komik', 'kaumik', 'dem-ul', 'kaja',
    'kaze', 'sichling', 'lalung', 'dhankhar', 'pin', 'mudh', 'poo', 'spello',
    'spillo', 'reckongpeo', 'recong peo', 'peo', 'rampur bushahr',
  };

  /// Canonical, Title-Cased place names for From/To autocomplete fields.
  /// Using these spellings guarantees the corridor matcher recognises them.
  static final List<String> knownPlaces = _milestone.keys
      .where((k) => !_altSpellings.contains(k))
      .map((k) => k
          .split(' ')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' '))
      .toList();

  /// Approx position (km) of a typed place, or null if unknown.
  /// Fuzzy: matches if the query contains a known key or vice-versa.
  static double? position(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    if (_milestone.containsKey(q)) return _milestone[q];
    // longest key that fuzzy-matches wins (avoids 'poo' matching inside 'pooh')
    double? best;
    int bestLen = 0;
    for (final e in _milestone.entries) {
      if ((q.contains(e.key) || e.key.contains(q)) && e.key.length > bestLen) {
        best = e.value;
        bestLen = e.key.length;
      }
    }
    return best;
  }

  /// True if a ride [rideFrom]→[rideTo] passes near AND in the same direction as
  /// a seeker's [passFrom]→[passTo]. Returns false if either side is unknown
  /// (caller falls back to plain text matching).
  static bool rideServesTrip(String rideFrom, String rideTo, String passFrom, String passTo) {
    final a = position(rideFrom);
    final b = position(rideTo);
    if (a == null || b == null) return false;

    final lo = (a < b ? a : b) - tolerance;
    final hi = (a > b ? a : b) + tolerance;

    final x = passFrom.trim().isEmpty ? null : position(passFrom);
    final y = passTo.trim().isEmpty ? null : position(passTo);
    if (x == null && y == null) return false;

    bool onCorridor(double? p) => p != null && p >= lo && p <= hi;

    if (x != null && y != null) {
      // Both ends known → must be same travel direction as the ride.
      final rideForward = b >= a;
      final passForward = y >= x;
      if (rideForward != passForward) return false;
      return onCorridor(x) && onCorridor(y);
    }
    // Only one end typed → just needs to lie on the corridor.
    return onCorridor(x) || onCorridor(y);
  }
}
