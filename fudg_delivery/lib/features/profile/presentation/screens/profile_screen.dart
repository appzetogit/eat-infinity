import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:food_user_application/core/constants/app_constants.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/features/auth/application/auth_controller.dart';
import 'package:food_user_application/core/theme/app_colors.dart';
import 'package:food_user_application/core/theme/theme_mode_provider.dart';
import 'package:food_user_application/features/notifications/application/unread_notifications_controller.dart';
import 'package:food_user_application/features/profile/application/availability_controller.dart';
import 'package:food_user_application/features/wallet/data/wallet_repository.dart';
import 'package:food_user_application/features/auth/application/auth_state.dart';
import 'package:food_user_application/features/support/presentation/widgets/emergency_help_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  /// The stat strip used to read ₹1,248.00 wallet / ₹1,248.00 today over 28
  /// orders / ₹7,856.00 this week over 182 orders — none of it fetched.
  Map<String, dynamic> _wallet = const {};
  Map<String, dynamic> _today = const {};
  Map<String, dynamic> _week = const {};
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final repo = ref.read(walletRepositoryProvider);
    final wallet = await repo.getWallet();
    final today = await repo.getEarnings(period: 'today');
    final week = await repo.getEarnings(period: 'week');
    if (!mounted) return;
    setState(() {
      wallet.when(
        success: (d) => _wallet = d['wallet'] as Map<String, dynamic>? ?? d,
        failure: (_) {},
      );
      today.when(
        success: (d) => _today = d['summary'] as Map<String, dynamic>? ?? d,
        failure: (_) {},
      );
      week.when(
        success: (d) => _week = d['summary'] as Map<String, dynamic>? ?? d,
        failure: (_) {},
      );
      _loadingStats = false;
    });
  }

  double _num(Map<String, dynamic> src, String key) =>
      (src[key] as num?)?.toDouble() ?? 0;
  int _int(Map<String, dynamic> src, String key) =>
      (src[key] as num?)?.toInt() ?? 0;

  /// Em dash until the backend has answered — never a placeholder amount.
  String _money(double v) =>
      _loadingStats ? '—' : '₹${v.toStringAsFixed(2)}';

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Logout', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp)),
        content: const Text('Are you sure you want to log out from your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'Match device',
      };

  /// App Theme picker.
  ///
  /// `themeModeProvider` and both ThemeData variants already existed and
  /// main.dart consumed them — there was simply no control anywhere in the app
  /// to change the value, so the setting could never do anything.
  void _showThemeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 16.h),
            Text(
              'App Theme',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.of(ctx).textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            for (final entry in const [
              (ThemeMode.light, Icons.light_mode_outlined),
              (ThemeMode.dark, Icons.dark_mode_outlined),
              (ThemeMode.system, Icons.phone_android_rounded),
            ])
              Consumer(
                builder: (context, ref, _) {
                  final current = ref.watch(themeModeProvider);
                  final selected = current == entry.$1;
                  return ListTile(
                    leading: Icon(
                      entry.$2,
                      color: selected
                          ? AppColors.primaryDark
                          : AppColors.of(ctx).textSecondary,
                    ),
                    title: Text(
                      _themeLabel(entry.$1),
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w500,
                        color: AppColors.of(ctx).textPrimary,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primaryDark)
                        : null,
                    onTap: () {
                      HapticService.light();
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(entry.$1);
                      Navigator.of(ctx).pop();
                    },
                  );
                },
              ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.of(context).surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 12.h),
            ListTile(
              leading: const Icon(Icons.person_outline, color: AppColors.primaryDark),
              title: const Text('Driver Details'),
              onTap: () {
                Navigator.of(ctx).pop();
                context.push('/driver-details');
              },
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined, color: AppColors.primaryDark),
              title: const Text('Driver ID Card'),
              onTap: () {
                Navigator.of(ctx).pop();
                context.push('/driver-id-card');
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.brightness_6_outlined, color: AppColors.primaryDark),
              title: const Text('App Theme'),
              subtitle: Text(
                _themeLabel(ref.read(themeModeProvider)),
                style: TextStyle(fontSize: 11.5.sp),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _showThemeSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title:
                  const Text('Log Out', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmLogout();
              },
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final partner = authState is AuthAuthenticated ? authState.user : null;
    final isOnline = ref.watch(availabilityControllerProvider);
    final unreadCount = ref.watch(unreadNotificationsProvider);

    // No stand-in identity. These were 'Ali Khan', 4.9 stars from 512
    // ratings and driver id DP78562 for anyone whose profile hadn't loaded.
    final driverName =
        partner?.name.isNotEmpty == true ? partner!.name : 'Partner';
    final rating = (partner?.rating ?? 0) > 0
        ? partner!.rating!.toStringAsFixed(1)
        : '—';
    final totalRatings = partner?.totalRatings ?? 0;
    final driverId = (partner?.id.isNotEmpty ?? false)
        ? 'DP${partner!.id.substring(0, partner.id.length.clamp(0, 5)).toUpperCase()}'
        : '—';
    final profilePhoto = partner?.profilePhoto;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        // Clears MainScreen's bottom navigation bar; without it the last menu
        // row sat underneath it.
        padding: EdgeInsets.only(bottom: 24.h),
        child: Column(
          children: [
            // 1. Header & Hero Area (Dark Teal Background)
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 55.h),
                      child: Column(
                        children: [
                          // Top Right Settings & Notification Buttons Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(width: 40.w),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: _showSettingsSheet,
                                    child: Container(
                                      width: 38.r,
                                      height: 38.r,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.18),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.settings_outlined, color: Colors.white, size: 20.sp),
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  GestureDetector(
                                    onTap: () {
                                      HapticService.light();
                                      context.push('/notifications');
                                    },
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: 38.r,
                                          height: 38.r,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.18),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.notifications_none_rounded, color: Colors.white, size: 20.sp),
                                        ),
                                        // Real unread count, and no badge at
                                        // all when there is nothing to read.
                                        if (unreadCount > 0)
                                          Positioned(
                                            top: -2,
                                            right: -2,
                                            child: Container(
                                              padding: EdgeInsets.all(4.r),
                                              constraints: BoxConstraints(
                                                minWidth: 16.r,
                                                minHeight: 16.r,
                                              ),
                                              decoration: const BoxDecoration(
                                                color: AppColors.error,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  unreadCount > 99
                                                      ? '99+'
                                                      : '$unreadCount',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9.sp,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 10.h),

                          // Driver Photo & Info Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Circular Avatar with Camera Overlay
                              Stack(
                                children: [
                                  Container(
                                    width: 72.r,
                                    height: 72.r,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(36.r),
                                      child: profilePhoto != null && profilePhoto.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: AppConstants.resolveMediaUrl(profilePhoto),
                                              fit: BoxFit.cover,
                                              errorWidget: (_, _, _) => _buildAvatarPlaceholder(),
                                            )
                                          : _buildAvatarPlaceholder(),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: EdgeInsets.all(4.r),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: Icon(Icons.camera_alt_outlined, color: AppColors.primaryDark, size: 14.sp),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: 14.w),

                              // Name & Rating Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            driverName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 20.sp,
                                              color: Colors.white,
                                              height: 1.1,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(width: 6.w),
                                        Icon(Icons.verified_rounded, color: Colors.white, size: 18.sp),
                                      ],
                                    ),
                                    SizedBox(height: 3.h),
                                    Text(
                                      'Delivery Partner',
                                      style: TextStyle(
                                        fontSize: 12.5.sp,
                                        color: Colors.white.withValues(alpha: 0.85),
                                      ),
                                    ),
                                    SizedBox(height: 6.h),

                                    // Rating Pill
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(16.r),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.star_rounded, color: Colors.amber, size: 14.sp),
                                          SizedBox(width: 4.w),
                                          Text(
                                            '$rating ($totalRatings Ratings)',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11.sp,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Online Status Dropdown & Driver ID (Top Right)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  GestureDetector(
                                    // Was a local bool that flipped a colour
                                    // and told the rider they were online
                                    // without telling the backend anything.
                                    onTap: () async {
                                      HapticService.light();
                                      final result = await ref
                                          .read(availabilityControllerProvider
                                              .notifier)
                                          .toggle();
                                      if (!mounted) return;
                                      result.when(
                                        success: (_) => _showSnack(
                                            ref.read(availabilityControllerProvider)
                                                ? 'You are now Online'
                                                : 'You are now Offline'),
                                        failure: (e) => _showSnack(e.message),
                                      );
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(16.r),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8.r,
                                            height: 8.r,
                                            decoration: BoxDecoration(
                                              color: isOnline ? AppColors.online : Colors.grey[400],
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(width: 5.w),
                                          Text(
                                            isOnline ? 'Online' : 'Offline',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11.5.sp,
                                            ),
                                          ),
                                          SizedBox(width: 3.w),
                                          Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 16.sp),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  Text(
                                    'ID: $driverId',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Floating Financial Overview Card Overlay
                Positioned(
                  left: 16.w,
                  right: 16.w,
                  bottom: -45.h,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Column 1: Wallet Balance
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticService.light();
                              context.push('/earnings');
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Wallet Balance', style: TextStyle(fontSize: 10.5.sp, color: Colors.grey[600])),
                                SizedBox(height: 3.h),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _money(_num(_wallet, 'pocketBalance')),
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.sp, color: Colors.black87),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 16.sp),
                                  ],
                                ),
                                SizedBox(height: 3.h),
                                Text(
                                  'View Wallet',
                                  style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 10.5.sp),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(width: 1.w, height: 38.h, color: Colors.grey[200]),

                        // Column 2: Today's Earnings
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: 8.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.local_mall_outlined, color: AppColors.primaryDark, size: 12.sp),
                                    SizedBox(width: 3.w),
                                    Flexible(
                                      child: Text(
                                        "Today's Earnings",
                                        style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 3.h),
                                Text(
                                  _money(_num(_today, 'totalEarnings')),
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.sp, color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 3.h),
                                Text(
                                  '${_int(_today, 'totalOrders')} Orders',
                                  style: TextStyle(fontSize: 10.5.sp, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(width: 1.w, height: 38.h, color: Colors.grey[200]),

                        // Column 3: This Week
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: 8.w),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('This Week', style: TextStyle(fontSize: 10.5.sp, color: Colors.grey[600])),
                                    SizedBox(height: 3.h),
                                    Text(
                                      _money(_num(_week, 'totalEarnings')),
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.sp, color: Colors.black87),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 3.h),
                                    Text(
                                      '${_int(_week, 'totalOrders')} Orders',
                                      style: TextStyle(fontSize: 10.5.sp, color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                                // 3D Wallet Graphic Icon
                                Positioned(
                                  right: -4.w,
                                  top: -6.h,
                                  child: Container(
                                    width: 24.r,
                                    height: 24.r,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF5D67),
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    child: Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 14.sp),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 58.h),

            // Main List Content Body
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: [
                  // 4. Profile Menu Options List Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: Icons.person_outline_rounded,
                          title: 'Personal Information',
                          subtitle: 'Update your personal details',
                          onTap: () => context.push('/driver-details'),
                        ),
                        Divider(height: 1, color: Colors.grey[100], indent: 60.w),
                        _buildMenuItem(
                          icon: Icons.two_wheeler_rounded,
                          title: 'Vehicle Information',
                          subtitle: 'Update your vehicle details',
                          onTap: () =>
                              context.push('/driver-details', extra: 'vehicle'),
                        ),
                        Divider(height: 1, color: Colors.grey[100], indent: 60.w),
                        _buildMenuItem(
                          icon: Icons.badge_outlined,
                          title: 'Partner ID Card',
                          subtitle: 'View your digital partner ID',
                          onTap: () => context.push('/driver-id-card'),
                        ),
                        Divider(height: 1, color: Colors.grey[100], indent: 60.w),
                        _buildMenuItem(
                          icon: Icons.account_balance_outlined,
                          title: 'Bank Details',
                          subtitle: 'Manage bank account & payouts',
                          // Was a snackbar naming the feature; the real bank
                          // card and its edit dialog live on /driver-details.
                          onTap: () =>
                              context.push('/driver-details', extra: 'bank'),
                        ),
                        Divider(height: 1, color: Colors.grey[100], indent: 60.w),
                        _buildMenuItem(
                          icon: Icons.shield_outlined,
                          title: 'Insurance',
                          subtitle: 'View your insurance details',
                          // The insurance line is an admin-configured
                          // emergency contact, already fetched by this sheet.
                          onTap: () => showEmergencyHelpSheet(context, ref),
                        ),
                        Divider(height: 1, color: Colors.grey[100], indent: 60.w),
                        _buildMenuItem(
                          icon: Icons.percent_rounded,
                          title: 'Incentives',
                          subtitle: 'View ongoing offers and incentives',
                          onTap: () => context.push('/earnings'),
                        ),
                        Divider(height: 1, color: Colors.grey[100], indent: 60.w),
                        _buildMenuItem(
                          icon: Icons.military_tech_outlined,
                          title: 'Ratings & Feedback',
                          subtitle: 'See your ratings and feedback',
                          onTap: () => _showSnack(
                            (partner?.rating ?? 0) > 0
                                ? 'Your rating: ${partner!.rating!.toStringAsFixed(1)} '
                                    'from $totalRatings ratings'
                                : 'No ratings yet',
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 14.h),

                  // 5. Support Card ("Need Help?")
                  Container(
                    padding: EdgeInsets.all(14.r),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5ED),
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(color: Colors.orange[100]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF0E5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.headset_mic_outlined, color: const Color(0xFFE65100), size: 22.sp),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Need Help?',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.sp, color: Colors.black87),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Our support team is here to help you',
                                style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        OutlinedButton(
                          onPressed: () {
                            HapticService.light();
                            context.push('/help');
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE65100), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                            backgroundColor: Colors.white,
                          ),
                          child: Text(
                            'Contact Support',
                            style: TextStyle(
                              color: const Color(0xFFE65100),
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 14.h),

                  // 6. Logout Option Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: _buildMenuItem(
                      icon: Icons.logout_rounded,
                      iconBg: const Color(0xFFFFEBEE),
                      iconColor: Colors.redAccent,
                      title: 'Logout',
                      subtitle: 'Logout from your account',
                      onTap: _confirmLogout,
                    ),
                  ),

                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widget for Profile Menu Rows
  Widget _buildMenuItem({
    required IconData icon,
    Color iconBg = AppColors.primaryLight,
    Color iconColor = AppColors.primaryDark,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: () {
        HapticService.light();
        onTap();
      },
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
      leading: Container(
        padding: EdgeInsets.all(10.r),
        decoration: BoxDecoration(
          color: iconBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20.sp),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.sp, color: Colors.black87),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11.5.sp, color: Colors.grey[500]),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20.sp),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Icon(Icons.person, color: AppColors.primaryDark, size: 40.sp),
    );
  }
}
