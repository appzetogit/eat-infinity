import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/services/socket_service.dart';
import '../data/models/delivery_order.dart';
import '../data/orders_repository.dart';
import 'orders_state.dart';
import 'pending_customer_rating_controller.dart';

class OrdersController extends Notifier<OrdersState> {
  late final OrdersRepository _repository;
  Timer? _pollTimer;
  StreamSubscription? _newOrderSub;
  StreamSubscription? _orderClaimedSub;
  StreamSubscription? _orderDeassignedSub;
  StreamSubscription? _orderStatusSub;
  StreamSubscription? _orderReadySub;
  StreamSubscription? _connectionSub;

  @override
  OrdersState build() {
    _repository = ref.read(ordersRepositoryProvider);

    final socket = ref.read(socketServiceProvider);
    _newOrderSub = socket.onNewOrderAvailable.listen((_) => refreshAvailable());
    _orderClaimedSub = socket.onOrderClaimed.listen((_) => refreshAvailable());
    _orderDeassignedSub = socket.onOrderDeassigned.listen((data) {
      _leaveTrackingIfCurrent(data);
      refreshAvailable();
    });
    _orderStatusSub = socket.onOrderStatusUpdate.listen(
      (_) => refreshCurrent(),
    );
    _orderReadySub = socket.onOrderReady.listen((_) => refreshCurrent());
    // Resume live-location sharing for the active order after a reconnect.
    _connectionSub = socket.onConnectionChange.listen((connected) {
      if (!connected) return;
      final current = state;
      if (current is OrdersLoaded && current.currentOrder != null) {
        socket.joinTracking(current.currentOrder!.id);
      }
    });

    ref.onDispose(() {
      _pollTimer?.cancel();
      _newOrderSub?.cancel();
      _orderClaimedSub?.cancel();
      _orderDeassignedSub?.cancel();
      _orderStatusSub?.cancel();
      _orderReadySub?.cancel();
      _connectionSub?.cancel();
    });

    return const OrdersInitial();
  }

  /// `GET /orders/current` and `GET /orders/available` don't project
  /// `deliveryVerification`, so a routine refresh always reports OTP as
  /// not-required. Never let that silently clear an OTP requirement we
  /// already learned about from reachedDrop/verifyDropOtp responses —
  /// otherwise a background refresh mid-delivery would let the driver
  /// complete the order without ever verifying it.
  DeliveryOrder _preserveOtpState(DeliveryOrder? previousCurrent, DeliveryOrder fresh) {
    if (previousCurrent == null || previousCurrent.id != fresh.id) return fresh;
    if (previousCurrent.dropOtpRequired && !fresh.dropOtpRequired) {
      return fresh.copyWith(
        dropOtpRequired: true,
        dropOtpVerified: previousCurrent.dropOtpVerified,
      );
    }
    return fresh;
  }

  /// On a fresh app start (or provider rebuild) there's no `previousCurrent`
  /// to fall back on, so `_preserveOtpState` can't protect against
  /// `/orders/current`'s stripped `deliveryVerification`. If the order is
  /// already at the drop step in that situation, hydrate the real OTP state
  /// from `GET /orders/:orderId`, which returns the full document.
  Future<DeliveryOrder> _hydrateOtpState(
    DeliveryOrder? previousCurrent,
    DeliveryOrder fresh,
  ) async {
    if (previousCurrent != null && previousCurrent.id == fresh.id) {
      return _preserveOtpState(previousCurrent, fresh);
    }
    if (fresh.currentPhase == 'at_drop') {
      final detailsResult = await _repository.getOrderDetails(fresh.id);
      return detailsResult.when(
        success: (full) => full,
        failure: (_) => fresh,
      );
    }
    return fresh;
  }

  void _leaveTrackingIfCurrent(Map<String, dynamic> data) {
    final current = state;
    if (current is! OrdersLoaded || current.currentOrder == null) return;
    final orderId = (data['orderId'] ?? data['_id'] ?? data['id'])?.toString();
    if (orderId == null || orderId == current.currentOrder!.id) {
      ref.read(socketServiceProvider).leaveTracking(current.currentOrder!.id);
    }
  }

