import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/core/theme/app_colors.dart';
import 'package:food_user_application/features/orders/application/active_trip_visibility_controller.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';

/// Shown wherever the rider goes while a trip is minimized. Backing out of the
/// trip screen used to drop them on the home tab with no way back to the live
/// delivery — the only route back was a new push or restarting the app.
class MinimizedTripBar extends ConsumerWidget {
  const MinimizedTripBar({super.key, required this.order});

  final DeliveryOrder order;

  static String _label(DeliveryOrder order) => switch (order.currentPhase) {
        'at_pickup' => 'At the store',
        'en_route_to_delivery' => 'On the way to customer',
        'at_drop' => 'At the drop location',
        'delivered' || 'completed' => 'Delivery complete',
        _ => 'Heading to the store',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = order.isPickupPhase
        ? (order.store.name.isNotEmpty ? order.store.name : 'Pickup store')
        : (order.customerName.isNotEmpty ? order.customerName : 'Customer');

    return Positioned(
      left: 16.w,
      right: 16.w,
      // Clears the bottom nav bar, which is the screen the rider lands on.
      bottom: 74.h + MediaQuery.paddingOf(context).bottom,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: () {
            HapticService.light();
            ref.read(activeTripVisibilityControllerProvider.notifier).show();
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34.r,
                  height: 34.r,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delivery_dining_rounded,
                      color: Colors.white, size: 19.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _label(order),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.sp,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        destination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  'Resume',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.sp,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20.sp),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
