import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/catalog_providers.dart';

/// Live offers from `GET /food/restaurant/offers`.
///
/// The backend prebuilds `headline` and `conditions`, so the UI renders what it
/// is given. There is deliberately no fallback list: with no offers configured
/// the screen shows an empty state rather than coupon codes that would be
/// rejected at checkout.
///
/// `autoDispose` is load-bearing, not tidiness: a coupon can be live only
/// between 12:00 and 15:00, so a list held for the whole session would keep
/// offering a lunch code at dinner. Disposing with the last listener means
/// every screen that opens re-reads what is valid this minute.
final offersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(catalogRemoteDataSourceProvider).getOffers();
});

/// Offers usable at one restaurant. Scoping server-side also drops coupons the
/// user has already exhausted and first-order-only ones they no longer qualify
/// for, which a client-side filter on [offersProvider] could not know about.
///
/// `autoDispose` for the same time-sensitivity reason as [offersProvider].
final restaurantOffersProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, restaurantId) {
  return ref
      .watch(catalogRemoteDataSourceProvider)
      .getOffers(restaurantId: restaurantId);
});

/// The server's own wording for an offer, e.g. "50% OFF up to ₹60".
///
/// Never rebuilt from `discountValue`/`maxDiscount` on the phone: the server
/// uses this exact string on the restaurant page, in the cart and on the bill,
/// and a locally composed one drops the cap. Falls back to the legacy `title`
/// only for offers an older backend returned without a headline.
String offerHeadline(Map<String, dynamic> offer) {
  final headline = (offer['headline'] ?? '').toString();
  return headline.isNotEmpty ? headline : (offer['title'] ?? '').toString();
}

/// The offer's qualifying rules, already phrased by the server —
/// "on orders above ₹199 · Mon-Fri · 12:00-15:00 · once per customer".
///
/// Whether a coupon actually applies is decided by `/orders/calculate`, never
/// worked out here; this only tells the customer what the rules are.
String offerConditions(Map<String, dynamic> offer) {
  return ((offer['conditions'] as List?) ?? const [])
      .map((e) => e.toString().trim())
      .where((s) => s.isNotEmpty)
      .join(' · ');
}

/// Bottom sheet spelling out an offer's rules.
///
/// Every line is the server's own wording — [offerHeadline] and each entry of
/// [offerConditions] — so the terms shown here are the terms the server will
/// enforce at checkout.
Future<void> showOfferDetailsSheet(
  BuildContext context,
  Map<String, dynamic> offer,
) {
  final headline = offerHeadline(offer);
  final code = (offer['couponCode'] ?? offer['code'] ?? '').toString();
  final conditions = ((offer['conditions'] as List?) ?? const [])
      .map((e) => e.toString().trim())
      .where((s) => s.isNotEmpty)
      .toList();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              headline.isNotEmpty ? headline : code,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            if (code.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                code,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF41222),
                  letterSpacing: 0.5,
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (conditions.isEmpty)
              Text(
                'No extra conditions on this offer.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              )
            else
              ...conditions.map(
                (c) => _detailRow(isDark, Icons.check_circle_outline_rounded, c),
              ),
          ],
        ),
      );
    },
  );
}

Widget _detailRow(bool isDark, IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFFF41222)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    ),
  );
}
