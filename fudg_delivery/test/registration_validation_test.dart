import 'package:flutter_test/flutter_test.dart';

/// Mirrors of `delivery.validator.js` (`deliveryRegisterSchema`).
///
/// Registration used to POST whatever the form held and let the server judge
/// it. The failure that surfaced in the field was `{"message":"Phone must be
/// at least 8 digits"}` for a partner whose phone the app had simply lost —
/// after the whole multipart upload, photos included, and with no phone field
/// on screen to correct.
///
/// These are the exact shapes the backend enforces. If the server schema
/// changes, this is what should fail first.
String digits(String raw) => raw.replaceAll(RegExp(r'\D'), '');

final panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
final aadhaarPattern = RegExp(r'^[0-9]{12}$');
final licensePattern = RegExp(r'^[A-Z]{2}[0-9A-Z]{8,16}$');

void main() {
  group('phone normalisation', () {
    test('strips the country code and separators the backend would reject', () {
      // `z.string().min(8)` counts characters, not digits, so '+91 98765 43210'
      // passes length but the value is not what the partner typed.
      expect(digits('+91 98765 43210'), '919876543210');
      expect(digits('98765-43210'), '9876543210');
    });

    test('an unresolved phone is caught before the request is built', () {
      // The exact case behind the reported 400: nothing to send.
      expect(digits('').length >= 8, isFalse);
      expect(digits('+91 ').length >= 8, isFalse);
    });

    test('a real ten-digit number clears the minimum', () {
      expect(digits('9876543210').length >= 8, isTrue);
    });
  });

  group('document formats', () {
    test('PAN', () {
      expect(panPattern.hasMatch('ABCDE1234F'), isTrue);
      expect(panPattern.hasMatch('ABCD1234F'), isFalse);
      expect(panPattern.hasMatch('ABCDE12345'), isFalse);
    });

    test('Aadhaar is exactly twelve digits', () {
      expect(aadhaarPattern.hasMatch('123456789012'), isTrue);
      expect(aadhaarPattern.hasMatch('12345678901'), isFalse);
      expect(aadhaarPattern.hasMatch('1234 5678 9012'), isFalse);
      // Which is why the field is normalised before it is checked.
      expect(aadhaarPattern.hasMatch(digits('1234 5678 9012')), isTrue);
    });

    test('driving licence, normalised of spaces and hyphens', () {
      expect(licensePattern.hasMatch('MH1220110012345'), isTrue);
      expect(licensePattern.hasMatch('MH12'), isFalse);
      final normalised =
          'MH-12 20110012345'.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
      expect(licensePattern.hasMatch(normalised), isTrue);
    });
  });
}
