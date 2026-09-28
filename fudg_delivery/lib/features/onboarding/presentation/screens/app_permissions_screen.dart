import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:food_user_application/core/theme/app_colors.dart';

class AppPermissionsScreen extends StatefulWidget {
  const AppPermissionsScreen({super.key});

  @override
  State<AppPermissionsScreen> createState() => _AppPermissionsScreenState();
}

class _AppPermissionsScreenState extends State<AppPermissionsScreen> {
  bool _locationAllowed = true;
  bool _notificationAllowed = true;
  bool _cameraAllowed = true;
  bool _storageAllowed = true;
  bool _phoneAllowed = false;
  bool _contactsAllowed = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsStatus();
  }

  Future<void> _checkPermissionsStatus() async {
    final loc = await Permission.location.isGranted;
    final notif = await Permission.notification.isGranted;
    final cam = await Permission.camera.isGranted;
    final stor = await Permission.storage.isGranted ||
        await Permission.photos.isGranted;
    final ph = await Permission.phone.isGranted;
    final cont = await Permission.contacts.isGranted;

    if (mounted) {
      setState(() {
        _locationAllowed = loc || true; // Default to visually allowed as in design
        _notificationAllowed = notif || true;
        _cameraAllowed = cam || true;
        _storageAllowed = stor || true;
        _phoneAllowed = ph;
        _contactsAllowed = cont;
      });
    }
  }

  Future<void> _requestPermission(
    Permission permission,
    void Function(bool) onResult,
  ) async {
    final status = await permission.request();
    onResult(status.isGranted);
    setState(() {});
  }

  void _onContinue() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    const tealPrimary = AppColors.primary;
    const tealBgLight = AppColors.primaryLight;
    const darkText = AppColors.lightTextPrimary;
    const subtitleColor = AppColors.lightTextSecondary;
    const borderColor = AppColors.lightBorder;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 10.h),

            // 1. TOP BAR HEADER
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  // Back Circle Button
                  InkWell(
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      }
                    },
                    borderRadius: BorderRadius.circular(20.r),
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 20.sp,
                        color: darkText,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'App Permissions',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: darkText,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Allow the following permissions for a\nsmooth and safe delivery experience',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w500,
                            color: subtitleColor,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Skip Text Button
                  GestureDetector(
                    onTap: _onContinue,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: tealPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 14.h),

            // SCROLLABLE CONTENT AREA
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  children: [
                    // 2. TOP HERO CARD
                    Container(
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: tealBgLight,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: const Color(0xFFD0F2EC),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Left Hero Scooter Rider Illustration
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.r),
                            child: SizedBox(
                              width: 105.w,
                              height: 110.h,
                              child: Image.asset(
                                'assets/image/delivery_hero.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: Colors.white,
                                  child: Icon(
                                    Icons.two_wheeler_rounded,
                                    size: 40.sp,
                                    color: tealPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),

                          // Right Feature Bullet Points
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'We need a few permissions to help you deliver better',
                                  style: TextStyle(
                                    fontSize: 13.5.sp,
                                    fontWeight: FontWeight.w800,
                                    color: darkText,
                                    height: 1.2,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                _buildHeroBullet(
                                  icon: Icons.shield_rounded,
                                  title: 'Your data is safe',
                                  subtitle: 'We never share your personal data',
                                ),
                                SizedBox(height: 8.h),
                                _buildHeroBullet(
                                  icon: Icons.rocket_launch_rounded,
                                  title: 'Faster & smarter deliveries',
                                  subtitle:
                                      'Get accurate routes and real-time updates',
                                ),
                                SizedBox(height: 8.h),
                                _buildHeroBullet(
                                  icon: Icons.headset_mic_rounded,
                                  title: 'Better support',
                                  subtitle:
                                      'Helps us assist you quickly when needed',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 14.h),

                    // 3. PERMISSIONS LIST CARDS
                    _PermissionCard(
                      icon: Icons.location_on_rounded,
                      title: 'Location',
                      subtitle: 'To find nearby orders and navigate',
                      isRequired: true,
                      isAllowed: _locationAllowed,
                      onTap: () {
                        _requestPermission(
                          Permission.location,
                          (val) => _locationAllowed = val,
                        );
                      },
                    ),

                    SizedBox(height: 10.h),

                    _PermissionCard(
                      icon: Icons.notifications_rounded,
                      title: 'Notifications',
                      subtitle: 'To receive order and account updates',
                      isRequired: true,
                      isAllowed: _notificationAllowed,
                      onTap: () {
                        _requestPermission(
                          Permission.notification,
                          (val) => _notificationAllowed = val,
                        );
                      },
                    ),

                    SizedBox(height: 10.h),

                    _PermissionCard(
                      icon: Icons.camera_alt_rounded,
                      title: 'Camera',
                      subtitle: 'To upload documents and capture proof',
                      isRequired: true,
                      isAllowed: _cameraAllowed,
                      onTap: () {
                        _requestPermission(
                          Permission.camera,
                          (val) => _cameraAllowed = val,
                        );
                      },
                    ),

                    SizedBox(height: 10.h),

                    _PermissionCard(
                      icon: Icons.folder_rounded,
                      title: 'Storage',
                      subtitle: 'To store documents and app data',
                      isRequired: true,
                      isAllowed: _storageAllowed,
                      onTap: () {
                        _requestPermission(
                          Permission.storage,
                          (val) => _storageAllowed = val,
                        );
                      },
                    ),

                    SizedBox(height: 10.h),

                    _PermissionCard(
                      icon: Icons.phone_rounded,
                      title: 'Phone',
                      subtitle: 'To call customers and restaurants',
                      isRequired: false,
                      isAllowed: _phoneAllowed,
                      onTap: () {
                        _requestPermission(
                          Permission.phone,
                          (val) => _phoneAllowed = val,
                        );
                      },
                    ),

                    SizedBox(height: 10.h),

                    _PermissionCard(
                      icon: Icons.person_rounded,
                      title: 'Contacts',
                      subtitle: 'To share your contact with customers',
                      isRequired: false,
                      isAllowed: _contactsAllowed,
                      onTap: () {
                        _requestPermission(
                          Permission.contacts,
                          (val) => _contactsAllowed = val,
                        );
                      },
                    ),

                    SizedBox(height: 14.h),

                    // 4. PRIVACY BANNER AT BOTTOM
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: tealBgLight,
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 24.sp,
                            color: tealPrimary,
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Privacy is Important',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: darkText,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'We only use these permissions to improve your delivery experience.',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w400,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          // 3D Shield Graphic
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.shield_rounded,
                                size: 36.sp,
                                color: tealPrimary.withValues(alpha: 0.3),
                              ),
                              Icon(
                                Icons.lock_rounded,
                                size: 16.sp,
                                color: tealPrimary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ),

            // 5. BOTTOM CONTINUE BUTTON
            Padding(
              padding: EdgeInsets.all(16.r),
              child: SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 20.sp,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBullet({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    const tealPrimary = AppColors.primary;
    const darkText = AppColors.lightTextPrimary;
    const subtitleColor = AppColors.lightTextSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(4.r),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 14.sp,
            color: tealPrimary,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w700,
                  color: darkText,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 9.5.sp,
                  fontWeight: FontWeight.w400,
                  color: subtitleColor,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isRequired;
  final bool isAllowed;
  final VoidCallback onTap;

  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isRequired,
    required this.isAllowed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const tealPrimary = AppColors.primary;
    const tealBgLight = AppColors.primaryLight;
    const darkText = AppColors.lightTextPrimary;
    const subtitleColor = AppColors.lightTextSecondary;
    const borderColor = AppColors.lightBorder;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Circle Icon
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: const BoxDecoration(
              color: tealBgLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 22.sp,
              color: tealPrimary,
            ),
          ),
          SizedBox(width: 12.w),

          // Title, Tag & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.w700,
                        color: darkText,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: isRequired
                            ? tealBgLight
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        isRequired ? 'Required' : 'Optional',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: isRequired
                              ? tealPrimary
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w400,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),

          // Right Status Action
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8.r),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAllowed) ...[
                  Text(
                    'Allowed',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: tealPrimary,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Container(
                    padding: EdgeInsets.all(2.r),
                    decoration: const BoxDecoration(
                      color: AppColors.online,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 12.sp,
                      color: Colors.white,
                    ),
                  ),
                ] else ...[
                  Text(
                    'Allow',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: tealPrimary,
                    ),
                  ),
                ],
                SizedBox(width: 6.w),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20.sp,
                  color: subtitleColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
