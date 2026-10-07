import 'package:flutter_test/flutter_test.dart';

import 'package:freshline_tt/src/utils/password_hash.dart';

void main() {
  test('hashProfilePassword returns a sha256 hex string', () {
    final String hash = hashProfilePassword('freshline123');

    expect(hash, hasLength(64));
    expect(looksLikePasswordHash(hash), isTrue);
  });

  test('verifyProfilePassword accepts hashed and legacy plain-text values', () {
    expect(
      verifyProfilePassword(
        storedPasswordHash: hashProfilePassword('freshline123'),
        password: 'freshline123',
      ),
      isTrue,
    );
    expect(
      verifyProfilePassword(
        storedPasswordHash: 'freshline123',
        password: 'freshline123',
      ),
      isTrue,
    );
    expect(
      verifyProfilePassword(
        storedPasswordHash: hashProfilePassword('freshline123'),
        password: 'wrong-password',
      ),
      isFalse,
    );
  });
}
