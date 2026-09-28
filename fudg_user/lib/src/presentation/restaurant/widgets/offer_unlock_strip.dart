import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../checkout/viewmodels/checkout_viewmodel.dart';
import '../../offers/viewmodels/offers_viewmodel.dart';

/// The "Unlock Flat ₹120 OFF — add items worth ₹29 more" bar that sits above
/// the View Cart button on a restaurant page.
///
/// Every line is the server's own wording: [offerHeadline] for the headline and
/// [offerConditions] for the rules, or the live `couponError` once the customer
/// has actually applied that code. Nothing about eligibility is worked out here.
/// Renders nothing when the restaurant has no live offers.
class OfferUnlockStrip extends ConsumerStatefulWidget {
  const OfferUnlockStrip({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  ConsumerState<OfferUnlockStrip> createState() => _OfferUnlockStripState();
}

class _OfferUnlockStripState extends ConsumerState<OfferUnlockStrip> {
  static const Duration _rotateInterval = Duration(milliseconds: 3500);
  static const Duration _transition = Duration(milliseconds: 450);

  /// Matches the search bar's hint: the incoming line travels bottom -> centre
  /// and the outgoing one, played in reverse, centre -> top.
  static const double _slide = 0.9;

  int _index = 0;
  Timer? _timer;

  /// Held while the customer is touching the strip or reading the details
  /// sheet, so the offer they tapped is the one they get — and so a half-read
  /// line does not slide away mid-glance.
  bool _paused = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Only runs while there is more than one offer to cycle between.
  void _syncTimer(int offerCount) {
    if (offerCount <= 1 || _paused) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null) return;
    _timer = Timer.periodic(_rotateInterval, (_) {
      if (!mounted) return;
      setState(() => _index++);
    });
  }

  void _setPaused(bool value) {
    if (_paused == value || !mounted) return;
    setState(() => _paused = value);
  }

  Future<void> _openDetails(Map<String, dynamic> offer) async {
    Haptics.light();
    _setPaused(true);
    await showOfferDetailsSheet(context, offer);
    _setPaused(false);
  }

  @override
  Widget build(BuildContext context) {
    final offers =
        ref
            .watch(restaurantOffersProvider(widget.restaurantId))
            .asData
            ?.value ??
        const <Map<String, dynamic>>[];
    if (offers.isEmpty) return const SizedBox.shrink();

    _syncTimer(offers.length);

    final offer = offers[_index % offers.length];
    final code = (offer['couponCode'] ?? '').toString();

    // The cart's own coupon error wins when this is the code they applied:
    // it is the server's live verdict ("Add ₹149 more to use this coupon"),
    // where `conditions` only states the rule in the abstract.
    final checkout = ref.watch(checkoutViewModelProvider);
    final isAppliedCode = code.isNotEmpty && checkout.couponCode == code;
    final liveError = isAppliedCode ? checkout.couponError : null;

    final headline = 'Unlock ${offerHeadline(offer)}';
    final hint = liveError ?? offerConditions(offer);

    return GestureDetector(
      onTap: () => _openDetails(offer),
      // Hold the rotation from the moment the finger lands, so the offer that
      // opens is the one that was on screen when they reached for it.
      onTapDown: (_) => _setPaused(true),
      onTapCancel: () => _setPaused(false),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primarySoft, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryAlpha(0.15),
              ),
              child: Icon(
                Icons.percent_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: _transition,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  // Left-align, otherwise the lines drift to centre mid-slide.
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, animation) {
                    final isIncoming =
                        (child.key as ValueKey<int>?)?.value == _index;
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, isIncoming ? _slide : -_slide),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Column(
                    key: ValueKey<int>(_index),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDeepText,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (offers.length > 1) ...[
              const SizedBox(width: 8),
              Text(
                '${(_index % offers.length) + 1}/${offers.length}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
