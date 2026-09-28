import 'package:flutter_test/flutter_test.dart';

/// Mirrors `_isCodeGone` / `_friendlyOtpError` in otp_verify_screen.dart.
///
/// `verifyOtp` in otp.service.js calls `record.deleteOne()` the moment a code
/// checks out, so the very code that just worked returns "OTP not found" on a
/// second attempt. That happens in practice: verify succeeds, registration
/// fails, the partner navigates back and retypes the same digits.
///
/// Retyping can never succeed — only a new code can. So the screen has to
/// (a) say that in words the partner can act on, and (b) release the 30-second
/// resend cooldown instead of making them wait it out.
bool isCodeGone(String message) {
  final m = message.toLowerCase();
  return m.contains('not found') ||
      m.contains('expired') ||
      m.contains('max attempts');
}

String friendlyOtpError(String message) {
  final m = message.toLowerCase();
  if (m.contains('not found')) {
    return 'That code has already been used or was never sent. '
        'Tap Resend OTP to get a new one.';
  }
  if (m.contains('expired')) {
    return 'This code has expired. Tap Resend OTP to get a new one.';
  }
  if (m.contains('max attempts')) {
    return 'Too many incorrect attempts. Tap Resend OTP to get a new code.';
  }
  if (m.contains('invalid')) {
    return 'That code is not correct. Please check and try again.';
  }
  return message;
}

void main() {
  group('a dead code releases the resend cooldown', () {
    // The exact strings otp.service.js returns.
    test('OTP not found — the consumed-code case seen in the field', () {
      expect(isCodeGone('OTP not found'), isTrue);
    });

    test('OTP expired', () => expect(isCodeGone('OTP expired'), isTrue));

    test('Max attempts exceeded',
        () => expect(isCodeGone('Max attempts exceeded'), isTrue));

    test('a merely mistyped code keeps the cooldown', () {
      // Still a live OTP — resending on every wrong digit would let anyone
      // spam the SMS gateway.
      expect(isCodeGone('Invalid OTP'), isFalse);
    });
  });

  group('server wording is rewritten for the person holding the phone', () {
    test('"OTP not found" does not reach the partner verbatim', () {
      final shown = friendlyOtpError('OTP not found');
      expect(shown, isNot('OTP not found'));
      expect(shown, contains('Resend OTP'));
    });

    test('every dead-code reason points at Resend', () {
      for (final reason in const [
        'OTP not found',
        'OTP expired',
        'Max attempts exceeded',
      ]) {
        expect(friendlyOtpError(reason), contains('Resend'), reason: reason);
      }
    });

    test('an unrecognised message is passed through unchanged', () {
      // Never swallow something the mapping has not been taught about.
      expect(friendlyOtpError('Service unavailable'), 'Service unavailable');
    });
  });

  group('phone normalisation keeps both OTP legs on one key', () {
    // FoodOtp is looked up with a raw findOne({phone}); request-otp and
    // verify-otp must send byte-identical strings.
    String normalise(String raw) => raw.replaceAll(RegExp(r'\D'), '');

    test('punctuation the phone keypad allows is stripped', () {
      expect(normalise('98765 43210'), '9876543210');
      expect(normalise('+91-9876543210'), '919876543210');
    });

    test('an already-clean number is untouched', () {
      expect(normalise('9876543210'), '9876543210');
    });
  });
}
