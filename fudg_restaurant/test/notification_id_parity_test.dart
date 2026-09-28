import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/core/services/local_notification_service.dart';

void main() {
  // NewOrderOverlay.kt cancels the new-order notification with
  // `orderId.hashCode() and 0x7FFFFFFF`. It runs in a process that cannot see
  // the Dart isolate that posted it, so the only thing keeping the two in
  // agreement is that both compute Java's String.hashCode. If this drifts, the
  // overlay goes up and the notification stays underneath it.
  test('notificationIdFor matches Java String.hashCode', () {
    expect(LocalNotificationService.notificationIdFor('a'), 97);
    expect(LocalNotificationService.notificationIdFor('POPUPTEST'), 23891742);
    expect(
      LocalNotificationService.notificationIdFor('6a757c6dc5fe264ffe23f3b8'),
      825276685,
    );
  });

  test('ids are stable and non-negative', () {
    // Android rejects a negative notification id.
    for (final id in ['', 'order-1', 'ZZZZZZZZZZZZZZZZZZZZZZZZ']) {
      final value = LocalNotificationService.notificationIdFor(id);
      expect(value, greaterThanOrEqualTo(0));
      expect(value, LocalNotificationService.notificationIdFor(id));
    }
  });
}
