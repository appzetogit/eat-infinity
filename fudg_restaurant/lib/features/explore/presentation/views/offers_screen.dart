import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/offers/domain/offer_model.dart';
import 'package:food_user_application/features/offers/presentation/controllers/offer_controller.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';

/// A restaurant's coupons, split into those still running and those finished.
///
/// Each card's status, headline and results come from the server; the screen
/// only arranges them.
class OffersScreen extends ConsumerStatefulWidget {
  const OffersScreen({super.key});

  @override
  ConsumerState<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends ConsumerState<OffersScreen> {
  bool _showRunning = true;
  String? _busyId;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _muted => _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  Future<void> _openForm([String? offerId]) async {
    await context.push(offerId == null ? '/create-coupon' : '/edit-coupon/$offerId');
    if (mounted) ref.read(offerControllerProvider.notifier).refresh();
  }

  Future<void> _run(OfferModel offer, Future<void> Function() action, String done) async {
    setState(() => _busyId = offer.id);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException ? e.message : 'Something went wrong.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _onMenu(OfferModel offer, String value) async {
    final controller = ref.read(offerControllerProvider.notifier);
    switch (value) {
      case 'edit':
        await _openForm(offer.id);
      case 'pause':
        await _run(offer, () => controller.setStatus(offer.id, 'paused'), 'Coupon paused');
      case 'resume':
        await _run(offer, () => controller.setStatus(offer.id, 'active'), 'Coupon resumed');
      case 'end':
        if (await _confirm(
          'End ${offer.couponCode}?',
          'Customers will no longer be able to use it. Its results are kept.',
          'End offer',
        )) {
          await _run(offer, () => controller.setStatus(offer.id, 'inactive'), 'Coupon ended');
        }
      case 'delete':
        if (await _confirm(
          'Delete ${offer.couponCode}?',
          'This permanently removes the coupon. It has never been used.',
          'Delete',
        )) {
          await _run(offer, () => controller.delete(offer.id), 'Coupon deleted');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final offersAsync = ref.watch(offerControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Offers & Coupons',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text('Discounts funded by your restaurant', style: TextStyle(color: _muted, fontSize: 13)),
          ],
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, color: Colors.white, size: 16),
                label: const Text('Add New', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
            ),
          ),
        ],
      ),
      body: AppRefreshIndicator(
        onRefresh: () => ref.read(offerControllerProvider.notifier).refresh(),
        child: offersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error is ApiException ? error.message : 'Failed to load offers.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          data: (offers) {
            final running = offers.where((o) => o.isRunning).toList();
            final past = offers.where((o) => !o.isRunning).toList();
            final shown = _showRunning ? running : past;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (offers.isNotEmpty) ...[
                  Row(
                    children: [
                      _tab('Running (${running.length})', _showRunning, () => setState(() => _showRunning = true)),
                      const SizedBox(width: 8),
                      _tab('Past (${past.length})', !_showRunning, () => setState(() => _showRunning = false)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
                    child: Text(
                      offers.isEmpty
                          ? 'No coupons yet. Offers like "50% off up to ₹100" bring in new customers and bigger orders. Tap "Add New" to create one.'
                          : _showRunning
                              ? 'No running coupons. Tap "Add New" to create one.'
                              : 'Ended and expired coupons appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted),
                    ),
                  )
                else
                  for (final offer in shown) ...[
                    Opacity(
                      opacity: _busyId == offer.id ? 0.5 : 1,
                      child: _buildCouponCard(context, offer),
                    ),
                    const SizedBox(height: 16),
                  ],
                const SizedBox(height: 64),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFF191F2C),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.onSurface
              : (_isDark ? AppColors.surfaceVariantDark : const Color(0xFFF1F2F6)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? Theme.of(context).scaffoldBackgroundColor : _muted,
          ),
        ),
      ),
    );
  }

  /// Label and colour for each server lifecycle state.
  (String, Color) _stateStyle(String state) => switch (state) {
        'live' => ('LIVE', AppColors.primary),
        'scheduled' => ('SCHEDULED', Colors.blue),
        'paused' => ('PAUSED', AppColors.warning),
        'exhausted' => ('LIMIT REACHED', Colors.grey),
        'expired' => ('EXPIRED', Colors.grey),
        _ => ('ENDED', Colors.grey),
      };

  String _rupees(double v) => '₹${NumberFormat.decimalPattern('en_IN').format(v.round())}';

  Widget _buildCouponCard(BuildContext context, OfferModel offer) {
    final dateFormat = DateFormat('d MMM yyyy');
    final (stateLabel, stateColor) = _stateStyle(offer.state);
    final dateRange =
        '${offer.startDate != null ? dateFormat.format(offer.startDate!) : 'Now'} → ${offer.endDate != null ? dateFormat.format(offer.endDate!) : 'No end date'}';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: offer.state == 'live' ? AppColors.primary : Colors.grey.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        stateLabel,
                        style: TextStyle(
                          color: stateColor == Colors.grey ? Colors.grey.shade700 : stateColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      enabled: _busyId != offer.id,
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      onSelected: (value) => _onMenu(offer, value),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        if (offer.canPause) const PopupMenuItem(value: 'pause', child: Text('Pause')),
                        if (offer.canResume) const PopupMenuItem(value: 'resume', child: Text('Resume')),
                        if (offer.isRunning)
                          const PopupMenuItem(
                            value: 'end',
                            child: Text('End offer', style: TextStyle(color: Colors.red)),
                          ),
                        if (offer.canDelete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  offer.displayHeadline,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (offer.conditions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(offer.conditions.join(' · '), style: TextStyle(color: _muted, fontSize: 12)),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Text(
                        offer.couponCode,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy code',
                      icon: const Icon(Icons.copy, size: 18, color: AppColors.primary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: offer.couponCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stat('REDEEMED', '${offer.usedCount}${offer.usageLimit != null ? ' / ${offer.usageLimit}' : ''}'),
                    _stat('CUSTOMERS', '${offer.results.customers}'),
                    _stat('SALES', _rupees(offer.results.sales)),
                    _stat('DISCOUNT', _rupees(offer.results.discountGiven)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: _muted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(dateRange, style: TextStyle(color: _muted, fontSize: 12))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
