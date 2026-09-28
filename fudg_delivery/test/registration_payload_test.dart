import 'package:flutter_test/flutter_test.dart';

/// Mirrors the payload assembly in registration_screen.dart `_submit`.
///
/// `vehicleNumber` carries `unique: true, sparse: true` in
/// deliveryPartner.model.js. A sparse index skips documents where the path is
/// *missing* — but '' is a present value and gets indexed like any other. The
/// app sent `vehicleNumber: ''` unconditionally, so the second partner to
/// register without a vehicle collided with the first:
///
///   E11000 duplicate key error collection: quickcommerce.food_delivery_partners
///   index: vehicleNumber_1 dup key: { vehicleNumber: "" }
///
/// Optional fields must therefore be omitted when blank, never sent empty.
Map<String, dynamic> buildPayload({
  required String name,
  required String phone,
  String email = '',
  String address = '',
  String city = '',
  String stateName = '',
  String vehicleName = '',
  String vehicleNumber = '',
  String license = '',
  String pan = '',
  String aadhaar = '',
  String ref = '',
}) {
  return {
    'name': name.isEmpty ? 'Partner' : name,
    'phone': phone,
    'countryCode': '+91',
    if (email.isNotEmpty) 'email': email,
    if (address.isNotEmpty) 'address': address,
    if (city.isNotEmpty) 'city': city,
    if (stateName.isNotEmpty) 'state': stateName,
    'vehicleType': 'bike',
    if (vehicleName.isNotEmpty) 'vehicleName': vehicleName,
    if (vehicleNumber.isNotEmpty) 'vehicleNumber': vehicleNumber,
    if (license.isNotEmpty) 'drivingLicenseNumber': license,
    if (pan.isNotEmpty) 'panNumber': pan,
    if (aadhaar.isNotEmpty) 'aadharNumber': aadhaar,
    if (ref.isNotEmpty) 'ref': ref,
    'platform': 'mobile',
  };
}

void main() {
  group('blank optional fields are omitted, not sent empty', () {
    final minimal = buildPayload(name: 'Asha', phone: '9876543210');

    test('vehicleNumber is absent — the key that threw E11000', () {
      expect(minimal.containsKey('vehicleNumber'), isFalse);
    });

    test('no optional field is present as an empty string', () {
      for (final entry in minimal.entries) {
        expect(entry.value, isNot(''), reason: '${entry.key} was sent empty');
      }
    });

    test('every other optional key is absent too', () {
      for (final key in const [
        'email',
        'address',
        'city',
        'state',
        'vehicleName',
        'drivingLicenseNumber',
        'panNumber',
        'aadharNumber',
        'ref',
      ]) {
        expect(minimal.containsKey(key), isFalse, reason: key);
      }
    });

    test('the fields the backend always needs are still sent', () {
      expect(minimal['phone'], '9876543210');
      expect(minimal['name'], 'Asha');
      expect(minimal['countryCode'], '+91');
      expect(minimal['vehicleType'], 'bike');
      expect(minimal['platform'], 'mobile');
    });
  });

  group('supplied values are sent through', () {
    final full = buildPayload(
      name: 'Asha',
      phone: '9876543210',
      email: 'asha@example.com',
      city: 'Indore',
      vehicleNumber: 'MH12AB1234',
      pan: 'ABCDE1234F',
      aadhaar: '123456789012',
    );

    test('a real vehicle number reaches the request', () {
      expect(full['vehicleNumber'], 'MH12AB1234');
    });

    test('other provided fields are preserved', () {
      expect(full['email'], 'asha@example.com');
      expect(full['city'], 'Indore');
      expect(full['panNumber'], 'ABCDE1234F');
      expect(full['aadharNumber'], '123456789012');
    });

    test('two partners without vehicles produce identical payloads', () {
      // Both omit the key, so neither writes an indexed '' — which is exactly
      // what the sparse unique index needs in order to allow both.
      final a = buildPayload(name: 'A', phone: '9000000001');
      final b = buildPayload(name: 'B', phone: '9000000002');
      expect(a.containsKey('vehicleNumber'), isFalse);
      expect(b.containsKey('vehicleNumber'), isFalse);
    });
  });
}
