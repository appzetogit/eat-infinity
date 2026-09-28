import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/utils/haptics.dart';
import '../branding/app_colors.dart';

/// Pill-shaped search bar with a vertically rotating hint.
///
/// Two modes:
///  * `readOnly: true`  — the whole bar is a button. Used on Home/Category,
///    where tapping navigates to the real search screen. No focus, no keyboard.
///  * `readOnly: false` — a live [TextField]. Used on the search screen itself.
///
/// While the field is empty the hint cycles through [categories] every
/// [rotateInterval], rendered as `Search "<item>"`. Rotation stops as soon as
/// the user types, and resumes when the field is cleared — a moving hint behind
/// real text is just noise.
class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({
    super.key,
    this.controller,
    this.readOnly = false,
    this.onTap,
    this.onMicTap,
    this.onScanTap,
    this.onChanged,
    this.onSubmitted,
    this.categories = const [],
    this.rotateInterval = const Duration(seconds: 3),
    this.showMic = true,
    this.showScanner = true,
    this.autofocus = false,
  });

  /// Optional. When null the widget owns an internal controller and disposes
  /// it; when supplied, disposal stays with the caller.
  final TextEditingController? controller;

  /// Renders as a button rather than an input. [onTap] is then the only way to
  /// interact with it.
  final bool readOnly;

  final VoidCallback? onTap;
  final VoidCallback? onMicTap;
  final VoidCallback? onScanTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Keywords cycled through in the animated hint. Fewer than two entries
  /// disables rotation — there would be nothing to rotate to.
  final List<String> categories;

  final Duration rotateInterval;
  final bool showMic;
  final bool showScanner;
  final bool autofocus;

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  static const _transition = Duration(milliseconds: 500);
  static const _slide = 1.2; // off-screen distance, in multiples of line height

  TextEditingController? _internalController;
  FocusNode? _internalFocusNode;
  Timer? _timer;
  int _index = 0;
  bool _isPressed = false;
  bool _isFocused = false;

  TextEditingController get _controller =>
      widget.controller ?? (_internalController ??= TextEditingController());

  FocusNode get _focusNode => _internalFocusNode ??= FocusNode();

  bool get _hasText => _controller.text.isNotEmpty;

  bool get _canRotate => widget.categories.length > 1 && !_hasText;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    _restartTimer();
  }

  @override
  void didUpdateWidget(SearchBarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onTextChanged);
      _controller.addListener(_onTextChanged);
    }
    // The category list is usually fetched, so it arrives after first build.
    if (oldWidget.categories.length != widget.categories.length ||
        oldWidget.rotateInterval != widget.rotateInterval) {
      if (_index >= widget.categories.length) _index = 0;
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _internalController?.dispose();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  void _onTextChanged() {
    // Only rebuild on the empty <-> non-empty edge: that is the only thing the
    // chrome depends on, and rebuilding per keystroke would restart the timer.
    final shouldRotate = _canRotate;
    final timerRunning = _timer?.isActive ?? false;
    if (shouldRotate != timerRunning) {
      setState(_restartTimer);
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!_canRotate) return;
    _timer = Timer.periodic(widget.rotateInterval, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.categories.length);
    });
  }

  void _clear() {
    Haptics.light();
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHighlighted = _isPressed || _isFocused;

    final barContent = Container(
      height: 48.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isHighlighted
              ? AppColors.primary
              : (isDark ? Colors.white24 : AppColors.primary.withValues(alpha: 0.35)),
          width: isHighlighted ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.22)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: isHighlighted ? 16 : 10,
            spreadRadius: isHighlighted ? 1 : 0,
            offset: isHighlighted ? const Offset(0, 4) : const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedScale(
            scale: isHighlighted ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Icon(
              Icons.search_rounded,
              size: 22.sp,
              color: isHighlighted ? AppColors.primary : const Color(0xFF64748B),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(child: _buildField(isDark)),
          if (_hasText)
            _IconButton(
              icon: Icons.close_rounded,
              color: const Color(0xFF94A3B8),
              onTap: _clear,
              tooltip: 'Clear',
            ),
          if (widget.showMic || widget.showScanner) ...[
            SizedBox(width: 6.w),
            Container(
              width: 1,
              height: 20.h,
              color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
            ),
            SizedBox(width: 6.w),
          ],
          if (widget.showMic)
            _IconButton(
              icon: Icons.mic_none_rounded,
              color: AppColors.primary,
              onTap: widget.onMicTap,
              tooltip: 'Voice search',
            ),
          if (widget.showScanner)
            _IconButton(
              icon: Icons.qr_code_scanner_rounded,
              color: AppColors.primary,
              onTap: widget.onScanTap,
              tooltip: 'Scan',
            ),
        ],
      ),
    );

    final animatedBar = AnimatedScale(
      scale: isHighlighted ? 1.025 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0.0, isHighlighted ? -2.0 : 0.0, 0.0),
        child: barContent,
      ),
    );

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        Haptics.light();
        if (widget.readOnly) {
          widget.onTap?.call();
        } else {
          _focusNode.requestFocus();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: animatedBar,
    );
  }

  /// The input itself, with the rotating hint layered behind it.
  ///
  /// The [TextField] deliberately has no `hintText` — the animated hint below
  /// it plays that role, and two hints would overlap.
  Widget _buildField(bool isDark) {
    final hint = _buildAnimatedHint();

    if (widget.readOnly) return hint;

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        if (!_hasText) IgnorePointer(child: hint),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          textInputAction: TextInputAction.search,
          cursorColor: AppColors.primary,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: const InputDecoration(
            isCollapsed: true,
            // The app theme sets `filled: true` for every TextField, which
            // painted an opaque fill straight over the animated hint sitting
            // behind this field — the bar looked empty on the search screen
            // while Home (readOnly, no TextField) rendered the hint fine.
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  /// Vertically rotating `Search "<item>"` hint.
  ///
  /// [AnimatedSwitcher] drives one animation for both children, running it in
  /// reverse for the outgoing one. Keying the tween off the current index is
  /// what makes both slide the *same* way (upward) instead of mirroring: the
  /// incoming child travels bottom -> centre, and the outgoing child, played
  /// backwards, travels centre -> top.
  Widget _buildAnimatedHint() {
    final categories = widget.categories;
    final text = categories.isEmpty
        ? 'Search for dishes and restaurants'
        : 'Search "${categories[_index % categories.length]}"';

    final currentKey = ValueKey<String>(text);

    return ClipRect(
      child: AnimatedSwitcher(
        duration: _transition,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        // Default layoutBuilder stacks children centre-aligned; left-align so
        // the hint sits against the search icon while it animates.
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) {
          final isIncoming = child.key == currentKey;
          final offset = Tween<Offset>(
            begin: Offset(0, isIncoming ? _slide : -_slide),
            end: Offset.zero,
          ).animate(animation);

          return SlideTransition(
            position: offset,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Text(
          text,
          key: currentKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}

/// Tap target for the trailing icons, sized to stay reachable inside a 48px bar.
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: InkResponse(
        onTap: onTap == null
            ? null
            : () {
                Haptics.light();
                onTap!.call();
              },
        radius: 20.r,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
          child: Icon(icon, size: 22.sp, color: color),
        ),
      ),
    );
  }
}
