import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/smart_image.dart';
import '../../../data/models/address_model.dart';
import '../../address/viewmodels/address_viewmodel.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/banners_viewmodel.dart';
import '../viewmodels/zone_viewmodel.dart';

class HomeHeaderBanner extends ConsumerStatefulWidget {
  const HomeHeaderBanner({super.key});

  @override
  ConsumerState<HomeHeaderBanner> createState() => _HomeHeaderBannerState();
}

class _HomeHeaderBannerState extends ConsumerState<HomeHeaderBanner> {
  AddressModel? get _deliveryAddress {
    final addresses = ref.watch(addressViewModelProvider);
    for (final a in addresses) {
      if (a.isDefault) return a;
    }
    return addresses.isNotEmpty ? addresses.last : null;
  }

  String _locationTitle() {
    final a = _deliveryAddress;
    if (a != null && a.title.isNotEmpty) return a.title;
    if (a != null && a.city.isNotEmpty) return a.city;
    final zone = ref.watch(zoneViewModelProvider).asData?.value;
    return zone?.name ?? 'Location';
  }

  String _locationSubtitle() {
    final a = _deliveryAddress;
    if (a != null && a.fullAddress.isNotEmpty) return a.fullAddress;
    final zone = ref.watch(zoneViewModelProvider).asData?.value;
    return zone != null ? '${zone.name} Area' : 'Select Location';
  }

  List<String> get _slideImages =>
      ref.watch(headerBannersProvider).value ?? const <String>[];

  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoRotation();
  }

  void _startAutoRotation() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      if (_pageController.hasClients && _slideImages.length > 1) {
        final next = (_currentPage + 1) % _slideImages.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final rowTop = topInset + 6.h;
    final headerHeight = topInset + 315.h;

    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
      child: SizedBox(
        width: double.infinity,
        height: headerHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Hero Image Carousel (Displaying only backend banner images)
            PageView.builder(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemCount: _slideImages.isEmpty ? 1 : _slideImages.length,
              itemBuilder: (context, index) {
                final imgUrl =
                    (_slideImages.isNotEmpty && index < _slideImages.length)
                    ? _slideImages[index]
                    : '';

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imgUrl.isNotEmpty) ...[
                      // A blurred, cover-cropped copy fills the header behind
                      // the artwork. The header is roughly square while the
                      // banners are 2048x768, so `cover` on its own would throw
                      // away most of the width — on artwork that carries its own
                      // text, that is the whole message. `contain` keeps the
                      // banner intact and this stands in for the space it cannot
                      // fill, which reads as depth rather than as empty bars.
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                        child: SmartImage(
                          url: imgUrl,
                          category: ImageCategory.food,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Center(
                        child: SmartImage(
                          url: imgUrl,
                          category: ImageCategory.food,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ] else
                      Container(color: AppColors.primary),
                    // Dark Vignette Overlay
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x80000000),
                            Color(0x22000000),
                            Color(0x77000000),
                          ],
                          stops: [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Top Header Row (Location Pin, "17/C", Bell & Avatar)
            Positioned(
              top: rowTop,
              left: 16.w,
              right: 16.w,
              height: 44.h,
              child: _buildTopRow(context),
            ),

            // Carousel Page Indicator Dots
            Positioned(
              bottom: 34.h,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slideImages.isEmpty ? 1 : _slideImages.length,
                  (i) => _dot(
                    i ==
                        (_currentPage %
                            (_slideImages.isEmpty ? 1 : _slideImages.length)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top Row: Red Pin, "17/C", "New Palasia, Indore >", Bell Notification, Profile Avatar
  Widget _buildTopRow(BuildContext context) {
    final user = ref.watch(authViewModelProvider).value;
    final avatarUrl = user?.avatarUrl ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Location Pin & Address (Tap to Add / Change Address)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Haptics.light();
              context.push(RouteNames.addAddress);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Suvio Primary Color Location Pin Icon
                Container(
                  padding: EdgeInsets.all(5.r),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 18.sp,
                  ),
                ),
                SizedBox(width: 8.w),

                // Location Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _locationTitle(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 3.w),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _locationSubtitle(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 14.sp,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // User Avatar Circle
        GestureDetector(
          onTap: () {
            Haptics.light();
            context.go(RouteNames.profile);
          },
          child: Container(
            width: 36.w,
            height: 36.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5.w),
            ),
            child: ClipOval(
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/images/user_avatar_3d.webp',
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset(
                      'assets/images/user_avatar_3d.webp',
                      fit: BoxFit.cover,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dot(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: 3.w),
      width: isActive ? 16.w : 6.w,
      height: 6.h,
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary
            : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3.r),
      ),
    );
  }
}
