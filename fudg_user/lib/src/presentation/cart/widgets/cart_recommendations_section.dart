import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/food_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/smart_image.dart';
import '../../home/viewmodels/veg_filter_provider.dart';
import '../../restaurant/widgets/food_detail_sheet.dart';
import 'package:go_router/go_router.dart';
import '../../../di/restaurant_providers.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/cart_viewmodel.dart';

final cartRecommendationsProvider = FutureProvider.family<List<FoodModel>, String>((ref, restaurantId) async {
  final repository = ref.watch(restaurantRepositoryProvider);
  if (restaurantId.isNotEmpty) {
    final menuRes = await repository.getRestaurantMenu(restaurantId);
    if (menuRes.isSuccess && menuRes.data != null && menuRes.data!.isNotEmpty) {
      return menuRes.data!;
    }
  }
  final popularRes = await repository.getPopularFoods();
  if (popularRes.isSuccess && popularRes.data != null) {
    return popularRes.data!;
  }
  return const [];
});

class CartRecommendationsSection extends ConsumerStatefulWidget {
  final String restaurantId;
  final GlobalKey? targetCartKey;

  const CartRecommendationsSection({
    super.key,
    required this.restaurantId,
    this.targetCartKey,
  });

  @override
  ConsumerState<CartRecommendationsSection> createState() => _CartRecommendationsSectionState();
}

class _CartRecommendationsSectionState extends ConsumerState<CartRecommendationsSection> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVegOnly = ref.watch(vegFilterProvider);
    final recommendationsAsync = ref.watch(cartRecommendationsProvider(widget.restaurantId));

    return recommendationsAsync.when(
      data: (rawItems) {
        if (rawItems.isEmpty) return const SizedBox.shrink();

        final inCart = ref
            .watch(cartViewModelProvider)
            .items
            .map((line) => line.food.id)
            .toSet();

        final displayItems = (isVegOnly ? rawItems.where((f) => f.isVeg) : rawItems)
            .where((f) => !inCart.contains(f.id))
            .take(10)
            .toList();

        if (displayItems.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Sparkle Icon + Title "You might also like" & "View All >"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFFF41222)),
                    SizedBox(width: 6),
                    Text(
                      'You might also like',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Haptics.light();
                    if (widget.restaurantId.isNotEmpty) {
                      context.push('${RouteNames.restaurantDetail}/${widget.restaurantId}');
                    } else {
                      context.push(RouteNames.search);
                    }
                  },
                  child: Row(
                    children: const [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF41222),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFFF41222)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Horizontal Scrollable Cards with full-width top image
            SizedBox(
              height: 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: displayItems.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final food = displayItems[index];
                  return _RecommendationCardItem(food: food, isDark: isDark);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}

class _RecommendationCardItem extends ConsumerWidget {
  final FoodModel food;
  final bool isDark;

  const _RecommendationCardItem({
    required this.food,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBestseller = food.isPopular;

    return Container(
      width: 135,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Full-width top image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            child: SizedBox(
              width: 135,
              height: 82,
              child: SmartImage(
                url: food.imageUrl,
                category: ImageCategory.food,
                width: 135,
                height: 82,
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Details area below image
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  food.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                if (isBestseller)
                  Container(
                    margin: const EdgeInsets.only(bottom: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Bestseller',
                      style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w800, color: Color(0xFF0284C7)),
                    ),
                  )
                else
                  const SizedBox(height: 2),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${food.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),

                    // ADD + Button
                    GestureDetector(
                      onTap: () {
                        Haptics.medium();
                        if (food.variants.isNotEmpty) {
                          FoodDetailSheet.show(context, food);
                        } else {
                          ref.read(cartViewModelProvider.notifier).addItem(food);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF41222), width: 1.1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'ADD',
                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Color(0xFFF41222)),
                            ),
                            SizedBox(width: 1),
                            Icon(Icons.add, size: 9, color: Color(0xFFF41222)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
