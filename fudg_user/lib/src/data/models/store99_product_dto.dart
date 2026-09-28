import '../../domain/model/store99_product.dart';

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

/// Data Transfer Object for 99 Store product items.
class Store99ProductDto {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final String imageUrl;
  final double rating;
  final int ratingCount;
  final String deliveryTime;
  final bool isVeg;
  final String cuisineId;

  const Store99ProductDto({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.imageUrl,
    required this.rating,
    required this.ratingCount,
    required this.deliveryTime,
    required this.isVeg,
    required this.cuisineId,
  });

  factory Store99ProductDto.fromJson(Map<String, dynamic> json) {
    return Store99ProductDto(
      id: json['id'] as String,
      restaurantId: json['restaurantId'] as String,
      restaurantName: json['restaurantName'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: _numOrNull(json['price']) ?? 0.0,
      originalPrice: _numOrNull(json['originalPrice']),
      imageUrl: json['imageUrl'] as String,
      rating: _numOrNull(json['rating']) ?? 0.0,
      ratingCount: json['ratingCount'] as int? ?? 0,
      deliveryTime: json['deliveryTime'] as String? ?? '',
      isVeg: json['isVeg'] as bool? ?? false,
      cuisineId: json['cuisineId'] as String? ?? 'all',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'name': name,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'imageUrl': imageUrl,
      'rating': rating,
      'ratingCount': ratingCount,
      'deliveryTime': deliveryTime,
      'isVeg': isVeg,
      'cuisineId': cuisineId,
    };
  }

  Store99Product toDomain() {
    return Store99Product(
      id: id,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      name: name,
      description: description,
      price: price,
      originalPrice: originalPrice,
      imageUrl: imageUrl,
      rating: rating,
      ratingCount: ratingCount,
      deliveryTime: deliveryTime,
      isVeg: isVeg,
      cuisineId: cuisineId,
    );
  }
}
