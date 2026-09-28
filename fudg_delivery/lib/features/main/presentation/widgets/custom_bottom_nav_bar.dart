import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/core/theme/app_colors.dart';
import 'package:food_user_application/features/notifications/application/unread_notifications_controller.dart';

class CustomBottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Was a fourth, darker teal (0xFF00897B) unrelated to the palette.
    const tealPrimary = AppColors.primaryDark;
    const unselectedColor = AppColors.lightTextSecondary;
    const borderColor = AppColors.lightBorder;
    final unread = ref.watch(unreadNotificationsProvider);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(top: 8.h, bottom: 6.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 1. Home
              Expanded(
                child: _buildNavItem(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  index: 0,
                  isActive: currentIndex == 0,
                  tealPrimary: tealPrimary,
                  unselectedColor: unselectedColor,
                ),
              ),

              // 2. Earnings
              Expanded(
                child: _buildNavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Earnings',
                  index: 1,
                  isActive: currentIndex == 1,
                  tealPrimary: tealPrimary,
                  unselectedColor: unselectedColor,
                ),
              ),

              // 3. Center Elevated "New Order" Button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticService.medium();
                    onTap(2);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44.w,
                        height: 44.w,
                        decoration: BoxDecoration(
                          color: tealPrimary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: tealPrimary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.shopping_bag_rounded,
                            color: Colors.white,
                            size: 22.sp,
                          ),
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        'New Order',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: currentIndex == 2 ? FontWeight.w700 : FontWeight.w500,
                          color: currentIndex == 2 ? tealPrimary : unselectedColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Notifications
              Expanded(
                child: _buildNavItem(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  index: 3,
                  isActive: currentIndex == 3,
                  tealPrimary: tealPrimary,
                  unselectedColor: unselectedColor,
                  badgeCount: unread,
                ),
              ),

              // 5. Profile
              Expanded(
                child: _buildNavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  index: 4,
                  isActive: currentIndex == 4,
                  tealPrimary: tealPrimary,
                  unselectedColor: unselectedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isActive,
    required Color tealPrimary,
    required Color unselectedColor,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: () {
        if (!isActive) HapticService.light();
        onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: isActive ? tealPrimary : unselectedColor,
                size: 24.sp,
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -3.h,
                  right: -6.w,
                  child: Container(
                    padding: EdgeInsets.all(2.r),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(
                      minWidth: 16.w,
                      minHeight: 16.w,
                    ),
                    child: Center(
                      child: Text(
                        '$badgeCount',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? tealPrimary : unselectedColor,
            ),
          ),
        ],
      ),
    );
  }
}

