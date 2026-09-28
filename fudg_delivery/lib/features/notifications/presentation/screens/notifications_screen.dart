import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/core/theme/app_colors.dart';
import 'package:food_user_application/features/notifications/application/unread_notifications_controller.dart';
import 'package:food_user_application/features/notifications/data/notifications_repository.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

/// One inbox row, built from `GET /food/notifications/inbox`.
///
/// The screen used to render a fixed list of seven invented notifications
/// ("Order #MF78563 has been assigned to you", a ₹200 incentive, a system
/// maintenance window) while quietly fetching — and discarding — the real
/// inbox. Everything on screen now comes from [_NotificationItem.fromJson].
class _NotificationItem {
  const _NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    required this.isRead,
  });

  final String id;
  final String title;
  final String body;

  /// Bucketed to one of the screen's filter chips.
  final String category;
  final DateTime? createdAt;
  final bool isRead;

  factory _NotificationItem.fromJson(Map<String, dynamic> json) {
    final raw = (json['createdAt'] ?? json['date'])?.toString();
    return _NotificationItem(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['message'] ?? json['body'] ?? '').toString(),
      category: _bucket(
        (json['category'] ?? '').toString(),
        (json['source'] ?? '').toString(),
      ),
      createdAt: raw == null ? null : DateTime.tryParse(raw)?.toLocal(),
      isRead: json['isRead'] == true,
    );
  }

  /// The backend `category` is free-form (it defaults to 'broadcast'), so it is
  /// mapped onto the four chips this screen offers rather than shown raw.
  static String _bucket(String category, String source) {
    final v = '$category $source'.toLowerCase();
    if (v.contains('order') || v.contains('trip') || v.contains('dispatch')) {
      return 'Orders';
    }
    if (v.contains('earn') ||
        v.contains('payout') ||
        v.contains('wallet') ||
        v.contains('bonus') ||
        v.contains('payment')) {
      return 'Earnings';
    }
    if (v.contains('promo') ||
        v.contains('offer') ||
        v.contains('referral') ||
        v.contains('incentive')) {
      return 'Promotions';
    }
    return 'Account';
  }

  /// Today / Yesterday / Earlier, from the real timestamp.
  String get section {
    final at = createdAt;
    if (at == null) return 'Earlier';
    final now = DateTime.now();
    final days =
        DateTime(now.year, now.month, now.day)
            .difference(DateTime(at.year, at.month, at.day))
            .inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return 'Earlier';
  }

  String get timeLabel {
    final at = createdAt;
    if (at == null) return '';
    final hour12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final clock =
        '${hour12.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')} '
        '${at.hour < 12 ? 'AM' : 'PM'}';
    switch (section) {
      case 'Today':
        return clock;
      case 'Yesterday':
        return 'Yesterday, $clock';
      default:
        return '${at.day.toString().padLeft(2, '0')}/'
            '${at.month.toString().padLeft(2, '0')}/${at.year}, $clock';
    }
  }
}

