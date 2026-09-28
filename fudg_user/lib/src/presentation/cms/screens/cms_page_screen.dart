import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../chat/screens/chat_screen.dart';
import '../../common_widgets/empty_state_widget.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/business_settings_provider.dart';
import '../viewmodels/cms_page_provider.dart';

/// Renders an admin-managed page (About, Help & Support, Privacy, Terms).
///
/// Content is whatever the admin publishes under
/// `/admin/pages-social-media/:key`. Nothing is hardcoded here: when a page has
/// not been published the screen says so instead of showing prose the business
/// never wrote.
class CmsPageScreen extends ConsumerWidget {
  const CmsPageScreen({
    super.key,
    required this.pageKey,
    required this.fallbackTitle,
  });

  /// A `PageKey` the backend recognises: about, support, terms, privacy,
  /// refund, shipping, cancellation.
  final String pageKey;

  /// Shown in the app bar until the CMS supplies its own title.
  final String fallbackTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(cmsPageProvider(pageKey));
    final textColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          async.asData?.value?.title.isNotEmpty == true
              ? async.asData!.value!.title
              : fallbackTitle,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ),
      floatingActionButton: pageKey == 'support'
          ? FloatingActionButton.extended(
              onPressed: () {
                Haptics.light();
                context.push(
                  RouteNames.chat,
                  extra: const ChatArgs(orderId: '', peerName: 'Support', peerRole: 'ADMIN'),
                );
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
              label: const Text('Chat with Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                EmptyStateWidget(
                  icon: Icons.wifi_off_rounded,
                  title: "Couldn't load this page",
                  subtitle: e.toString(),
                ),
                SizedBox(height: 16.h),
                TextButton(
                  onPressed: () => ref.invalidate(cmsPageProvider(pageKey)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (page) {
          if (page == null || page.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.article_outlined,
              title: '$fallbackTitle is not published yet',
              subtitle:
                  'This page is managed from the admin panel. Once it is '
                  'published it will appear here.',
            );
          }
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final block in _htmlToBlocks(page.content)) ...[
                  Text(
                    block,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      height: 1.6,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 12.h),
                ],
                _ContactBlock(page: page, isDark: isDark),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Turns the admin editor's HTML into display paragraphs.
///
/// The editor emits simple markup — paragraphs, breaks and list items — so a
/// tag strip is enough and avoids pulling in an HTML rendering dependency for
/// four static pages. Block tags become paragraph breaks so the text does not
/// run together.
List<String> _htmlToBlocks(String html) {
  var text = html
      .replaceAll(RegExp(r'<\s*(br|hr)\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
          RegExp(r'</\s*(p|div|li|h[1-6]|tr)\s*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<\s*li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'<[^>]+>'), '');

  const entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&rsquo;': '’',
    '&ldquo;': '“',
    '&rdquo;': '”',
  };
  entities.forEach((from, to) => text = text.replaceAll(from, to));

  return text
      .split(RegExp(r'\n\s*\n'))
      .map((block) => block.trim().replaceAll(RegExp(r'[ \t]+'), ' '))
      .where((block) => block.isNotEmpty)
      .toList();
}

/// Contact details for the page, preferring what the admin typed on the page
/// itself and otherwise falling back to the business settings the admin
/// maintains separately. Both are real admin-managed sources; nothing is shown
/// when neither has been filled in.
class _ContactBlock extends ConsumerWidget {
  const _ContactBlock({required this.page, required this.isDark});

  final CmsPage page;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business =
        ref.watch(businessSettingsProvider).asData?.value ?? const {};
    final email = page.email.isNotEmpty
        ? page.email
        : (business['email'] ?? '').toString().trim();
    final phone = page.mobile.isNotEmpty
        ? page.mobile
        : '${business['phoneCountryCode'] ?? ''}'
                '${business['phoneNumber'] ?? ''}'
            .trim();

    if (email.isEmpty && phone.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 8.h),
        Divider(color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
        SizedBox(height: 12.h),
        if (email.isNotEmpty)
          _ContactRow(
            icon: Icons.mail_outline_rounded,
            label: email,
            uri: Uri(scheme: 'mailto', path: email),
          ),
        if (phone.isNotEmpty)
          _ContactRow(
            icon: Icons.phone_outlined,
            label: phone,
            uri: Uri(scheme: 'tel', path: phone),
          ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label, required this.uri});

  final IconData icon;
  final String label;
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        Haptics.light();
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Row(
          children: [
            Icon(icon, size: 18.sp, color: AppColors.primary),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
