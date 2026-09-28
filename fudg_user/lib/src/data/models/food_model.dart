import '../../core/config/api_config.dart';
import 'food_variant.dart';

/// Tolerant numeric parse — this API serialises some Decimal columns as JSON
/// strings (`"price": "259"`), and a bare `as num?` cast throws on those,
/// which would blank the whole menu rather than one field.
double? _numOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

class FoodModel {
  final String id;
  final String restaurantId;
  /// Section this dish is filed under, used for the menu category rail.
  final String categoryName;
  /// That section's icon, restaurant-owned categories included — the only
  /// place a restaurant's own category images are exposed publicly.
  final String categoryImage;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final String imageUrl;
  final List<String> imageGallery;
  final double rating;
  final int reviewCount;
  final int calories;
  final String deliveryTime;
  final bool isVeg;
  final bool isSpicy;
  final bool isPopular;

  /// Size/portion choices. Empty when the item has a single price.
  final List<FoodVariant> variants;

  const FoodModel({
    required this.id,
    required this.restaurantId,
    this.categoryName = '',
    this.categoryImage = '',
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.imageUrl,
    this.imageGallery = const [],
    this.rating = 0.0,
    this.reviewCount = 0,
    this.calories = 0,
    this.deliveryTime = '',
    this.isVeg = false,
    this.isSpicy = false,
    this.isPopular = false,
    this.variants = const [],
  });

  /// "X% OFF" badge value, or null when there's no genuine [originalPrice] to
  /// compare against. Single source of truth so every badge agrees.
  int? get discountPercent {
    final original = originalPrice;
    if (original == null || original <= 0) return null;
    return (((1 - (price / original)) * 100).clamp(0, 99)).round();
  }

  /// Every image for the dish, primary first, as absolute URLs.
  ///
  /// Deduplicated because the backend keeps `image` as `images[0]`, so a naive
  /// merge of the two would repeat the primary and render a duplicate slide.
  static List<String> _galleryFrom(Map<String, dynamic> json) {
    final raw = <String?>[
      json['image'] as String?,
      ...((json['images'] as List<dynamic>?) ?? const [])
          .map((e) => e?.toString()),
    ];

    final seen = <String>{};
    final gallery = <String>[];
    for (final entry in raw) {
      if (entry == null || entry.trim().isEmpty) continue;
      final url = ApiConfig.resolveMedia(entry);
      if (url.isEmpty || !seen.add(url)) continue;
      gallery.add(url);
    }
    return gallery;
  }

  /// A compare-at price, or null when there is no genuine discount to show.
  ///
  /// The backend stores `otherPrice: 0` for dishes that were never given one,
  /// and 0 is not null — so it slipped through every `originalPrice != null`
  /// guard in the UI. The percent-off badges divide by it, and 1 - price/0 is
  /// Infinity, which `.toInt()` refuses: "Unsupported operation: Infinity or
  /// NaN toInt". That replaced the whole section with a red error box the
  /// moment a dish priced this way went live.
  ///
  /// Anything not strictly above the selling price is discarded here rather
  /// than at each call site, so the strikethrough and the badge can never
  /// disagree, and no future screen has to remember the rule.
  static double? _compareAtPrice(Object? raw, double price) {
    final value = _numOrNull(raw);
    if (value == null || !value.isFinite) return null;
    return value > price ? value : null;
  }

  /// Maps a backend food/menu item. Used by the cross-restaurant feed
  /// (`/public/foods`) and by each menu section's `items[]` — same shape.
  factory FoodModel.fromApi(
    Map<String, dynamic> json, {
    String? restaurantId,
    String? categoryImage,
  }) {
    final price = _numOrNull(json['price']) ?? 0.0;
    return FoodModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      restaurantId: (json['restaurantId'] ?? restaurantId ?? '').toString(),
      categoryName: (json['categoryName'] ?? json['category'] ?? '').toString(),
      categoryImage: ApiConfig.resolveMedia(
        (categoryImage ?? json['categoryImage'] as String?),
      ),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: price,
      originalPrice: _compareAtPrice(json['otherPrice'], price),
      imageUrl: ApiConfig.resolveMedia(json['image'] as String?),
      // The API sends `images` (primary first) for dishes with a gallery, and
      // only `image` for everything saved before galleries existed. Falling back
      // to the single image means the detail screen can always just read
      // imageGallery instead of special-casing the old shape.
      imageGallery: _galleryFrom(json),
      rating: _numOrNull(json['rating']) ?? 0.0,
      reviewCount: _numOrNull(json['totalRatings'])?.toInt() ?? 0,
      calories: _numOrNull(json['calories'])?.toInt() ?? 0,
      deliveryTime: (json['preparationTime'] ?? json['prepTime'] ?? json['deliveryTime'] ?? '').toString(),
      isVeg: (json['foodType']?.toString().toLowerCase() ?? '') == 'veg',
      isPopular: json['isRecommended'] as bool? ?? false,
      variants: FoodVariant.listFrom(json),
    );
  }

  factory FoodModel.fromJson(Map<String, dynamic> json) {
    return FoodModel(
      id: json['id'] as String,
      restaurantId: json['restaurantId'] as String,
      categoryName: json['categoryName'] as String? ?? '',
      categoryImage: json['categoryImage'] as String? ?? '',
      name: json['name'] as String,
      description: json['description'] as String,
      price: _numOrNull(json['price']) ?? 0.0,
      // Same rule as fromApi: a cached model must not resurrect a zero or
      // below-price compare-at value that the network path would have dropped.
      originalPrice: _compareAtPrice(
        json['originalPrice'],
        _numOrNull(json['price']) ?? 0.0,
      ),
      imageUrl: json['imageUrl'] as String,
      imageGallery: (json['imageGallery'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      rating: _numOrNull(json['rating']) ?? 0.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      calories: json['calories'] as int? ?? 0,
      deliveryTime: json['deliveryTime'] as String? ?? '',
      isVeg: json['isVeg'] as bool? ?? false,
      isSpicy: json['isSpicy'] as bool? ?? false,
      isPopular: json['isPopular'] as bool? ?? false,
      variants: FoodVariant.listFrom(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'categoryName': categoryName,
      'categoryImage': categoryImage,
      'name': name,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'imageUrl': imageUrl,
      'imageGallery': imageGallery,
      'rating': rating,
      'reviewCount': reviewCount,
      'calories': calories,
      'deliveryTime': deliveryTime,
      'isVeg': isVeg,
      'isSpicy': isSpicy,
      'isPopular': isPopular,
      'variants': variants.map((v) => v.toJson()).toList(),
    };
  }
}
