import 'package:flutter/foundation.dart';
import '../../core/config/api_config.dart';

/// Tolerant numeric parse.
///
/// The API serialises some Decimal-backed columns as JSON strings — the
/// restaurant listing sends `"featuredPrice": "260"` — and a bare `as num?`
/// cast throws a TypeError on those. Because one bad field aborts the whole
/// `fromApi`, that single string was enough to blank the entire restaurant
/// list on Home. Accept both shapes instead.
double? _numOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

/// Only badges the card knows how to render. An unrecognised value from the
/// backend hides the pill rather than drawing an empty one.
const _kHighlightBadges = {'bestseller', 'popular'};

String? _highlightBadge(dynamic v) {
  final badge = v?.toString().trim().toLowerCase() ?? '';
  return _kHighlightBadges.contains(badge) ? badge : null;
}

class RestaurantModel {
  final String id;
  final String name;
  final String imageUrl;
  final List<String> coverImages;
  final List<String> menuImages;
  final double rating;
  final int reviewCount;
  final String deliveryTime;
  final double deliveryFee;
  final List<String> tags;
  final bool isFeatured;

  /// Distance to the customer, or null when the backend did not compute one.
  ///
  /// Nullable on purpose: a customer standing at the restaurant gets a real
  /// 0.0 km, and a non-null default of 0.0 made that indistinguishable from
  /// "no distance" — so the UI's `> 0` checks hid a correct value.
  final double? distanceKm;
  final double priceForOne;
  final String? featuredDishName;
  final bool isNearAndFast;
  final List<String> offerBadges;
  final List<String> restaurantTags;
  final bool isOpen;
  final String closingTime;
  final bool isPureVeg;
  final bool isFreeDelivery;
  final String area;

  /// Admin-set merchandising pill: 'bestseller', 'popular', or null for none.
  /// Was derived from the card's index in the list, so the same restaurant
  /// changed badge whenever the feed re-sorted.
  final String? highlightBadge;

  /// Subtotal at or above which this restaurant delivers free, or null when it
  /// has no such offer. The backend's pricing honours the same number.
  final double? freeDeliveryAbove;

  /// The restaurant's own logo (`profileImage`). Separate from [imageUrl],
  /// which falls back to a cover photo — the round brand badge wants the logo
  /// or nothing, not a photo of the storefront squeezed into 38px.
  final String logoUrl;

