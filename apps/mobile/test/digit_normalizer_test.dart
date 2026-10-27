import 'package:flutter_test/flutter_test.dart';
import 'package:smi_phone/util/digit_normalizer.dart';

void main() {
  group('DigitNormalizer (T03)', () {
    test('accepts plain ASCII', () {
      expect(DigitNormalizer.normalizeInternal('102'), '102');
      expect(DigitNormalizer.normalizeInternal(' 199 '), '199');
    });

    test('converts Persian and Arabic-Indic digits', () {
      expect(DigitNormalizer.normalizeInternal('۱۰۲'), '102');
      expect(DigitNormalizer.normalizeInternal('١٠٢'), '102');
    });

    test('rejects invalid targets', () {
      for (final bad in ['10', '1021', '100', 'abc', '10a', '+102', '', '  ']) {
        expect(DigitNormalizer.normalizeInternal(bad), isNull, reason: bad);
      }
      expect(DigitNormalizer.normalizeInternal(null), isNull);
    });

    test('rejects hidden direction marks (never partially interpreted)', () {
      expect(DigitNormalizer.normalizeInternal('\u200E102'), isNull);
    });
  });
}
