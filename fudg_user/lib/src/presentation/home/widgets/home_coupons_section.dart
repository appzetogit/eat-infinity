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

            // Horizontal Scrollable Coupon Cards List
            SizedBox(
              height: 100.h,
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

    final formattedExpiry = offer.endDate != null
        ? DateFormat('d MMM').format(offer.endDate!)
        : null;

    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleTextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return GestureDetector(
      onTap: () => _copyCoupon(context),
      child: Container(
        width: 275.w,
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
        child: Padding(
          padding: EdgeInsets.all(10.r),
          child: Row(
            children: [
              // Left Content: Title, Subtitle, Code Badge & Copy Action
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title / Discount Headline
                        Text(
                          offer.title.isNotEmpty
                              ? offer.title
                              : (offer.discountType == 'percentage'
                                  ? '${offer.discountValue.toInt()}% OFF'
                                  : 'FLAT ₹${offer.discountValue.toInt()} OFF'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleTextColor,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2.h),

                        // Subtitle / Order Threshold & Expiry
                        Text(
                          offer.minOrderValue > 0
                              ? 'On orders above ₹${offer.minOrderValue.toInt()}${formattedExpiry != null ? ' · Till $formattedExpiry' : ''}'
                              : (offer.restaurantScope == 'all'
                                  ? 'Valid on all orders${formattedExpiry != null ? ' · Till $formattedExpiry' : ''}'
                                  : offer.restaurantName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: subtitleTextColor,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // Coupon Code Badge & Copy Button Row
                    Row(
                      children: [
                        // Coupon Code Pill
                        Container(
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
                              Text(
                                offer.couponCode,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),

                        // Copy Button Pill
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
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
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(width: 8.w),

              // Right Content: Clear Image Thumbnail Container
              Container(
                width: 76.w,
                height: 76.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  color:
                      isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasImage
                    ? SmartImage(
                        url: imageUrl,
                        category: ImageCategory.restaurant,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withValues(alpha: 0.15),
                              AppColors.primary.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.local_offer_rounded,
                            color: AppColors.primary,
                            size: 28.sp,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
