/// Phone-number matching helpers.
///
/// Users type the same number differently ("+91 98160 12345", "9816012345",
/// "98160-12345"), and "My Rides" / "My Homestays" / duplicate checks matched
/// with exact string equality — so a formatting difference silently hid a
/// person's own listings. Compare on the last 10 digits instead.
library;

/// Normalise a phone to its last 10 digits.
String normPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
}

/// True when both numbers refer to the same 10-digit mobile.
/// Empty/short numbers never match anything.
bool samePhone(String a, String b) {
  final na = normPhone(a);
  return na.length == 10 && na == normPhone(b);
}
