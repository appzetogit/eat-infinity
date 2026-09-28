import 'dart:async';

import 'haptic_service.dart';
import 'sound_service.dart';

/// The incoming-order alarm: looping ringtone + haptic pattern, started and
/// stopped as one thing.
///
/// They are bundled deliberately. The two used to be raised separately, and
/// every exit path (accept, reject, expiry, cancellation, another partner
/// claiming it, the alert being dismissed) then had to remember to silence
/// both — one missed call and the rider is left with a phone that keeps
/// buzzing after the order is gone. One start, one stop, nothing to forget.
class OrderAlert {
  OrderAlert._();

  static Timer? _hapticTimer;

  /// The pattern pulses rather than vibrating continuously, and stops on its
  /// own after this many pulses even if nothing ever calls [stop] — a runaway
  /// vibration is worse than a missed order.
  static const _maxPulses = 12;
  static const _pulseGap = Duration(milliseconds: 1200);

  static Future<void> start({required String source}) async {
    // Re-entrant by design: a second offer replacing the first restarts the
    // alarm rather than stacking a second player/timer on top of it.
    _hapticTimer?.cancel();
    var pulses = 0;
    HapticService.heavy();
    _hapticTimer = Timer.periodic(_pulseGap, (timer) {
      if (++pulses >= _maxPulses) {
        timer.cancel();
        return;
      }
      HapticService.heavy();
    });

    await SoundService.playRingtone(source: source);
  }

  static Future<void> stop({required String source}) async {
    _hapticTimer?.cancel();
    _hapticTimer = null;
    await SoundService.stopRingtone(source: source);
  }
}
