import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../../di/network_providers.dart';

/// Company contact details from `GET /food/admin/business-settings/public`.
///
/// The About screen used to hardcode `www.minto.com`, `support@minto.com` and
/// `+91 98765 43210` — the domain was wrong (it is mintofood.com) and the
/// number was the demo restaurant's. Fields the backend leaves blank are simply
/// not shown rather than filled with a placeholder.
final businessSettingsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>(ApiPaths.businessSettings, auth: false);
  final settings = data['businessSettings'];
  return settings is Map
      ? settings.cast<String, dynamic>()
      : data;
});
