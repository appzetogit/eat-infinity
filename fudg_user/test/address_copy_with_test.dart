import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/src/data/models/address_model.dart';

void main() {
  final address = AddressModel.fromApi(const {
    'id': 'a1',
    'label': 'Other',
    'street': '11/ 2A',
    'city': 'Indore',
    'state': 'Madhya Pradesh',
    'zipCode': '452001',
    'latitude': 22.7284956,
    'longitude': 75.8833497,
  });

  test('copyWith keeps the fields the order payload validates on', () {
    // setDefaultAddress rebuilds the whole list through copyWith. When it
    // dropped these, POST /food/orders answered "Street required".
    final flagged = address.copyWith(isDefault: true);

    expect(flagged.street, '11/ 2A');
    expect(flagged.city, 'Indore');
    expect(flagged.state, 'Madhya Pradesh');
    expect(flagged.zipCode, '452001');
    expect(flagged.latitude, 22.7284956);
    expect(flagged.longitude, 75.8833497);

    final payload = flagged.toOrderPayload();
    expect(payload['street'], isNotEmpty);
    expect(payload['city'], isNotEmpty);
    expect(payload['state'], isNotEmpty);
    expect(payload['location'], isNotNull);
  });
}