  const RestaurantModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.coverImages = const [],
    this.menuImages = const [],
    required this.rating,
    this.reviewCount = 0,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.tags,
    this.isFeatured = false,
    this.distanceKm,
    this.priceForOne = 0.0,
    this.featuredDishName,
    this.isNearAndFast = false,
    this.offerBadges = const [],
    this.restaurantTags = const [],
    this.isOpen = true,
    this.closingTime = '',
    this.isPureVeg = false,
    this.isFreeDelivery = false,
    this.area = '',
    this.highlightBadge,
    this.freeDeliveryAbove,
    this.logoUrl = '',
  });

  /// Extracts locality / area name from backend restaurant JSON.
  static String _extractLocationFromApi(Map<String, dynamic> json) {
    // 1. Direct String fields for area / locality / locationName
    final directKeys = [
      'area',
      'locality',
      'subLocality',
      'locationName',
      'areaName',
      'outletArea',
      'branchName',
      'neighborhood',
      'vicinity',
    ];

    for (final key in directKeys) {
      final val = json[key];
      if (val is String && val.trim().isNotEmpty) {
        return val.trim();
      }
    }

    // 2. Check if 'location' or 'address' is a Map object
    final mapsToCheck = <Map>[];
    if (json['location'] is Map) mapsToCheck.add(json['location'] as Map);
    if (json['address'] is Map) mapsToCheck.add(json['address'] as Map);

    for (final locMap in mapsToCheck) {
      final mapKeys = [
        'area',
        'locality',
        'subLocality',
        'locationName',
        'areaName',
        'name',
        'addressLine1',
        'street',
        'city',
      ];
      for (final key in mapKeys) {
        final val = locMap[key];
        if (val is String && val.trim().isNotEmpty) {
          return val.trim();
        }
      }
    }

    // 3. Fallback to raw address or location string (e.g. "Shop 12, Main Road, Vijay Nagar, Indore")
    String? rawAddress;
    if (json['address'] is String &&
        (json['address'] as String).trim().isNotEmpty) {
      rawAddress = (json['address'] as String).trim();
    } else if (json['location'] is String &&
        (json['location'] as String).trim().isNotEmpty) {
      rawAddress = (json['location'] as String).trim();
    } else if (json['addressLine1'] is String &&
        (json['addressLine1'] as String).trim().isNotEmpty) {
      rawAddress = (json['addressLine1'] as String).trim();
    } else if (json['city'] is String &&
        (json['city'] as String).trim().isNotEmpty) {
      rawAddress = (json['city'] as String).trim();
    }

    if (rawAddress != null && rawAddress.isNotEmpty) {
      final parts = rawAddress
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (parts.isNotEmpty) {
        if (parts.length == 1) {
          return parts.first;
        } else if (parts.length == 2) {
          return parts.first;
        } else {
          // If e.g. "Shop 101, Main Road, Vijay Nagar, Indore", pick second to last part ("Vijay Nagar")
          return parts[parts.length - 2];
        }
      }
    }

    return '';
  }

  /// Maps a backend restaurant document.
  factory RestaurantModel.fromApi(Map<String, dynamic> json) {
    final image = json['profileImage'];
    final imageUrlRaw = image is Map
        ? image['url'] as String?
        : image as String?;

    final coversRaw =
        (json['coverImages'] as List?)
            ?.map((e) => e is Map ? e['url'] as String? : e as String?)
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList() ??
        const [];

    final resolvedCovers = coversRaw
        .map((c) => ApiConfig.resolveMedia(c))
        .toList();

    final menusRaw =
        (json['menuImages'] as List?)
            ?.map((e) => e is Map ? e['url'] as String? : e as String?)
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList() ??
        const [];

    final resolvedMenuImages = menusRaw
        .map((c) => ApiConfig.resolveMedia(c))
        .toList();

    final primaryImageUrl = ApiConfig.resolveMedia(
      (imageUrlRaw != null && imageUrlRaw.isNotEmpty)
          ? imageUrlRaw
          : (resolvedCovers.isNotEmpty ? resolvedCovers.first : null),
    );

    final offers = <String>[];
    final offer = json['offer'];
    if (offer is String && offer.isNotEmpty) offers.add(offer);
    for (final o in (json['offers'] as List?) ?? const []) {
      if (o is Map && o['title'] is String) {
        offers.add(o['title'] as String);
      } else if (o is String && o.isNotEmpty) {
        offers.add(o);
      }
    }
    if (json['discountText'] is String &&
        (json['discountText'] as String).isNotEmpty) {
      offers.add(json['discountText'] as String);
    }

    final isPureVeg =
        json['pureVegRestaurant'] == true ||
        json['isVeg'] == true ||
        json['isPureVeg'] == true ||
        json['pureVeg'] == true ||
        json['veg'] == true ||
        json['isVegOnly'] == true ||
        (json['category']?.toString().toLowerCase().contains('veg') == true) ||
        (json['foodType']?.toString().toLowerCase() == 'veg');
    final isFreeDeliv =
        json['isFreeDelivery'] == true ||
        json['freeDelivery'] == true ||
        _numOrNull(json['deliveryFee']) == 0.0;
    final areaName = _extractLocationFromApi(json);

    final restId = (json['_id'] ?? json['id'] ?? json['restaurantId'] ?? '')
        .toString();
    final restName = (json['restaurantName'] ?? json['name'] ?? '').toString();

    if (kDebugMode) {
      debugPrint(
        '[RESTAURANT_LOCATION] ID: $restId | Name: $restName | Extracted Location: "$areaName"',
      );
    }

    final isOpen =
        json['isAcceptingOrders'] as bool? ?? json['isOpen'] as bool? ?? true;
    final closes =
        (json['closingTime'] ??
                json['closesIn'] ??
                json['operatingHours'] ??
                json['openingTime'] ??
                '')
            .toString();
    final featuredDishName =
        (json['featuredDish'] as String?)?.isNotEmpty == true
        ? json['featuredDish'] as String
        : null;

    final priceForOne =
        _numOrNull(json['featuredPrice']) ??
        _numOrNull(json['priceForOne']) ??
        _numOrNull(json['startingPrice']) ??
        _numOrNull(json['minOrder']) ??
        0.0;

    // The API sends `estimatedDeliveryTime` as a bare number ("30"), so the
    // branch that appends "mins" was never reached and every screen rendered a
    // unitless "30". Normalise here rather than at each call site.
    final rawDeliveryTime =
        (json['estimatedDeliveryTime'] ??
                json['deliveryTime'] ??
                json['estimatedDeliveryTimeMinutes'] ??
                '')
            .toString()
            .trim();
    final deliveryTimeStr = RegExp(r'^\d+$').hasMatch(rawDeliveryTime)
        ? '$rawDeliveryTime mins'
        : rawDeliveryTime;

    return RestaurantModel(
      id: restId,
      name: restName,
      imageUrl: primaryImageUrl,
      coverImages: resolvedCovers.isNotEmpty
          ? resolvedCovers
          : (primaryImageUrl.isNotEmpty ? [primaryImageUrl] : const []),
      menuImages: resolvedMenuImages,
      rating: _numOrNull(json['rating']) ?? 0.0,
      reviewCount:
          _numOrNull(json['totalRatings'])?.toInt() ??
          _numOrNull(json['reviewCount'])?.toInt() ??
          0,
      deliveryTime: deliveryTimeStr,
      deliveryFee: _numOrNull(json['deliveryFee']) ?? 0.0,
      tags:
          (json['cuisines'] as List?)?.whereType<String>().toList() ??
          (json['tags'] as List?)?.whereType<String>().toList() ??
          const [],
      isFeatured: json['isFeatured'] as bool? ?? false,
      // `?? 0` here would defeat the nullability: with neither field present
      // it produced a non-null 0.0, so every card claimed "0.0 km" whenever
      // the listing was fetched without lat/lng. Absent must stay null.
      distanceKm:
          _numOrNull(json['distanceInKm']) ??
          (() {
            final meters = _numOrNull(json['distanceMeters']);
            return meters == null ? null : meters / 1000;
          })(),
      priceForOne: priceForOne,
      featuredDishName: featuredDishName,
      isNearAndFast: json['isNearAndFast'] as bool? ?? false,
      offerBadges: offers,
      restaurantTags: [
        if (isPureVeg) 'Pure Veg',
        if (isFreeDeliv) 'Free Delivery',
        if (areaName.isNotEmpty) areaName,
      ],
      isOpen: isOpen,
      closingTime: closes,
      isPureVeg: isPureVeg,
      isFreeDelivery: isFreeDeliv,
      area: areaName,
      highlightBadge: _highlightBadge(json['highlightBadge']),
      freeDeliveryAbove: _numOrNull(json['freeDeliveryAbove']),
      logoUrl: ApiConfig.resolveMedia(imageUrlRaw),
    );
  }

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    final areaVal = json['area'] as String? ?? _extractLocationFromApi(json);
    return RestaurantModel(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String,
      coverImages:
          (json['coverImages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      menuImages:
          (json['menuImages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      rating: _numOrNull(json['rating']) ?? 0.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      deliveryTime: json['deliveryTime'] as String? ?? '',
      deliveryFee: _numOrNull(json['deliveryFee']) ?? 0.0,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      isFeatured: json['isFeatured'] as bool? ?? false,
      distanceKm: _numOrNull(json['distanceKm']),
      priceForOne: _numOrNull(json['priceForOne']) ?? 0.0,
      featuredDishName: json['featuredDishName'] as String?,
      isNearAndFast: json['isNearAndFast'] as bool? ?? false,
      offerBadges:
          (json['offerBadges'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      restaurantTags:
          (json['restaurantTags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isOpen: json['isOpen'] as bool? ?? true,
      closingTime: json['closingTime'] as String? ?? '',
      isPureVeg: json['isPureVeg'] as bool? ?? false,
      isFreeDelivery: json['isFreeDelivery'] as bool? ?? false,
      area: areaVal,
      highlightBadge: _highlightBadge(json['highlightBadge']),
      freeDeliveryAbove: _numOrNull(json['freeDeliveryAbove']),
      logoUrl: json['logoUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'coverImages': coverImages,
      'menuImages': menuImages,
      'rating': rating,
      'reviewCount': reviewCount,
      'deliveryTime': deliveryTime,
      'deliveryFee': deliveryFee,
      'tags': tags,
      'isFeatured': isFeatured,
      'distanceKm': distanceKm,
      'priceForOne': priceForOne,
      'featuredDishName': featuredDishName,
      'isNearAndFast': isNearAndFast,
      'offerBadges': offerBadges,
      'restaurantTags': restaurantTags,
      'isOpen': isOpen,
      'closingTime': closingTime,
      'isPureVeg': isPureVeg,
      'isFreeDelivery': isFreeDelivery,
      'area': area,
      'highlightBadge': highlightBadge,
      'freeDeliveryAbove': freeDeliveryAbove,
      'logoUrl': logoUrl,
    };
  }
}
