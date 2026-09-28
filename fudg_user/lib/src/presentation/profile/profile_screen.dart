import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/haptics.dart';
import '../auth/viewmodels/auth_viewmodel.dart';
import '../branding/app_colors.dart';
import '../../data/models/user_model.dart';
import '../common_widgets/app_snackbar.dart';
import '../common_widgets/smart_image.dart';
import '../orders/viewmodels/orders_viewmodel.dart';
import '../favorites/viewmodels/favorites_viewmodel.dart';
import '../referral/viewmodels/referral_viewmodel.dart';
import '../address/viewmodels/address_viewmodel.dart';
import '../wallet/viewmodels/wallet_state.dart';
import '../wallet/viewmodels/wallet_viewmodel.dart';
import '../navigation/route_names.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  /// Real wallet balance, or an em dash until it loads.
  String _walletBalanceLabel() {
    final w = ref.watch(walletViewModelProvider);
    if (w.status != WalletStatus.success) return '—';
    return '₹${w.wallet.balance.toStringAsFixed(0)}';
  }

  /// Signed-in customer, or null when the session has gone.
  UserModel? get _user => ref.watch(authViewModelProvider).value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final systemUiStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiStyle,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFFAFDFF),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header Bar: Title
            _buildTopHeader(context),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // 2. Main User Profile Card with Stats Row
                    _buildUserProfileCard(context),

                    const SizedBox(height: 20),

                    // 3. "My Account" Settings List Section
                    _buildMyAccountSection(context),

                    const SizedBox(height: 24),

                    // 5. Logout Button
                    _buildLogoutButton(context),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  /// 1. Top Header Row
  Widget _buildTopHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'My Profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),

        ],
      ),
    );
  }

  /// 2. Main User Profile Card with 4 Stats
  Widget _buildUserProfileCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
              children: [
                // Avatar Photo with Camera Badge (Tapping opens edit profile screen)
                GestureDetector(
                  onTap: () {
                    Haptics.light();
                    context.push(RouteNames.editProfile);
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE2E8F0),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipOval(
                          child: (_user?.avatarUrl ?? '').isNotEmpty
                              ? SmartImage(
                                  url: _user!.avatarUrl!,
                                  category: ImageCategory.brand,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.person_rounded, color: Color(0xFF64748B), size: 40),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: -2,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // Name and contact details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _user?.displayName ?? 'Guest',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (_user?.phone ?? '').isNotEmpty ? _user!.phone! : '',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _user?.email ?? '',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),

              ],
            ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 14),

          // 4-Column Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildProfileStatItem(
                icon: Icons.shopping_bag_outlined,
                iconColor: const Color(0xFF16A34A),
                value: () {
                  final o = ref.watch(ordersViewModelProvider);
                  return o.totalOrders > 0
                      ? '${o.totalOrders}'
                      : (o.orders.isNotEmpty ? '${o.orders.length}' : '—');
                }(),
                label: 'Orders',
                onTap: () => context.go(RouteNames.orders),
              ),
              _buildStatDivider(),
              _buildProfileStatItem(
                icon: Icons.favorite_border_rounded,
                iconColor: const Color(0xFFEF4444),
                value: () {
                  final f = ref.watch(favoritesViewModelProvider).value;
                  final n =
                      (f?.restaurantIds.length ?? 0) + (f?.foodIds.length ?? 0);
                  return n > 0 ? '$n' : '—';
                }(),
                label: 'Favourites',
                onTap: () => context.push(RouteNames.favorites),
              ),
              _buildStatDivider(),
              _buildProfileStatItem(
                icon: Icons.card_giftcard_rounded,
                iconColor: const Color(0xFF8B5CF6),
                value: () {
                  final w = ref.watch(walletViewModelProvider);
                  if (w.status != WalletStatus.success) return '—';
                  final r = w.wallet.referralEarnings;
                  return r > 0 ? r.toStringAsFixed(0) : '—';
                }(),
                label: 'Rewards',
                onTap: () => context.push(RouteNames.referral),
              ),
              _buildStatDivider(),
              _buildProfileStatItem(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFF0284C7),
                value: _walletBalanceLabel(),
                label: 'Wallet Balance',
                onTap: () => context.push(RouteNames.wallet),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        Haptics.light();
        onTap();
      },
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 28, color: const Color(0xFFE2E8F0));
  }

  Widget _buildMyAccountSection(BuildContext context) {
    final accountItems = [
      {
        'icon': Icons.person_outline_rounded,
        'title': 'Personal Information',
        'badge': null,
        'route': RouteNames.editProfile,
      },
      {
        'icon': Icons.location_on_outlined,
        'title': 'Addresses',
        'badge': () {
          final n = ref.watch(addressViewModelProvider).length;
          return n == 0 ? null : '$n Saved';
        }(),
        'onTap': () => _showSavedAddressesModal(context),
      },
      {
        'icon': Icons.credit_card_outlined,
        'title': 'Payment Methods',
        'badge': null,
        'onTap': () => _showPaymentMethodsModal(context),
      },
      {
        'icon': Icons.account_balance_wallet_outlined,
        'title': 'My Wallet',
        'badge': _walletBalanceLabel(),
        'route': RouteNames.wallet,
      },
      {
        'icon': Icons.card_giftcard_rounded,
        'title': 'Refer & Earn',
        'badge': () {
          final r = ref.watch(referralDetailsProvider).value;
          final amt = r?.rewardAmount ?? 0;
          return amt > 0 ? 'Earn ₹${amt.toStringAsFixed(0)}' : null;
        }(),
        'route': RouteNames.referral,
      },
      {
        'icon': Icons.notifications_none_rounded,
        'title': 'Notifications',
        'badge': null,
        'route': RouteNames.notifications,
      },
      {
        'icon': Icons.headset_mic_outlined,
        'title': 'Help & Support',
        'badge': null,
        'route': RouteNames.helpSupport,
      },
      {
        'icon': Icons.info_outline_rounded,
        'title': 'About Eatinfinity',
        'badge': null,
        'route': RouteNames.about,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Account',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: List.generate(accountItems.length, (index) {
              final item = accountItems[index];
              final isLast = index == accountItems.length - 1;

              return Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      Haptics.light();
                      final customTap = item['onTap'] as VoidCallback?;
                      if (customTap != null) {
                        customTap();
                      } else if (item['route'] != null) {
                        context.push(item['route'] as String);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFE6F7F5),
                            ),
                            child: Icon(item['icon'] as IconData, color: AppColors.primary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item['title'] as String,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            ),
                          ),
                          if (item['badge'] != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (item['badge'] as String).contains('Saved')
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFE6F7F5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item['badge'] as String,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: (item['badge'] as String).contains('Saved')
                                      ? const Color(0xFF16A34A)
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 18),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast) const Divider(color: Color(0xFFF1F5F9), height: 1, indent: 52),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  /// 4. Logout Button
  Widget _buildLogoutButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        Haptics.medium();
        await ref.read(authViewModelProvider.notifier).logout();
        if (!context.mounted) return;
        AppSnackbar.info(context, 'Logged out successfully');
        context.go(RouteNames.login);
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
            SizedBox(width: 8),
            Text(
              'Logout',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFEF4444)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentMethodsModal(BuildContext context) {
    Haptics.light();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE6F7F5),
                  ),
                  child: Icon(Icons.credit_card_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Payment Methods',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Fudg Wallet Option Tile
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                context.push(RouteNames.wallet);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Eatinfinity Wallet',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Balance: ${_walletBalanceLabel()}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Top Up',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Online Payments via Razorpay
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF16A34A), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'UPI / Credit & Debit Cards',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'GPay, PhonePe, Paytm, Cards & Net Banking via Razorpay',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Cash on Delivery
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, color: Color(0xFFD97706), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Cash on Delivery (COD)',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Pay cash at your doorstep upon delivery',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push(RouteNames.wallet);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text(
                  'Manage Wallet & Top Up',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSavedAddressesModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Consumer(
          builder: (context, ref, child) {
            final addresses = ref.watch(addressViewModelProvider);
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
            final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final secondaryColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final maxHeight = MediaQuery.of(context).size.height * 0.75;

            return Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Row: Title & Subtitle + Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saved Addresses',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            addresses.isEmpty
                                ? 'No saved addresses'
                                : '${addresses.length} saved ${addresses.length == 1 ? 'address' : 'addresses'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalContext),
                        icon: Icon(Icons.close_rounded, color: secondaryColor),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Saved Addresses List or Empty State
                  Flexible(
                    child: addresses.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.location_off_outlined,
                                      size: 36,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No Saved Addresses Yet',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Add an address for faster checkout & easy delivery.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: secondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: addresses.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final address = addresses[index];
                              final isDefault = address.isDefault;

                              IconData iconData = Icons.location_on_outlined;
                              final typeLower = (address.title.isNotEmpty ? address.title : address.type).toLowerCase();
                              if (typeLower.contains('home')) {
                                iconData = Icons.home_outlined;
                              } else if (typeLower.contains('office') || typeLower.contains('work')) {
                                iconData = Icons.business_outlined;
                              }

                              return InkWell(
                                onTap: () {
                                  Haptics.light();
                                  ref.read(addressViewModelProvider.notifier).setDefaultAddress(address.id);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDefault
                                          ? AppColors.primary
                                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                      width: isDefault ? 1.8 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDefault
                                              ? AppColors.primary.withValues(alpha: 0.12)
                                              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          iconData,
                                          size: 20,
                                          color: isDefault ? AppColors.primary : secondaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    address.title.isNotEmpty ? address.title : address.type,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w800,
                                                      color: textColor,
                                                    ),
                                                  ),
                                                ),
                                                if (isDefault) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFDCFCE7),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      'DEFAULT',
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w900,
                                                        color: Color(0xFF16A34A),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              address.fullAddress,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: secondaryColor,
                                                height: 1.3,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () {
                                          Haptics.light();
                                          ref.read(addressViewModelProvider.notifier).deleteAddress(address.id);
                                        },
                                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                                        splashRadius: 18,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Bottom Button: Add New Address
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Haptics.medium();
                        Navigator.pop(modalContext);
                        context.push(RouteNames.addAddress);
                      },
                      icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 20),
                      label: const Text(
                        'Add New Address',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
