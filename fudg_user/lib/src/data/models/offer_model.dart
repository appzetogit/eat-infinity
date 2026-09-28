import '../../core/config/api_config.dart';

/// Model representing a coupon/offer from `GET /food/restaurant/offers`.
class OfferModel {
  final String id;
  final String couponCode;
  final String title;
  final String discountType; // percentage | flat_price
  final double discountValue;
  final double? maxDiscount;
  final double minOrderValue;
  final String customerScope; // all | first_time | specific
  final bool isFirstOrderOnly;
  final String restaurantScope; // all | selected
  final List<String> restaurantIds;
  final String restaurantName;
  final String? restaurantSlug;
  final String? restaurantImage;
  final String imageUrl;
  final DateTime? endDate;
  final bool showInCart;

  const OfferModel({
    required this.id,
    required this.couponCode,
    required this.title,
    required this.discountType,
    required this.discountValue,
    this.maxDiscount,
    required this.minOrderValue,
    required this.customerScope,
    required this.isFirstOrderOnly,
    required this.restaurantScope,
    required this.restaurantIds,
    required this.restaurantName,
    this.restaurantSlug,
    this.restaurantImage,
    required this.imageUrl,
    this.endDate,
    this.showInCart = true,
  });

  factory OfferModel.fromJson(Map<String, dynamic> j) {
    // Check all possible JSON fields backend might return for coupon/offer image
    final imgUrl = (j['imageUrl'] ??
            j['image'] ??
            j['banner'] ??
            j['bannerUrl'] ??
            j['photo'] ??
            j['offerImage'] ??
            '')
        .toString()
        .trim();

    // Check all possible JSON fields for restaurant image fallback
    final restImg = (j['restaurantImage'] ??
            j['restaurant_image'] ??
            (j['restaurant'] is Map
                ? (j['restaurant']['image'] ??
                    j['restaurant']['imageUrl'] ??
                    j['restaurant']['logo'])
                : null) ??
            '')
        .toString()
        .trim();

    return OfferModel(
      id: (j['id'] ?? j['offerId'] ?? '').toString(),
      couponCode: (j['couponCode'] as String? ?? j['code'] as String? ?? '')
          .toUpperCase(),
      title: j['title'] as String? ?? j['headline'] as String? ?? '',
      discountType: j['discountType'] as String? ?? 'percentage',
      discountValue: (j['discountValue'] as num?)?.toDouble() ?? 0,
      maxDiscount: (j['maxDiscount'] as num?)?.toDouble(),
      minOrderValue: (j['minOrderValue'] as num?)?.toDouble() ?? 0,
      customerScope: j['customerScope'] as String? ?? 'all',
      isFirstOrderOnly: j['isFirstOrderOnly'] as bool? ?? false,
      restaurantScope: j['restaurantScope'] as String? ?? 'all',
      restaurantIds: (j['restaurantIds'] as List? ?? []).cast<String>(),
      restaurantName: j['restaurantName'] as String? ?? 'All Restaurants',
      restaurantSlug: j['restaurantSlug'] as String?,
      restaurantImage: restImg.isNotEmpty ? restImg : null,
      imageUrl: imgUrl,
      endDate: j['endDate'] == null
          ? null
          : DateTime.tryParse(j['endDate'] as String)?.toLocal(),
      showInCart: j['showInCart'] as bool? ?? true,
    );
  }

  /// Resolve card image URL (imageUrl -> restaurantImage -> null)
  String? get resolvedImageUrl {
    if (imageUrl.isNotEmpty) {
      final res = ApiConfig.resolveMedia(imageUrl);
      if (res.isNotEmpty) return res;
    }
    if (restaurantImage != null && restaurantImage!.isNotEmpty) {
      final res = ApiConfig.resolveMedia(restaurantImage);
      if (res.isNotEmpty) return res;
    }
    return null;
  }
}
