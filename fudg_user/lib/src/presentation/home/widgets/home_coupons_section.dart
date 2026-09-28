import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/offer_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../common_widgets/smart_image.dart';
import '../../navigation/route_names.dart';
import '../../offers/viewmodels/offers_viewmodel.dart';

/// Horizontal list of live Coupons & Offers displayed directly below the category grid on Home.
class HomeCouponsSection extends ConsumerWidget {
  const HomeCouponsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final asyncOffers = ref.watch(offersProvider);

    return asyncOffers.when(
      data: (rawList) {
        if (rawList.isEmpty) return const SizedBox.shrink();

        final offers = rawList.map((e) => OfferModel.fromJson(e)).toList();
        if (offers.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 14.h),
            // Header Row: Title & View All
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.local_offer_rounded,
                          color: AppColors.primary,
                          size: 16.sp,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Coupons & Offers',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Haptics.light();
                      context.push(RouteNames.allOffers);
                    },
                    child: Row(
                      children: const [
                        Text(
                          'View All',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF64748B),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10.h),

            // Horizontal Scrollable Coupon Cards List. The height is the
            // card's 2:1 image plus its fixed text block, so nothing clips.
            SizedBox(
              height: _CouponCardTile.imageHeight + _CouponCardTile.bodyHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 2.w),
                itemCount: offers.length,
                separatorBuilder: (context, index) => SizedBox(width: 10.w),
                itemBuilder: (context, index) {
                  return _CouponCardTile(
                    offer: offers[index],
                    isDark: isDark,
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}

class _CouponCardTile extends StatelessWidget {
  const _CouponCardTile({
    required this.offer,
    required this.isDark,
  });

  final OfferModel offer;
  final bool isDark;

  /// The admin uploads coupon artwork at 2:1, so the image area is exactly
  /// 2:1 at full card width: BoxFit.cover then shows the whole image, with
  /// no crop and nothing drawn on top of it.
  static double get cardWidth => 260.w;
  static double get imageHeight => cardWidth / 2;
  static double get bodyHeight => 84.h;

  String get _headline {
    if (offer.title.isNotEmpty) return offer.title;
    return offer.discountType == 'percentage'
        ? '${offer.discountValue.toInt()}% OFF'
        : 'FLAT ₹${offer.discountValue.toInt()} OFF';
  }

  String get _condition {
    final expiry = offer.endDate != null
        ? ' · Till ${DateFormat('d MMM').format(offer.endDate!)}'
        : '';
    if (offer.minOrderValue > 0) {
      return 'On orders above ₹${offer.minOrderValue.toInt()}$expiry';
    }
    return offer.restaurantScope == 'all'
        ? 'Valid on all orders$expiry'
        : '${offer.restaurantName}$expiry';
  }

  void _copyCoupon(BuildContext context) {
    Haptics.light();
    Clipboard.setData(ClipboardData(text: offer.couponCode));
    AppSnackbar.success(
      context,
      'Coupon ${offer.couponCode} copied! Use it in your cart to save.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = offer.resolvedImageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleTextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return GestureDetector(
      onTap: () => _copyCoupon(context),
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Coupon image: full width, 2:1, nothing overlaid.
            SizedBox(
              height: imageHeight - 2, // minus the 1px border top and bottom
              child: hasImage
                  ? SmartImage(
                      url: imageUrl,
                      category: ImageCategory.restaurant,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : _FallbackArtwork(headline: _headline),
            ),

            // Text block: headline, condition, code pill and COPY.
            SizedBox(
              height: bodyHeight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 8.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleTextColor,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      _condition,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtitleTextColor,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        // Coupon Code Pill
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.confirmation_number_outlined,
                                  color: AppColors.primary,
                                  size: 12.sp,
                                ),
                                SizedBox(width: 4.w),
                                Flexible(
                                  child: Text(
                                    offer.couponCode,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),

                        // Copy Button — its own tap target as well as the card.
                        GestureDetector(
                          onTap: () => _copyCoupon(context),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              'COPY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown in the image area when a coupon has neither its own image nor a
/// restaurant photo, so the card keeps its shape instead of collapsing.
class _FallbackArtwork extends StatelessWidget {
  const _FallbackArtwork({required this.headline});

  final String headline;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.85),
            AppColors.primary,
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Icon(Icons.local_offer_rounded, color: Colors.white, size: 30.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              headline,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
