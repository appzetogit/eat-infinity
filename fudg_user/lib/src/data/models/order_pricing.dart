/// Server-computed bill from `POST /food/orders/calculate`.
///
/// Pricing is server-owned: never compute or adjust these numbers client-side.
/// The same object is echoed straight back into `POST /food/orders`.
class OrderPricing {
  final double subtotal;
  final double tax;
  final double packagingFee;
  final double deliveryFee;
  final double deliveryFeeGst;
  final double platformFee;
  final double quickDeliveryFee;
  final double discount;
  final double tip;
  final double total;

  /// Percentages behind [tax] and [deliveryFeeGst], for labelling bill rows.
  /// 0 when the server did not send them (older backend).
  final double gstRate;
  final double deliveryFeeGstRate;
  final String currency;
  final String deliveryMode;
  final String? couponCode;

  /// Null when a coupon was rejected — `couponCode` is echoed back either way,
  /// so this is the only reliable "did the discount land" signal.
  final Map<String, dynamic>? appliedCoupon;

  /// Stable machine reason a coupon was refused (`min-order`, `wrong-time`,
  /// `used-up`, …). Null when none was sent or the coupon applied.
  final String? couponErrorCode;

  /// Customer-facing refusal text, written by the server. Shown verbatim —
  /// the phone never composes its own wording for these.
  final String? couponErrorMessage;

  final double? roadDistanceKm;

  /// Verbatim server payload, echoed into order creation unchanged.
  final Map<String, dynamic> raw;

  const OrderPricing({
    required this.subtotal,
    required this.tax,
    required this.packagingFee,
    required this.deliveryFee,
    required this.deliveryFeeGst,
    required this.platformFee,
    required this.quickDeliveryFee,
    required this.discount,
    this.tip = 0,
    required this.total,
    this.gstRate = 0,
    this.deliveryFeeGstRate = 0,
    required this.currency,
    required this.deliveryMode,
    this.couponCode,
    this.appliedCoupon,
    this.couponErrorCode,
    this.couponErrorMessage,
    this.roadDistanceKm,
    this.raw = const {},
  });

  /// True once a coupon actually landed.
  ///
  /// Deliberately keyed off [appliedCoupon] alone: `couponCode` is echoed back
  /// for refused codes too, so reading it would call a rejected coupon applied.
  bool get hasCouponApplied => appliedCoupon != null;

  /// A code is attached but the server refused it. The code stays on the order
  /// so the customer can act on [couponErrorMessage] and re-qualify.
  bool get hasCouponError => couponErrorMessage != null;

  /// The pricing object to echo into `POST /food/orders`.
  ///
  /// `couponCode` is stripped unless the last preview actually applied it: the
  /// server re-prices on submit, and a code it already refused would refuse the
  /// whole order rather than just being ignored.
  Map<String, dynamic> get orderPayload =>
      hasCouponApplied ? raw : (Map<String, dynamic>.from(raw)..remove('couponCode'));

  static double _d(dynamic v) => _num(v) ?? 0.0;

  /// Prisma serializes `Decimal` columns as strings, so `as num?` silently
  /// returns null for "130" and would zero a real charge.
  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  factory OrderPricing.fromApi(Map<String, dynamic> json) {
    final appliedCoupon = (json['appliedCoupon'] as Map?)?.cast<String, dynamic>();
    final couponError = (json['couponError'] as Map?)?.cast<String, dynamic>();
    return OrderPricing(
      subtotal: _d(json['subtotal']),
      tax: _d(json['tax']),
      packagingFee: _d(json['packagingFee']),
      deliveryFee: _d(json['deliveryFee']),
      deliveryFeeGst: _d(json['deliveryFeeGst']),
      platformFee: _d(json['platformFee']),
      quickDeliveryFee: _d(json['quickDeliveryFee']),
      // Same discount, different key across backend responses — mirrors the
      // fallback chain OrderModel already uses for a placed order's pricing.
      discount: _d(
        json['discount'] ?? json['discountAmount'] ?? json['couponDiscount'],
      ),
      tip: _d(json['tipAmount'] ?? json['tip']),
      total: _d(json['total'] ?? json['finalAmount'] ?? json['totalPayable']),
      gstRate: _d(json['gstRate']),
      deliveryFeeGstRate: _d(json['deliveryFeeGstRate']),
      currency: (json['currency'] ?? 'INR').toString(),
      deliveryMode: (json['deliveryMode'] ?? 'basic').toString(),
      couponCode: (json['couponCode'] ?? appliedCoupon?['code'])?.toString(),
      appliedCoupon: appliedCoupon,
      couponErrorCode: couponError?['code']?.toString(),
      couponErrorMessage: couponError?['message']?.toString(),
      roadDistanceKm: _num(json['roadDistanceKm']),
      raw: json,
    );
  }
}

/// A menu price that moved between adding to cart and checking out.
///
/// Non-empty `priceChanges` must be confirmed by the user before the order is
/// submitted — that is the entire reason the backend returns it.
class PriceChange {
  final String itemId;
  final String name;
  final double previousPrice;
  final double price;

  const PriceChange({
    required this.itemId,
    required this.name,
    required this.previousPrice,
    required this.price,
  });

  factory PriceChange.fromApi(Map<String, dynamic> json) {
    return PriceChange(
      itemId: (json['itemId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      previousPrice: OrderPricing._d(json['previousPrice']),
      price: OrderPricing._d(json['price']),
    );
  }
}

/// Full `/calculate` result: authoritative items, price drift, and the bill.
class OrderCalculation {
  final List<Map<String, dynamic>> items;
  final List<PriceChange> priceChanges;
  final OrderPricing pricing;

  const OrderCalculation({
    required this.items,
    required this.priceChanges,
    required this.pricing,
  });

  bool get hasPriceChanges => priceChanges.isNotEmpty;

  factory OrderCalculation.fromApi(Map<String, dynamic> json) {
    return OrderCalculation(
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(),
      priceChanges: ((json['priceChanges'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => PriceChange.fromApi(e.cast<String, dynamic>()))
          .toList(),
      pricing: OrderPricing.fromApi(
        ((json['pricing'] as Map?) ?? const {}).cast<String, dynamic>(),
      ),
    );
  }
}
