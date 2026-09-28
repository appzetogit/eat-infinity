import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/addons/domain/addon_model.dart';
import 'package:food_user_application/features/addons/presentation/controllers/addon_controller.dart';
import 'package:food_user_application/features/addons/presentation/widgets/addon_form_sheet.dart';
import 'package:food_user_application/features/menu_items/domain/food_item_model.dart';
import 'package:food_user_application/features/menu_items/domain/menu_section_model.dart';
import 'package:food_user_application/features/menu_items/presentation/controllers/menu_controller.dart';
import 'package:food_user_application/features/menu_items/presentation/widgets/food_item_form_sheet.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';
import 'package:food_user_application/core/widgets/app_drawer.dart';

enum _StockFilter { all, inStock, outOfStock }

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  bool _isItemsTab = true;
  String _search = '';
  _StockFilter _stockFilter = _StockFilter.all;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<({MenuSectionModel section, List<FoodItemModel> items})> _filterSections(
    List<MenuSectionModel> sections,
  ) {
    return sections
        .map((section) {
          final matchesSectionName = section.name.toLowerCase().contains(
            _search,
          );
          final items = section.items.where((item) {
            final matchesSearch =
                _search.isEmpty ||
                matchesSectionName ||
                item.name.toLowerCase().contains(_search);
            final matchesStock = switch (_stockFilter) {
              _StockFilter.all => true,
              _StockFilter.inStock => item.isAvailable,
              _StockFilter.outOfStock => !item.isAvailable,
            };
            return matchesSearch && matchesStock;
          }).toList();
          return (section: section, items: items);
        })
        .where((entry) => entry.items.isNotEmpty)
        .toList();
  }

  List<AddonModel> _filterAddons(List<AddonModel> addons) {
    return addons
        .where((a) => _search.isEmpty || a.name.toLowerCase().contains(_search))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuControllerProvider);
    final addonsAsync = ref.watch(addonControllerProvider);

    final totalItems =
        menuAsync.value?.fold<int>(
          0,
          (sum, section) => sum + section.items.length,
        ) ??
        0;
    final totalAddons = addonsAsync.value?.length ?? 0;
    final focusedItemsCount = menuAsync.value == null
        ? totalItems
        : _filterSections(
            menuAsync.value!,
          ).fold<int>(0, (sum, entry) => sum + entry.items.length);
    final focusedAddonsCount = addonsAsync.value == null
        ? totalAddons
        : _filterAddons(addonsAsync.value!).length;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const AppDrawer(),
      appBar: _buildAppBar(context),
      floatingActionButton: Padding(
        // Lifts the FAB clear of the app's floating bottom nav bar, which
        // lives outside this Scaffold and would otherwise overlap/hide it.
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton.extended(
          onPressed: () {
            if (_isItemsTab) {
              showFoodItemFormSheet(context);
            } else {
              showAddonFormSheet(context);
            }
          },
          icon: const Icon(Icons.add),
          label: Text(
            _isItemsTab ? 'Add item' : 'Add add-on',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      ),
      body: AppRefreshIndicator(
        onRefresh: () async {
          await ref.read(menuControllerProvider.notifier).refresh();
          await ref.read(addonControllerProvider.notifier).refresh();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopTabs(context, totalItems, totalAddons),
              const SizedBox(height: 16),
              _buildSearchAndFilters(
                context,
                focusedItemsCount,
                focusedAddonsCount,
              ),
              const SizedBox(height: 16),
              if (_isItemsTab)
                _buildItemsBody(context, menuAsync)
              else
                _buildAddonsBody(context, addonsAsync),
              const SizedBox(height: 120), // clearance for the FAB and nav bar
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final restaurant = ref.watch(restaurantProfileControllerProvider).value;
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      titleSpacing: 16,
      toolbarHeight: 70,
      title: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                Icons.restaurant,
                color: Theme.of(context).cardColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  restaurant?.restaurantName ?? '—',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        restaurant?.fullAddress.isNotEmpty == true
                            ? restaurant!.fullAddress
                            : 'Address not set',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

  Widget _buildTopTabs(BuildContext context, int totalItems, int totalAddons) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              context,
              'All items',
              totalItems,
              _isItemsTab,
              () => setState(() => _isItemsTab = true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTabButton(
              context,
              'Add-ons',
              totalAddons,
              !_isItemsTab,
              () => setState(() => _isItemsTab = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context,
    String label,
    int count,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(30),
          border: isSelected
              ? null
              : Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.surfaceVariantDark
                      : AppColors.surfaceVariantLight,
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.primary
                    : (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.surfaceVariantDark
                          : AppColors.surfaceVariantLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primaryDark
                      : (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(
    BuildContext context,
    int focusedItemsCount,
    int focusedAddonsCount,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search and manage menu inventory',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _isItemsTab
                ? '$focusedItemsCount item(s) in focus'
                : '$focusedAddonsCount add-on(s) in focus',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (value) =>
                setState(() => _search = value.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: _isItemsTab
                  ? 'Search categories or menu items'
                  : 'Search add-ons',
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                    ),
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfaceVariantDark
                  : AppColors.backgroundLight,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          if (_isItemsTab) ...[
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(context, 'All', _StockFilter.all),
                  const SizedBox(width: 8),
                  _buildFilterChip(context, 'In stock', _StockFilter.inStock),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    context,
                    'Out of stock',
                    _StockFilter.outOfStock,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    _StockFilter filter,
  ) {
    final isSelected = _stockFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _stockFilter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.surfaceVariantDark
                    : AppColors.backgroundLight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.surfaceVariantLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondaryLight,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildItemsBody(
    BuildContext context,
    AsyncValue<List<MenuSectionModel>> menuAsync,
  ) {
    return menuAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          error is ApiException ? error.message : 'Failed to load menu.',
          textAlign: TextAlign.center,
        ),
      ),
      data: (sections) {
        final filteredSections = _filterSections(sections);

        if (sections.isEmpty) {
          return _buildEmptyCard(
            context,
            'No menu items yet. Tap "Add item" to create your first one.',
          );
        }
        if (filteredSections.isEmpty) {
          return _buildEmptyCard(context, 'No items match your search/filter.');
        }

        return Column(
          children: [
            for (final entry in filteredSections) ...[
              _buildCategorySection(context, entry.section, entry.items),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEmptyCard(BuildContext context, String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    MenuSectionModel section,
    List<FoodItemModel> items,
  ) {
    final availableCount = items.where((i) => i.isAvailable).length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  section.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length} item${items.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              availableCount == items.length
                  ? 'All visible items are in stock'
                  : '$availableCount of ${items.length} item(s) in stock',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < items.length; i++) ...[
            _buildItemCard(context, items[i]),
            if (i < items.length - 1)
              Divider(
                height: 32,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.surfaceVariantDark
                    : AppColors.surfaceVariantLight,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, FoodItemModel item) {
    final statusColor = switch (item.approvalStatus) {
      'approved' => AppColors.primary,
      'rejected' => AppColors.error,
      _ => AppColors.warning,
    };

    return GestureDetector(
      onTap: () => showFoodItemFormSheet(context, existing: item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.stop_circle_outlined,
                      color: item.isVeg ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.isVeg ? 'Veg' : 'Non-Veg',
                      style: TextStyle(
                        color: item.isVeg ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    item.approvalStatus[0].toUpperCase() +
                        item.approvalStatus.substring(1),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.isAvailable ? 'In stock' : 'Out of stock',
                  style: TextStyle(
                    color: item.isAvailable
                        ? AppColors.primary
                        : AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Amount: ₹${item.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (item.isPending) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Pending admin approval',
                    style: TextStyle(color: AppColors.warning, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              Switch(
                value: item.isAvailable,
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.green,
                onChanged: (value) async {
                  try {
                    await ref
                        .read(menuControllerProvider.notifier)
                        .toggleAvailability(item.id, value);
                  } catch (e) {
                    if (context.mounted) _showError(context, e);
                  }
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                tooltip: 'Edit item',
                onPressed: () => showFoodItemFormSheet(context, existing: item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddonsBody(
    BuildContext context,
    AsyncValue<List<AddonModel>> addonsAsync,
  ) {
    return addonsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          error is ApiException ? error.message : 'Failed to load add-ons.',
          textAlign: TextAlign.center,
        ),
      ),
      data: (addons) {
        final filtered = _filterAddons(addons);
        if (addons.isEmpty) {
          return _buildEmptyCard(
            context,
            'No add-ons yet. Tap "Add add-on" to create your first one.',
          );
        }
        if (filtered.isEmpty) {
          return _buildEmptyCard(context, 'No add-ons match your search.');
        }
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < filtered.length; i++) ...[
                _buildAddonCard(context, filtered[i]),
                if (i < filtered.length - 1)
                  Divider(
                    height: 32,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.surfaceVariantDark
                        : AppColors.surfaceVariantLight,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddonCard(BuildContext context, AddonModel addon) {
    final statusColor = switch (addon.approvalStatus) {
      'approved' => AppColors.primary,
      'rejected' => AppColors.error,
      _ => AppColors.warning,
    };

    return GestureDetector(
      onTap: () => showAddonFormSheet(context, existing: addon),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        addon.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.stop_circle_outlined,
                      color: addon.isVeg ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      addon.isVeg ? 'Veg' : 'Non-Veg',
                      style: TextStyle(
                        color: addon.isVeg ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    addon.approvalStatus[0].toUpperCase() +
                        addon.approvalStatus.substring(1),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Amount: ₹${addon.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Switch(
                value: addon.isAvailable,
                activeThumbColor: Colors.white,
                activeTrackColor: Colors.green,
                onChanged: (value) async {
                  try {
                    await ref
                        .read(addonControllerProvider.notifier)
                        .toggleAvailability(addon.id, value);
                  } catch (e) {
                    if (context.mounted) _showError(context, e);
                  }
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                tooltip: 'Edit add-on',
                onPressed: () => showAddonFormSheet(context, existing: addon),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                  size: 20,
                ),
                onPressed: () => _confirmDeleteAddon(context, addon),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAddon(
    BuildContext context,
    AddonModel addon,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete add-on?'),
        content: Text('This will permanently remove "${addon.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(addonControllerProvider.notifier).delete(addon.id);
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  void _showError(BuildContext context, Object error) {
    final message = error is ApiException
        ? error.message
        : 'Something went wrong. Please try again.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }
}
