import 'package:flutter/services.dart';

const String bahrainPhonePrefix = '+973';
const String bahrainPhoneExample = '+973 3000 0000';
const int bahrainPhoneDigitsLength = 8;

String? normalizeBahrainPhone(String? value, {bool allowEmpty = false}) {
  final String trimmed = (value ?? '').trim();
  if (trimmed.isEmpty) {
    return allowEmpty ? '' : null;
  }

  String digits = _digitsOnly(trimmed);
  if (digits.startsWith('00973')) {
    digits = digits.substring(5);
  } else if (digits.startsWith('973')) {
    digits = digits.substring(3);
  }

  if (!_bahrainDigitsPattern.hasMatch(digits)) {
    return null;
  }

  return formatBahrainPhone(digits);
}

String formatBahrainPhone(String localDigits) {
  final String digits = _digitsOnly(localDigits);
  if (digits.isEmpty) {
    return '';
  }
  if (digits.length <= 4) {
    return '$bahrainPhonePrefix $digits';
  }
  return '$bahrainPhonePrefix ${digits.substring(0, 4)} ${digits.substring(4)}';
}

String? validateRequiredBahrainPhone(String? value) {
  if ((value ?? '').trim().isEmpty) {
    return 'Enter the phone number.';
  }
  if (normalizeBahrainPhone(value) == null) {
    return 'Use a Bahraini phone number with +973 and exactly 8 digits.';
  }
  return null;
}

String? validateOptionalBahrainPhone(String? value) {
  if ((value ?? '').trim().isEmpty) {
    return null;
  }
  if (normalizeBahrainPhone(value) == null) {
    return 'Use a Bahraini phone number with +973 and exactly 8 digits.';
  }
  return null;
}

String normalizeBahrainPhoneOrThrow(
  String value, {
  String fieldLabel = 'Phone number',
}) {
  final String? normalized = normalizeBahrainPhone(value);
  if (normalized == null) {
    throw StateError('$fieldLabel must use +973 and exactly 8 digits.');
  }
  return normalized;
}

const List<TextInputFormatter> bahrainPhoneInputFormatters =
    <TextInputFormatter>[BahrainPhoneTextInputFormatter()];

class BahrainPhoneTextInputFormatter extends TextInputFormatter {
  const BahrainPhoneTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String localDigits = _extractLocalDigits(
      newValue.text,
      clampToMaxLength: true,
    );
    if (localDigits.isEmpty) {
      return const TextEditingValue();
    }

    final int safeSelection = newValue.selection.baseOffset.clamp(
      0,
      newValue.text.length,
    );
    final int digitsBeforeCursor = _extractLocalDigits(
      newValue.text.substring(0, safeSelection),
      clampToMaxLength: true,
    ).length;
    final String formatted = formatBahrainPhone(localDigits);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: _selectionOffsetForDigits(digitsBeforeCursor),
      ),
    );
  }

  int _selectionOffsetForDigits(int digitCount) {
    if (digitCount <= 0) {
      return 0;
    }
    final String sampleDigits = List<String>.filled(digitCount, '0').join();
    return formatBahrainPhone(sampleDigits).length;
  }
}

final RegExp _digitsPattern = RegExp(r'\D');
final RegExp _bahrainDigitsPattern = RegExp(r'^\d{8}$');

String _digitsOnly(String value) => value.replaceAll(_digitsPattern, '');

String _extractLocalDigits(String value, {required bool clampToMaxLength}) {
  String digits = _digitsOnly(value);
  if (digits.startsWith('00973')) {
    digits = digits.substring(5);
  } else if (digits.startsWith('973')) {
    digits = digits.substring(3);
  }

  if (clampToMaxLength && digits.length > bahrainPhoneDigitsLength) {
    return digits.substring(0, bahrainPhoneDigitsLength);
  }
  return digits;
}
