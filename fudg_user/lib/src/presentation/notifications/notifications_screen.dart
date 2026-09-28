import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/wallet_model.dart' show AppNotification;
import '../branding/app_colors.dart';
import '../navigation/route_names.dart';
import 'viewmodels/notification_inbox_viewmodel.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Orders, 2: Offers, 3: Account
  bool _showAlertBanner = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFFAFDFF),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header Row: Back Button, Title (Settings gear button removed)
            _buildTopHeader(context),

            const SizedBox(height: 8),

            // 2. Filter Category Pills with Dynamic Badges
            _buildFilterPills(),

            const SizedBox(height: 12),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 3. Real-time Alerts Permission Banner
                    if (_showAlertBanner) _buildAlertPermissionBanner(),

                    const SizedBox(height: 16),

                    // Real inbox: GET /food/notifications/inbox
                    _buildInboxList(context),

                    const SizedBox(height: 16),

                    _buildArchivedNotificationsCard(),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Real notification inbox, grouped by day. Tapping a card marks it read and
  /// follows the server-supplied deep link when there is one.
  Widget _buildInboxList(BuildContext context) {
    final state = ref.watch(notificationInboxProvider);

    if (state.isLoading && state.items.isEmpty) {
      return _buildInboxMessage(
        icon: Icons.notifications_none_rounded,
        title: 'Loading notifications…',
        subtitle: 'Checking for your latest updates and offers.',
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return _buildInboxMessage(
        icon: Icons.wifi_off_rounded,
        title: "Couldn't load notifications",
        subtitle: state.error!,
        actionLabel: 'Retry',
        onAction: () => ref.read(notificationInboxProvider.notifier).refresh(),
      );
    }

    // Filter items based on selected category pill
    List<AppNotification> displayItems = state.items;
    if (_selectedFilterIndex == 1) {
      displayItems = state.items.where((n) {
        final c = n.category.toLowerCase();
        return c == 'order' || c == 'delivery';
      }).toList();
    } else if (_selectedFilterIndex == 2) {
      displayItems = state.items.where((n) {
        final c = n.category.toLowerCase();
        return c == 'offer' || c == 'promotion' || c == 'cashback';
      }).toList();
    } else if (_selectedFilterIndex == 3) {
      displayItems = state.items.where((n) {
        final c = n.category.toLowerCase();
        return c == 'account' || c == 'wallet' || c == 'referral';
      }).toList();
    }

    if (displayItems.isEmpty) {
      final categoryLabels = ['All', 'Orders', 'Offers', 'Account'];
      final categoryName = categoryLabels[_selectedFilterIndex];
      return _buildInboxMessage(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications yet',
        subtitle: _selectedFilterIndex == 0
            ? "You're all caught up! Order updates, offers, and news will show up here."
            : "No $categoryName notifications found.",
      );
    }

    final groups = <String, List<AppNotification>>{};
    for (final n in displayItems) {
      groups.putIfAbsent(_dayLabel(n.createdAt), () => []).add(n);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          _buildSectionHeader(entry.key),
          const SizedBox(height: 10),
          for (final n in entry.value) ...[
            _buildNotificationCard(
              context,
              icon: _iconFor(n.category),
              iconBg: const Color(0xFFE6F7F5),
              iconColor: AppColors.primary,
              title: n.title,
              subtitle: n.message,
              time: _time(n.createdAt),
              isUnread: !n.isRead,
              hasDot: !n.isRead,
              route: n.link ?? '',
              notificationId: n.id,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
        ],
        if (state.page < state.totalPages)
          Center(
            child: TextButton(
              onPressed: state.isLoadingMore
                  ? null
                  : () =>
                      ref.read(notificationInboxProvider.notifier).loadMore(),
              child: Text(state.isLoadingMore ? 'Loading…' : 'Load more'),
            ),
          ),
      ],
    );
  }

  /// Maps a backend deep link onto an in-app route. Returns null when there's
  /// nothing sensible to open, so the card just marks itself read.
  String? _appRouteFor(String link) {
    if (link.isEmpty) return null;
    if (link.startsWith('/orders/') ||
        link.startsWith('/wallet') ||
        link.startsWith('/offers')) {
      return link;
    }
    final orderMatch =
        RegExp(r'/orders?/([A-Za-z0-9_-]+)$').firstMatch(link);
    if (orderMatch != null) {
      return '/orders/details/${orderMatch.group(1)}';
    }
    return null;
  }

  IconData _iconFor(String category) {
    switch (category.toLowerCase()) {
      case 'order':
        return Icons.shopping_bag_rounded;
      case 'delivery':
        return Icons.two_wheeler_rounded;
      case 'wallet':
      case 'cashback':
      case 'refund':
        return Icons.account_balance_wallet_rounded;
      case 'offer':
      case 'promotion':
        return Icons.local_offer_rounded;
      case 'referral':
        return Icons.card_giftcard_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _dayLabel(DateTime? at) {
    if (at == null) return 'Earlier';
    final now = DateTime.now();
    final d = DateTime(at.year, at.month, at.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${at.day} ${months[at.month - 1]} ${at.year}';
  }

  String _time(DateTime? at) {
    if (at == null) return '';
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final m = at.minute.toString().padLeft(2, '0');
    return '$h:$m ${at.hour >= 12 ? 'PM' : 'AM'}';
  }

  Widget _buildInboxMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 52, color: AppColors.primary.withValues(alpha: 0.35)),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  /// 1. Top Navigation Header Row (Settings option removed)
  Widget _buildTopHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Circular Back Button
          GestureDetector(
            onTap: () {
              Haptics.light();
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(RouteNames.home);
              }
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
            ),
          ),

          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),

          // Empty spacer to balance the back button on the left
          const SizedBox(width: 38),
        ],
      ),
    );
  }

  /// 2. Filter Category Pills with Dynamic Badges
  Widget _buildFilterPills() {
    final state = ref.watch(notificationInboxProvider);

    final allCount = state.items.length;
    final ordersCount = state.items.where((n) {
      final c = n.category.toLowerCase();
      return c == 'order' || c == 'delivery';
    }).length;
    final offersCount = state.items.where((n) {
      final c = n.category.toLowerCase();
      return c == 'offer' || c == 'promotion' || c == 'cashback';
    }).length;
    final accountCount = state.items.where((n) {
      final c = n.category.toLowerCase();
      return c == 'account' || c == 'wallet' || c == 'referral';
    }).length;

    final filters = [
      {'label': 'All', 'count': '$allCount'},
      {'label': 'Orders', 'count': '$ordersCount'},
      {'label': 'Offers', 'count': '$offersCount'},
      {'label': 'Account', 'count': '$accountCount'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: List.generate(filters.length, (index) {
          final isSelected = _selectedFilterIndex == index;
          final item = filters[index];

          return GestureDetector(
            onTap: () {
              Haptics.light();
              setState(() => _selectedFilterIndex = index);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE6F7F5) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    item['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item['count']!,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 3. Real-time Alerts Permission Banner
  Widget _buildAlertPermissionBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFDCFCE7),
            ),
            child: Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Stay updated with real-time alerts!',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 1),
                Text(
                  'Enable notifications to never miss orders, offers and exciting updates.',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              Haptics.light();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary, width: 1.2),
              ),
              child: Text(
                'Enable Now',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              Haptics.light();
              setState(() => _showAlertBanner = false);
            },
            child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
    );
  }

  /// Single Notification Card Component
  Widget _buildNotificationCard(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
    required bool isUnread,
    required bool hasDot,
    required String route,
    String? codeHighlight,
    String? notificationId,
  }) {
    return GestureDetector(
      onTap: () {
        Haptics.light();
        if (notificationId != null && isUnread) {
          ref.read(notificationInboxProvider.notifier).markRead(notificationId);
        }
        final target = _appRouteFor(route);
        if (target != null) context.push(target);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconBg,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                if (hasDot)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF16A34A),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  if (codeHighlight != null)
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        children: [
                          TextSpan(text: subtitle.split(codeHighlight).first),
                          WidgetSpan(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                codeHighlight,
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFF16A34A)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500, height: 1.25),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                if (hasDot)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF16A34A),
                    ),
                  )
                else
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 5. View Archived Notifications Card
  Widget _buildArchivedNotificationsCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE6F7F5),
            ),
            child: Icon(Icons.inbox_outlined, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'View Archived Notifications',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 1),
                Text(
                  'Check your old notifications',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 18),
        ],
      ),
    );
  }
}
