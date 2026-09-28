import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:food_user_application/config/constants/app_constants.dart';
import 'package:food_user_application/core/providers/core_providers.dart';

/// Thin wrapper around the Socket.IO connection used for live restaurant
/// events (`new_order`, `order_status_update`, ...). The server auto-joins
/// the `restaurant:<id>` room on connect based on the JWT role/id — see
/// `Backend/src/config/socket.js`.
class SocketService {
  SocketService(this._ref);

  final Ref _ref;
  io.Socket? _socket;

  Future<void> connect() async {
    if (_socket != null) return;
    final token = await _ref.read(tokenStorageProvider).accessToken;
    if (token == null || token.isEmpty) return;

    _socket = io.io(
      AppConstants.socketUrl,
      io.OptionBuilder()
          // Polling first, then upgrade. websocket-only fails silently behind a
          // proxy that won't upgrade, and new orders would then arrive by FCM
          // only — a restaurant missing orders with no visible error.
          .setTransports(['polling', 'websocket'])
          .setPath('/socket.io/')
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket?.connect();

    // No manual reconnect in onDisconnect: enableReconnection() already handles
    // it with backoff, and doing both raced into a reconnect storm.
  }

  void on(String event, void Function(dynamic data) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService(ref);
  ref.onDispose(service.disconnect);
  return service;
});

/// Sink for orders cancelled elsewhere — by support from the admin panel, or
/// by the customer.
///
/// Fed by `LiveOrdersController`, which already owns the `order_status_update`
/// handler. A second listener cannot simply be registered alongside it because
/// [SocketService.off] clears every handler for an event, so the first dispose
/// would silently take the other one down with it.
final orderCancelledBusProvider =
    Provider<StreamController<Map<String, dynamic>>>((ref) {
  final controller = StreamController<Map<String, dynamic>>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});

final orderCancelledProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return ref.watch(orderCancelledBusProvider).stream;
});
