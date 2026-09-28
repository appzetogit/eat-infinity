import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/router/app_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:confetti/confetti.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/core/services/location_service.dart';
import 'package:food_user_application/core/utils/map_launcher.dart';
import 'package:food_user_application/core/constants/app_constants.dart';
import 'package:food_user_application/core/constants/map_styles.dart';
import 'package:food_user_application/core/utils/polyline_decoder.dart';
import '../widgets/otp_bottom_sheet.dart';
import 'package:food_user_application/features/orders/application/active_trip_visibility_controller.dart';
import 'package:food_user_application/features/orders/application/orders_controller.dart';
import 'package:food_user_application/features/orders/application/orders_state.dart';
import 'package:food_user_application/features/chat/presentation/screens/chat_screen.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';
import 'package:food_user_application/features/orders/data/orders_repository.dart';
import 'package:food_user_application/features/orders/presentation/widgets/collect_payment_sheet.dart';
import 'package:food_user_application/core/theme/app_colors.dart';
import 'package:food_user_application/features/orders/presentation/widgets/order_products_sheet.dart';
import 'package:food_user_application/features/orders/presentation/screens/order_delivered_screen.dart';

/// Full-screen "active trip" map view, stacked over the app by [main.dart]'s
/// overlay builder whenever there is an active order and the trip hasn't
/// been minimized. Mirrors [IncomingOrderScreen]'s overlay pattern so it
/// works regardless of the current GoRouter location, and automatically
/// reappears if the app is relaunched mid-delivery.
final GlobalKey<NavigatorState> _activeTripNavKey = GlobalKey<NavigatorState>();

class ActiveTripScreen extends ConsumerWidget {
  const ActiveTripScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Navigator(
      key: _activeTripNavKey,
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (context) => const _ActiveTripScaffold(),
      ),
    );
  }
}

class _ActiveTripScaffold extends ConsumerStatefulWidget {
  const _ActiveTripScaffold();

  @override
  ConsumerState<_ActiveTripScaffold> createState() => _ActiveTripScaffoldState();
}

