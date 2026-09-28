import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';

/// Parsing checks for the delivery-sanitized order payload.
///
/// The wire format still uses the pre-quick-commerce field names
/// (`restaurantId`, `menuImages`, `cookingNote`, `otherPrice`), so these guard
/// the mapping between those keys and the store/product model the UI reads.
void main() {
  Map<String, dynamic> orderJson({
    Map<String, dynamic>? store,
    List<Map<String, dynamic>>? items,
    Map<String, dynamic>? extra,
  }) => {
    '_id': 'abc123',
    'order_id': 'FOD-1',
    'orderStatus': 'ready_for_pickup',
    'deliveryState': {'currentPhase': 'at_pickup'},
    'restaurantId': store ?? {'restaurantName': 'Corner Mart'},
    'deliveryAddress': {'street': '12 MG Road', 'city': 'Indore'},
    'items': items ?? const [],
    'pricing': {'total': 546},
    'payment': {'status': 'cod_pending'},
    ...?extra,
  };

  group('OrderItem', () {
    test('reads the quick-commerce catalogue fields', () {
      final item = OrderItem.fromJson({
        'name': 'Toned Milk',
        'price': 32,
        'quantity': 3,
        'brand': 'Amul',
        'packSize': '500 ml',
        'otherPrice': 40,
        'gstRate': 5,
        'image': '/uploads/milk.webp',
        'addons': [
          {'name': 'Carry bag', 'price': 5},
        ],
      });

      expect(item.brand, 'Amul');
      expect(item.packSize, '500 ml');
      expect(item.gstRate, 5);
      expect(item.addons.single.name, 'Carry bag');
      expect(item.lineTotal, 96);
      expect(item.hasDiscount, isTrue);
      expect(item.subtitle, '500 ml · Amul');
    });

    test('blank strings become null rather than empty labels', () {
      final item = OrderItem.fromJson({
        'name': 'Rice',
        'price': 60,
        'quantity': 1,
        'brand': '',
        'packSize': '   ',
      });

      expect(item.brand, isNull);
      expect(item.packSize, isNull);
      expect(item.subtitle, isEmpty);
    });

    test('compare-at below the paid price is not a discount', () {
      final item = OrderItem.fromJson({
        'name': 'Sugar',
        'price': 50,
        'quantity': 1,
        'otherPrice': 45,
      });

      expect(item.hasDiscount, isFalse);
    });
  });

  group('DeliveryOrder', () {
    test('counts products and units separately', () {
      final order = DeliveryOrder.fromJson(
        orderJson(
          items: [
            {'name': 'Milk', 'price': 30, 'quantity': 2},
            {'name': 'Bread', 'price': 40, 'quantity': 1},
          ],
        ),
      );

      expect(order.productCount, 2);
      expect(order.totalUnits, 3);
      expect(order.itemsSummary, '2 products · 3 items');
    });

    test('collapses the summary when every product is a single unit', () {
      final order = DeliveryOrder.fromJson(
        orderJson(
          items: [
            {'name': 'Milk', 'price': 30, 'quantity': 1},
          ],
        ),
      );

      expect(order.itemsSummary, '1 product');
    });

    test('routes to the store before pickup and the customer after', () {
      final atPickup = DeliveryOrder.fromJson(orderJson());
      expect(atPickup.isPickupPhase, isTrue);
      expect(atPickup.routeTarget, 'restaurant'); // wire value is unchanged
      expect(atPickup.phaseIndex, 1);

      final enRoute = DeliveryOrder.fromJson(
        orderJson(
          extra: {
            'deliveryState': {'currentPhase': 'en_route_to_delivery'},
          },
        ),
      );
      expect(enRoute.isPickupPhase, isFalse);
      expect(enRoute.routeTarget, 'customer');
    });

    test('an unknown phase falls back to the first step, not -1', () {
      final order = DeliveryOrder.fromJson(
        orderJson(
          extra: {
            'deliveryState': {'currentPhase': 'something_new'},
          },
        ),
      );

      expect(order.phaseIndex, 0);
    });

    test('folds flattened seller fields onto the nested store', () {
      final order = DeliveryOrder.fromJson(
        orderJson(
          extra: {
            'restaurantLandmark': 'Near SBI ATM',
            'restaurantGalleryImages': ['/uploads/shopfront.webp'],
          },
        ),
      );

      expect(order.store.landmark, 'Near SBI ATM');
      expect(order.store.galleryImages, ['/uploads/shopfront.webp']);
    });

    test('an empty flattened array never wipes real nested media', () {
      final order = DeliveryOrder.fromJson(
        orderJson(
          store: {
            'restaurantName': 'Corner Mart',
            'galleryImages': ['/uploads/real.webp'],
          },
          extra: {'restaurantGalleryImages': <String>[]},
        ),
      );

      expect(order.store.galleryImages, ['/uploads/real.webp']);
    });

    test('note is the delivery instruction; cookingNote is the store note', () {
      final order = DeliveryOrder.fromJson(
        orderJson(
          extra: {'note': 'Ring the bell', 'cookingNote': 'Pack cold items last'},
        ),
      );

      expect(order.deliveryInstructions, 'Ring the bell');
      expect(order.storeNote, 'Pack cold items last');
    });

    test('store media falls back through premises, cover, catalogue, logo', () {
      final order = DeliveryOrder.fromJson(
        orderJson(
          store: {
            'restaurantName': 'Corner Mart',
            'menuImages': ['/uploads/shelf.webp'],
            'profileImage': '/uploads/logo.webp',
          },
        ),
      );

      expect(order.store.catalogImages, ['/uploads/shelf.webp']);
      expect(order.store.displayImage, '/uploads/shelf.webp');
      expect(order.store.allImages, [
        '/uploads/shelf.webp',
        '/uploads/logo.webp',
      ]);
    });

    test('a missing seller document does not throw', () {
      final json = orderJson()..['restaurantId'] = 'raw-object-id';
      final order = DeliveryOrder.fromJson(json);

      expect(order.store.name, isEmpty);
      expect(order.store.location, isNull);
    });

    test('order time comes off createdAt, not the acceptance deadline', () {
      // acceptanceDeadlineAt is nulled the moment the rider accepts, so the
      // trip screen's "Order Time" fell through to a hardcoded 09:35 AM.
      final order = DeliveryOrder.fromJson(orderJson(extra: {
        'createdAt': '2026-09-11T10:50:00.000Z',
        'acceptanceDeadlineAt': null,
        'deliveryState': {
          'currentPhase': 'delivered',
          'pickedUpAt': '2026-09-11T11:05:00.000Z',
          'deliveredAt': '2026-09-11T11:20:00.000Z',
        },
      }));

      expect(order.placedAt, DateTime.utc(2026, 9, 11, 10, 50).toLocal());
      expect(order.pickedUpAt, isNotNull);
      expect(order.deliveryDuration, const Duration(minutes: 30));
    });

    test('an order with no timestamps reports no duration', () {
      final order = DeliveryOrder.fromJson(orderJson());

      expect(order.placedAt, isNull);
      expect(order.deliveredAt, isNull);
      expect(order.deliveryDuration, isNull);
    });

    test('GeoPoint reads the stored [lng, lat] order', () {
      final point = GeoPoint.fromCoordinates([75.88, 22.72]);

      expect(point!.lng, 75.88);
      expect(point.lat, 22.72);
      expect(GeoPoint.fromCoordinates([75.88]), isNull);
      expect(GeoPoint.fromCoordinates(null), isNull);
    });
  });
}
