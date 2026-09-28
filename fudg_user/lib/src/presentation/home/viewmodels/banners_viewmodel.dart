import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/promo_banner_model.dart';
import '../../../di/catalog_providers.dart';
import 'zone_viewmodel.dart';

/// Hero banner image URLs from `GET /food/hero-banners/public`.
///
/// Returns an empty list on failure so the header falls back to its video
/// slide rather than showing a broken carousel.
final heroBannersProvider = FutureProvider<List<String>>((ref) async {
  try {
    return await ref
        .watch(catalogRemoteDataSourceProvider)
        .getHeroBannerImages();
  } catch (_) {
    return const [];
  }
});

/// Admin-uploaded promo banners for the home carousel.
///
/// Returns an empty list on failure, like the hero provider above: the section
/// hides itself when there is nothing to show, so a banner outage costs a strip
/// of the home screen rather than an error state in the middle of it.
final promoBannersProvider = FutureProvider<List<PromoBannerModel>>((
  ref,
) async {
  try {
    return await ref.watch(catalogRemoteDataSourceProvider).getPromoBanners();
  } catch (_) {
    return const [];
  }
});

/// Images for the home header carousel.
///
/// Prefers the dedicated hero CMS, then falls back to the home-promotion
/// banners. The fallback is the path that actually runs on this deployment:
/// `/food/hero-banners/public` is empty and the admin panel's banners are
/// uploaded under Home Promotion Banners, so the header was falling through to
/// its flat brand-colour placeholder while the artwork sat in a strip further
/// down the page.
///
/// Reads both through `.future` rather than `.value` so the header waits for
/// the real answer instead of deciding "hero is empty" off a still-loading
/// provider and locking in the fallback.
final headerBannersProvider = FutureProvider<List<String>>((ref) async {
  final hero = await ref.watch(heroBannersProvider.future);
  if (hero.isNotEmpty) return hero;
  final promo = await ref.watch(promoBannersProvider.future);
  return promo
      .map((b) => b.imageUrl)
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
});

/// Admin-managed deal cards ("Items under ₹X" etc.) for the home deals row.
///
/// Replaces the old hardcoded `deal_29.webp` / `deal_49.webp` assets, which
/// could only change by shipping a new app build. Empty on failure, same as
/// the providers above.
final dealBannersProvider = FutureProvider<List<PromoBannerModel>>((ref) async {
  try {
    return await ref.watch(catalogRemoteDataSourceProvider).getDealBanners();
  } catch (_) {
    return const [];
  }
});

/// "Promotions Management → Offer Banners" — see OFFER_BANNERS_FLUTTER.md.
/// Zone-scoped like the deals row: watching [currentZoneIdProvider] means an
/// address change refetches automatically. Empty on failure, same as above.
final offerBannersProvider = FutureProvider<List<PromoBannerModel>>((
  ref,
) async {
  final zoneId = ref.watch(currentZoneIdProvider);
  try {
    return await ref
        .watch(catalogRemoteDataSourceProvider)
        .getOfferBanners(zoneId: zoneId);
  } catch (_) {
    return const [];
  }
});
