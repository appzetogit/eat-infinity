import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/services/location_service.dart';
import 'package:food_user_application/core/services/order_alert.dart';
import 'package:food_user_application/features/orders/application/incoming_order_controller.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';
import 'package:food_user_application/features/orders/data/orders_repository.dart';
import 'package:food_user_application/features/orders/presentation/widgets/incoming_order_card.dart';

/// How long an offer stays on screen when the backend didn't say.
///
/// The backend drives this through `acceptanceDeadlineAt`; this is only the
/// fallback for a payload that carries neither that nor a window length.
const kIncomingOrderWindowSeconds = 20;

/// Seconds remaining in the offer, from whatever the payload actually carries.
///
/// The absolute deadline is preferred — it cannot drift with delivery latency —
/// but a push held in Doze arrives already past it, so the window length wins
/// in that case rather than opening the card at zero.
int incomingOrderSecondsLeft(DeliveryOrder order) {
  final deadline = order.acceptanceDeadlineAt;
  if (deadline != null) {
    final left = deadline.difference(DateTime.now()).inSeconds;
    if (left > 0) return left;
  }
  return kIncomingOrderWindowSeconds;
}

/// Full-screen incoming-order alert, stacked over the whole app by [main.dart]
/// whenever [incomingOrderControllerProvider] is non-null — so it works
/// regardless of the current GoRouter location, and is the single UI path for
/// orders arriving via Socket.IO (app open) or FCM (backgrounded/locked).
class IncomingOrderScreen extends ConsumerStatefulWidget {
  const IncomingOrderScreen({super.key, required this.order});

  final DeliveryOrder order;

  @override
  ConsumerState<IncomingOrderScreen> createState() =>
      _IncomingOrderScreenState();
}

class _IncomingOrderScreenState extends ConsumerState<IncomingOrderScreen> {
  late final int _totalSeconds;
  late int _secondsLeft;
  Timer? _timer;

  /// Set the moment accept/reject/expiry is triggered. Guards every one of
  /// them: a second tap, or a tap racing the countdown to zero, is dropped.
  bool _resolving = false;
  bool _expired = false;

  double? _etaMins;
  StreamSubscription<Position>? _positionSub;
  bool _routeFetchInFlight = false;

  @override
  void initState() {
    super.initState();
    OrderAlert.start(source: 'IncomingOrderScreen');

    _totalSeconds = incomingOrderSecondsLeft(widget.order);
    _secondsLeft = _totalSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      // Counts down to a displayed 0 before expiring, rather than stopping at
      // 1 — the last second is the one the rider is staring at.
      final next = _secondsLeft - 1;
      setState(() => _secondsLeft = next < 0 ? 0 : next);
      if (next <= 0) {
        timer.cancel();
        _expire();
      }
    });

    _fetchRoute();
    // GPS often isn't warm the instant this appears (fresh launch from a
    // killed-state push), and the fetch above silently no-ops without a fix —
    // so retry as soon as a live position arrives.
    _positionSub = ref
        .read(locationServiceProvider)
        .positionStream
        .listen(_onPositionUpdate);
  }

  void _onPositionUpdate(Position pos) {
    if (_etaMins == null && !_routeFetchInFlight) _fetchRoute();
  }

  /// Live routed ETA for the "Est. Delivery" cell — measured from where the
  /// rider actually is, rather than the order's stored estimate.
  Future<void> _fetchRoute() async {
    final pos = ref.read(locationServiceProvider).lastPosition;
    if (pos == null) return;
    _routeFetchInFlight = true;
    final result = await ref.read(ordersRepositoryProvider).getRoute(
          widget.order.id,
          lat: pos.latitude,
          lng: pos.longitude,
          target: 'restaurant',
        );
    _routeFetchInFlight = false;
    if (!mounted) return;
    result.when(
      success: (data) =>
          setState(() => _etaMins = (data['durationMins'] as num?)?.toDouble()),
      failure: (_) {},
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSub?.cancel();
    // Backstop. Accept/reject/expiry already silenced the alarm; this covers
    // the alert being torn down some other way — the order being cancelled or
    // claimed by another partner clears the controller state and removes this
    // widget without any of those paths running.
    OrderAlert.stop(source: 'IncomingOrderScreen.dispose');
    super.dispose();
  }

  // The alarm is silenced on the tap, not left to dispose(): dispose only runs
  // once the request comes back and this screen is torn down, so on a slow
  // network it would keep ringing for seconds after the rider decided.
  Future<void> _accept() async {
    if (_resolving || _expired) return;
    setState(() => _resolving = true);
    _timer?.cancel();
    await OrderAlert.stop(source: 'IncomingOrderScreen.accept');

    final result =
        await ref.read(incomingOrderControllerProvider.notifier).accept();
    // Losing the race to another partner is the common case here. Say so —
    // otherwise the alert just disappears and no trip starts.
    result?.when(
      success: (_) {},
      failure: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      },
    );
  }

  Future<void> _decline() async {
    if (_resolving || _expired) return;
    setState(() => _resolving = true);
    _timer?.cancel();
    await OrderAlert.stop(source: 'IncomingOrderScreen.decline');
    await ref.read(incomingOrderControllerProvider.notifier).decline();
  }

  /// The window ran out. The card flips to the expired state and stays up for
  /// a beat before clearing, so the alert doesn't simply vanish mid-glance —
  /// and accept is refused from the instant this runs, not when it finishes.
  Future<void> _expire() async {
    if (_resolving) return;
    _resolving = true;
    if (mounted) setState(() => _expired = true);
    await OrderAlert.stop(source: 'IncomingOrderScreen.expire');
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    await ref.read(incomingOrderControllerProvider.notifier).expire();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.62),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: _expired
                  ? const IncomingOrderExpiredCard()
                  : IncomingOrderCard(
                      order: widget.order,
                      secondsLeft: _secondsLeft,
                      totalSeconds: _totalSeconds,
                      etaMins: _etaMins,
                      busy: _resolving,
                      onAccept: _resolving ? null : _accept,
                      onReject: _resolving ? null : _decline,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
