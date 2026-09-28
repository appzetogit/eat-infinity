import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/src/data/models/restaurant_model.dart';

/// Distance has three distinct states and the card renders each differently:
/// a real distance, a genuine 0.0 km (you are standing at the restaurant), and
/// "the backend never computed one". Collapsing the last two is what made every
/// card read "0.0 km" when the listing was fetched without coordinates.
void main() {
  RestaurantModel parse(Map<String, dynamic> extra) => RestaurantModel.fromApi({
        'id': 'r1',
        'restaurantName': 'Test',
        ...extra,
      });

  test('a real distance is kept', () {
    expect(parse({'distanceInKm': 2.9}).distanceKm, 2.9);
  });

  test('a numeric string distance is parsed', () {
    expect(parse({'distanceInKm': '545.69'}).distanceKm, closeTo(545.69, 0.001));
  });

  test('a genuine zero survives as 0.0, not null', () {
    expect(parse({'distanceInKm': 0}).distanceKm, 0.0);
  });

  test('no distance fields at all stays null', () {
    expect(parse(const {}).distanceKm, isNull);
  });

  test('distanceMeters is converted only when present', () {
    expect(parse({'distanceMeters': 2900}).distanceKm, closeTo(2.9, 0.001));
  });
}
