import 'package:flutter_test/flutter_test.dart';

import 'package:freshline_tt/src/utils/bahrain_phone.dart';

void main() {
  test('normalizes local Bahrain numbers to +973 format', () {
    expect(normalizeBahrainPhone('30000000'), '+973 3000 0000');
  });

  test('normalizes already prefixed Bahrain numbers', () {
    expect(normalizeBahrainPhone('+97330000000'), '+973 3000 0000');
    expect(normalizeBahrainPhone('+973 3000 0000'), '+973 3000 0000');
  });

  test('rejects Bahrain numbers with wrong digit counts', () {
    expect(normalizeBahrainPhone('+973 3000 000'), isNull);
    expect(normalizeBahrainPhone('+973 3000 00000'), isNull);
    expect(
      validateRequiredBahrainPhone('+973 3000 000'),
      'Use a Bahraini phone number with +973 and exactly 8 digits.',
    );
  });
}