/// Chip styling per bucket. Colour is presentation, not data — it is the one
/// thing here that is still decided in the client.
const _categoryStyles = <String, ({Color bg, Color fg, IconData icon})>{
  'Orders': (
    bg: AppColors.primaryLight,
    fg: AppColors.primaryDark,
    icon: Icons.local_mall_outlined,
  ),
  'Earnings': (
    bg: Color(0xFFFFF3E0),
    fg: Color(0xFFF57C00),
    icon: Icons.account_balance_wallet_outlined,
  ),
  'Promotions': (
    bg: Color(0xFFE8F5E9),
    fg: Color(0xFF2E7D32),
    icon: Icons.card_giftcard_rounded,
  ),
  'Account': (
    bg: Color(0xFFECEFF1),
    fg: Color(0xFF455A64),
    icon: Icons.shield_outlined,
  ),
};

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'All'; // 'All', 'Orders', 'Earnings', 'Account', 'Promotions'

  List<_NotificationItem> _items = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadApiNotifications();
  }

  Future<void> _loadApiNotifications() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result =
        await ref.read(notificationsRepositoryProvider).getInbox(limit: 50);
    if (!mounted) return;
    result.when(
      success: (data) {
        final items = (data['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(_NotificationItem.fromJson)
            .toList();
        final unread = (data['unreadCount'] as num?)?.toInt() ??
            items.where((i) => !i.isRead).length;
        setState(() {
          _items = items;
          _unreadCount = unread;
          _loading = false;
        });
        ref.read(unreadNotificationsProvider.notifier).setCount(unread);
      },
      // An empty inbox and a failed fetch are different things and now look
      // different: no silent fallback to a canned list.
      failure: (error) => setState(() {
        _error = error.message;
        _loading = false;
      }),
    );
  }

  Future<void> _openNotification(_NotificationItem item) async {
    HapticService.light();
    if (!item.isRead && item.id.isNotEmpty) {
      final result =
          await ref.read(notificationsRepositoryProvider).markRead(item.id);
      if (!mounted) return;
      result.when(
        success: (_) => setState(() {
          _items = _items
              .map((i) => i.id == item.id
                  ? _NotificationItem(
                      id: i.id,
                      title: i.title,
                      body: i.body,
                      category: i.category,
                      createdAt: i.createdAt,
                      isRead: true,
                    )
                  : i)
              .toList();
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
          ref
              .read(unreadNotificationsProvider.notifier)
              .setCount(_unreadCount);
        }),
        failure: (error) => _showSnack(error.message),
      );
    }
  }

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

  Future<void> _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Clear Notifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp)),
        content: const Text('Are you sure you want to clear all notifications?'),
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
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    // Clear the list only once the backend confirms — the previous version
    // emptied the UI and fired the request without waiting, so a failed
    // delete looked identical to a successful one.
    final result =
        await ref.read(notificationsRepositoryProvider).deleteAll();
    if (!mounted) return;
    result.when(
      success: (_) {
        setState(() {
          _items = [];
          _unreadCount = 0;
        });
        ref.read(unreadNotificationsProvider.notifier).setCount(0);
        _showSnack('All notifications cleared');
      },
      failure: (error) => _showSnack(error.message),
    );
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(20.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Notifications', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.sp)),
            SizedBox(height: 16.h),
            ...['All', 'Orders', 'Earnings', 'Account', 'Promotions'].map((cat) {
              final isSelected = _selectedCategory == cat;
              return ListTile(
                title: Text(cat, style: TextStyle(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500)),
                trailing: isSelected ? Icon(Icons.check_rounded, color: AppColors.primaryDark) : null,
                onTap: () {
                  setState(() => _selectedCategory = cat);
                  Navigator.of(ctx).pop();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter list by selected category
    final filteredList = _items
        .where((item) =>
            _selectedCategory == 'All' || item.category == _selectedCategory)
        .toList();

    // Group by section (Today, Yesterday, Earlier), keeping that order.
    final Map<String, List<_NotificationItem>> grouped = {};
    for (final section in const ['Today', 'Yesterday', 'Earlier']) {
      final rows = filteredList.where((i) => i.section == section).toList();
      if (rows.isNotEmpty) grouped[section] = rows;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Header Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20.sp,
                            color: Colors.black87,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Stay updated with all the important updates',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Filter Button
                  GestureDetector(
                    onTap: _showFilterModal,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.filter_list_rounded, color: Colors.black87, size: 16.sp),
                          SizedBox(width: 4.w),
                          Text(
                            'Filter',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.sp,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Clear All Button
                  GestureDetector(
                    onTap: _clearAllNotifications,
                    child: Container(
                      width: 38.r,
                      height: 38.r,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Icon(Icons.delete_outline_rounded, color: Colors.grey[700], size: 18.sp),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Horizontal Category Filter Chips Bar
            SizedBox(
              height: 42.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(left: 16.w, right: 8.w),
                children: [
                  _buildCategoryChip(name: 'All', icon: Icons.notifications_rounded, count: null),
                  _buildCategoryChip(name: 'Orders', icon: Icons.local_mall_outlined, count: null),
                  _buildCategoryChip(name: 'Earnings', icon: Icons.currency_rupee_rounded, count: null),
                  _buildCategoryChip(name: 'Account', icon: Icons.person_outline_rounded, count: null),
                  _buildCategoryChip(name: 'Promotions', icon: Icons.card_giftcard_rounded, count: null),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // 3. Main Notifications List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildErrorState()
                      : filteredList.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadApiNotifications,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                    16.w, 4.h, 16.w, 96.h),
                                children: grouped.entries.map((entry) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.only(
                                            top: 8.h, bottom: 10.h),
                                        child: Text(
                                          entry.key,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14.sp,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      ...entry.value
                                          .map(_buildNotificationCard),
                                      SizedBox(height: 8.h),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
            ),
          ],
        ),
      ),

    );
  }

  Widget _buildCategoryChip({
    required String name,
    required IconData icon,
    int? count,
  }) {
    final isSelected = _selectedCategory == name;
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: GestureDetector(
        onTap: () {
          HapticService.light();
          setState(() => _selectedCategory = name);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.lightBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15.sp,
                color: isSelected ? Colors.white : AppColors.lightTextSecondary,
              ),
              SizedBox(width: 6.w),
              Text(
                name,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color:
                      isSelected ? Colors.white : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pull-to-refresh has to stay reachable on an empty inbox, so the message
  /// sits inside a scrollable rather than a bare Center.
  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: _loadApiNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: constraints.maxHeight * 0.22),
            Icon(
              Icons.notifications_off_outlined,
              size: 56.sp,
              color: AppColors.lightBorder,
            ),
            SizedBox(height: 14.h),
            Text(
              _selectedCategory == 'All'
                  ? 'No notifications yet'
                  : 'No $_selectedCategory notifications',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.lightTextPrimary,
              ),
            ),
            SizedBox(height: 6.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 48.w),
              child: Text(
                'Order updates and announcements will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  color: AppColors.lightTextSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 48.sp,
              color: AppColors.lightTextSecondary,
            ),
            SizedBox(height: 14.h),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              // A server error can run to hundreds of lines; unbounded it
              // pushes the retry button off the screen.
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5.sp,
                color: AppColors.lightTextSecondary,
                height: 1.4,
              ),
            ),
            SizedBox(height: 18.h),
            ElevatedButton.icon(
              onPressed: _loadApiNotifications,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(_NotificationItem item) {
    final isRead = item.isRead;
    final style = _categoryStyles[item.category] ?? _categoryStyles['Account']!;

    return GestureDetector(
      onTap: () => _openNotification(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          // Unread rows carry a faint tint so the list is scannable at a
          // glance, rather than relying on an 8px dot alone.
          color: isRead ? Colors.white : style.bg.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isRead ? AppColors.lightBorder : style.fg.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44.r,
              height: 44.r,
              decoration: BoxDecoration(
                color: style.bg,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(style.icon, color: style.fg, size: 22.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: style.bg,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 9.5.sp,
                            fontWeight: FontWeight.w800,
                            color: style.fg,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Flexible so a long absolute date cannot push the pill
                      // off the row on a narrow screen.
                      Flexible(
                        child: Text(
                          item.timeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 10.5.sp,
                            color: AppColors.lightTextSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                      fontSize: 14.sp,
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                  if (item.body.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      item.body,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: AppColors.lightTextSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              width: 8.r,
              height: 8.r,
              margin: EdgeInsets.only(top: 4.h),
              decoration: BoxDecoration(
                color: isRead ? Colors.transparent : style.fg,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
