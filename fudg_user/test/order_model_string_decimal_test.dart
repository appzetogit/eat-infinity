import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/src/data/models/order_model.dart';

/// Prisma serializes every `Decimal` column as a JSON string, so a real
/// `GET /food/orders/:id` payload carries "274" and "4.5", not numbers. A bare
/// `as num?` cast threw on those and blanked the whole Order Details screen
/// with "Order details unavailable" — after the order had already been placed.
void main() {
  test('parses an order whose money and distance arrive as strings', () {
    final order = OrderModel.fromApi({
      'id': '40518e796d5650c684ff0033',
      'order_id': 'FOD-3271069228',
      'orderStatus': 'created',
      'restaurantId': {'id': 'r1', 'name': 'Suvio', 'rating': '4.5'},
      'items': [
        {'name': 'Cold Coffee with ice cream', 'price': '134', 'quantity': '1'},
      ],
      'pricing': {'total': '274', 'deliveryFee': '130', 'roadDistanceKm': '545.69'},
      'total': '274',
    });

    expect(order.orderNumber, 'FOD-3271069228');
    expect(order.restaurantRating, 4.5);
    expect(order.roadDistanceKm, closeTo(545.69, 0.001));
    expect(order.items.single.price, 134.0);
    expect(order.items.single.quantity, 1);
  });
}
