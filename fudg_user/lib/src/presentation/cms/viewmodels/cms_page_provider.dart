import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../../di/network_providers.dart';

/// One admin-managed page from `GET /food/pages/:key`.
///
/// Keys come from the backend's `PageKey` enum: about, support, terms, privacy,
/// refund, shipping, cancellation. The admin panel edits them under
/// `/admin/pages-social-media/:key`.
///
/// The About, Help, Privacy and Terms screens used to ship their own prose —
/// mission statements, a support SLA, policy text — none of which anyone could
/// change without a release, and none of which was reviewed. They now render
/// whatever the admin publishes, and an empty state when nothing is published.
class CmsPage {
  const CmsPage({
    required this.title,
    required this.content,
    required this.email,
    required this.mobile,
  });

  final String title;

  /// HTML fragment as entered in the admin editor.
  final String content;
  final String email;
  final String mobile;

  bool get isEmpty => content.trim().isEmpty;

  factory CmsPage.fromApi(Map<String, dynamic> json) => CmsPage(
        title: (json['title'] ?? '').toString().trim(),
        content: (json['content'] ?? '').toString().trim(),
        email: (json['email'] ?? '').toString().trim(),
        mobile: (json['mobile'] ?? '').toString().trim(),
      );
}

/// Null when the admin has never saved this page — the endpoint answers 200
/// with `data: null` rather than a 404, so an error state would be wrong.
final cmsPageProvider =
    FutureProvider.family<CmsPage?, String>((ref, key) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<dynamic>(ApiPaths.cmsPage(key), auth: false);
  if (data is! Map) return null;
  return CmsPage.fromApi(data.cast<String, dynamic>());
});
