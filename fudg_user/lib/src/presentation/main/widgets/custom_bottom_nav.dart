import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../orders/viewmodels/active_order_viewmodel.dart';

class CustomBottomNav extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // `select` so the bar only repaints when an order starts or finishes,
    // not on every status poll while one is in flight.
    final hasActiveOrder = ref.watch(
      activeOrderViewModelProvider.select((s) => s.activeOrder != null),
    );

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: 84 + bottomPadding,
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: Row(
        children: [
          // 1. Home (Index 0)
          _buildNavItem(
            context: context,
            icon: currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
            label: 'Home',
            index: 0,
            isDark: isDark,
          ),

          // 2. Search (Index 1)
          _buildNavItem(
            context: context,
            icon: Icons.search_rounded,
            label: 'Search',
            index: 1,
            isDark: isDark,
          ),

          // 3. Orders (Index 2)
          _buildNavItem(
            context: context,
            icon: currentIndex == 2 ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined,
            label: 'Orders',
            index: 2,
            isDark: isDark,
            badgeCount: hasActiveOrder ? 1 : 0,
          ),

          // 4. Offers (Index 3)
          _buildNavItem(
            context: context,
            icon: currentIndex == 3 ? Icons.local_offer_rounded : Icons.local_offer_outlined,
            label: 'Offers',
            index: 3,
            isDark: isDark,
          ),

          // 5. Account (Index 4)
          _buildNavItem(
            context: context,
            icon: currentIndex == 4 ? Icons.person_rounded : Icons.person_outline_rounded,
            label: 'Account',
            index: 4,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
    required bool isDark,
    int badgeCount = 0,
  }) {
    final isSelected = currentIndex == index;
    final activeColor = AppColors.primary;
    final unselectedColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          Haptics.light();
          onTap(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected ? activeColor : unselectedColor,
                  size: 24,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '$badgeCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : unselectedColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
