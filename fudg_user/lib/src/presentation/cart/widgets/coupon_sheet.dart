import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../offers/viewmodels/offers_viewmodel.dart';
import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../checkout/viewmodels/checkout_viewmodel.dart';
import '../../common_widgets/app_snackbar.dart';

class CouponSheet {
  const CouponSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CouponSheetBody(),
    );
  }
}

class _CouponSheetBody extends ConsumerStatefulWidget {
  const _CouponSheetBody();

  @override
  ConsumerState<_CouponSheetBody> createState() => _CouponSheetBodyState();
}

class _CouponSheetBodyState extends ConsumerState<_CouponSheetBody> {
  final TextEditingController _promoController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasInputText = false;

  @override
  void initState() {
    super.initState();
    _promoController.addListener(() {
      final hasText = _promoController.text.trim().isNotEmpty;
      if (hasText != _hasInputText) {
        setState(() => _hasInputText = hasText);
      }
    });
    _focusNode.addListener(() {
      setState(() {});
    });
  }

  /// Live coupons from `GET /food/restaurant/offers`. No fallback: an empty
  /// list here means the user genuinely has no coupons to apply.
  List<Map<String, dynamic>> _couponsFrom(List<Map<String, dynamic>> raw) {
    return raw
        .map((o) {
          // headline/conditions verbatim from the server — the same wording it
          // uses in the cart and on the bill. Composing our own from
          // discountValue would silently drop the "up to ₹60" cap.
          final conditions = offerConditions(o);
          return {
            'code': (o['couponCode'] ?? o['code'] ?? '').toString(),
            'discount': offerHeadline(o),
            'subtitle': conditions,
            'isFirstOrderOnly': o['isFirstOrderOnly'] == true,
            'raw': o,
          };
        })
        .where((c) => (c['code'] as String).isNotEmpty)
        .toList();
  }

