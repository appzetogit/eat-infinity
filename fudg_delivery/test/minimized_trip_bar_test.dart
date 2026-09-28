import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/features/orders/application/active_trip_visibility_controller.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';
import 'package:food_user_application/features/orders/presentation/widgets/minimized_trip_bar.dart';

/// Backing out of the trip screen left the rider on the home tab with no route
/// back to a live delivery. The bar is the route back, so it has to render
/// inside main.dart's Stack and it has to re-show the trip.
void main() {
  final order = DeliveryOrder.fromJson({
    '_id': 'abc123',
    'order_id': 'FOD-1',
    'orderStatus': 'out_for_delivery',
    'deliveryState': {'currentPhase': 'en_route_to_delivery'},
    'restaurantId': {'restaurantName': 'Corner Mart'},
    'deliveryAddress': {'street': '12 MG Road', 'city': 'Indore'},
    'customerName': 'Meera',
    'items': const [],
    'pricing': {'total': 546},
    'payment': {'status': 'cod_pending'},
  });

  testWidgets('shows the live leg and restores the trip when tapped',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(activeTripVisibilityControllerProvider.notifier).hide();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            // A Stack, because MinimizedTripBar returns a Positioned straight
            // into main.dart's overlay stack.
            home: Stack(children: [MinimizedTripBar(order: order)]),
          ),
        ),
      ),
    );

    expect(find.text('On the way to customer'), findsOneWidget);
    expect(find.text('Meera'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pump();

    expect(container.read(activeTripVisibilityControllerProvider), isTrue);
  });
}