class _ActiveTripScaffoldState extends ConsumerState<_ActiveTripScaffold> {
  GoogleMapController? _mapController;
  List<LatLng> _routePoints = [];
  LatLng? _routeDestination;
  double? _etaMins;
  String? _routeKey;
  Timer? _routeRefreshTimer;
  BitmapDescriptor? _bikeMarkerIcon;
  BitmapDescriptor? _storeMarkerIcon;
  StreamSubscription<Position>? _positionSub;
  bool _routeFetchInFlight = false;
  DeliveryOrder? _lastOrder;
  double _currentHeading = 0.0;
  Position? _previousPos;
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  bool _isCompleting = false;
  bool _isActionLoading = false;
  bool _trafficEnabled = false;
  bool _isSheetExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomMarkers();
    });
    _positionSub = ref.read(locationServiceProvider).positionStream.listen(_onPositionUpdate);
  }

  @override
  void dispose() {
    _routeRefreshTimer?.cancel();
    _positionSub?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomMarkers() async {
    try {
      final cutleryMarker = await _createCutleryMarker();
      final riderMarker = await _createRiderNavigationMarker();
      if (!mounted) return;
      setState(() {
        _storeMarkerIcon = cutleryMarker;
        _bikeMarkerIcon = riderMarker;
      });
    } catch (e) {
      debugPrint('Error generating markers: $e');
    }
  }

  /// The pin art is authored at 100x120; [_markerScale] is what it is actually
  /// drawn at. Both markers were rendered full size and covered the street they
  /// were pointing at.
  static const double _markerScale = 0.6;

  Future<BitmapDescriptor> _createCutleryMarker() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 100, 120));
    canvas.scale(_markerScale);

    // Shadow
    canvas.drawCircle(
      const Offset(50, 50),
      40,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Outer teal pin circle
    canvas.drawCircle(
      const Offset(50, 50),
      38,
      Paint()..color = AppColors.primaryDark,
    );

    // White border ring
    canvas.drawCircle(
      const Offset(50, 50),
      38,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Pointer triangle below
    final path = Path()
      ..moveTo(38, 82)
      ..lineTo(62, 82)
      ..lineTo(50, 104)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.primaryDark);

    // Cutlery Icon
    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.restaurant_rounded.codePoint),
      style: TextStyle(
        fontSize: 40,
        fontFamily: Icons.restaurant_rounded.fontFamily,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(50 - textPainter.width / 2, 50 - textPainter.height / 2));

    final picture = recorder.endRecording();
    final img = await picture.toImage(
        (100 * _markerScale).round(), (120 * _markerScale).round());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createRiderNavigationMarker() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 120, 120));
    canvas.scale(_markerScale);

    // Outer light teal halo/aura
    canvas.drawCircle(
      const Offset(60, 60),
      54,
      Paint()..color = const Color(0x3300A884),
    );

    // Inner dark teal circle
    canvas.drawCircle(
      const Offset(60, 60),
      34,
      Paint()..color = AppColors.primaryDark,
    );

    // White outline ring
    canvas.drawCircle(
      const Offset(60, 60),
      34,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Navigation Arrow icon in center
    TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.navigation_rounded.codePoint),
      style: TextStyle(
        fontSize: 34,
        fontFamily: Icons.navigation_rounded.fontFamily,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(60 - textPainter.width / 2, 60 - textPainter.height / 2));

    final picture = recorder.endRecording();
    final img = await picture.toImage(
        (120 * _markerScale).round(), (120 * _markerScale).round());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  /// The overlays that sit on top of the map — a distance/ETA readout and the
  /// map controls. Both used to be opaque white cards big enough to hide a
  /// quarter of the route between them, so they are compact and translucent:
  /// the rider can read them and still see what is underneath.
  Widget _mapInfoPill(String distance, String eta) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.near_me_rounded, color: AppColors.primaryDark, size: 14.sp),
          SizedBox(width: 5.w),
          Text(
            distance,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.sp, color: Colors.black87),
          ),
          Container(
            width: 1.w,
            height: 11.h,
            margin: EdgeInsets.symmetric(horizontal: 8.w),
            color: Colors.grey[300],
          ),
          Icon(Icons.schedule_rounded, color: Colors.grey[600], size: 13.sp),
          SizedBox(width: 5.w),
          Text(
            eta,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.sp, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  /// Icon-only so it stays out of the way. [label] is the tooltip, which is
  /// also what a screen reader announces — dropping the printed caption must
  /// not drop the name.
  Widget _mapControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38.r,
          height: 38.r,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: active ? AppColors.primaryDark : Colors.black87,
            size: 19.sp,
          ),
        ),
      ),
    );
  }

  /// Straight-line km from the rider to the leg's destination, or null until
  /// there is both a GPS fix and a decoded route.
  double? _distanceToDestinationKm() {
    final pos = ref.watch(locationServiceProvider).lastPosition;
    if (pos == null || _routeDestination == null) return null;
    return Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          _routeDestination!.latitude,
          _routeDestination!.longitude,
        ) /
        1000.0;
  }

  String _formattedOrderTime(DateTime? date) {
    if (date == null) return '—';
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $ampm';
  }

  /// "Today" / "Yesterday" / "12 Sep" under the order time. It used to say
  /// "Today" for every order, including ones placed before midnight.
  String _orderDayLabel(DateTime? date) {
    if (date == null) return '';
    final today = DateUtils.dateOnly(DateTime.now());
    final days = today.difference(DateUtils.dateOnly(date)).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]}';
  }

  /// Arrival clock time, or `—` while the route call has not answered. The
  /// fallback used to be a flat 15 minutes, which read as a real ETA.
  String _formattedEstimatedArrival() {
    if (_etaMins == null) return '—';
    final mins = _etaMins!.round();
    final arrival = DateTime.now().add(Duration(minutes: mins));
    final hour = arrival.hour > 12 ? arrival.hour - 12 : (arrival.hour == 0 ? 12 : arrival.hour);
    final minute = arrival.minute.toString().padLeft(2, '0');
    final ampm = arrival.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  void _onPositionUpdate(Position position) {
    if (_routePoints.isEmpty && !_routeFetchInFlight && _lastOrder != null) {
      _fetchRoute(_lastOrder!, _targetFor(_lastOrder!));
    }

    final hasDeviceHeading = position.headingAccuracy >= 0 && position.heading >= 0;
    double? nextHeading;
    if (hasDeviceHeading) {
      nextHeading = position.heading;
    } else if (_previousPos != null) {
      final distance = Geolocator.distanceBetween(
        _previousPos!.latitude,
        _previousPos!.longitude,
        position.latitude,
        position.longitude,
      );
      if (distance > 1.5) {
        nextHeading = Geolocator.bearingBetween(
          _previousPos!.latitude,
          _previousPos!.longitude,
          position.latitude,
          position.longitude,
        );
      }
    }
    if (nextHeading != null && mounted) {
      setState(() => _currentHeading = nextHeading!);
    }
    _previousPos = position;
  }

  void _maybeFetchRoute(DeliveryOrder order) {
    _lastOrder = order;
    final target = _targetFor(order);
    final key = '${order.id}::$target';
    if (key == _routeKey) return;
    _routeKey = key;
    _fetchRoute(order, target);

    _routeRefreshTimer?.cancel();
    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final ordersState = ref.read(ordersControllerProvider);
      if (ordersState is OrdersLoaded && ordersState.hasActiveOrder) {
        _fetchRoute(ordersState.currentOrder!, target);
      }
    });
  }

  String _targetFor(DeliveryOrder order) {
    final navigateToStore = order.currentPhase == 'en_route_to_pickup' ||
        order.currentPhase == 'at_pickup';
    return navigateToStore ? 'restaurant' : 'customer';
  }

  Future<void> _fetchRoute(DeliveryOrder order, String target) async {
    final pos = ref.read(locationServiceProvider).lastPosition;
    if (pos == null || _routeFetchInFlight) return;
    // `grep '\[trip-route\]'`. Every way this can fail — no GPS fix, a route
    // call that errors, a 200 carrying an empty polyline — used to look the
    // same from the outside: a map with no line on it. The empty-polyline case
    // is the one that actually happened, and it was a backend config gap, not
    // anything this screen did.
    void log(String m) => debugPrint('[trip-route] $m');
    _routeFetchInFlight = true;
    final result = await ref.read(ordersRepositoryProvider).getRoute(
          order.id,
          lat: pos.latitude,
          lng: pos.longitude,
          target: target,
        );
    _routeFetchInFlight = false;
    if (!mounted) return;
    result.when(
      success: (data) {
        final encoded = data['polyline'] as String?;
        final points = (encoded != null && encoded.isNotEmpty)
            ? decodePolyline(encoded)
            : <LatLng>[];
        if (points.isEmpty) {
          log('target=$target returned no polyline (origin=${data['origin']}, '
              'destination=${data['destination']})');
        } else {
          log('target=$target ${points.length} points, '
              '${data['distanceKm']} km, ${data['durationMins']} min');
        }
        final destLoc = target == 'restaurant'
            ? order.store.location
            : order.deliveryAddress.location;
        final destination = destLoc != null
            ? LatLng(destLoc.lat, destLoc.lng)
            : (points.isNotEmpty ? points.last : null);
        setState(() {
          _routePoints = points;
          _routeDestination = destination;
          _etaMins = (data['durationMins'] as num?)?.toDouble();
        });
        if (destination != null && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(
              _boundsFor(LatLng(pos.latitude, pos.longitude), destination),
              80,
            ),
          );
        }
      },
      failure: (e) => log('target=$target fetch failed: ${e.message}'),
    );
  }

  LatLngBounds _boundsFor(LatLng a, LatLng b) {
    return LatLngBounds(
      southwest: LatLng(
        a.latitude < b.latitude ? a.latitude : b.latitude,
        a.longitude < b.longitude ? a.longitude : b.longitude,
      ),
      northeast: LatLng(
        a.latitude > b.latitude ? a.latitude : b.latitude,
        a.longitude > b.longitude ? a.longitude : b.longitude,
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runAction(Future<Result<DeliveryOrder, AppError>> Function() call) async {
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    final result = await call();
    if (mounted) setState(() => _isActionLoading = false);
    result.when(success: (_) {}, failure: (error) => _showSnack(error.message));
  }

  ({String label, IconData icon, Future<void> Function() action})? _actionFor(DeliveryOrder order) {
    final controller = ref.read(ordersControllerProvider.notifier);
    switch (order.currentPhase) {
      case 'en_route_to_pickup':
        return (
          label: 'Reached Restaurant',
          icon: Icons.storefront_outlined,
          action: () => _runAction(() => controller.reachedPickup(order.id)),
        );
      case 'at_pickup':
        return (
          label: 'Confirm Pickup',
          icon: Icons.check_circle_outline,
          action: () => _confirmPickup(order),
        );
      case 'en_route_to_delivery':
        return (
          label: 'Reached Customer',
          icon: Icons.flag_outlined,
          action: () => _runAction(() => controller.reachedDrop(order.id)),
        );
      case 'at_drop':
        if (order.dropOtpRequired && !order.dropOtpVerified) {
          return (
            label: 'Verify OTP',
            icon: Icons.verified_user_outlined,
            action: () => _promptDropOtp(order),
          );
        }
        if (!order.isPaid) {
          return (
            label: 'Collect payment',
            icon: Icons.payments_outlined,
            action: () => _showCollectPaymentSheet(order),
          );
        }
        return (
          label: 'Complete delivery',
          icon: Icons.done_all_rounded,
          action: () => _completeDelivery(order),
        );
      default:
        return null;
    }
  }

  Future<void> _confirmPickup(DeliveryOrder order) async {
    final confirmed = await showOrderProductsSheet(
      context,
      order: order,
      checklist: true,
    );
    if (confirmed != true) return;
    await _runAction(
      () => ref.read(ordersControllerProvider.notifier).confirmPickup(order.id),
    );
  }

  Future<void> _completeDelivery(DeliveryOrder order) async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    
    _confettiController.play();
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    final result = await ref.read(ordersControllerProvider.notifier).completeOrder(order.id);
    result.when(
      success: (_) {
        ref.read(activeTripVisibilityControllerProvider.notifier).show();
        if (mounted) {
           ref.read(activeTripVisibilityControllerProvider.notifier).hide();
           ref.read(goRouterProvider).go('/order-delivered', extra: order);
        }
      },
      failure: (error) {
        _showSnack(error.message);
        if (mounted) setState(() => _isCompleting = false);
      },
    );
  }

  Future<void> _promptDropOtp(DeliveryOrder order) async {
    final controller = ref.read(ordersControllerProvider.notifier);
    final otp = await showOtpBottomSheet(context, customerName: order.customerName);
    if (otp == null || otp.length != 4) return;
    final result = await controller.verifyDropOtp(order.id, otp);
    result.when(
      success: (updatedOrder) async {
        if (!updatedOrder.isPaid) {
          if (mounted) await _showCollectPaymentSheet(updatedOrder);
          return;
        }
        if (_isCompleting) return;
        setState(() => _isCompleting = true);

        _confettiController.play();
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          final completeResult = await ref.read(ordersControllerProvider.notifier).completeOrder(order.id);
          completeResult.when(
            success: (_) {
              ref.read(activeTripVisibilityControllerProvider.notifier).hide();
              ref.read(goRouterProvider).go('/main');
            },
            failure: (error) {
              _showSnack(error.message);
              if (mounted) setState(() => _isCompleting = false);
            }
          );
        }
      },
      failure: (error) => _showSnack(error.message)
    );
  }

  Future<void> _showCollectPaymentSheet(DeliveryOrder order) async {
    final collected = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CollectPaymentSheet(order: order),
    );
    if (collected == true && mounted) {
      await _completeDelivery(order);
    }
  }

  void _openChat(DeliveryOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerRole: 'USER',
          peerId: order.customerId,
          orderId: order.id,
          title: order.customerName.isNotEmpty ? order.customerName : 'Customer',
          subtitle: 'Order #${order.orderCode}',
        ),
      ),
    );
  }

  void _openRestaurantGallery(DeliveryOrder order) {
    final images = order.store.allImages;
    if (images.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _RestaurantGalleryViewer(
        images: images,
        restaurantName: order.store.name,
      ),
    );
  }

  Future<void> _dial(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildMap(DeliveryOrder order) {
    return StreamBuilder<Position>(
      stream: ref.read(locationServiceProvider).positionStream,
      initialData: ref.read(locationServiceProvider).lastPosition,
      builder: (context, snapshot) {
        final pos = snapshot.data;
        // Rider fix first, then the order's own destination, then the store's
        // coordinates. The last resort used to be a fixed Mumbai point
        // (19.1136, 72.8697), which put a rider anywhere else on the map in
        // the wrong city until their first GPS fix landed.
        final storeLocation = order.store.location;
        final dropLocation = order.deliveryAddress.location;
        final initialTarget = pos != null
            ? LatLng(pos.latitude, pos.longitude)
            : _routeDestination ??
                (storeLocation != null
                    ? LatLng(storeLocation.lat, storeLocation.lng)
                    : dropLocation != null
                        ? LatLng(dropLocation.lat, dropLocation.lng)
                        : null);
        final isPickupPhase = _targetFor(order) == 'restaurant';
        final hasGalleryImages = order.store.allImages.isNotEmpty;

        // Nothing real to centre on yet: say so rather than open the map on
        // an arbitrary city.
        if (initialTarget == null) return const _AwaitingLocationMap();

        return GoogleMap(
          onMapCreated: (controller) => _mapController = controller,
          initialCameraPosition: CameraPosition(target: initialTarget, zoom: 15),
          trafficEnabled: _trafficEnabled,
          markers: {
            if (_routeDestination != null)
              Marker(
                markerId: const MarkerId('trip_destination'),
                position: _routeDestination!,
                icon: _storeMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
                onTap: isPickupPhase && hasGalleryImages
                    ? () {
                        HapticService.light();
                        _openRestaurantGallery(order);
                      }
                    : null,
              ),
            if (pos != null)
              Marker(
                markerId: const MarkerId('delivery_partner'),
                position: LatLng(pos.latitude, pos.longitude),
                icon: _bikeMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                anchor: const Offset(0.5, 0.5),
                rotation: _currentHeading,
                flat: true,
              ),
          },
          polylines: {
            if (_routePoints.length > 1)
              Polyline(
                polylineId: const PolylineId('active_trip_route'),
                points: _routePoints,
                color: AppColors.primaryDark,
                width: 5,
              ),
          },
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          style: MapStyles.mutedGrey,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersControllerProvider);

    ref.listen<OrdersState>(ordersControllerProvider, (previous, next) {
      if (next is OrdersLoaded && next.hasActiveOrder) {
        _maybeFetchRoute(next.currentOrder!);
      }
    });

    if (ordersState is! OrdersLoaded || !ordersState.hasActiveOrder) {
      return const SizedBox.shrink();
    }
    final order = ordersState.currentOrder!;

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeFetchRoute(order));

    if (order.currentPhase == 'at_pickup') {
      return _buildAtPickupScreen(order);
    } else if (order.currentPhase == 'en_route_to_delivery') {
      return _buildOnTheWayScreen(order);
    } else if (order.currentPhase == 'delivered' || order.orderStatus == 'delivered') {
      return OrderDeliveredScreen(order: order);
    }

    final isPickupPhase = _targetFor(order) == 'restaurant';
    final distKm = _distanceToDestinationKm();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(activeTripVisibilityControllerProvider.notifier).hide();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Map Layer
            Positioned.fill(child: _buildMap(order)),

            // 2. Top Header Navigation Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticService.light();
                              ref.read(activeTripVisibilityControllerProvider.notifier).hide();
                            },
                            child: Container(
                              width: 40.r,
                              height: 40.r,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.arrow_back, color: Colors.black87, size: 20.sp),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isPickupPhase ? 'Go to Restaurant' : 'Go to Customer',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18.sp,
                                    color: Colors.black87,
                                    height: 1.1,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  isPickupPhase ? 'Pick up the order' : 'Deliver the order',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _dial(isPickupPhase ? (order.store.phone ?? '') : order.customerPhone),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40.r,
                                  height: 40.r,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey[200]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(Icons.call_outlined, color: AppColors.primaryDark, size: 19.sp),
                                ),
                                SizedBox(height: 3.h),
                                Text(
                                  'Call',
                                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[700], fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12.w),
                          GestureDetector(
                            onTap: () => _openChat(order),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40.r,
                                  height: 40.r,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey[200]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryDark, size: 18.sp),
                                ),
                                SizedBox(height: 3.h),
                                Text(
                                  'Chat',
                                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[700], fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      // 3 & 4. Map overlays — distance/ETA on the left, the map
                      // controls on the right. They used to hang off a guessed
                      // `top:`, which dropped them on the Call/Chat buttons;
                      // sitting at the end of the header column they always
                      // land just under whatever the header really measures.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _mapInfoPill(
                            distKm == null ? '—' : '${distKm.toStringAsFixed(1)} km',
                            _etaMins == null ? '—' : '${_etaMins!.round()} min',
                          ),
                          const Spacer(),
                          Column(
                            children: [
                              _mapControlButton(
                                icon: Icons.my_location_rounded,
                                label: 'Re-center',
                                onTap: () {
                                  HapticService.light();
                                  final pos = ref.read(locationServiceProvider).lastPosition;
                                  if (pos != null && _mapController != null) {
                                    _mapController!.animateCamera(
                                      CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
                                    );
                                  }
                                },
                              ),
                              SizedBox(height: 8.h),
                              _mapControlButton(
                                icon: Icons.traffic_rounded,
                                label: 'Live traffic',
                                active: _trafficEnabled,
                                onTap: () {
                                  HapticService.light();
                                  setState(() => _trafficEnabled = !_trafficEnabled);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Bottom Sheet Overlay
            _draggableDetailSheet(
              (controller) => _buildBottomCard(order, isPickupPhase, controller),
            ),

            // Confetti Overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.05,
                numberOfParticles: 25,
                gravity: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreAvatar(String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      final resolved = AppConstants.resolveMediaUrl(photoUrl);
      if (resolved.isNotEmpty) {
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: resolved,
            width: 52.r,
            height: 52.r,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => _defaultGoldenAvatar(),
          ),
        );
      }
    }
    return _defaultGoldenAvatar();
  }

  Widget _defaultGoldenAvatar() {
    return Container(
      width: 52.r,
      height: 52.r,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFD97706), width: 1.5),
          ),
          child: Icon(
            Icons.restaurant_menu_rounded,
            color: const Color(0xFFF59E0B),
            size: 22.sp,
          ),
        ),
      ),
    );
  }

  /// The trip detail card sits on top of the map, so it has to be draggable.
  /// At its natural height it covered the whole route — the rider could read the
  /// order but never see where they were going. Snaps to peek / default / full.
  Widget _draggableDetailSheet(Widget Function(ScrollController) builder) {
    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.16,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.16, 0.58, 0.92],
      builder: (_, controller) => builder(controller),
    );
  }

  Widget _buildBottomCard(DeliveryOrder order, bool isPickupPhase, ScrollController scrollController) {
    final action = _actionFor(order);
    final name = isPickupPhase
        ? (order.store.name.isNotEmpty ? order.store.name : 'Pickup store')
        : order.customerName;
    final address = isPickupPhase
        ? (order.store.address.isNotEmpty ? order.store.address : 'Address not provided')
        : order.deliveryAddress.fullAddress;
    final destLat = isPickupPhase ? order.store.location?.lat : order.deliveryAddress.location?.lat;
    final destLng = isPickupPhase ? order.store.location?.lng : order.deliveryAddress.location?.lng;

    final itemCount = order.items.fold(0, (sum, i) => sum + i.quantity);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle Bar
            Center(
              child: Container(
                width: 38.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 14.h),

            // 1. Restaurant / Customer Profile Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStoreAvatar(isPickupPhase ? order.store.displayImage : order.customerPhoto),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          isPickupPhase ? 'PICKUP FROM' : 'DELIVER TO',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 9.sp,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16.sp,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(Icons.verified_rounded, color: AppColors.primaryDark, size: 16.sp),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey[600], height: 1.2),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                OutlinedButton(
                  onPressed: () {
                    HapticService.light();
                    showOrderProductsSheet(context, order: order);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View Details',
                    style: TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.sp,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // 2. Order Summary 3-Grid Cards Row
            Row(
              children: [
                // Card 1: Order ID
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(4.r),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.shopping_bag_outlined, color: AppColors.primaryDark, size: 12.sp),
                            ),
                            SizedBox(width: 4.w),
                            Text('Order ID', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          order.orderCode.isNotEmpty ? '#${order.orderCode}' : '—',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${itemCount > 0 ? itemCount : 2} Items',
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                // Card 2: Order Time
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(4.r),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.access_time_rounded, color: AppColors.primaryDark, size: 12.sp),
                            ),
                            SizedBox(width: 4.w),
                            Text('Order Time', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          _formattedOrderTime(order.placedAt),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp, color: Colors.black87),
                          maxLines: 1,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          _orderDayLabel(order.placedAt),
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                // Card 3: Payment
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(4.r),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.bookmark_outline_rounded, color: AppColors.primaryDark, size: 12.sp),
                            ),
                            SizedBox(width: 4.w),
                            Text('Payment', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          order.isPaid ? 'Prepaid' : 'COD',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp, color: Colors.black87),
                          maxLines: 1,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          order.isPaid ? 'Online' : 'Cash',
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),

            // 3. Restaurant Instruction Banner Card
            GestureDetector(
              onTap: () {
                HapticService.light();
                showOrderProductsSheet(context, order: order);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9EE),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notifications_active_rounded, color: const Color(0xFFD97706), size: 18.sp),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Restaurant Instruction',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.sp, color: const Color(0xFFB45309)),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            (order.deliveryInstructions != null && order.deliveryInstructions!.isNotEmpty)
                                ? order.deliveryInstructions!
                                : ((order.storeNote != null && order.storeNote!.isNotEmpty)
                                    ? order.storeNote!
                                    : 'No instructions from the restaurant.'),
                            style: TextStyle(fontSize: 11.sp, color: const Color(0xFF92400E)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: const Color(0xFFD97706), size: 20.sp),
                  ],
                ),
              ),
            ),
            SizedBox(height: 14.h),

            // 4. Action Buttons Row (Call Restaurant, Message, Reached Restaurant CTA)
            Row(
              children: [
                GestureDetector(
                  onTap: () => _dial(isPickupPhase ? (order.store.phone ?? '') : order.customerPhone),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.phone_outlined, color: AppColors.primaryDark, size: 16.sp),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Call Restaurant',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10.sp, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: () => _openChat(order),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryDark, size: 16.sp),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'Message',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10.sp, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: GestureDetector(
                    onTap: _isActionLoading
                        ? null
                        : () {
                            HapticService.light();
                            action?.action();
                          },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(14.r),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  action?.label ?? (isPickupPhase ? 'Reached Restaurant' : 'Reached Customer'),
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.sp, color: Colors.white),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  isPickupPhase ? 'Verify & pick up order' : 'Deliver to customer',
                                  style: TextStyle(fontSize: 10.sp, color: Colors.white.withValues(alpha: 0.8)),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24.sp),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),

            // 5. Bottom Estimated Arrival Drawer Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticService.light();
                      setState(() => _isSheetExpanded = !_isSheetExpanded);
                    },
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isSheetExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                        color: Colors.black87,
                        size: 20.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Estimated arrival',
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                      ),
                      Text(
                        _formattedEstimatedArrival(),
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17.sp, color: Colors.black87),
                      ),
                    ],
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () {
                      if (destLat != null && destLng != null) {
                        MapLauncher.launchGoogleMaps(destLat, destLng);
                      } else {
                        _showSnack('Location not available');
                      }
                    },
                    icon: Icon(Icons.navigation_outlined, color: AppColors.primaryDark, size: 16.sp),
                    label: Text(
                      'Open in Maps',
                      style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 12.sp),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryDark),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepper(int activeStep) {
    final steps = [
      'Go to Restaurant',
      'Restaurant Pickup',
      'On the Way',
      'Deliver Order',
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 10.h),
      child: Column(
        children: [
          Row(
            children: List.generate(7, (i) {
              if (i.isOdd) {
                final stepBefore = (i ~/ 2) + 1;
                final isDone = stepBefore < activeStep;
                return Expanded(
                  child: Container(
                    height: 2.h,
                    margin: EdgeInsets.symmetric(horizontal: 2.w),
                    color: isDone ? AppColors.primaryDark : Colors.grey[300],
                  ),
                );
              }
              final stepNum = (i ~/ 2) + 1;
              final isDone = stepNum < activeStep;
              final isActive = stepNum == activeStep;

              return Container(
                width: 26.r,
                height: 26.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? AppColors.primaryLight
                      : (isActive ? AppColors.primaryDark : Colors.white),
                  border: Border.all(
                    color: (isDone || isActive)
                        ? AppColors.primaryDark
                        : Colors.grey[300]!,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? Icon(Icons.check, size: 14.sp, color: AppColors.primaryDark)
                      : Text(
                          '$stepNum',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: isActive ? Colors.white : Colors.grey[500],
                          ),
                        ),
                ),
              );
            }),
          ),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (index) {
              final stepNum = index + 1;
              final isActive = stepNum == activeStep;
              final isDone = stepNum < activeStep;
              return SizedBox(
                width: 75.w,
                child: Text(
                  steps[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? AppColors.primaryDark
                        : (isDone ? Colors.black87 : Colors.grey[500]),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildVegBadge(bool isVeg) {
    return Container(
      width: 14.r,
      height: 14.r,
      padding: EdgeInsets.all(2.r),
      decoration: BoxDecoration(
        border: Border.all(color: isVeg ? const Color(0xFF2E7D32) : const Color(0xFFC62828), width: 1.5),
        borderRadius: BorderRadius.circular(3.r),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isVeg ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildFoodImage(String? url) {
    final resolved = url != null ? AppConstants.resolveMediaUrl(url) : '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        width: 52.r,
        height: 52.r,
        color: Colors.grey[100],
        child: resolved.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: resolved,
                width: 52.r,
                height: 52.r,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _fallbackFoodPlaceholder(),
              )
            : _fallbackFoodPlaceholder(),
      ),
    );
  }

  Widget _fallbackFoodPlaceholder() {
    return Container(
      width: 52.r,
      height: 52.r,
      color: const Color(0xFFFFF3E0),
      child: Icon(Icons.lunch_dining_rounded, color: const Color(0xFFF57C00), size: 26.sp),
    );
  }

  Widget _buildAtPickupScreen(DeliveryOrder order) {
    // This is the screen a rider reads while standing at the counter, so it
    // shows the order the backend sent and nothing else. It used to substitute
    // a two-item sample basket (Chicken Biryani ₹189 + Mirchi Ka Salan ₹49,
    // ₹238 total, stock Unsplash photos) whenever `order.items` came back
    // empty — a rider could have collected the wrong goods on it.
    final storeName =
        order.store.name.isNotEmpty ? order.store.name : 'Pickup store';
    final storeAddress = order.store.address.isNotEmpty
        ? order.store.address
        : 'Address not provided';
    final orderCode = order.orderCode.isNotEmpty ? '#${order.orderCode}' : '—';
    final itemsList = order.items;
    final totalBill = order.total;
    final riderEarning = order.riderEarning;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(activeTripVisibilityControllerProvider.notifier).hide();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Column(
          children: [
            // Top Sticky Header
            Container(
              color: Colors.white,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              HapticService.light();
                              ref.read(activeTripVisibilityControllerProvider.notifier).hide();
                            },
                            child: Container(
                              width: 40.r,
                              height: 40.r,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey[200]!),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.arrow_back, color: Colors.black87, size: 20.sp),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Restaurant Pickup',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18.sp,
                                    color: Colors.black87,
                                    height: 1.1,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'Pick up the order from the restaurant',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _dial(order.store.phone ?? ''),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40.r,
                                  height: 40.r,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey[200]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(Icons.call_outlined, color: AppColors.primaryDark, size: 19.sp),
                                ),
                                SizedBox(height: 3.h),
                                Text('Call', style: TextStyle(fontSize: 11.sp, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          SizedBox(width: 12.w),
                          GestureDetector(
                            onTap: () => _openChat(order),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40.r,
                                  height: 40.r,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey[200]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryDark, size: 18.sp),
                                ),
                                SizedBox(height: 3.h),
                                Text('Chat', style: TextStyle(fontSize: 11.sp, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStepper(2),
                  ],
                ),
              ),
            ),
            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(16.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Restaurant Header Card
                    Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStoreAvatar(order.store.displayImage),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    'PICKUP FROM',
                                    style: TextStyle(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9.sp,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        storeName,
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp, color: Colors.black87),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 4.w),
                                    Icon(Icons.verified_rounded, color: AppColors.primaryDark, size: 16.sp),
                                  ],
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  storeAddress,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600], height: 1.2),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          OutlinedButton(
                            onPressed: () {
                              HapticService.light();
                              showOrderProductsSheet(context, order: order);
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primaryDark),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'View Details',
                              style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 11.sp),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // 2. Order Summary 3-Grid Cards
                    Row(
                      children: [
                        // Card 1: Order Time
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(10.r),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14.r),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(4.r),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.access_time_rounded, color: AppColors.primaryDark, size: 12.sp),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text('Order Time', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
                                  ],
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  _formattedOrderTime(order.placedAt),
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp, color: Colors.black87),
                                  maxLines: 1,
                                ),
                                SizedBox(height: 2.h),
                                Text('Today', style: TextStyle(fontSize: 10.sp, color: Colors.grey[500])),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        // Card 2: Order ID
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(10.r),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14.r),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(4.r),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.tag_rounded, color: AppColors.primaryDark, size: 12.sp),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text('Order ID', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
                                  ],
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  orderCode,
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp, color: Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2.h),
                                Text('${itemsList.length} Items', style: TextStyle(fontSize: 10.sp, color: Colors.grey[500])),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        // Card 3: Payment
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(10.r),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14.r),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(4.r),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryDark, size: 12.sp),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text('Payment', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
                                  ],
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  order.isPaid ? 'Prepaid' : 'COD',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp, color: Colors.black87),
                                  maxLines: 1,
                                ),
                                SizedBox(height: 2.h),
                                Text(order.isPaid ? 'Online' : 'Cash', style: TextStyle(fontSize: 10.sp, color: Colors.grey[500])),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),

                    // 3. Restaurant Instructions Banner Card
                    GestureDetector(
                      onTap: () {
                        HapticService.light();
                        showOrderProductsSheet(context, order: order);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9EE),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEF3C7),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.notifications_active_rounded, color: const Color(0xFFD97706), size: 18.sp),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Restaurant Instructions',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp, color: const Color(0xFFB45309)),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    (order.deliveryInstructions != null && order.deliveryInstructions!.isNotEmpty)
                                        ? order.deliveryInstructions!
                                        : ((order.storeNote != null && order.storeNote!.isNotEmpty)
                                            ? order.storeNote!
                                            : 'No instructions from the restaurant.'),
                                    style: TextStyle(fontSize: 11.sp, color: const Color(0xFF92400E)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down_rounded, color: const Color(0xFFD97706), size: 22.sp),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // 4. Items to pick up Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Items to pick up (${itemsList.length})',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: Colors.black87),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticService.light();
                            showOrderProductsSheet(context, order: order);
                          },
                          child: Row(
                            children: [
                              Text(
                                'View Details',
                                style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 12.sp),
                              ),
                              Icon(Icons.chevron_right_rounded, color: AppColors.primaryDark, size: 18.sp),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < itemsList.length; i++) ...[
                            if (i > 0) Divider(height: 20.h, color: Colors.grey[100]),
                            Row(
                              children: [
                                _buildFoodImage(itemsList[i].image),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          _buildVegBadge(itemsList[i].isVeg),
                                          SizedBox(width: 6.w),
                                          Expanded(
                                            child: Text(
                                              itemsList[i].name,
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.sp, color: Colors.black87),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        '${itemsList[i].quantity} x ₹${itemsList[i].price.toStringAsFixed(0)}',
                                        style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${(itemsList[i].lineTotal > 0 ? itemsList[i].lineTotal : itemsList[i].price * itemsList[i].quantity).toStringAsFixed(2)}',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.sp, color: Colors.black87),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // 5. Total Bill & Rider Earnings Summary Card
                    Container(
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8.r),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.bookmark_outline_rounded, color: AppColors.primaryDark, size: 18.sp),
                                ),
                                SizedBox(width: 10.w),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Bill', style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
                                    SizedBox(height: 2.h),
                                    Text(
                                      '₹${totalBill.toStringAsFixed(2)}',
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1.w, height: 40.h, color: Colors.grey[200]),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: 14.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('You will earn', style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
                                      SizedBox(width: 4.w),
                                      Icon(Icons.info_outline_rounded, size: 13.sp, color: Colors.grey[500]),
                                    ],
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    '₹${riderEarning.toStringAsFixed(2)}',
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18.sp, color: AppColors.primaryDark),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // 6. Before you pick up Guide Box
                    Container(
                      padding: EdgeInsets.all(14.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FAF8),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Before you pick up',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp, color: Colors.grey[800]),
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8.r),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.shopping_bag_outlined, color: AppColors.primaryDark, size: 18.sp),
                                    ),
                                    SizedBox(height: 6.h),
                                    Text('Verify items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.sp, color: AppColors.primaryDark)),
                                    SizedBox(height: 2.h),
                                    Text('Check items &\nquantities', textAlign: TextAlign.center, style: TextStyle(fontSize: 9.sp, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8.r),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.assignment_outlined, color: AppColors.primaryDark, size: 18.sp),
                                    ),
                                    SizedBox(height: 6.h),
                                    Text('Confirm order', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.sp, color: AppColors.primaryDark)),
                                    SizedBox(height: 2.h),
                                    Text('Confirm with restaurant\nstaff', textAlign: TextAlign.center, style: TextStyle(fontSize: 9.sp, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8.r),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.work_outline_rounded, color: AppColors.primaryDark, size: 18.sp),
                                    ),
                                    SizedBox(height: 6.h),
                                    Text('Ensure packaging', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.sp, color: AppColors.primaryDark)),
                                    SizedBox(height: 2.h),
                                    Text('Ensure order is\nproperly packed', textAlign: TextAlign.center, style: TextStyle(fontSize: 9.sp, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // 7. Main Confirm Pickup CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 60.h,
                      child: ElevatedButton(
                        onPressed: _isActionLoading
                            ? null
                            : () {
                                HapticService.light();
                                _confirmPickup(order);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          elevation: 4,
                          shadowColor: AppColors.primaryDark.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
                          padding: EdgeInsets.symmetric(horizontal: 14.w),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38.r,
                              height: 38.r,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.fact_check_outlined, color: AppColors.primaryDark, size: 20.sp),
                            ),
                            SizedBox(width: 14.w),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Confirm Pickup',
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp, color: Colors.white),
                                  ),
                                  Text(
                                    'I have picked up the order',
                                    style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.8)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 36.r,
                              height: 36.r,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.chevron_right_rounded, color: AppColors.primaryDark, size: 24.sp),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperOnTheWay(int activeStep) {
    final steps = [
      'Picked up',
      'On the Way',
      'Arrived',
      'Delivered',
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 10.h),
      child: Column(
        children: [
          Row(
            children: List.generate(7, (i) {
              if (i.isOdd) {
                final stepBefore = (i ~/ 2) + 1;
                final isDone = stepBefore < activeStep;
                return Expanded(
                  child: Container(
                    height: 2.h,
                    margin: EdgeInsets.symmetric(horizontal: 2.w),
                    color: isDone ? AppColors.primaryDark : Colors.grey[300],
                  ),
                );
              }
              final stepNum = (i ~/ 2) + 1;
              final isDone = stepNum < activeStep;
              final isActive = stepNum == activeStep;

              return Container(
                width: 26.r,
                height: 26.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone
                      ? AppColors.primaryDark
                      : (isActive ? AppColors.primaryDark : Colors.white),
                  border: Border.all(
                    color: (isDone || isActive)
                        ? AppColors.primaryDark
                        : Colors.grey[300]!,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? Icon(Icons.check, size: 14.sp, color: Colors.white)
                      : Text(
                          '$stepNum',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: isActive ? Colors.white : Colors.grey[500],
                          ),
                        ),
                ),
              );
            }),
          ),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (index) {
              final stepNum = index + 1;
              final isActive = stepNum == activeStep;
              final isDone = stepNum < activeStep;
              return SizedBox(
                width: 75.w,
                child: Text(
                  steps[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    fontWeight: (isActive || isDone) ? FontWeight.w700 : FontWeight.w500,
                    color: (isActive || isDone)
                        ? AppColors.primaryDark
                        : Colors.grey[500],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildOnTheWayScreen(DeliveryOrder order) {
    final storeName =
        order.store.name.isNotEmpty ? order.store.name : 'Pickup store';
    final storeAddress = order.store.address.isNotEmpty
        ? order.store.address
        : 'Address not provided';
    final customerName =
        order.customerName.isNotEmpty ? order.customerName : 'Customer';
    final customerAddress = order.deliveryAddress.fullAddress.isNotEmpty
        ? order.deliveryAddress.fullAddress
        : 'Address not provided';
    final orderCode = order.orderCode.isNotEmpty ? '#${order.orderCode}' : '—';

    final itemsSummaryStr = order.items.isNotEmpty
        ? order.items.map((e) => e.name).join(', ')
        : 'No item details available';
    final itemsCount = order.items.length;

    final riderEarning = order.riderEarning;
    final remainingKm = _distanceToDestinationKm();
    final remainingKmText =
        remainingKm == null ? '—' : '${remainingKm.toStringAsFixed(1)} km';
    final etaTimeStr = _formattedEstimatedArrival();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(activeTripVisibilityControllerProvider.notifier).hide();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // 1. Map Layer (Showing Route to Customer)
            Positioned.fill(child: _buildMap(order)),

            // 2. Top Navigation Bar with Stepper
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              // The overlays ride under the header in one
              // column, so they cannot land on the stepper.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    color: Colors.white,
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    HapticService.light();
                                    ref.read(activeTripVisibilityControllerProvider.notifier).hide();
                                  },
                                  child: Container(
                                    width: 40.r,
                                    height: 40.r,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey[200]!),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(Icons.arrow_back, color: Colors.black87, size: 20.sp),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'On the Way',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18.sp,
                                          color: Colors.black87,
                                          height: 1.1,
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        'Delivering to customer',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _dial(order.customerPhone),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 40.r,
                                        height: 40.r,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.grey[200]!),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.06),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(Icons.call_outlined, color: AppColors.primaryDark, size: 19.sp),
                                      ),
                                      SizedBox(height: 3.h),
                                      Text('Call', style: TextStyle(fontSize: 11.sp, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                GestureDetector(
                                  onTap: () => _openChat(order),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 40.r,
                                        height: 40.r,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.grey[200]!),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.06),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryDark, size: 18.sp),
                                      ),
                                      SizedBox(height: 3.h),
                                      Text('Chat', style: TextStyle(fontSize: 11.sp, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildStepperOnTheWay(2),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _mapInfoPill(
                          remainingKmText,
                          _etaMins == null ? '—' : '${_etaMins!.round()} min',
                        ),
                        const Spacer(),
                        Column(
                          children: [
                            _mapControlButton(
                              icon: Icons.navigation_outlined,
                              label: 'View route in Maps',
                              onTap: () {
                                HapticService.light();
                                final lat = order.deliveryAddress.location?.lat;
                                final lng = order.deliveryAddress.location?.lng;
                                if (lat != null && lng != null) {
                                  MapLauncher.launchGoogleMaps(lat, lng);
                                } else {
                                  _showSnack('Customer location not available');
                                }
                              },
                            ),
                            SizedBox(height: 8.h),
                            _mapControlButton(
                              icon: Icons.traffic_rounded,
                              label: 'Live traffic',
                              active: _trafficEnabled,
                              onTap: () {
                                HapticService.light();
                                setState(() => _trafficEnabled = !_trafficEnabled);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 5. Bottom Sheet Card Overlay
            _draggableDetailSheet(
              (controller) => Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: controller,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h + MediaQuery.paddingOf(context).bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 38.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),

                      // Order ID, Order Time, Payment Header Grid
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6.r),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.assignment_outlined, color: AppColors.primaryDark, size: 14.sp),
                                ),
                                SizedBox(width: 6.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('ORDER ID', style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w700, color: Colors.grey[500])),
                                      SizedBox(height: 2.h),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              orderCode,
                                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.black87),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(width: 4.w),
                                          GestureDetector(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: orderCode));
                                              HapticService.light();
                                              _showSnack('Order ID copied to clipboard');
                                            },
                                            child: Icon(Icons.copy_rounded, color: AppColors.primaryDark, size: 13.sp),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1.w, height: 28.h, color: Colors.grey[200]),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: 8.w),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(6.r),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.access_time_rounded, color: AppColors.primaryDark, size: 14.sp),
                                  ),
                                  SizedBox(width: 6.w),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('ORDER TIME', style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w700, color: Colors.grey[500])),
                                      SizedBox(height: 2.h),
                                      Text(
                                        _formattedOrderTime(order.placedAt),
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(width: 1.w, height: 28.h, color: Colors.grey[200]),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: 8.w),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(6.r),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryDark, size: 14.sp),
                                  ),
                                  SizedBox(width: 6.w),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('PAYMENT', style: TextStyle(fontSize: 9.sp, fontWeight: FontWeight.w700, color: Colors.grey[500])),
                                      SizedBox(height: 2.h),
                                      Text(
                                        order.isPaid ? 'Prepaid' : 'COD',
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 24.h, color: Colors.grey[200]),

                      // Trip Route Card (Pickup -> Deliver To)
                      Container(
                        padding: EdgeInsets.all(14.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            // Pickup Store Section
                            Row(
                              children: [
                                _buildStoreAvatar(order.store.displayImage),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PICKUP FROM',
                                        style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 9.sp),
                                      ),
                                      SizedBox(height: 2.h),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              storeName,
                                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: Colors.black87),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(width: 4.w),
                                          Icon(Icons.verified_rounded, color: AppColors.primaryDark, size: 15.sp),
                                        ],
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        storeAddress,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                GestureDetector(
                                  onTap: () => _dial(order.store.phone ?? ''),
                                  child: Container(
                                    width: 36.r,
                                    height: 36.r,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey[200]!),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                                      ],
                                    ),
                                    child: Icon(Icons.call_outlined, color: AppColors.primaryDark, size: 16.sp),
                                  ),
                                ),
                              ],
                            ),

                            // Dotted Vertical Line Divider
                            Padding(
                              padding: EdgeInsets.only(left: 24.w, top: 4.h, bottom: 4.h),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  height: 20.h,
                                  child: CustomPaint(
                                    painter: _DottedLinePainter(),
                                  ),
                                ),
                              ),
                            ),

                            // Deliver To Customer Section
                            Row(
                              children: [
                                Container(
                                  width: 52.r,
                                  height: 52.r,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryDark,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.home_rounded, color: Colors.white, size: 26.sp),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'DELIVER TO',
                                        style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 9.sp),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        customerName,
                                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: Colors.black87),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        customerAddress,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                GestureDetector(
                                  onTap: () => _dial(order.customerPhone),
                                  child: Container(
                                    width: 36.r,
                                    height: 36.r,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey[200]!),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                                      ],
                                    ),
                                    child: Icon(Icons.call_outlined, color: AppColors.primaryDark, size: 16.sp),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),

                      // Order Items Summary Banner Card
                      GestureDetector(
                        onTap: () {
                          HapticService.light();
                          showOrderProductsSheet(context, order: order);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FAF8),
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.local_mall_outlined, color: AppColors.primaryDark, size: 18.sp),
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Order Items ($itemsCount)',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.sp, color: Colors.black87),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      itemsSummaryStr,
                                      style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'View Details',
                                    style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 11.sp),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: AppColors.primaryDark, size: 16.sp),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 14.h),

                      // Financial & ETA 3-Grid Row (Earnings, Distance, Drop-off by)
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8.r),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.currency_rupee_rounded, color: AppColors.primaryDark, size: 16.sp),
                                ),
                                SizedBox(width: 8.w),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Earnings', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
                                    Text(
                                      '₹${riderEarning.toStringAsFixed(2)}',
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.sp, color: Colors.black87),
                                    ),
                                    Text('Total Earning', style: TextStyle(fontSize: 9.sp, color: Colors.grey[500])),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8.r),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.alt_route_rounded, color: AppColors.primaryDark, size: 16.sp),
                                ),
                                SizedBox(width: 8.w),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Distance', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
                                    Text(
                                      remainingKmText,
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.sp, color: Colors.black87),
                                    ),
                                    Text('Remaining', style: TextStyle(fontSize: 9.sp, color: Colors.grey[500])),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8.r),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.access_time_rounded, color: AppColors.primaryDark, size: 16.sp),
                                ),
                                SizedBox(width: 8.w),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Drop-off by', style: TextStyle(fontSize: 10.sp, color: Colors.grey[600])),
                                    Text(
                                      etaTimeStr,
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.sp, color: Colors.black87),
                                    ),
                                    Text('ETA', style: TextStyle(fontSize: 9.sp, color: Colors.grey[500])),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      // Reached Customer Location Main Swipe CTA Button
                      SizedBox(
                        width: double.infinity,
                        height: 60.h,
                        child: ElevatedButton(
                          onPressed: _isActionLoading
                              ? null
                              : () {
                                  HapticService.light();
                                  _reachDropoff(order);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            elevation: 4,
                            shadowColor: AppColors.primaryDark.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
                            padding: EdgeInsets.symmetric(horizontal: 14.w),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40.r,
                                height: 40.r,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.keyboard_double_arrow_right_rounded, color: AppColors.primaryDark, size: 24.sp),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Reached Customer Location',
                                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: Colors.white),
                                    ),
                                    Text(
                                      'Swipe right to continue',
                                      style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.8)),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Container(width: 3.w, height: 16.h, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(2.r))),
                                  SizedBox(width: 3.w),
                                  Container(width: 3.w, height: 16.h, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(2.r))),
                                  SizedBox(width: 3.w),
                                  Container(width: 3.w, height: 16.h, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2.r))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reachDropoff(DeliveryOrder order) async {
    await _runAction(
      () => ref.read(ordersControllerProvider.notifier).reachedDrop(order.id),
    );
  }
}