  @override
  void dispose() {
    _promoController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Applies the code against the real order and only reports success once the
  /// server has actually granted a discount.
  ///
  /// A refused code stays attached rather than being dropped: the sheet then
  /// shows the server's reason under it, and it applies by itself on the next
  /// preview once the cart qualifies again.
  Future<void> _applyCoupon(String code) async {
    Haptics.medium();
    await ref.read(checkoutViewModelProvider.notifier).applyCoupon(code);
    if (!mounted) return;

    final state = ref.read(checkoutViewModelProvider);
    final pricing = state.pricing;
    if (pricing?.hasCouponApplied ?? false) {
      AppSnackbar.success(context, 'Coupon "$code" applied — saved ₹${pricing!.discount.toStringAsFixed(0)}!');
      Navigator.of(context).pop();
    } else {
      // The server writes these for customers; show it exactly.
      AppSnackbar.error(
        context,
        state.couponError ?? 'Coupon "$code" is not valid for this order',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTeal = AppColors.primary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Title & Close Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Promocodes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Save more on your order',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                // Floating Close Button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: primaryTeal,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Enter Promocode Input Row + Apply Button
                  _buildEnterPromocodeRow(isDark, primaryTeal),

                  const SizedBox(height: 12),

                  // 2. Applied Code Highlight Banner Box
                  _buildAppliedCodeBanner(isDark, primaryTeal),

                  const SizedBox(height: 20),

                  // 3. Best Offers for You Section
                  _buildBestOffersSection(isDark, primaryTeal),

                  const SizedBox(height: 22),

                  // 4. For First Time Users Section
                  _buildFirstTimeUsersSection(isDark, primaryTeal),

                  const SizedBox(height: 22),

                  // 5. How it works Explainer Box
                  _buildHowItWorksBox(isDark, primaryTeal),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 1. Enter Promocode Input Row + Apply Button
  Widget _buildEnterPromocodeRow(bool isDark, Color primaryTeal) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.local_offer_outlined,
            color: primaryTeal,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _promoController,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              decoration: const InputDecoration(
                hintText: 'Enter Promocode',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_hasInputText)
            GestureDetector(
              onTap: () => _promoController.clear(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.cancel,
                  size: 18,
                  color: Color(0xFFCBD5E1),
                ),
              ),
            ),
          GestureDetector(
            onTap: () {
              final text = _promoController.text.trim();
              if (text.isNotEmpty) {
                _applyCoupon(text);
              } else {
                Haptics.light();
              }
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: primaryTeal,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
              ),
              child: const Center(
                child: Text(
                  'Apply',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Applied Code Banner — only shown once the server has actually granted
  /// a discount for the coupon currently on the order.
  Widget _buildAppliedCodeBanner(bool isDark, Color primaryTeal) {
    final state = ref.watch(checkoutViewModelProvider);
    final pricing = state.pricing;
    if (state.couponCode == null || !(pricing?.hasCouponApplied ?? false)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryTeal, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.local_offer_outlined, color: primaryTeal, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  const TextSpan(text: 'Code '),
                  TextSpan(
                    text: state.couponCode,
                    style: TextStyle(fontWeight: FontWeight.w900, color: primaryTeal),
                  ),
                  const TextSpan(text: ' applied — you saved '),
                  TextSpan(
                    text: '₹${pricing!.discount.toStringAsFixed(0)}',
                    style: TextStyle(fontWeight: FontWeight.w900, color: primaryTeal),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => ref.read(checkoutViewModelProvider.notifier).removeCoupon(),
            child: Text(
              'REMOVE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: primaryTeal,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Best Offers for You Section & Ticket Cards
  Widget _buildBestOffersSection(bool isDark, Color primaryTeal) {
    final async = ref.watch(offersProvider);
    final rawOffers = async.asData?.value ?? const [];
    final coupons = _couponsFrom(rawOffers.map((e) => Map<String, dynamic>.from(e)).toList());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Best Offers for You',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        if (coupons.isEmpty)
          Text(
            'No offers available right now',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ...coupons.map((c) {
          final code = c['code'].toString();
          final checkout = ref.watch(checkoutViewModelProvider);
          final isSelected = checkout.couponCode == code;
          return _buildCouponTicketCard(
            code: code,
            discount: c['discount'].toString(),
            subtitle: c['subtitle'].toString(),
            isFirstOrderOnly: c['isFirstOrderOnly'] == true,
            isSelected: isSelected,
            isDark: isDark,
            primaryTeal: primaryTeal,
            raw: c['raw'] as Map<String, dynamic>,
            // Only the attached code has a live verdict from the server; the
            // rest just show their conditions.
            reason: isSelected ? checkout.couponError : null,
          );
        }),
      ],
    );
  }

  Widget _buildCouponTicketCard({
    required String code,
    required String discount,
    required String subtitle,
    required bool isFirstOrderOnly,
    required bool isSelected,
    required bool isDark,
    required Color primaryTeal,
    required Map<String, dynamic> raw,
    String? reason,
  }) {
    const double notchPosition = 100.0;
    const double cardHeight = 84.0;

    return GestureDetector(
      onTap: () {
        Haptics.light();
        _applyCoupon(code);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: cardHeight,
        child: Stack(
          children: [
            // Custom Clipped Ticket Background & Border
            ClipPath(
              clipper: _TicketClipper(notchPosition: notchPosition),
              child: Container(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
              ),
            ),
            CustomPaint(
              size: const Size(double.infinity, cardHeight),
              painter: _TicketBorderPainter(
                notchPosition: notchPosition,
                borderColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),

            // Content inside the ticket card
            Row(
              children: [
                // Left Ticket Code Box
                Container(
                  width: notchPosition,
                  height: cardHeight,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF112E2A)
                        : const Color(0xFFE6F7F5),
                  ),
                  child: Center(
                    child: Text(
                      code,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: primaryTeal,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                // Dashed Vertical Separator Line
                CustomPaint(
                  size: const Size(1, cardHeight),
                  painter: _DashedLinePainter(
                    color: primaryTeal.withValues(alpha: 0.4),
                  ),
                ),

                // Right Details Column
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              discount,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),

                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isFirstOrderOnly) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: primaryTeal,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      'FIRST ORDER',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        color: primaryTeal,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],

                                // Radio Selection Indicator Button
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? primaryTeal
                                          : (isDark
                                              ? const Color(0xFF475569)
                                              : const Color(0xFFCBD5E1)),
                                      width: 1.8,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: primaryTeal,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          // Backend terms text is free-form; a second line
                          // overflows this fixed-height ticket. Full text is
                          // in the details sheet.
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Only the attached code gets a pill, carrying the
                            // server's live refusal. The conditions already sit
                            // on the line above, so repeating them here would
                            // just be the same text twice.
                            if (reason != null)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEDD5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    reason,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFEA580C),
                                    ),
                                  ),
                                ),
                              )
                            else
                              const SizedBox.shrink(),
                            const SizedBox(width: 6),

                            GestureDetector(
                              onTap: () => showOfferDetailsSheet(context, raw),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View details',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: primaryTeal,
                                    ),
                                  ),
                                  const SizedBox(width: 1),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 13,
                                    color: primaryTeal,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 4. For First Time Users Section — only shown when a real first-order
  /// coupon exists in the backend's offer list.
  Widget _buildFirstTimeUsersSection(bool isDark, Color primaryTeal) {
    final async = ref.watch(offersProvider);
    final rawOffers = async.asData?.value ?? const [];
    final coupons = _couponsFrom(rawOffers.map((e) => Map<String, dynamic>.from(e)).toList());
    final firstOrderCoupon = coupons.cast<Map<String, dynamic>?>().firstWhere(
          (c) => c!['isFirstOrderOnly'] == true,
          orElse: () => null,
        );
    if (firstOrderCoupon == null) return const SizedBox.shrink();

    final code = firstOrderCoupon['code'].toString();
    final discount = firstOrderCoupon['discount'].toString();
    final subtitle = firstOrderCoupon['subtitle'].toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'For First Time Users',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Gift Icon Box
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? primaryTeal.withValues(alpha: 0.2)
                      : const Color(0xFFE6F7F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.card_giftcard_rounded,
                  color: primaryTeal,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      code,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: primaryTeal,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      discount,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Apply Button (Outlined)
              GestureDetector(
                onTap: () => _applyCoupon(code),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: primaryTeal,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    'Apply',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: primaryTeal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 5. How it works Explainer Box
  Widget _buildHowItWorksBox(bool isDark, Color primaryTeal) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF4FAF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryTeal.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.info_outline_rounded,
              color: primaryTeal,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How it works?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Choose a code, apply it at checkout and the discount will be applied to your order.',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Custom Shopping Bag + Tag Graphic matching screenshot
          _buildHowItWorksGraphic(primaryTeal),
        ],
      ),
    );
  }

  /// Custom Vector Illustration for "How it works?" matching screenshot
  Widget _buildHowItWorksGraphic(Color primaryTeal) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sparkle stars
          Positioned(
            top: 2,
            left: 4,
            child: Text('✦', style: TextStyle(fontSize: 9, color: primaryTeal.withValues(alpha: 0.6))),
          ),
          Positioned(
            bottom: 4,
            right: 2,
            child: Text('✨', style: TextStyle(fontSize: 8, color: primaryTeal.withValues(alpha: 0.6))),
          ),

          // Shopping bag container
          Positioned(
            right: 0,
            bottom: 2,
            child: Container(
              width: 32,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F7F5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryTeal.withValues(alpha: 0.3), width: 1),
              ),
            ),
          ),

          // Discount Tag
          Positioned(
            left: 2,
            top: 10,
            child: Transform.rotate(
              angle: -0.2,
              child: Container(
                width: 26,
                height: 30,
                decoration: BoxDecoration(
                  color: primaryTeal,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Text(
                    '%',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Clipper for Coupon Ticket with top and bottom notches
class _TicketClipper extends CustomClipper<Path> {
  final double notchPosition;

  _TicketClipper({required this.notchPosition});

  @override
  Path getClip(Size size) {
    const double notchRadius = 6.0;
    final path = Path();
    path.moveTo(0, 0);

    // Top edge to top notch
    path.lineTo(notchPosition - notchRadius, 0);
    path.arcToPoint(
      Offset(notchPosition + notchRadius, 0),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(size.width, 0);

    // Right edge
    path.lineTo(size.width, size.height);

    // Bottom edge to bottom notch
    path.lineTo(notchPosition + notchRadius, size.height);
    path.arcToPoint(
      Offset(notchPosition - notchRadius, size.height),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(0, size.height);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldDelegate) => true;
}

/// Custom Border Painter along the ticket notch path
class _TicketBorderPainter extends CustomPainter {
  final double notchPosition;
  final Color borderColor;

  _TicketBorderPainter({
    required this.notchPosition,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double notchRadius = 6.0;
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(notchPosition - notchRadius, 0);
    path.arcToPoint(
      Offset(notchPosition + notchRadius, 0),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(notchPosition + notchRadius, size.height);
    path.arcToPoint(
      Offset(notchPosition - notchRadius, size.height),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom Vertical Dashed Line Painter for Coupon Tickets
class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    double dashHeight = 4, dashSpace = 3, startY = 4;
    while (startY < size.height - 4) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
