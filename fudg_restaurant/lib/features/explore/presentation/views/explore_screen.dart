import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_controller.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/config/theme/theme_mode_provider.dart';
import 'package:food_user_application/core/widgets/app_drawer.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          _buildBackgroundDecoration(context),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(context, ref),
                const SizedBox(height: 32),
                _buildSectionTitle(context, 'MANAGE OUTLET'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildVerticalCard(
                      context: context,
                      title: 'Outlet info',
                      subtitle: 'View and edit outlet\ninformation',
                      icon: Icons.info,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/outlet-info'),
                    ),
                    _buildVerticalCard(
                      context: context,
                      title: 'Outlet timings',
                      subtitle: 'Manage your outlet\nopening hours',
                      icon: Icons.access_time_filled,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/outlet-timings'),
                    ),
                    _buildVerticalCard(
                      context: context,
                      title: 'Menu categories',
                      subtitle: 'Add & manage\nmenu categories',
                      imageAsset: 'assets/image/menu.webp',
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/menu-categories'),
                    ),
                    _buildVerticalCard(
                      context: context,
                      title: 'Offers & Coupons',
                      subtitle: 'Create & manage offers\nand coupons',
                      imageAsset: 'assets/image/offer.webp',
                      iconBgColor: AppColors.primarySurface,
                      width: _getCardWidth(context, 3) * 1.6,
                      onTap: () => context.push('/offers'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildSectionTitle(context, 'SETTINGS'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildVerticalCard(
                      context: context,
                      title: 'Delivery settings',
                      subtitle: 'Manage delivery\npreferences',
                      imageAsset: 'assets/image/deliverysetting.webp',
                      iconBgColor: Colors.green.shade50,
                      iconColor: Colors.green.shade600,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/delivery-settings'),
                    ),
                    _buildVerticalCard(
                      context: context,
                      title: 'Zone Setup',
                      subtitle: 'Manage delivery\nzones & areas',
                      imageAsset: 'assets/image/zonesetup.webp',
                      iconBgColor: Colors.deepPurple.shade50,
                      iconColor: Colors.deepPurple.shade400,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/zone-setup'),
                    ),
                    _buildVerticalCard(
                      context: context,
                      title: 'Appearance',
                      subtitle: 'Theme settings\nLight & Dark',
                      icon: Icons.palette_outlined,
                      iconBgColor: Colors.teal.shade50,
                      iconColor: Colors.teal.shade600,
                      width: _getCardWidth(context, 3),
                      onTap: () => _showAppearanceSheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildSectionTitle(context, 'ORDERS'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildVerticalCard(
                      context: context,
                      title: 'Order history',
                      subtitle: 'View past orders',
                      icon: Icons.assignment,
                      iconColor: AppColors.primary,
                      iconBgColor: AppColors.primarySurface,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/order-history'),
                    ),
                    _buildVerticalCard(
                      context: context,
                      title: 'Complaints',
                      subtitle: 'Manage issues',
                      icon: Icons.chat_bubble,
                      iconColor: Colors.blue.shade600,
                      iconBgColor: Colors.blue.shade50,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/complaints'),
                    ),
                    _buildVerticalCard(
                      context: context,
                      title: 'Reviews',
                      subtitle: 'Customer reviews',
                      icon: Icons.star,
                      iconColor: Colors.pink.shade400,
                      iconBgColor: Colors.pink.shade50,
                      width: _getCardWidth(context, 3),
                      onTap: () =>
                          context.push('/complaints', extra: 'reviews'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildSectionTitle(context, 'HELP'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildVerticalCard(
                      context: context,
                      title: 'Support',
                      subtitle: 'Get help and support',
                      icon: Icons.support,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/support'),
                    ),
                    _buildVerticalCard(
                      context: context,
                      title: 'Feedback',
                      subtitle: 'Share your feedback',
                      icon: Icons.edit_note,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/feedback'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildSectionTitle(context, 'FINANCE'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildVerticalCard(
                      context: context,
                      title: 'Payout',
                      subtitle: 'View payout details',
                      icon: Icons.currency_rupee,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/payouts', extra: 'payouts'),
                    ),
                    _buildVerticalCard(
                      context: context,
                      title: 'Invoices',
                      subtitle: 'View your invoices',
                      icon: Icons.receipt_long,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/payouts', extra: 'invoices'),
                    ),
                    _buildVerticalCard(
                      context: context,
                      title: 'Bank details',
                      subtitle: 'Manage bank details',
                      icon: Icons.account_balance,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/bank-details'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildLogoutCard(context, ref),
                const SizedBox(height: 16),
                _buildDeleteAccountCard(context, ref),
                const SizedBox(height: 100), // padding for bottom nav
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAppearanceSheet(BuildContext context) {
    final theme = Theme.of(context);
    
    // In ConsumerWidget we can use ProviderScope.containerOf or just pass ref if we had it,
    // but context gives us what we need for ModalBottomSheet. We can use a Consumer widget inside.
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final currentMode = ref.watch(themeModeProvider);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appearance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAppearanceOption(
                    ref: ref,
                    sheetContext: sheetContext,
                    title: 'System Default',
                    icon: Icons.brightness_auto,
                    value: ThemeMode.system,
                    groupValue: currentMode,
                  ),
                  _buildAppearanceOption(
                    ref: ref,
                    sheetContext: sheetContext,
                    title: 'Light',
                    icon: Icons.light_mode,
                    value: ThemeMode.light,
                    groupValue: currentMode,
                  ),
                  _buildAppearanceOption(
                    ref: ref,
                    sheetContext: sheetContext,
                    title: 'Dark',
                    icon: Icons.dark_mode,
                    value: ThemeMode.dark,
                    groupValue: currentMode,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppearanceOption({
    required WidgetRef ref,
    required BuildContext sheetContext,
    required String title,
    required IconData icon,
    required ThemeMode value,
    required ThemeMode groupValue,
  }) {
    final isSelected = value == groupValue;
    final theme = Theme.of(sheetContext);
    
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primary : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : null,
        ),
      ),
      trailing: isSelected 
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : const Icon(Icons.circle_outlined, color: Colors.grey),
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(value);
        Navigator.pop(sheetContext);
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      centerTitle: false,
      leadingWidth: 70,
      leading: Center(
        child: Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/orders');
              }
            },
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          Text(
            'Manage your outlet & grow your business',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        Center(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
              onPressed: () => context.push('/order-history'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => context.push('/outlet-info'),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.person, size: 24, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(BuildContext context, WidgetRef ref) {
    final restaurantAsync = ref.watch(restaurantProfileControllerProvider);

    return GestureDetector(
      onTap: () => context.push('/outlet-info'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primarySurfaceStrong, AppColors.primarySurface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: restaurantAsync.value?.profileImage.isNotEmpty == true
                      ? CachedNetworkImage(
                          imageUrl: restaurantAsync.value!.profileImage,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.storefront,
                            color: Colors.white,
                            size: 32,
                          ),
                        )
                      : const Icon(
                          Icons.storefront,
                          color: Colors.white,
                          size: 32,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurantAsync.value?.restaurantName ?? '—',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade600,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Active',
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (restaurantAsync.value != null && restaurantAsync.value!.rating > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: AppColors.primary,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${restaurantAsync.value!.rating.toStringAsFixed(1)} (${restaurantAsync.value!.totalRatings})',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              restaurantAsync.value?.fullAddress.isNotEmpty ==
                                      true
                                  ? restaurantAsync.value!.fullAddress
                                  : 'Address not set yet',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 80), // Space for image
              ],
            ),
            Positioned(
              right: -20,
              bottom: -20,
              child: Image.asset(
                'assets/image/shopman.webp',
                width: 130,
                height: 130,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              right: 0,
              top: 20,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.black54,
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: -50,
              child: SizedBox(
                width: 32, // 3 columns of dots
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    12,
                    (index) => Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primaryBorder.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  double _getCardWidth(BuildContext context, int count) {
    final screenWidth = MediaQuery.of(context).size.width;
    return (screenWidth - 32 - (16 * (count - 1))) / count;
  }

  Widget _buildVerticalCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    IconData? icon,
    String? imageAsset,
    required double width,
    Color? iconBgColor,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageAsset != null)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor ?? AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Image.asset(
                    imageAsset,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor ?? AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? AppColors.primary,
                  size: 24,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 9,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (iconColor ?? AppColors.primary).withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              child: Icon(
                Icons.chevron_right,
                size: 14,
                color: iconColor ?? AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutCard(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Logout?'),
            content: const Text(
              'You will need to verify your phone number again to log back in.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await ref.read(authControllerProvider.notifier).logout();
        }
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.logout, color: Colors.red),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to sign out from this device',
                    style: TextStyle(
                      color: Colors.red.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.red.withValues(alpha: 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteAccountCard(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Account?'),
            content: const Text(
              'Are you sure you want to delete your account? This will permanently delete your restaurant profile, menu items, order history, and account data. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete Account',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          try {
            await ref.read(authControllerProvider.notifier).deleteAccount();
          } catch (e) {
            if (context.mounted) {
              final message = e is ApiException
                  ? e.message
                  : 'Failed to delete account. Please try again.';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        }
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.red),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delete Account',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Permanently delete your account',
                    style: TextStyle(
                      color: Colors.red.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.red.withValues(alpha: 0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundDecoration(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 350,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primarySurfaceStrong.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
          ),
        ),
        Positioned(
          top: 400,
          right: 20,
          child: SizedBox(
            width: 50,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(
                16,
                (index) => Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBorder.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
