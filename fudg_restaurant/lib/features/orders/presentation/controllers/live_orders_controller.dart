import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/services/socket_service.dart';
import 'package:food_user_application/features/orders/data/order_repository.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';

/// Backs the main Orders tab: one list of current orders, bucketed
/// client-side into the 7 status tabs (see [OrderModel.restaurantBucket]),
/// kept fresh by the `new_order` / `order_status_update` socket events.
///
/// Socket.IO never replays events missed while disconnected (app
/// backgrounded, brief network drop, etc.), so a status change like a
/// cancellation during that window would otherwise sit stale until a manual
/// pull-to-refresh — also refresh on reconnect and on app resume to close
/// that gap.
class LiveOrdersController extends AsyncNotifier<List<OrderModel>> {
  bool _socketWired = false;
  AppLifecycleListener? _lifecycleListener;

  @override
  Future<List<OrderModel>> build() async {
    await _wireSocket();
    _lifecycleListener ??= AppLifecycleListener(onResume: refresh);
    ref.onDispose(() => _lifecycleListener?.dispose());
    return ref.read(orderRepositoryProvider).listCurrent();
  }

  Future<void> _wireSocket() async {
    if (_socketWired) return;
    _socketWired = true;
    final socket = ref.read(socketServiceProvider);
    await socket.connect();
    socket.on('new_order', (_) => refresh());
    socket.on('order_status_update', (data) {
      refresh();
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : const <String, dynamic>{};
      final status = (map['orderStatus'] ?? map['status'])?.toString() ?? '';
      // Always `cancelled_by_user` / `_by_restaurant` / `_by_admin`, never a
      // bare "cancelled".
      if (status.contains('cancel')) {
        ref.read(orderCancelledBusProvider).add(map);
      }
    });
    socket.on('order_cancelled', (_) => refresh());
    socket.on('cancel_order', (_) => refresh());
    socket.on('order_accepted', (_) => refresh());
    socket.on('order_rejected', (_) => refresh());
    socket.on('connect', (_) => refresh());
    ref.onDispose(() {
      socket.off('new_order');
      socket.off('order_status_update');
      socket.off('order_cancelled');
      socket.off('cancel_order');
      socket.off('order_accepted');
      socket.off('order_rejected');
      socket.off('connect');
    });
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(orderRepositoryProvider).listCurrent(),
    );
  }

  Future<void> updateStatus(
    String orderId,
    String orderStatus, {
    String? note,
  }) async {
    await ref
        .read(orderRepositoryProvider)
        .updateStatus(orderId, orderStatus, note: note);
    await refresh();
  }

  Future<void> resendNotification(String orderId) async {
    await ref.read(orderRepositoryProvider).resendNotification(orderId);
  }
}

final liveOrdersControllerProvider =
    AsyncNotifierProvider<LiveOrdersController, List<OrderModel>>(
      LiveOrdersController.new,
    );
