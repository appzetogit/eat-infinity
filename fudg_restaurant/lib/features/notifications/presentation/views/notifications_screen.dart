import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/notifications/domain/notification_model.dart';
import 'package:food_user_application/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final notificationsAsync = ref.watch(notificationsControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : AppColors.textPrimaryLight,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            color: isDarkMode ? Colors.white : AppColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDarkMode ? Colors.white : AppColors.textPrimaryLight,
            ),
            onPressed: () =>
                ref.read(notificationsControllerProvider.notifier).refresh(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error is ApiException
                  ? error.message
                  : 'Failed to load notifications.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (state) => AppRefreshIndicator(
          onRefresh: () =>
              ref.read(notificationsControllerProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildSummaryCard(isDarkMode, state),
                ),
                if (state.items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _confirmClearAll(context, ref),
                          child: const Text(
                            'Clear all',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                state.items.isEmpty
                    ? _buildEmptyState(isDarkMode)
                    : _buildNotificationList(isDarkMode, state.items),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDarkMode, NotificationsState state) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.backgroundDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: isDarkMode
            ? null
            : Border.all(color: AppColors.surfaceVariantLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inbox',
                style: TextStyle(
                  color: isDarkMode
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${state.total} Notification${state.total == 1 ? '' : 's'}',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppColors.surfaceVariantDark
                  : AppColors.surfaceVariantLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Unread: ${state.unreadCount}',
              style: TextStyle(
                color: isDarkMode ? Colors.white : AppColors.textPrimaryLight,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none,
            size: 48,
            color: isDarkMode
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(height: 12),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: isDarkMode
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(
    bool isDarkMode,
    List<NotificationModel> items,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          for (final notification in items) ...[
            _NotificationCard(
              notification: notification,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This removes every notification from your inbox.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Clear all',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(notificationsControllerProvider.notifier).dismissAll();
    }
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({
    required this.notification,
    required this.isDarkMode,
  });

  final NotificationModel notification;
  final bool isDarkMode;

  IconData get _icon {
    switch (notification.source) {
      case 'FSSAI_EXPIRY':
        return Icons.warning_amber_rounded;
      case 'SUPPORT_RESPONSE':
        return Icons.support_agent_outlined;
      case 'ADMIN_BROADCAST':
      default:
        return Icons.campaign_outlined;
    }
  }

  Color get _iconColor {
    switch (notification.source) {
      case 'FSSAI_EXPIRY':
        return AppColors.error;
      case 'SUPPORT_RESPONSE':
        return AppColors.success;
      case 'ADMIN_BROADCAST':
      default:
        return Colors.blue[600]!;
    }
  }

  Color get _tagColor {
    switch (notification.source) {
      case 'FSSAI_EXPIRY':
        return Colors.red[100]!;
      case 'SUPPORT_RESPONSE':
        return Colors.green[100]!;
      case 'ADMIN_BROADCAST':
      default:
        return Colors.blue[100]!;
    }
  }

  Color get _tagTextColor {
    switch (notification.source) {
      case 'FSSAI_EXPIRY':
        return Colors.red[800]!;
      case 'SUPPORT_RESPONSE':
        return Colors.green[800]!;
      case 'ADMIN_BROADCAST':
      default:
        return Colors.blue[800]!;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = notification.isRead;
    final cardColor = isDarkMode
        ? (isRead ? AppColors.surfaceDark : AppColors.surfaceVariantDark)
        : (isRead ? AppColors.surfaceLight : const Color(0xFFF8F9FF));
    final borderColor = isDarkMode
        ? (isRead
              ? AppColors.surfaceVariantDark
              : AppColors.primary.withValues(alpha: 0.4))
        : (isRead
              ? AppColors.surfaceVariantLight
              : Colors.blue.withValues(alpha: 0.2));
    final textColor = isDarkMode ? Colors.white : AppColors.textPrimaryLight;
    final secondaryTextColor = isDarkMode
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => ref
          .read(notificationsControllerProvider.notifier)
          .dismiss(notification.id),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref
            .read(notificationsControllerProvider.notifier)
            .markRead(notification.id),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(_icon, size: 20, color: _iconColor),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _tagColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          notification.tag,
                          style: TextStyle(
                            color: _tagTextColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: secondaryTextColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => ref
                        .read(notificationsControllerProvider.notifier)
                        .dismiss(notification.id),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isRead) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      notification.title,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                notification.message,
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                DateFormat('d MMM, h:mm a').format(notification.createdAt.toLocal()),
                style: TextStyle(color: secondaryTextColor, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
