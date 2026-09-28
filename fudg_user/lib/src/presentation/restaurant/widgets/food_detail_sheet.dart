import 'package:flutter/material.dart';
import '../../../data/models/food_variant.dart';
import '../../../di/catalog_providers.dart';
import '../../common_widgets/smart_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/food_model.dart';
import '../../branding/app_colors.dart';
import '../../cart/utils/cart_restaurant_guard.dart';

class FoodDetailSheet {
  const FoodDetailSheet._();

  static Future<void> show(
    BuildContext context,
    FoodModel? food, {
    VoidCallback? onAdded,
    String? restaurantName,
    dynamic existingCartItem,
    bool autoScrollToOptions = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FoodDetailSheetBody(
        food: food,
        onAdded: onAdded,
      ),
    );
  }
}

class _FoodDetailSheetBody extends ConsumerStatefulWidget {
  final FoodModel? food;
  final VoidCallback? onAdded;

  const _FoodDetailSheetBody({
    this.food,
    this.onAdded,
  });

  @override
  ConsumerState<_FoodDetailSheetBody> createState() => _FoodDetailSheetBodyState();
}

class _FoodDetailSheetBodyState extends ConsumerState<_FoodDetailSheetBody> {
  int _quantity = 1;

  /// Base price: the dish's real price.
  double get _itemPrice => widget.food?.price ?? 0;

  /// Sum of the chosen add-ons, priced from the backend's addon list.
  double get _addonsTotal {
    final rid = widget.food?.restaurantId ?? '';
    if (rid.isEmpty) return 0;
    final addons =
        ref.read(restaurantAddonsProvider(rid)).asData?.value ??
            const <FoodAddon>[];
    var total = 0.0;
    for (final a in addons) {
      total += (_addonCounts[a.id] ?? 0) * a.price;
    }
    return total;
  }

  double get _finalTotal => (_itemPrice + _addonsTotal) * _quantity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Dish Image + Title + Price + Close Button
                  _buildHeaderRow(context),

                  if ((widget.food?.description ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.food!.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 16),

                  // Section 1: Quantity
                  _buildQuantitySection(),

                  // Section 2: Choose Add-ons — only when the backend
                  // actually has add-ons for this restaurant.
                  if (_hasAddons(ref)) ...[
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                    const SizedBox(height: 16),
                    _buildAddonsSection(),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Floating Action Bar
          _buildBottomActionBar(context),
        ],
      ),
    );
  }

  /// Top Header: large dish image with a floating close button, then
  /// title/price/badges below it — matches a product-detail card layout
  /// instead of a small thumbnail-beside-text row.
  Widget _buildHeaderRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SmartImage(
                url: widget.food?.imageUrl ?? '',
                category: ImageCategory.food,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.close_rounded, color: AppColors.primary, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF16A34A), width: 1.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF16A34A)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.food?.name ?? '',
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (widget.food?.isPopular == true) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Bestseller',
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Text(
              '₹${(widget.food?.price ?? 0).toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            if (widget.food?.originalPrice != null) ...[
              const SizedBox(width: 6),
              Text(
                '₹${widget.food!.originalPrice!.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), decoration: TextDecoration.lineThrough),
              ),
            ],
            if (widget.food?.discountPercent != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${widget.food!.discountPercent}% OFF',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 1. Quantity Section
  Widget _buildQuantitySection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '1. Quantity',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),

        // Counter Control
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  if (_quantity > 1) setState(() => _quantity--);
                },
                child: Icon(Icons.remove, size: 16, color: AppColors.primary),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '$_quantity',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  setState(() => _quantity++);
                },
                child: Icon(Icons.add, size: 16, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _hasAddons(WidgetRef ref) {
    final rid = widget.food?.restaurantId ?? '';
    if (rid.isEmpty) return false;
    return (ref.watch(restaurantAddonsProvider(rid)).asData?.value ??
            const <FoodAddon>[])
        .isNotEmpty;
  }

  /// 2. Choose Add-ons (Optional)
  Widget _buildAddonsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '2. Choose Add-ons',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            Text(
              '(Optional)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Real add-ons for this restaurant (GET /food/restaurant/:id/addons).
        // Counts are keyed by addon id instead of one field per hardcoded item.
        ...() {
          final rid = widget.food?.restaurantId ?? '';
          if (rid.isEmpty) return const <Widget>[];
          final addons =
              ref.watch(restaurantAddonsProvider(rid)).asData?.value ??
                  const <FoodAddon>[];
          return addons.map((a) {
            final count = _addonCounts[a.id] ?? 0;
            return _buildAddonItemRow(
              title: a.name,
              subtitle: a.description.isNotEmpty ? a.description : null,
              price: '₹${a.price.toStringAsFixed(0)}',
              count: count,
              onIncrement: () =>
                  setState(() => _addonCounts[a.id] = count + 1),
              onDecrement: () => setState(() {
                if (count > 0) _addonCounts[a.id] = count - 1;
              }),
            );
          }).toList();
        }(),
      ],
    );
  }

  /// Selected quantity per add-on id.
  final Map<String, int> _addonCounts = {};

  Widget _buildAddonItemRow({
    required String title,
    String? subtitle,
    required String price,
    required int count,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    final isSelected = count > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        children: [
          // Checkbox Icon
          GestureDetector(
            onTap: isSelected ? onDecrement : onIncrement,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
            ),
          ),
          const SizedBox(width: 12),

          // Title & Subtitle Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          ),

          // Price Label
          Text(
            price,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(width: 12),

          // Counter Box
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onDecrement,
                  child: Icon(Icons.remove, size: 14, color: AppColors.primary),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '$count',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ),
                GestureDetector(
                  onTap: onIncrement,
                  child: Icon(Icons.add, size: 14, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom Floating Action Bar: the full-width Add to Cart button.
  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      // The Item Total / Add-ons / To Pay breakdown that used to sit beside
      // this button is the cart screen's job — repeating it crowded the bar,
      // and the button already carries the total.
      child: GestureDetector(
        onTap: () async {
          Haptics.medium();
          final food = widget.food;
          if (food == null) {
            Navigator.of(context).pop();
            return;
          }
          final rid = food.restaurantId;
          final addons = rid.isEmpty
              ? const <FoodAddon>[]
              : ref.read(restaurantAddonsProvider(rid)).asData?.value ??
                  const <FoodAddon>[];
          final selected =
              addons.where((a) => (_addonCounts[a.id] ?? 0) > 0).toList();
          await addFoodToCart(
            context,
            ref,
            food,
            quantity: _quantity,
            selectedAddons: selected.map((a) => a.id).toList(),
            selectedAddonsPrice: _addonsTotal,
            selectedAddonDetails: selected,
            fromBottomSheet: true,
          );
          if (context.mounted) Navigator.of(context).pop();
          widget.onAdded?.call();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Add to Cart',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 14, color: Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Text(
                '₹${_finalTotal.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
