import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/offers/data/offer_repository.dart';
import 'package:food_user_application/features/offers/domain/offer_model.dart';
import 'package:food_user_application/features/offers/presentation/controllers/offer_controller.dart';

/// Create a coupon, or edit one when [offerId] is given.
///
/// Mirrors the server's rules so a restaurant hears about a problem while
/// filling the form, not after tapping save -- but the server still decides,
/// and its message is shown as-is when it refuses.
class CreateCouponScreen extends ConsumerStatefulWidget {
  const CreateCouponScreen({super.key, this.offerId});

  final String? offerId;

  @override
  ConsumerState<CreateCouponScreen> createState() => _CreateCouponScreenState();
}

class _CreateCouponScreenState extends ConsumerState<CreateCouponScreen> {
  // Monday first, the way a restaurant reads its week; values are the server's
  // 0 = Sunday .. 6 = Saturday.
  static const _days = [
    (1, 'Mon'), (2, 'Tue'), (3, 'Wed'), (4, 'Thu'), (5, 'Fri'), (6, 'Sat'), (0, 'Sun'),
  ];
  static const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  bool _isPercentage = true;
  CouponAudience _audience = CouponAudience.everyone;
  final _couponCode = TextEditingController();
  final _discountValue = TextEditingController();
  final _minOrderValue = TextEditingController();
  final _maxDiscount = TextEditingController();
  final _usageLimit = TextEditingController();
  final _perUserLimit = TextEditingController(text: '1');
  DateTime? _startDate;
  DateTime? _endDate;
  final Set<int> _activeDays = {};
  bool _allDay = true;
  TimeOfDay _from = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 15, minute: 0);

  bool _isSaving = false;
  bool _isLoading = false;
  bool _codeLocked = false;
  int _usedCount = 0;

  bool get _isEdit => widget.offerId != null;

  @override
  void initState() {
    super.initState();
    for (final c in [_couponCode, _discountValue, _minOrderValue, _maxDiscount, _perUserLimit]) {
      // Keeps the live preview in step with what is typed.
      c.addListener(() => setState(() {}));
    }
    if (_isEdit) {
      _isLoading = true;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final o = await ref.read(offerRepositoryProvider).get(widget.offerId!);
      if (!mounted) return;
      String fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
      TimeOfDay? clock(String? s) {
        final parts = s?.split(':');
        if (parts == null || parts.length != 2) return null;
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        return (h == null || m == null) ? null : TimeOfDay(hour: h, minute: m);
      }

      setState(() {
        _couponCode.text = o.couponCode;
        _isPercentage = o.isPercentage;
        _discountValue.text = fmt(o.discountValue);
        _maxDiscount.text = o.maxDiscount == null ? '' : fmt(o.maxDiscount!);
        _minOrderValue.text = o.minOrderValue > 0 ? fmt(o.minOrderValue) : '';
        _usageLimit.text = o.usageLimit?.toString() ?? '';
        _perUserLimit.text = o.perUserLimit?.toString() ?? '';
        _audience = o.audience;
        _startDate = o.startDate;
        _endDate = o.endDate;
        _activeDays
          ..clear()
          ..addAll(o.activeDays);
        final from = clock(o.activeFromTime);
        final to = clock(o.activeToTime);
        _allDay = from == null || to == null;
        if (from != null) _from = from;
        if (to != null) _to = to;
        _codeLocked = !o.canChangeCode;
        _usedCount = o.usedCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showError(e is ApiException ? e.message : 'Could not load this coupon.');
      context.pop();
    }
  }

  @override
  void dispose() {
    _couponCode.dispose();
    _discountValue.dispose();
    _minOrderValue.dispose();
    _maxDiscount.dispose();
    _usageLimit.dispose();
    _perUserLimit.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? _today)
        : (_endDate ?? (_startDate ?? _today).add(const Duration(days: 30)));
    final first = isStart ? (_isEdit ? DateTime(2020) : _today) : (_startDate ?? _today);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(_today.year + 3),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime({required bool isFrom}) async {
    final picked = await showTimePicker(context: context, initialTime: isFrom ? _from : _to);
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    setState(() => _couponCode.text = List.generate(8, (_) => chars[r.nextInt(chars.length)]).join());
  }

  String _rupees(double v) => v == v.roundToDouble() ? '₹${v.toStringAsFixed(0)}' : '₹${v.toStringAsFixed(2)}';

  /// The same wording customers see, built from the form as it stands.
  ({String headline, List<String> conditions}) get _preview {
    final value = double.tryParse(_discountValue.text.trim()) ?? 0;
    final cap = double.tryParse(_maxDiscount.text.trim()) ?? 0;
    final min = double.tryParse(_minOrderValue.text.trim()) ?? 0;
    final perUser = int.tryParse(_perUserLimit.text.trim()) ?? 0;
    final headline = value <= 0
        ? 'Your offer'
        : _isPercentage
            ? '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}% OFF${cap > 0 ? ' up to ${_rupees(cap)}' : ''}'
            : '${_rupees(value)} OFF';

    final days = _activeDays.toList()..sort();
    String? dayText;
    if (days.isNotEmpty && days.length < 7) {
      final contiguous = days.length >= 3 &&
          List.generate(days.length, (i) => i).every((i) => i == 0 || days[i] == days[i - 1] + 1);
      dayText = contiguous
          ? '${_dayNames[days.first]}-${_dayNames[days.last]}'
          : days.map((d) => _dayNames[d]).join(', ');
    }

    return (
      headline: headline,
      conditions: [
        if (min > 0) 'on orders above ${_rupees(min)}',
        if (dayText != null) dayText,
        if (!_allDay) '${_hhmm(_from)}-${_hhmm(_to)}',
        if (_audience == CouponAudience.newToRestaurant) 'new customers only',
        if (_audience == CouponAudience.firstOrder) 'first order only',
        if (perUser == 1) 'once per customer',
        if (perUser > 1) '$perUser times per customer',
      ],
    );
  }

  Future<void> _submit() async {
    final code = _couponCode.text.trim().toUpperCase();
    final value = double.tryParse(_discountValue.text.trim());
    final cap = double.tryParse(_maxDiscount.text.trim());
    final min = double.tryParse(_minOrderValue.text.trim()) ?? 0;
    final usageText = _usageLimit.text.trim();
    final perUserText = _perUserLimit.text.trim();
    final usage = int.tryParse(usageText);
    final perUser = int.tryParse(perUserText);

    String? problem;
    if (!RegExp(r'^[A-Z0-9]{3,20}$').hasMatch(code)) {
      problem = 'Coupon code must be 3-20 letters or numbers, with no spaces or symbols.';
    } else if (value == null || value <= 0) {
      problem = 'Enter a valid discount.';
    } else if (_isPercentage && value > 100) {
      problem = 'A percentage discount cannot be more than 100%.';
    } else if (_isPercentage && (cap == null || cap <= 0)) {
      problem = 'Set the most a customer can save on a percentage coupon.';
    } else if (!_isPercentage && min <= value) {
      problem = 'For a flat discount, the minimum order must be more than ${_rupees(value)}, or small orders become free.';
    } else if (usageText.isNotEmpty && (usage == null || usage < 1)) {
      problem = 'Total redemptions must be a whole number, 1 or more.';
    } else if (perUserText.isNotEmpty && (perUser == null || perUser < 1)) {
      problem = 'Redemptions per customer must be a whole number, 1 or more.';
    } else if (usage != null && perUser != null && perUser > usage) {
      problem = 'Redemptions per customer cannot be more than total redemptions.';
    } else if (_isEdit && usage != null && usage < _usedCount) {
      problem = 'It has already been used $_usedCount times; set total redemptions to at least that.';
    } else if (_endDate == null) {
      problem = 'Select an end date.';
    } else if (_endDate!.isBefore(_today)) {
      // The end date covers that whole day, so today is still a valid end.
      problem = 'End date cannot be in the past.';
    } else if (_startDate != null && _endDate!.isBefore(_startDate!)) {
      problem = 'End date must be on or after the start date.';
    } else if (!_allDay && _hhmm(_from) == _hhmm(_to)) {
      problem = 'Start and end time cannot be the same.';
    }
    if (problem != null) {
      _showError(problem);
      return;
    }

    final draft = OfferDraft(
      couponCode: code,
      isPercentage: _isPercentage,
      discountValue: value!,
      maxDiscount: _isPercentage ? cap : null,
      minOrderValue: min,
      usageLimit: usage,
      perUserLimit: perUser,
      startDate: _startDate,
      endDate: _endDate!,
      audience: _audience,
      activeDays: (_activeDays.toList()..sort()),
      activeFromTime: _allDay ? null : _hhmm(_from),
      activeToTime: _allDay ? null : _hhmm(_to),
    );

    setState(() => _isSaving = true);
    try {
      final controller = ref.read(offerControllerProvider.notifier);
      if (_isEdit) {
        await controller.save(widget.offerId!, draft);
      } else {
        await controller.create(draft);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Coupon updated' : 'Coupon created and live for customers')),
        );
        context.pop();
      }
    } catch (e) {
      _showError(e is ApiException ? e.message : 'Failed to save coupon. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _muted => _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy');
    final preview = _preview;

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
              _isEdit ? 'Edit Coupon' : 'Create Coupon',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text('Funded by your restaurant', style: TextStyle(color: _muted, fontSize: 13)),
          ],
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildPreview(context, preview),
                  const SizedBox(height: 16),
                  _buildSection(
                    context: context,
                    title: 'DISCOUNT',
                    children: [
                      _buildLabelWithAsterisk(context, 'Coupon Code'),
                      if (_codeLocked)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Customers have used this code, so it cannot change.',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              context,
                              _couponCode,
                              hint: 'e.g. LUNCH50',
                              textCapitalization: TextCapitalization.characters,
                              enabled: !_codeLocked,
                              formatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                                LengthLimitingTextInputFormatter(20),
                              ],
                            ),
                          ),
                          if (!_codeLocked) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: _generateCode,
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Icon(Icons.auto_fix_high, size: 20),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildLabelWithAsterisk(context, 'Type'),
                      _buildChoiceRow(context, [
                        ('Percentage', _isPercentage, () => setState(() => _isPercentage = true)),
                        ('Flat amount', !_isPercentage, () => setState(() => _isPercentage = false)),
                      ]),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabelWithAsterisk(context, _isPercentage ? 'Discount %' : 'Discount ₹'),
                                _buildTextField(context, _discountValue,
                                    hint: _isPercentage ? 'e.g. 50' : 'e.g. 75',
                                    keyboardType: TextInputType.number),
                              ],
                            ),
                          ),
                          if (_isPercentage) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabelWithAsterisk(context, 'Max discount ₹'),
                                  _buildTextField(context, _maxDiscount,
                                      hint: 'e.g. 100', keyboardType: TextInputType.number),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      _isPercentage
                          ? _buildLabel(context, 'Minimum order ₹')
                          : _buildLabelWithAsterisk(context, 'Minimum order ₹'),
                      _buildTextField(context, _minOrderValue,
                          hint: _isPercentage ? 'Leave empty for no minimum' : 'More than the discount',
                          keyboardType: TextInputType.number),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context: context,
                    title: 'WHO CAN USE IT',
                    children: [
                      _buildAudienceOption(context, CouponAudience.everyone, 'Everyone',
                          'Any customer can use it'),
                      const SizedBox(height: 8),
                      _buildAudienceOption(context, CouponAudience.newToRestaurant, 'New to your restaurant',
                          'Customers who have never ordered from you'),
                      const SizedBox(height: 8),
                      _buildAudienceOption(context, CouponAudience.firstOrder, 'First order on the app',
                          'Customers placing their very first order'),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(context, 'Max per customer'),
                                _buildTextField(context, _perUserLimit,
                                    hint: 'Unlimited', keyboardType: TextInputType.number, integer: true),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(context, 'Total redemptions'),
                                _buildTextField(context, _usageLimit,
                                    hint: 'Unlimited', keyboardType: TextInputType.number, integer: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    context: context,
                    title: 'WHEN IT WORKS',
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel(context, 'Start date'),
                                _buildDateField(context, _startDate, dateFormat,
                                    () => _pickDate(isStart: true), placeholder: 'Starts now'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabelWithAsterisk(context, 'End date'),
                                _buildDateField(context, _endDate, dateFormat,
                                    () => _pickDate(isStart: false), placeholder: 'Select date'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildLabel(context, 'Days'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _days.map((d) {
                          final selected = _activeDays.contains(d.$1);
                          return ChoiceChip(
                            label: Text(d.$2),
                            selected: selected,
                            selectedColor: AppColors.primary.withValues(alpha: 0.15),
                            onSelected: (_) => setState(() {
                              if (selected) {
                                _activeDays.remove(d.$1);
                              } else {
                                _activeDays.add(d.$1);
                              }
                            }),
                          );
                        }).toList(),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _activeDays.isEmpty ? 'No days selected = every day' : 'Only on the selected days',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel(context, 'Hours'),
                      _buildChoiceRow(context, [
                        ('All day', _allDay, () => setState(() => _allDay = true)),
                        ('Specific hours', !_allDay, () => setState(() => _allDay = false)),
                      ]),
                      if (!_allDay) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildTimeField(context, 'From', _from, () => _pickTime(isFrom: true))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTimeField(context, 'To', _to, () => _pickTime(isFrom: false))),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'India time. An end before the start runs overnight, e.g. 22:00 to 02:00.',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              _isEdit ? 'Save changes' : 'Create coupon',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildPreview(BuildContext context, ({String headline, List<String> conditions}) preview) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CUSTOMERS WILL SEE',
              style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Text(
            preview.headline,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: 'Use code ',
              style: TextStyle(color: _muted, fontSize: 13),
              children: [
                TextSpan(
                  text: _couponCode.text.trim().isEmpty ? 'CODE' : _couponCode.text.trim().toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (preview.conditions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(preview.conditions.join(' · '), style: TextStyle(color: _muted, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _buildAudienceOption(BuildContext context, CouponAudience value, String title, String hint) {
    final selected = _audience == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _audience = value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : (_isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : _muted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      )),
                  Text(hint, style: TextStyle(color: _muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceRow(BuildContext context, List<(String, bool, VoidCallback)> options) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: options[i].$3,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: options[i].$2
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : (_isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: options[i].$2
                        ? AppColors.primary
                        : Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  options[i].$1,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: options[i].$2 ? AppColors.primary : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildLabelWithAsterisk(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          children: const [
            TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool enabled = true,
    bool integer = false,
    List<TextInputFormatter>? formatters,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: _isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: formatters ??
            (keyboardType == TextInputType.number
                ? [
                    integer
                        ? FilteringTextInputFormatter.digitsOnly
                        : FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ]
                : null),
        style: TextStyle(color: enabled ? null : _muted),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.transparent,
          hintText: hint,
          hintStyle: TextStyle(
            color: _isDark ? AppColors.textSecondaryDark : const Color(0xFF9CA3AF),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDateField(
    BuildContext context,
    DateTime? value,
    DateFormat dateFormat,
    VoidCallback onTap, {
    required String placeholder,
  }) {
    return _buildTappableField(
      context,
      value != null ? dateFormat.format(value) : placeholder,
      hasValue: value != null,
      icon: Icons.calendar_today_outlined,
      onTap: onTap,
    );
  }

  Widget _buildTimeField(BuildContext context, String label, TimeOfDay value, VoidCallback onTap) {
    return _buildTappableField(
      context,
      '$label  ${_hhmm(value)}',
      hasValue: true,
      icon: Icons.schedule,
      onTap: onTap,
    );
  }

  Widget _buildTappableField(
    BuildContext context,
    String text, {
    required bool hasValue,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasValue
                      ? Theme.of(context).colorScheme.onSurface
                      : (_isDark ? AppColors.textSecondaryDark : const Color(0xFF9CA3AF)),
                  fontSize: 14,
                ),
              ),
            ),
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
