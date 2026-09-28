import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/core/theme/app_colors.dart';
import 'package:food_user_application/features/chat/presentation/screens/chat_screen.dart';
import 'package:food_user_application/features/support/presentation/widgets/emergency_help_sheet.dart';

class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('Help Centre')),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How can we help?',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w900,
                color: c.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Raise a ticket and our support team will get back to you.',
              style: TextStyle(
                fontSize: 14.sp,
                color: c.textSecondary,
                height: 1.5,
              ),
            ),
            SizedBox(height: 32.h),
            _HelpCard(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Chat with Support',
              subtitle: 'Message our support desk directly',
              color: AppColors.primary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ChatScreen(peerRole: 'ADMIN', title: 'Support'),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            _HelpCard(
              icon: Icons.confirmation_number_outlined,
              title: 'Raise a Support Ticket',
              subtitle: 'Describe your issue and track the reply',
              color: AppColors.primary,
              onTap: () => context.push('/help/ticket'),
            ),
            SizedBox(height: 16.h),
            _HelpCard(
              icon: Icons.report_problem_outlined,
              title: 'Emergency Contacts',
              subtitle: 'Medical, accident and police helplines',
              color: AppColors.error,
              onTap: () => showEmergencyHelpSheet(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13.sp, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: c.textSecondary,
              size: 22.sp,
            ),
          ],
        ),
      ),
    );
  }
}