  void startPolling() {
    _pollTimer?.cancel();
    refreshAll();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => refreshAll(),
    );
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refreshAll() async {
    if (state is OrdersInitial) state = const OrdersLoading();
    final currentResult = await _repository.getCurrentOrder();
    final DeliveryOrder? current = currentResult.when(
      success: (order) => order,
      failure: (_) => null,
    );

    if (current != null) {
      final prev = state;
      final hydrated = await _hydrateOtpState(
        prev is OrdersLoaded ? prev.currentOrder : null,
        current,
      );
      state = OrdersLoaded(
        availableOrders: prev is OrdersLoaded ? prev.availableOrders : const [],
        currentOrder: hydrated,
      );
      return;
    }

    final availableResult = await _repository.getAvailableOrders();
    availableResult.when(
      success: (orders) {
        state = OrdersLoaded(availableOrders: orders, currentOrder: null);
      },
      failure: (error) {
        if (state is! OrdersLoaded) state = OrdersError(error.message);
      },
    );
  }

  Future<void> refreshAvailable() async {
    final prev = state;
    if (prev is OrdersLoaded && prev.hasActiveOrder) return;
    final result = await _repository.getAvailableOrders();
    result.when(
      success: (orders) {
        state = OrdersLoaded(availableOrders: orders, currentOrder: null);
      },
      failure: (_) {},
    );
  }

  Future<void> refreshCurrent() async {
    final result = await _repository.getCurrentOrder();
    await result.when(
      success: (order) async {
        final prev = state;
        final previousCurrent = prev is OrdersLoaded ? prev.currentOrder : null;
        final hydrated = order != null
            ? await _hydrateOtpState(previousCurrent, order)
            : null;
        state = OrdersLoaded(
          availableOrders: prev is OrdersLoaded ? prev.availableOrders : const [],
          currentOrder: hydrated,
        );
      },
      failure: (_) async {},
    );
  }

  Future<Result<DeliveryOrder, AppError>> acceptOrder(String orderId) async {
    final result = await _repository.accept(orderId);
    result.when(
      success: (order) {
        state = OrdersLoaded(availableOrders: const [], currentOrder: order);
        // Start live location sharing for this order (requirement: after accept).
        ref.read(socketServiceProvider).joinTracking(order.id);
      },
      failure: (_) {},
    );
    return result;
  }

  Future<Result<DeliveryOrder, AppError>> rejectOrder(String orderId) async {
    final result = await _repository.reject(orderId);
    result.when(success: (_) => refreshAvailable(), failure: (_) {});
    return result;
  }

  Future<Result<DeliveryOrder, AppError>> reachedPickup(String orderId) =>
      _mutateCurrent(() => _repository.reachedPickup(orderId));

  Future<Result<DeliveryOrder, AppError>> confirmPickup(
    String orderId, {
    String? billImageUrl,
  }) => _mutateCurrent(
    () => _repository.confirmPickup(orderId, billImageUrl: billImageUrl),
  );

  Future<Result<DeliveryOrder, AppError>> reachedDrop(String orderId) =>
      _mutateCurrent(() => _repository.reachedDrop(orderId));

  Future<Result<DeliveryOrder, AppError>> verifyDropOtp(
    String orderId,
    String otp,
  ) => _mutateCurrent(() => _repository.verifyDropOtp(orderId, otp));

  Future<Result<DeliveryOrder, AppError>> completeOrder(String orderId) async {
    final previousOrder =
        state is OrdersLoaded ? (state as OrdersLoaded).currentOrder : null;
    final result = await _repository.complete(orderId);
    result.when(
      success: (_) {
        // Stop live location sharing for this order (requirement: after delivered).
        ref.read(socketServiceProvider).leaveTracking(orderId);
        state = const OrdersLoaded(availableOrders: [], currentOrder: null);
        refreshAvailable();
        if (previousOrder != null && previousOrder.id == orderId) {
          ref
              .read(pendingCustomerRatingControllerProvider.notifier)
              .show(previousOrder);
        }
      },
      failure: (_) {},
    );
    return result;
  }

  Future<Result<DeliveryOrder, AppError>> _mutateCurrent(
    Future<Result<DeliveryOrder, AppError>> Function() action,
  ) async {
    final result = await action();
    result.when(
      success: (order) {
        final prev = state;
        state = OrdersLoaded(
          availableOrders: prev is OrdersLoaded ? prev.availableOrders : const [],
          currentOrder: order,
        );
      },
      failure: (_) {},
    );
    return result;
  }
}

final ordersControllerProvider =
    NotifierProvider<OrdersController, OrdersState>(OrdersController.new);
