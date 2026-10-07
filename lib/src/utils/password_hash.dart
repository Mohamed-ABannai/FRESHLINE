import 'dart:convert';

import 'package:crypto/crypto.dart';

final RegExp _sha256HexPattern = RegExp(r'^[0-9a-f]{64}$');

String hashProfilePassword(String password) {
  return sha256.convert(utf8.encode(password)).toString();
}

bool looksLikePasswordHash(String value) {
  return _sha256HexPattern.hasMatch(value.trim().toLowerCase());
}

bool verifyProfilePassword({
  required String storedPasswordHash,
  required String password,
}) {
  final String normalizedStored = storedPasswordHash.trim();
  if (normalizedStored.isEmpty) {
    return false;
  }
  if (looksLikePasswordHash(normalizedStored)) {
    return normalizedStored.toLowerCase() == hashProfilePassword(password);
  }
  return normalizedStored == password;
}
