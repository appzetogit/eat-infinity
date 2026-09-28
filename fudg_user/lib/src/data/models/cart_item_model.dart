import 'food_model.dart';
import 'food_variant.dart';

class CartItemModel {
  final String id;
  final FoodModel food;
  final int quantity;
  final String? selectedVariant;
  final double selectedVariantPrice;
  final List<String> selectedAddons;
  final double selectedAddonsPrice;
  final List<FoodAddon> selectedAddonDetails;
  final String? specialInstructions;

  const CartItemModel({
    required this.id,
    required this.food,
    this.quantity = 1,
    this.selectedVariant,
    this.selectedVariantPrice = 0.0,
    this.selectedAddons = const [],
    this.selectedAddonsPrice = 0.0,
    this.selectedAddonDetails = const [],
    this.specialInstructions,
  });

  double get unitPrice => food.price + selectedVariantPrice + selectedAddonsPrice;
  double get totalPrice => unitPrice * quantity;

  CartItemModel copyWith({
    String? id,
    FoodModel? food,
    int? quantity,
    String? selectedVariant,
    double? selectedVariantPrice,
    List<String>? selectedAddons,
    double? selectedAddonsPrice,
    List<FoodAddon>? selectedAddonDetails,
    String? specialInstructions,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      food: food ?? this.food,
      quantity: quantity ?? this.quantity,
      selectedVariant: selectedVariant ?? this.selectedVariant,
      selectedVariantPrice: selectedVariantPrice ?? this.selectedVariantPrice,
      selectedAddons: selectedAddons ?? this.selectedAddons,
      selectedAddonsPrice: selectedAddonsPrice ?? this.selectedAddonsPrice,
      selectedAddonDetails: selectedAddonDetails ?? this.selectedAddonDetails,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: (json['id'] ?? '').toString(),
      food: FoodModel.fromJson((json['food'] as Map).cast<String, dynamic>()),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      selectedVariant: json['selectedVariant'] as String?,
      selectedVariantPrice: (json['selectedVariantPrice'] as num?)?.toDouble() ?? 0.0,
      selectedAddons: (json['selectedAddons'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      selectedAddonsPrice: (json['selectedAddonsPrice'] as num?)?.toDouble() ?? 0.0,
      selectedAddonDetails: (json['selectedAddonDetails'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) => FoodAddon.fromJson(e.cast<String, dynamic>()))
              .toList() ??
          const [],
      specialInstructions: json['specialInstructions'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'food': food.toJson(),
      'quantity': quantity,
      'selectedVariant': selectedVariant,
      'selectedVariantPrice': selectedVariantPrice,
      'selectedAddons': selectedAddons,
      'selectedAddonsPrice': selectedAddonsPrice,
      'selectedAddonDetails': selectedAddonDetails.map((a) => a.toJson()).toList(),
      'specialInstructions': specialInstructions,
    };
  }
}

