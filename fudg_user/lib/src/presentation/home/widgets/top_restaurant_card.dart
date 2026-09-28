import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/restaurant_model.dart';
import '../../common_widgets/smart_image.dart';
import '../../favorites/viewmodels/favorites_viewmodel.dart';

class TopRestaurantCard extends ConsumerWidget {
  final RestaurantModel restaurant;
  final int index;
  final VoidCallback onTap;

  const TopRestaurantCard({
    super.key,
    required this.restaurant,
    this.index = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favState = ref.watch(favoritesViewModelProvider).value;
    final isFav = favState?.restaurantIds.contains(restaurant.id) ?? false;

    // Merchandising pill, set per restaurant in the admin panel. This used to
    // be `index % 2 == 0`, so a restaurant was "Bestseller" or "Popular"
    // purely by where it landed in the feed.
    final String? highlight = restaurant.highlightBadge;
    final bool isBestseller = highlight == 'bestseller';

    // Cuisine string display
    final String cuisinesText = restaurant.tags.isNotEmpty
        ? restaurant.tags.join(' • ')
        : restaurant.area;

    // Rating & Time — blank when the backend has no value, rather than the
    // invented 4.3 / 20 mins every unrated restaurant used to claim.
    final String ratingStr = restaurant.rating > 0
        ? restaurant.rating.toStringAsFixed(1)
        : '';
    final String timeStr = restaurant.deliveryTime.isEmpty
        ? ''
        : (restaurant.deliveryTime.contains('min')
              ? restaurant.deliveryTime
              : '${restaurant.deliveryTime} mins');

    // Colours still rotate for visual variety, but keyed off the restaurant id
    // so a card keeps its palette when the feed re-sorts. The copy is the
    // restaurant's own free-delivery threshold; no threshold, no pill.
    final int colorVariant = restaurant.id.hashCode.abs() % 3;
    final Color tagBgColor;
    final Color tagTextColor;

    if (colorVariant == 0) {
      tagBgColor = isDark ? const Color(0xFF143823) : const Color(0xFFEBF7EE);
      tagTextColor = const Color(0xFF16A34A);
    } else if (colorVariant == 1) {
      tagBgColor = isDark ? const Color(0xFF3B1519) : const Color(0xFFFDE8E8);
      tagTextColor = const Color(0xFFDC2626);
    } else {
      tagBgColor = isDark ? const Color(0xFF382D12) : const Color(0xFFFEF9C3);
      tagTextColor = const Color(0xFFD97706);
    }

    final Widget? discountBadge = _buildDiscountBadge(restaurant);

    final double? freeAbove = restaurant.freeDeliveryAbove;
    final String freeDeliveryText = freeAbove == null
        ? ''
        : (freeAbove <= 0
              ? 'Free delivery'
              : 'Free delivery above ₹${freeAbove.toStringAsFixed(0)}');

    return GestureDetector(
      onTap: () {
        Haptics.light();
        onTap();
      },
      // No fixed width: the grid cell decides it now, so the card grows with
      // the row instead of pinning itself to the old 114pt and letting the grid
      // pad around it.
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 5,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Image Area with Overlay Badges
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Restaurant / Food Banner Image
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(11),
                  ),
                  child: SizedBox(
                    // Scales with the card rather than staying at the 54pt that
                    // suited the old narrow one, so the image keeps its share of
                    // the card at any width.
                    height: 68,
                    width: double.infinity,
                    child: SmartImage(
                      url: restaurant.imageUrl,
                      category: ImageCategory.restaurant,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Top Left Pill Badge ("👑 Bestseller" or "★ Popular")
                if (highlight != null)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isBestseller
                            ? const Color(0xFFFDE047) // Golden yellow
                            : const Color(0xFFFF2B42), // Bright Red
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isBestseller) ...[
                            const Text('👑', style: TextStyle(fontSize: 8)),
                            const SizedBox(width: 1.5),
                            const Text(
                              'Bestseller',
                              style: TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ] else ...[
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 8.5,
                            ),
                            const SizedBox(width: 1.5),
                            const Text(
                              'Popular',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                // Top Right Favorite Heart Button
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      Haptics.light();
                      ref
                          .read(favoritesViewModelProvider.notifier)
                          .toggle(restaurant.id, restaurant);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.25),
                      ),
                      child: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFav ? const Color(0xFFEF4444) : Colors.white,
                        size: 13.5,
                      ),
                    ),
                  ),
                ),

                // Bottom Left Overlapping Brand Logo Badge (Circular)
                Positioned(
                  left: 5,
                  bottom: -9,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 2.5,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _buildBrandLogo(colorVariant, restaurant),
                    ),
                  ),
                ),

                // Bottom Discount Badge Banner. Bounded on both sides: the
                // offer copy is free text from the admin panel, and anchoring
                // only the right edge let a long one render wider than the
                // 114px card and get clipped at both ends. `left` clears the
                // brand logo below.
                if (discountBadge != null)
                  Positioned(
                    left: 32,
                    right: 4,
                    bottom: 4,
                    child: discountBadge,
                  ),
              ],
            ),

            // Card Body Details (Below Image)
            //
            // Top inset clears the brand disc, which is pinned at `bottom: -9`
            // on the image above and so hangs into this block. At 4 the disc
            // sat on the restaurant name.
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 13, 5, 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Restaurant Name — marquees instead of truncating
                  _MarqueeText(
                    text: restaurant.name,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFE2E8F0)
                          : const Color(0xFF334155),
                      letterSpacing: -0.2,
                    ),
                  ),

                  const SizedBox(height: 1),

                  // Cuisines Subtitle
                  _MarqueeText(
                    text: cuisinesText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),

                  const SizedBox(height: 2),

                  // Rating & Delivery Time Row
                  Row(
                    children: [
                      // Rating Green Pill
                      if (ratingStr.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3.5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A), // Vibrant Green
                            borderRadius: BorderRadius.circular(3.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 9,
                              ),
                              const SizedBox(width: 1.5),
                              Text(
                                ratingStr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Vertical Divider Line — only when it separates two things.
                      if (ratingStr.isNotEmpty && timeStr.isNotEmpty)
                        Container(
                          height: 8,
                          width: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: isDark
                              ? const Color(0xFF475569)
                              : const Color(0xFFCBD5E1),
                        ),

                      // Delivery Bike Icon & Time
                      if (timeStr.isNotEmpty) ...[
                        Icon(
                          Icons.directions_bike_rounded,
                          size: 11.5,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF334155),
                        ),
                        const SizedBox(width: 2.5),
                        Expanded(
                          child: Text(
                            timeStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Free Delivery Offer Tag Banner (Bottom Pill)
                  if (freeDeliveryText.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tagBgColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sell_rounded,
                            size: 9.5,
                            color: tagTextColor,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              freeDeliveryText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: tagTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The circular brand badge.
  ///
  /// Shows the restaurant's uploaded logo when it has one. The generated badge
  /// below is the fallback — it is derived from the restaurant's own name, not
  /// invented branding, so a partner who has not uploaded a logo still gets a
  /// recognisable mark.
  Widget _buildBrandLogo(int variant, RestaurantModel r) {
    if (r.logoUrl.isNotEmpty) {
      return SmartImage(
        url: r.logoUrl,
        category: ImageCategory.restaurant,
        fit: BoxFit.cover,
      );
    }

    final name = r.name;
    final Color bg = variant == 0
        ? const Color(0xFF0D4734)
        : (variant == 1 ? const Color(0xFFD31027) : const Color(0xFFFFCB05));

    final Color textCol = variant == 2 ? Colors.black : Colors.white;

    return Container(
      color: bg,
      padding: const EdgeInsets.all(2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_rounded, size: 10, color: textCol),
          Text(
            name.toUpperCase(),
            textAlign: TextAlign.center,
            // One line, not two: an icon plus two lines of text overflowed the
            // 24pt disc this is drawn inside by 5.5px.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 5.5,
              fontWeight: FontWeight.w900,
              color: textCol,
              height: 0.85,
            ),
          ),
        ],
      ),
    );
  }

  /// The restaurant's live offer, e.g. "20% OFF above ₹199" or "FLAT 30% OFF".
  ///
  /// Used to fall back to one of two hardcoded offers chosen by the card's
  /// position, so a restaurant running no promotion still advertised one.
  /// Returns null now, and the caller omits the badge entirely.
  Widget? _buildDiscountBadge(RestaurantModel r) {
    if (r.offerBadges.isEmpty) return null;
    final String badgeText = r.offerBadges.first;

    if (badgeText.trim().isEmpty) return null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(
          0xFFDC2626,
        ), // Soft vibrant red matching reference UI
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        badgeText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

/// A single line of text that marquees left-right when it doesn't fit its
/// width, instead of ellipsis-truncating and hiding part of it.
class _MarqueeText extends StatefulWidget {
  const _MarqueeText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> {
  final _scrollController = ScrollController();
  bool _started = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loop(double overflow) async {
    // Slow, even pace (~28ms per pixel) reads as a smooth drift rather than a
    // jerky flick. Always scrolls forward; it snaps back to the start (no
    // reverse animation) so the motion only ever reads as one direction.
    final duration = Duration(
      milliseconds: (overflow * 28).clamp(1400, 4500).round(),
    );
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted || !_scrollController.hasClients) return;
      await _scrollController.animateTo(
        overflow,
        duration: duration,
        curve: Curves.easeInOutSine,
      );
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        final overflow = painter.width - constraints.maxWidth;

        // Skip the marquee for a near-fit: a couple of stray pixels of
        // overflow would only twitch back and forth, not read as scrolling.
        if (overflow > 6 && !_started) {
          _started = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loop(overflow + 6);
          });
        }

        return SizedBox(
          height: painter.height,
          width: constraints.maxWidth,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        );
      },
    );
  }
}
