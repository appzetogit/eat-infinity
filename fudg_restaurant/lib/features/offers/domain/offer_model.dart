/// A restaurant's coupon, as `GET /food/restaurant/my-offers` returns it.
///
/// The server words and classifies each offer -- [headline], [conditions],
/// [state] -- so this screen says exactly what customers see and never works
/// out an offer's status from dates on the phone.
class OfferModel {
  OfferModel({
    required this.id,
    required this.couponCode,
    required this.discountType,
    required this.discountValue,
    required this.minOrderValue,
    required this.maxDiscount,
    required this.usageLimit,
    required this.perUserLimit,
    required this.usedCount,
    required this.isFirstOrderOnly,
    required this.customerScope,
    required this.newToRestaurantOnly,
    required this.activeDays,
    required this.activeFromTime,
    required this.activeToTime,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.state,
    required this.headline,
    required this.conditions,
    required this.results,
    required this.canDelete,
    required this.canChangeCode,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    // Stored in UTC; shown and edited as the restaurant's local calendar day.
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());
    String? asText(dynamic v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    final discountType = (json['discountType'] ?? 'percentage').toString();
    final usedCount = asNum(json['usedCount'])?.toInt() ?? 0;
    final status = (json['status'] ?? 'active').toString();

    return OfferModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      couponCode: (json['couponCode'] ?? '').toString(),
      discountType: discountType,
      discountValue: asNum(json['discountValue'])?.toDouble() ?? 0,
      minOrderValue: asNum(json['minOrderValue'])?.toDouble() ?? 0,
      maxDiscount: asNum(json['maxDiscount'])?.toDouble(),
      usageLimit: asNum(json['usageLimit'])?.toInt(),
      perUserLimit: asNum(json['perUserLimit'])?.toInt(),
      usedCount: usedCount,
      isFirstOrderOnly: json['isFirstOrderOnly'] == true,
      customerScope: (json['customerScope'] ?? 'all').toString(),
      newToRestaurantOnly: json['newToRestaurantOnly'] == true,
      activeDays: ((json['activeDays'] as List?) ?? const [])
          .map((d) => asNum(d)?.toInt())
          .whereType<int>()
          .toList(),
      activeFromTime: asText(json['activeFromTime']),
      activeToTime: asText(json['activeToTime']),
      startDate: parseDate(json['startDate']),
      endDate: parseDate(json['endDate']),
      status: status,
      // Older servers send no state; fall back to the stored status.
      state: asText(json['state']) ?? (status == 'active' ? 'live' : 'ended'),
      headline: asText(json['headline']) ?? '',
      conditions: ((json['conditions'] as List?) ?? const [])
          .map((c) => c.toString())
          .where((c) => c.isNotEmpty)
          .toList(),
      results: OfferResults.fromJson(
        (json['results'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      canDelete: json['canDelete'] is bool ? json['canDelete'] as bool : usedCount == 0,
      canChangeCode:
          json['canChangeCode'] is bool ? json['canChangeCode'] as bool : usedCount == 0,
    );
  }

  final String id;
  final String couponCode;

  /// `percentage` or `flat_price` (older data may say `flat-price`).
  final String discountType;
  final double discountValue;
  final double minOrderValue;
  final double? maxDiscount;
  final int? usageLimit;
  final int? perUserLimit;
  final int usedCount;
  final bool isFirstOrderOnly;
  final String customerScope;
  final bool newToRestaurantOnly;

  /// 0 = Sunday .. 6 = Saturday, India time. Empty means every day.
  final List<int> activeDays;

  /// "HH:mm", India time; both null means all day.
  final String? activeFromTime;
  final String? activeToTime;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;

  /// live | scheduled | paused | exhausted | expired | ended -- from the server.
  final String state;

  /// "50% OFF up to ₹100", worded by the server exactly as customers see it.
  final String headline;
  final List<String> conditions;
  final OfferResults results;

  /// A used coupon cannot be deleted (it is ended instead, keeping its results)
  /// and its code cannot change.
  final bool canDelete;
  final bool canChangeCode;

  bool get isPercentage => discountType == 'percentage';

  /// Still running, as opposed to finished for good.
  bool get isRunning => state == 'live' || state == 'scheduled' || state == 'paused';

  bool get canPause => state == 'live' || state == 'scheduled';
  bool get canResume => state == 'paused';

  /// Who the coupon is for, as the form's single choice.
  CouponAudience get audience => newToRestaurantOnly
      ? CouponAudience.newToRestaurant
      : (customerScope == 'first_time' || customerScope == 'first-time' || isFirstOrderOnly)
          ? CouponAudience.firstOrder
          : CouponAudience.everyone;

  /// The headline, or a plain fallback from an older server.
  String get displayHeadline => headline.isNotEmpty
      ? headline
      : isPercentage
          ? '${discountValue.toStringAsFixed(0)}% OFF'
          : '₹${discountValue.toStringAsFixed(0)} OFF';
}

/// How an offer has done, from the server. Never computed on the phone.
class OfferResults {
  const OfferResults({
    this.orders = 0,
    this.customers = 0,
    this.discountGiven = 0,
    this.sales = 0,
  });

  factory OfferResults.fromJson(Map<String, dynamic> json) {
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());
    return OfferResults(
      orders: asNum(json['orders'])?.toInt() ?? 0,
      customers: asNum(json['customers'])?.toInt() ?? 0,
      discountGiven: asNum(json['discountGiven'])?.toDouble() ?? 0,
      sales: asNum(json['sales'])?.toDouble() ?? 0,
    );
  }

  final int orders;
  final int customers;
  final double discountGiven;
  final double sales;
}

enum CouponAudience { everyone, newToRestaurant, firstOrder }

/// What the create and edit form sends. One shape for both, so an edit can
/// never quietly send less than creating would.
class OfferDraft {
  const OfferDraft({
    required this.couponCode,
    required this.isPercentage,
    required this.discountValue,
    required this.maxDiscount,
    required this.minOrderValue,
    required this.usageLimit,
    required this.perUserLimit,
    required this.startDate,
    required this.endDate,
    required this.audience,
    required this.activeDays,
    required this.activeFromTime,
    required this.activeToTime,
  });

  final String couponCode;
  final bool isPercentage;
  final double discountValue;
  final double? maxDiscount;
  final double minOrderValue;
  final int? usageLimit;
  final int? perUserLimit;
  final DateTime? startDate;
  final DateTime endDate;
  final CouponAudience audience;
  final List<int> activeDays;
  final String? activeFromTime;
  final String? activeToTime;

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'couponCode': couponCode,
        'discountType': isPercentage ? 'percentage' : 'flat_price',
        'discountValue': discountValue,
        if (isPercentage) 'maxDiscount': maxDiscount,
        'minOrderValue': minOrderValue,
        // 0 clears a limit: the server stores it as "unlimited".
        'usageLimit': usageLimit ?? 0,
        'perUserLimit': perUserLimit ?? 0,
        // Calendar days, which the server reads as whole days in India.
        if (startDate != null) 'startDate': _day(startDate!),
        'endDate': _day(endDate),
        'customerScope': audience == CouponAudience.firstOrder ? 'first_time' : 'all',
        'newToRestaurantOnly': audience == CouponAudience.newToRestaurant,
        'activeDays': activeDays,
        // Empty strings clear a window on edit.
        'activeFromTime': activeFromTime ?? '',
        'activeToTime': activeToTime ?? '',
      };
}
