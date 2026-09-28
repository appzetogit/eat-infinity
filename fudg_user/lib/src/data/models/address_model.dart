/// Parses a number that the API may send as a string.
///
/// Prisma serializes `Decimal` columns as strings, so a bare `as num?` cast
/// throws (or silently nulls) on values like "4.5" and takes the whole parse
/// down with it.
double? _numOrNull(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

class AddressModel {
  final String id;
  final String title;
  final String fullAddress;
  final String type; // 'Home', 'Office', 'Other'
  final bool isDefault;
  final String? contactName;
  final String? contactPhone;

  // Backend fields — the order payload needs the raw parts and GeoJSON, while
  // the saved-address DTO takes flat latitude/longitude. The server converts.
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final double? latitude;
  final double? longitude;

  const AddressModel({
    required this.id,
    required this.title,
    required this.fullAddress,
    required this.type,
    this.isDefault = false,
    this.contactName,
    this.contactPhone,
    this.street = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.latitude,
    this.longitude,
  });

  /// Maps `GET/POST /food/user/addresses`. The response carries every
  /// coordinate representation at once (latitude/longitude, lat/lng, location).
  factory AddressModel.fromApi(Map<String, dynamic> json) {
    final parts = [
      json['street'],
      json['additionalDetails'],
      json['city'],
      json['state'],
      json['zipCode'],
    ].whereType<String>().where((e) => e.trim().isNotEmpty).toList();

    return AddressModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['label'] ?? 'Home').toString(),
      fullAddress: parts.join(', '),
      type: (json['label'] ?? 'Home').toString(),
      isDefault: json['isDefault'] as bool? ?? false,
      contactPhone: json['phone']?.toString(),
      street: (json['street'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      zipCode: (json['zipCode'] ?? '').toString(),
      latitude: _numOrNull(json['latitude']),
      longitude: _numOrNull(json['longitude']),
    );
  }

  /// Body for POST/PATCH /food/user/addresses (flat coordinates).
  Map<String, dynamic> toApiPayload() => {
        'label': type,
        'street': street,
        'city': city,
        'state': state,
        'zipCode': zipCode,
        'phone': ?contactPhone,
        'latitude': ?latitude,
        'longitude': ?longitude,
      };

  /// Body for the order payload's `address` (GeoJSON `[lng, lat]`).
  Map<String, dynamic> toOrderPayload({String? customerName}) => {
        'label': type,
        'name': ?customerName,
        'street': street,
        'city': city,
        'state': state,
        'zipCode': zipCode,
        'phone': ?contactPhone,
        if (latitude != null && longitude != null)
          'location': {
            'type': 'Point',
            'coordinates': [longitude, latitude],
          },
      };

  /// Every field, not just the display ones.
  ///
  /// This used to omit street/city/state/zipCode and the coordinates, so they
  /// silently reverted to their `''`/null defaults. `setDefaultAddress` rebuilds
  /// the whole list through here, so one tap on "Change address" emptied the
  /// street on every saved address and the next `POST /food/orders` came back
  /// "Street required" — with the address still reading correctly on screen,
  /// because `fullAddress` survived.
  AddressModel copyWith({
    String? id,
    String? title,
    String? fullAddress,
    String? type,
    bool? isDefault,
    String? contactName,
    String? contactPhone,
    String? street,
    String? city,
    String? state,
    String? zipCode,
    double? latitude,
    double? longitude,
  }) {
    return AddressModel(
      id: id ?? this.id,
      title: title ?? this.title,
      fullAddress: fullAddress ?? this.fullAddress,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
