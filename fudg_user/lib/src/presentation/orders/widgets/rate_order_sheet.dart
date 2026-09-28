import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/order_model.dart';
import '../../../core/services/review_service.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../common_widgets/smart_image.dart';
import '../viewmodels/orders_viewmodel.dart';

/// Rates a delivered order: the restaurant, and the partner who brought it.
///
/// Both go in one submission because the backend takes them together and
/// refuses a second — rating them on separate screens would mean whichever
/// was sent first locked the other out forever.
class RateOrderSheet {
  const RateOrderSheet._();

  /// [initialDeliveryRating] pre-selects the partner's stars, so tapping a
  /// star on the delivered screen carries that choice straight into the sheet.
  static Future<bool?> show(
    BuildContext context,
    OrderModel order, {
    int initialDeliveryRating = 0,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RateOrderSheetBody(
        order: order,
        initialDeliveryRating: initialDeliveryRating,
      ),
    );
  }
}

class _RateOrderSheetBody extends ConsumerStatefulWidget {
  const _RateOrderSheetBody({
    required this.order,
    this.initialDeliveryRating = 0,
  });

  final OrderModel order;
  final int initialDeliveryRating;

  @override
  ConsumerState<_RateOrderSheetBody> createState() => _RateOrderSheetBodyState();
}

class _RateOrderSheetBodyState extends ConsumerState<_RateOrderSheetBody> {
  int _restaurantRating = 0;
  late int _deliveryRating = widget.initialDeliveryRating;
  final _restaurantComment = TextEditingController();
  final _deliveryComment = TextEditingController();
  bool _submitting = false;

  /// Per-dish scores, keyed by itemId. Optional throughout: the server accepts
  /// a rating with none of these, so a customer is never made to score every
  /// dish just to rate the order.
  final Map<String, int> _itemRatings = {};
  final Map<String, TextEditingController> _itemComments = {};

  /// One entry per distinct dish. An order can list the same itemId twice
  /// (different variants), and the server rejects a dish rated twice.
  List<OrderItem> get _rateableItems {
    final seen = <String>{};
    return widget.order.items
        .where((i) => i.itemId.isNotEmpty && seen.add(i.itemId))
        .toList();
  }

  TextEditingController _commentFor(String itemId) =>
      _itemComments.putIfAbsent(itemId, TextEditingController.new);

  /// Only orders that actually had a partner assigned can rate one — the
  /// server rejects a delivery rating otherwise, and requires one when there
  /// was a partner.
  bool get _hasPartner => widget.order.deliveryPartner != null;

  bool get _canSubmit =>
      _restaurantRating > 0 && (!_hasPartner || _deliveryRating > 0);

  @override
  void dispose() {
    _restaurantComment.dispose();
    _deliveryComment.dispose();
    for (final c in _itemComments.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);
    Haptics.medium();

    final error = await ref.read(ordersViewModelProvider.notifier).submitRating(
          widget.order.id,
          restaurantRating: _restaurantRating,
          deliveryPartnerRating: _hasPartner ? _deliveryRating : null,
          restaurantComment: _restaurantComment.text.trim().isEmpty
              ? null
              : _restaurantComment.text.trim(),
          deliveryPartnerComment: _deliveryComment.text.trim().isEmpty
              ? null
              : _deliveryComment.text.trim(),
          itemRatings: _itemRatings.isEmpty
              ? null
              : _itemRatings.entries.map((e) {
                  final comment = _itemComments[e.key]?.text.trim() ?? '';
                  return {
                    'itemId': e.key,
                    'rating': e.value,
                    if (comment.isNotEmpty) 'comment': comment,
                  };
                }).toList(),
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      AppSnackbar.error(context, error);
      return;
    }

    // Only ask for a store review off the back of a happy one.
    ReviewService.requestReviewIfQualified(_restaurantRating);
    Navigator.of(context).pop(true);
    AppSnackbar.success(context, 'Thanks for your feedback!');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final order = widget.order;
    final partner = order.deliveryPartner;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Rate your order',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Your feedback helps everyone do better',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),

              _RatingBlock(
                isDark: isDark,
                title: order.restaurantName.isEmpty
                    ? 'The restaurant'
                    : order.restaurantName,
                subtitle: 'How was the food?',
                imageUrl: order.restaurantImage,
                fallbackIcon: Icons.storefront_rounded,
                rating: _restaurantRating,
                onRate: (value) => setState(() => _restaurantRating = value),
                controller: _restaurantComment,
                hint: 'Tell us about the food (optional)',
              ),

              if (_hasPartner) ...[
                const SizedBox(height: 18),
                _RatingBlock(
                  isDark: isDark,
                  title: (partner?.name.isEmpty ?? true)
                      ? 'Your delivery partner'
                      : partner!.name,
                  subtitle: 'How was the delivery?',
                  imageUrl: partner?.photoUrl ?? '',
                  fallbackIcon: Icons.two_wheeler_rounded,
                  rating: _deliveryRating,
                  onRate: (value) => setState(() => _deliveryRating = value),
                  controller: _deliveryComment,
                  hint: 'Tell us about the delivery (optional)',
                ),
              ],

              if (_rateableItems.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Rate items',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Optional — skip any dish you would rather not score',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 10),
                ..._rateableItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RatingBlock(
                      isDark: isDark,
                      title: item.name,
                      subtitle: 'Qty ${item.quantity}',
                      imageUrl: item.imageUrl,
                      fallbackIcon: Icons.restaurant_menu_rounded,
                      rating: _itemRatings[item.itemId] ?? 0,
                      onRate: (value) =>
                          setState(() => _itemRatings[item.itemId] = value),
                      controller: _commentFor(item.itemId),
                      hint: 'Comment on this dish (optional)',
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _canSubmit && !_submitting ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Submit Rating',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One rateable subject: who it is, its stars, and an optional comment.
class _RatingBlock extends StatelessWidget {
  const _RatingBlock({
    required this.isDark,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.fallbackIcon,
    required this.rating,
    required this.onRate,
    required this.controller,
    required this.hint,
  });

  final bool isDark;
  final String title;
  final String subtitle;
  final String imageUrl;
  final IconData fallbackIcon;
  final int rating;
  final ValueChanged<int> onRate;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: imageUrl.isNotEmpty
                      ? SmartImage(
                          url: imageUrl,
                          category: ImageCategory.restaurant,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: AppColors.primaryAlpha(0.12),
                          child: Icon(fallbackIcon, size: 20, color: AppColors.primary),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final value = index + 1;
              final filled = value <= rating;
              return GestureDetector(
                onTap: () {
                  Haptics.light();
                  onRate(value);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 34,
                    color: filled ? const Color(0xFFFFB800) : const Color(0xFFCBD5E1),
                  ),
                ),
              );
            }),
          ),
          if (rating > 0) ...[
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLength: 500,
              maxLines: 2,
              minLines: 1,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: hint,
                counterText: '',
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
