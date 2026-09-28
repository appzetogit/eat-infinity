class OrderItemModel {
  OrderItemModel({
    required this.name,
    required this.variantName,
    required this.quantity,
    required this.price,
    required this.isVeg,
    required this.notes,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());
    return OrderItemModel(
      name: (json['name'] ?? '').toString(),
      variantName: (json['variantName'] ?? '').toString(),
      quantity: (asNum(json['quantity']) ?? 1).toInt(),
      price: asNum(json['price'])?.toDouble() ?? 0,
      isVeg: json['isVeg'] == true,
      notes: (json['notes'] ?? '').toString(),
    );
  }

  final String name;
  final String variantName;
  final int quantity;
  final double price;
  final bool isVeg;
  final String notes;
}

/// Drop-off address snapshot — captured on the order at checkout time, so it
/// stays correct even if the customer later edits/deletes the saved address.
class DeliveryAddressModel {
  DeliveryAddressModel({
    required this.label,
    required this.recipientName,
    required this.street,
    required this.additionalDetails,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.phone,
  });

  factory DeliveryAddressModel.fromJson(Map<String, dynamic> json) {
    return DeliveryAddressModel(
      label: (json['label'] ?? '').toString(),
      recipientName: (json['fullName'] ?? json['name'] ?? '').toString(),
      street: (json['street'] ?? '').toString(),
      additionalDetails: (json['additionalDetails'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      zipCode: (json['zipCode'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
    );
  }

  final String label;
  final String recipientName;
  final String street;
  final String additionalDetails;
  final String city;
  final String state;
  final String zipCode;
  final String phone;

  bool get isEmpty => street.isEmpty && city.isEmpty;

  String get fullAddress => [
    street,
    additionalDetails,
    city,
    state,
    zipCode,
  ].where((s) => s.isNotEmpty).join(', ');
}

/// Full fare breakdown — mirrors `pricingSchema` on the backend order model.
class OrderPricingModel {
  OrderPricingModel({
    required this.subtotal,
    required this.tax,
    required this.packagingFee,
    required this.deliveryFee,
    required this.platformFee,
    required this.discount,
    required this.couponCode,
    required this.total,
  });

  factory OrderPricingModel.fromJson(Map<String, dynamic> json) {
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());
    return OrderPricingModel(
      subtotal: asNum(json['subtotal'])?.toDouble() ?? 0,
      tax: asNum(json['tax'])?.toDouble() ?? 0,
      packagingFee: asNum(json['packagingFee'])?.toDouble() ?? 0,
      deliveryFee: asNum(json['deliveryFee'])?.toDouble() ?? 0,
      platformFee: asNum(json['platformFee'])?.toDouble() ?? 0,
      discount: asNum(json['discount'])?.toDouble() ?? 0,
      couponCode: (json['couponCode'] ?? '').toString(),
      total: asNum(json['total'])?.toDouble() ?? 0,
    );
  }

  final double subtotal;
  final double tax;
  final double packagingFee;
  final double deliveryFee;
  final double platformFee;
  final double discount;
  final String couponCode;
  final double total;
}

class OrderModel {
  OrderModel({
    required this.id,
    required this.displayId,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.deliveryAddress,
    required this.pricing,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
    required this.dispatchStatus,
    required this.riderName,
    required this.riderPhone,
    required this.riderRating,
    this.customerRating,
    this.customerRatingComment = '',
    required this.cancelledBy,
    required this.cancellationReason,
    required this.sendCutlery,
    required this.note,
    required this.deliveryInstructions,
    required this.acceptanceDeadlineAt,
    required this.createdAt,
    this.statusTimes = const {},
    this.distanceKm,
    this.durationMins,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());
    final user = json['userId'];
    final userMap = user is Map ? user : null;
    final pricing = Map<String, dynamic>.from((json['pricing'] ?? {}) as Map);
    final payment = Map<String, dynamic>.from((json['payment'] ?? {}) as Map);
    final dispatch = Map<String, dynamic>.from((json['dispatch'] ?? {}) as Map);
    final deliveryAddress = Map<String, dynamic>.from(
      (json['deliveryAddress'] ?? {}) as Map,
    );
    final rider = dispatch['deliveryPartnerId'];
    final riderMap = rider is Map ? rider : null;
    final deliveryState = Map<String, dynamic>.from(
      (json['deliveryState'] ?? {}) as Map,
    );
    DateTime? asDate(dynamic v) {
      final raw = v?.toString();
      return (raw == null || raw.isEmpty) ? null : DateTime.tryParse(raw);
    }

    // statusHistory is the authoritative per-step clock; deliveryState fills in
    // the delivery milestones that don't always produce a history row.
    final statusTimes = <String, DateTime>{};
    for (final h in (json['statusHistory'] as List? ?? const [])) {
      if (h is! Map) continue;
      final to = (h['to'] ?? '').toString();
      final at = asDate(h['at']);
      if (to.isEmpty || at == null) continue;
      statusTimes.putIfAbsent(to, () => at);
    }
    for (final entry in {
      'reached_pickup': deliveryState['reachedPickupAt'],
      'picked_up': deliveryState['pickedUpAt'],
      'reached_drop': deliveryState['reachedDropAt'],
      'delivered': deliveryState['deliveredAt'],
    }.entries) {
      final at = asDate(entry.value);
      if (at != null) statusTimes.putIfAbsent(entry.key, () => at);
    }

    final items = (json['items'] as List? ?? [])
        .map(
          (e) => OrderItemModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    return OrderModel(
      id: (json['_id'] ?? json['orderMongoId'] ?? '').toString(),
      displayId: (json['order_id'] ?? json['orderId'] ?? '').toString(),
      customerName: (json['customerName'] ?? userMap?['name'] ?? 'Customer')
          .toString(),
      customerPhone: (json['customerPhone'] ?? userMap?['phone'] ?? '')
          .toString(),
      items: items,
      deliveryAddress: DeliveryAddressModel.fromJson(deliveryAddress),
      pricing: OrderPricingModel.fromJson(pricing),
      total: asNum(pricing['total'])?.toDouble() ?? 0,
      paymentMethod: (payment['method'] ?? '').toString(),
      paymentStatus: (payment['status'] ?? '').toString(),
      orderStatus: (json['orderStatus'] ?? json['status'] ?? '').toString(),
      dispatchStatus: (dispatch['status'] ?? 'unassigned').toString(),
      statusTimes: statusTimes,
      distanceKm: asNum(pricing['roadDistanceKm'] ?? pricing['distanceKm'])
          ?.toDouble(),
      durationMins: asNum(pricing['roadDurationMins'])?.toInt(),
      riderName: (riderMap?['name'] ?? riderMap?['fullName'] ?? '').toString(),
      riderPhone: (riderMap?['phone'] ?? riderMap?['phoneNumber'] ?? '')
          .toString(),
      riderRating: riderMap != null
          ? asNum(riderMap['rating'])?.toDouble()
          : null,
      // What the customer scored THIS order, as opposed to riderRating, which
      // is the partner's lifetime average.
      customerRating: asNum(
        ((json['ratings'] as Map?)?['restaurant'] as Map?)?['rating'],
      )?.toDouble(),
      customerRatingComment:
          (((json['ratings'] as Map?)?['restaurant'] as Map?)?['comment'] ?? '')
              .toString(),
      cancelledBy: (json['cancelledBy'] ?? '').toString(),
      cancellationReason: (json['cancellationReason'] ?? '').toString(),
      sendCutlery: json['sendCutlery'] == true,
      note: (json['note'] ?? '').toString(),
      deliveryInstructions: (json['deliveryInstructions'] ?? '').toString(),
      acceptanceDeadlineAt: DateTime.tryParse(
        (json['acceptanceDeadlineAt'] ?? '').toString(),
      ),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String id;
  final String displayId;
  final String customerName;
  final String customerPhone;
  final List<OrderItemModel> items;
  final DeliveryAddressModel deliveryAddress;
  final OrderPricingModel pricing;
  final double total;
  final String paymentMethod;
  final String paymentStatus;
  final String orderStatus;
  final String dispatchStatus;
  final String riderName;
  final String riderPhone;
  final double? riderRating;

  /// The customer's rating of this order, once they have left one.
  final double? customerRating;
  final String customerRatingComment;

  final String cancelledBy;
  final String cancellationReason;
  final bool sendCutlery;
  final String note;
  final String deliveryInstructions;
  final DateTime? acceptanceDeadlineAt;
  final DateTime createdAt;

  /// Real per-status timestamps from the order's `statusHistory`, keyed by the
  /// status moved *to*. The timeline used to print `createdAt` against every
  /// step, so a 40-minute-old order looked like it was picked up instantly.
  final Map<String, DateTime> statusTimes;

  /// Trip distance/duration from `pricing`. Null when the backend hasn't
  /// computed them yet — the UI shows nothing rather than a made-up figure.
  final double? distanceKm;
  final int? durationMins;

  bool get isAllVeg => items.isNotEmpty && items.every((item) => item.isVeg);
  bool get isCancelled => orderStatus.startsWith('cancelled');
  bool get hasRider => riderName.isNotEmpty;

  /// Restaurant-facing lifecycle bucket — matches the 7 tabs on the Orders screen.
  String get restaurantBucket {
    if (isCancelled) return 'cancelled';
    switch (orderStatus) {
      case 'created':
      case 'confirmed':
        return 'new';
      case 'preparing':
        return 'preparing';
      case 'ready_for_pickup':
        return 'ready';
      case 'reached_pickup':
      case 'picked_up':
      case 'reached_drop':
        return 'out_for_delivery';
      case 'delivered':
        return 'completed';
      default:
        return 'other';
    }
  }
}
