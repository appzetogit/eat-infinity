import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/services/fcm_service.dart';
import '../data/notifications_repository.dart';

/// Unread badge count, shared by every place that draws one.
///
/// There were three badges on screen at once and none of them were real: the
/// bottom bar hardcoded `3`, the profile header hardcoded `3`, and the
/// earnings header was wired to the *order* count so it read "0". They now all
/// read this one value, which comes from `unreadCount` on
/// `GET /food/notifications/inbox`.
///
/// This is presentation state over the existing repository — no new endpoint
/// and no change to the request.
class UnreadNotificationsNotifier extends Notifier<int> {
  StreamSubscription<Map<String, dynamic>>? _fcmSub;

  @override
  int build() {
    // A push is the one event that can change this count while the app is
    // open, so recount when one lands.
    _fcmSub = ref
        .read(fcmServiceProvider)
        .onNotificationReceived
        .listen((_) => unawaited(refresh()));
    ref.onDispose(() => _fcmSub?.cancel());

    unawaited(refresh());
    return 0;
  }

  Future<void> refresh() async {
    final result =
        await ref.read(notificationsRepositoryProvider).getInbox(limit: 1);
    result.when(
      // A failed count must not invent one — leave the badge as it was.
      success: (data) => state = (data['unreadCount'] as num?)?.toInt() ?? 0,
      failure: (_) {},
    );
  }

  /// Called by the inbox screen when it marks rows read locally, so the badge
  /// drops immediately rather than after the next round trip.
  void setCount(int value) => state = value < 0 ? 0 : value;
}

final unreadNotificationsProvider =
    NotifierProvider<UnreadNotificationsNotifier, int>(
  UnreadNotificationsNotifier.new,
);
