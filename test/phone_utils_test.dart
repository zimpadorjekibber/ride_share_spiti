import 'package:flutter_test/flutter_test.dart';
import 'package:ride_share_spiti/services/phone_utils.dart';

void main() {
  group('phone_utils', () {
    test('normPhone strips formatting and country code', () {
      expect(normPhone('+91 98160 12345'), '9816012345');
      expect(normPhone('98160-12345'), '9816012345');
      expect(normPhone('9816012345'), '9816012345');
    });

    test('samePhone matches the same mobile across formats', () {
      expect(samePhone('+91 98160 12345', '9816012345'), isTrue);
      expect(samePhone('98160 12345', '+919816012345'), isTrue);
      expect(samePhone('9816012345', '9816099999'), isFalse);
    });

    test('empty or short numbers never match anything', () {
      expect(samePhone('', ''), isFalse);
      expect(samePhone('123', '123'), isFalse);
    });
  });
}
