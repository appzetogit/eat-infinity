import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/core/services/socket_service.dart';
import 'package:food_user_application/features/feed/presentation/screens/feed_screen.dart';
import 'package:food_user_application/features/earnings/presentation/screens/earnings_screen.dart';
import 'package:food_user_application/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:food_user_application/features/profile/presentation/screens/profile_screen.dart';
import 'package:food_user_application/features/notifications/application/unread_notifications_controller.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'package:food_user_application/core/theme/app_colors.dart';

class MainTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

final mainTabIndexProvider = NotifierProvider<MainTabIndexNotifier, int>(
  MainTabIndexNotifier.new,
);

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  /// Index 2 is the raised "New Order" CTA, not a destination — offers arrive
  /// as a full-screen alert from IncomingOrderController, so there is no
  /// separate screen behind it. It used to hold a second FeedScreen, which
  /// meant tapping it showed Home while Home itself appeared unselected.
  /// [_resolveIndex] folds it back onto Home.
  static const _screens = [
    FeedScreen(),
    EarningsScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  /// Nav slot (0-4, with 2 as the CTA) to screen index (0-3).
  static int _resolveIndex(int navIndex) => switch (navIndex) {
        0 || 2 => 0,
        1 => 1,
        3 => 2,
        _ => 3,
      };

  Future<bool?> _showExitAppDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
        backgroundColor: isDarkMode ? AppColors.darkSurface : AppColors.lightSurface,
        elevation: 8,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Warning Icon
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: const BoxDecoration(
                  color: AppColors.errorBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  color: AppColors.error,
                  size: 32.sp,
                ),
              ),
              SizedBox(height: 16.h),

              // Title
              Text(
                'Exit App?',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20.sp,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: 8.h),

              // Description
              Text(
                'Are you sure you want to exit the delivery application?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  height: 1.4,
                ),
              ),
              SizedBox(height: 24.h),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48.h,
                      child: OutlinedButton(
                        onPressed: () {
                          HapticService.light();
                          Navigator.of(ctx).pop(false);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDarkMode ? Colors.white24 : Colors.grey[300]!,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: SizedBox(
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticService.medium();
                          Navigator.of(ctx).pop(true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Text(
                          'Exit',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                            color: Colors.white,
                          ),
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
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(mainTabIndexProvider);

    // An order called off elsewhere — by support from the admin panel, or by
    // the customer — must not leave the rider on a delivery screen for a job
    // that no longer exists. Send them back to the home tab with the server's
    // own message. Delivery screens are pushed above this shell, so the stack
    // is popped back to it first.
    ref.listen(orderStatusUpdateProvider, (previous, next) {
      final data = next.value;
      if (data == null) return;
      final status = (data['orderStatus'] ?? data['status'])?.toString() ?? '';
      if (!status.contains('cancel')) return;

      ref.read(mainTabIndexProvider.notifier).setIndex(0);
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              (data['message'] ?? 'This order has been cancelled').toString(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (currentIndex != 0) {
          // If on Wallet, History, or Profile screen, navigate directly back to Home/Orders tab
          HapticService.light();
          ref.read(mainTabIndexProvider.notifier).setIndex(0);
        } else {
          // If already on Home/Orders tab, show Exit App confirmation popup
          final shouldExit = await _showExitAppDialog(context);
          if (shouldExit == true) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _resolveIndex(currentIndex),
          children: _screens,
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: currentIndex,
          onTap: (index) {
            // The CTA is not its own destination; land on Home instead of
            // leaving the bar in a selected-but-empty state.
            ref
                .read(mainTabIndexProvider.notifier)
                .setIndex(index == 2 ? 0 : index);
            if (index == 3) {
              // Opening the inbox is what clears the badge.
              ref.read(unreadNotificationsProvider.notifier).refresh();
            }
          },
        ),
      ),
    );
  }
}