/// Full-screen swipeable viewer for a store's uploaded photos, opened
/// when the delivery partner taps the store's map marker or avatar.
class _RestaurantGalleryViewer extends StatefulWidget {
  const _RestaurantGalleryViewer({required this.images, required this.restaurantName});

  final List<String> images;
  final String restaurantName;

  @override
  State<_RestaurantGalleryViewer> createState() => _RestaurantGalleryViewerState();
}

class _RestaurantGalleryViewerState extends State<_RestaurantGalleryViewer> {
  final PageController _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.images[i],
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const CircularProgressIndicator(color: Colors.white),
                  errorWidget: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16.r),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16.sp),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 32.h,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    width: active ? 20.w : 6.w,
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dashHeight = 3.0;
    const dashSpace = 3.0;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Shown in place of the map until there is a real coordinate to centre on —
/// a GPS fix, the order's route destination, or the store/drop location.
///
/// The map previously fell back to a hardcoded Mumbai point, so a rider with
/// location off saw a confident, wrong map instead of a prompt to turn it on.
class _AwaitingLocationMap extends StatelessWidget {
  const _AwaitingLocationMap();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.mapPlaceholderDark
          : AppColors.mapPlaceholderDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_searching_rounded,
                  size: 40, color: Colors.white70),
              const SizedBox(height: 12),
              const Text(
                'Waiting for your location',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Turn on location to see the route to this order.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: Geolocator.openLocationSettings,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                child: const Text('Open location settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
