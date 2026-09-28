import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';
import 'package:food_user_application/features/orders/presentation/screens/incoming_order_screen.dart';
import 'package:food_user_application/features/orders/presentation/widgets/incoming_order_card.dart';

/// The incoming-order offer window and the all-strings FCM payload it arrives
/// in. Both are easy to get quietly wrong: a bad window opens the card at zero
/// (or counts down from a number unrelated to the real offer), and a missed key
/// alias shows the partner a blank address or a ₹0 earning on the one screen
/// they decide from.
void main() {
  group('offer window', () {
    test('uses the remaining time when the deadline is still ahead', () {
      final order = DeliveryOrder.fromRealtimePayload({
        'orderMongoId': 'o1',
        'acceptanceDeadlineAt':
            DateTime.now().add(const Duration(seconds: 18)).toIso8601String(),
      });
      // Allow a second of slack for the clock ticking during the call.
      expect(incomingOrderSecondsLeft(order), inInclusiveRange(16, 18));
    });

    test('falls back to the full window when the push arrived late', () {
      // A push held in Doze lands after its own deadline. Opening the card at
      // zero would expire it before the partner could read it.
      final order = DeliveryOrder.fromRealtimePayload({
        'orderMongoId': 'o1',
        'acceptanceDeadlineAt':
            DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
      });
      expect(incomingOrderSecondsLeft(order), kIncomingOrderWindowSeconds);
    });

    test('falls back to the full window when no deadline is sent', () {
      final order = DeliveryOrder.fromRealtimePayload({'orderMongoId': 'o1'});
      expect(incomingOrderSecondsLeft(order), kIncomingOrderWindowSeconds);
    });
  });

  group('FCM payload', () {
    // FCM rejects anything but strings in `data`, so every value arrives as one.
    final fcmData = <String, dynamic>{
      'type': 'new_order',
      // `orderId` carries the Mongo id on this wire; the readable code is
      // `orderDisplayId`. Both are present so the mapping can't quietly swap.
      'orderMongoId': '65f0aa1234bb5566cc7788dd',
      'orderId': '65f0aa1234bb5566cc7788dd',
      'orderDisplayId': 'AZ10567',
      'restaurantName': 'Appzeto Dark Store',
      'pickupAddress': 'New Palasia, Indore',
      'dropAddress': '17/C, New Palasia, Indore',
      'customerName': 'Rahul Sharma',
      'price': '52',
      'distance': '1.8',
      'total': '486',
      'paymentMethod': 'online',
      'paymentStatus': 'paid',
      'items': jsonEncode([
        {'name': 'Bananas', 'price': 60, 'quantity': 2, 'image': 'a.png'},
        {'name': 'Milk', 'price': 33, 'quantity': 1},
      ]),
    };

    final order = DeliveryOrder.fromRealtimePayload(fcmData);

    test('reads the addresses under their push spellings', () {
      expect(order.store.address, 'New Palasia, Indore');
      expect(order.deliveryAddress.fullAddress, '17/C, New Palasia, Indore');
    });

    test('shows the readable code, not the Mongo id, as the order reference',
        () {
      expect(order.orderCode, 'AZ10567');
      expect(order.id, '65f0aa1234bb5566cc7788dd');
    });

    test('reads the earning from `price`', () {
      expect(order.riderEarning, 52);
    });

    test('reads the trip distance from `distance`', () {
      expect(order.tripDistanceKm, 1.8);
    });

    test('parses the JSON-encoded item list', () {
      expect(order.items.length, 2);
      expect(order.totalUnits, 3);
      expect(order.items.first.image, 'a.png');
    });

    test('an online order is not treated as cash on delivery', () {
      expect(order.isCashOnDelivery, isFalse);
      expect(order.total, 486);
    });

    testWidgets('the card lays out on a small screen without overflowing',
        (tester) async {
      // 320x568 is the smallest phone the app has to survive. The card lives in
      // a scroll view in both hosts, so it must never be the thing that paints
      // outside its box.
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: IncomingOrderCard(
              order: order,
              secondsLeft: 12,
              totalSeconds: 20,
              busy: false,
              onAccept: () {},
              onReject: () {},
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('New Order!'), findsOneWidget);
      expect(find.text('Accept Order'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      // The figures the rider decides on, straight off the push: `price` is
      // the earning and `total` the order value. Neither may be a fallback.
      expect(find.text('₹52.00'), findsOneWidget);
      expect(find.text('₹486.00'), findsOneWidget);
      expect(find.text('Prepaid'), findsOneWidget);
    });
  });

  group('NewOrderPush', () {
    // Exactly the keys order-dispatch.service.js puts on the wire, all strings.
    Map<String, dynamic> push({Map<String, dynamic>? overrides}) => {
          'type': 'new_order',
          'orderId': '6a7dfbb1c8c7665b5b49beae',
          'orderMongoId': '6a7dfbb1c8c7665b5b49beae',
          'orderDisplayId': 'FOD-3293323386',
          'restaurantName': "Tanu's Store",
          'riderEarning': '52',
          'price': '52',
          'total': '54',
          'itemsCount': '1',
          ...?overrides,
        };

    test('takes the order id straight off the push', () {
      final parsed = NewOrderPush.parse(push())!;
      expect(parsed.orderId, '6a7dfbb1c8c7665b5b49beae');
      expect(parsed.displayId, 'FOD-3293323386');
      expect(parsed.earning, '52');
    });

    test('refuses a push with no order id rather than alerting on nothing', () {
      // Without an id there is nothing to accept, fetch or de-duplicate, so an
      // alert would strand the partner on a notification leading nowhere.
      expect(NewOrderPush.parse({'type': 'new_order'}), isNull);
      expect(NewOrderPush.parse({'type': 'new_order', 'orderId': ''}), isNull);
    });

    test('falls back to the id tail when the readable code is absent', () {
      final parsed =
          NewOrderPush.parse(push(overrides: {'orderDisplayId': ''}))!;
      expect(parsed.reference, '#49BEAE');
    });

    test('the notification body carries the real values, never a placeholder',
        () {
      final body = NewOrderPush.parse(push())!.notificationBody;
      expect(body, contains('Order FOD-3293323386'));
      expect(body, contains('₹52 earning'));
      expect(body, contains("Tanu's Store"));
      expect(body, contains('₹54 order'));
      expect(body, isNot(contains('AZ10567')));
      expect(body, isNot(contains('not arrived')));
    });

    test('the same order always maps to one notification id', () {
      final a = NewOrderPush.parse(push())!;
      final b = NewOrderPush.parse(push(overrides: {'price': '99'}))!;
      expect(
        incomingOrderNotificationId(a.orderId),
        incomingOrderNotificationId(b.orderId),
      );
    });
  });

  // The card used to substitute a sample order for any field the push left
  // out: "The Biryani House", "Ali Khan", a Mumbai address, ₹68.00 of
  // earnings, 2.4 km and 2 items. A rider decides in 20 seconds on exactly
  // these numbers, so an absent field has to read as absent.
  group('a sparse offer shows no invented order', () {
    testWidgets('renders placeholders, never sample values', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Only an id — every other field missing.
      final bare = DeliveryOrder.fromRealtimePayload({'orderMongoId': 'o404'});

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: IncomingOrderCard(
              order: bare,
              secondsLeft: 20,
              totalSeconds: 20,
              busy: false,
              onAccept: () {},
              onReject: () {},
            ),
          ),
        ),
      ));

      expect(tester.takeException(), isNull);

      for (final invented in const [
        'The Biryani House',
        'Ali Khan',
        '₹68.00',
        '2.4 km',
        '9 min',
        '2 Items',
        "Please ring the bell. Don't call.",
      ]) {
        expect(find.text(invented), findsNothing,
            reason: '\'$invented\' is sample data and must never render');
      }

      // Absent distance/ETA read as unknown rather than as a small trip.
      expect(find.text('—'), findsWidgets);
      // No customer instructions were sent, so that box is not built at all.
      expect(find.text('Special Instructions'), findsNothing);
    });
  });
}
