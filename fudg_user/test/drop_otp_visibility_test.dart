import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/src/data/models/order_model.dart';

/// The handover OTP card on the tracking screen renders on [showDropOtp]
/// alone. The digits never travel over REST with the order —
/// `sanitizeOrderForExternal` strips them and leaves only these two booleans,
/// so the card has to key off them and fetch the code separately.
void main() {
  Map<String, dynamic> orderJson(Map<String, dynamic> verification) => {
        'id': '40518e796d5650c684ff0033',
        'order_id': 'FOD-3271069228',
        'orderStatus': 'out_for_delivery',
        'restaurantId': {'id': 'r1', 'name': 'Corner Mart'},
        'items': const [],
        'pricing': {'total': '274'},
        'deliveryVerification': verification,
      };

  test('the OTP is shown once the rider has the order and not yet verified', () {
    final order = OrderModel.fromApi(orderJson({
      'dropOtp': {'required': true, 'verified': false},
    }));
    expect(order.showDropOtp, isTrue);
  });

  test('the OTP disappears the moment the rider verifies it', () {
    final order = OrderModel.fromApi(orderJson({
      'dropOtp': {'required': true, 'verified': true},
    }));
    expect(order.showDropOtp, isFalse);
  });

  test('an order with no verification block shows nothing', () {
    final order = OrderModel.fromApi(orderJson(const {}));
    expect(order.showDropOtp, isFalse);
  });
}
