class FoodItemModel {
  FoodItemModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.description,
    required this.price,
    required this.otherPrice,
    required this.image,
    required this.foodType,
    required this.isAvailable,
    required this.isRecommended,
    required this.approvalStatus,
    required this.rejectionReason,
    required this.preparationTime,
  });

  factory FoodItemModel.fromJson(Map<String, dynamic> json) {
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());
    return FoodItemModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      categoryId: json['categoryId']?.toString(),
      categoryName: (json['categoryName'] ?? json['category'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: asNum(json['price'])?.toDouble() ?? 0,
      otherPrice: asNum(json['otherPrice'])?.toDouble() ?? 0,
      image: (json['image'] ?? '').toString(),
      foodType: (json['foodType'] ?? 'Non-Veg').toString(),
      isAvailable: json['isAvailable'] != false,
      isRecommended: json['isRecommended'] == true,
      approvalStatus: (json['approvalStatus'] ?? 'pending').toString(),
      rejectionReason: (json['rejectionReason'] ?? '').toString(),
      preparationTime: (json['preparationTime'] ?? '').toString(),
    );
  }

  final String id;
  final String? categoryId;
  final String categoryName;
  final String name;
  final String description;
  final double price;
  final double otherPrice;
  final String image;
  final String foodType; // Veg | Non-Veg
  final bool isAvailable;
  final bool isRecommended;
  final String approvalStatus; // pending | approved | rejected
  final String rejectionReason;
  final String preparationTime;

  bool get isVeg => foodType == 'Veg';
  bool get isPending => approvalStatus == 'pending';
  bool get isApproved => approvalStatus == 'approved';
}
