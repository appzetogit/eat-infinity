import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/auth_viewmodel.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String? devOtp;
  final String? name;
  final String? fromPath;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.devOtp,
    this.name,
    this.fromPath,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  // 4-digit OTP fields matching rounded square design
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  int _resendCountdown = 28;
  Timer? _timer;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint('[AUTH] OTP screen opened for +91 ${widget.phoneNumber}');
    _startResendTimer();

    // Pre-fill only the dev OTP the server chose to return, and only in a
    // debug build. There is deliberately no fallback: hardcoding one filled
    // every real user's boxes with a guessable code they never had to read.
    final code = widget.devOtp;
    if (kDebugMode && code != null && code.length == 4) {
      for (int i = 0; i < 4; i++) {
        _controllers[i].text = code[i];
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendCountdown = 28);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        if (mounted) setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _enteredOtp => _controllers.map((c) => c.text).join();

  void _onOtpDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      Haptics.light();
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_enteredOtp.length == 4 && !_isVerifying) {
          _verifyOtp();
        }
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _verifyOtp() async {
    if (_isVerifying) return;

    final enteredOtp = _enteredOtp;
    if (enteredOtp.length < 4) {
      _showErrorSnackBar('Please enter all 4 digits of your OTP');
      return;
    }

    Haptics.light();
    setState(() => _isVerifying = true);

    final session = await ref.read(authViewModelProvider.notifier).verifyOtp(
          phone: widget.phoneNumber,
          otp: enteredOtp,
        );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (session == null) {
      _showErrorSnackBar(
        ref.read(authViewModelProvider.notifier).lastError ?? 'Invalid OTP code. Please try again.',
      );
      return;
    }

    Haptics.success();
    final target = widget.fromPath ?? RouteNames.home;

    // A first-time customer (or anyone whose account still has no name) is
    // asked for it here. Without this the name was never collected anywhere
    // during sign-up, so the profile read "Guest" until they went and edited
    // it themselves.
    if (session.needsProfileSetup) {
      context.go(RouteNames.profileSetup, extra: {'from': target});
      return;
    }

    context.go(target);
  }

  void _handleResend() async {
    if (_resendCountdown > 0) return;
    Haptics.medium();
    _startResendTimer();

    final result = await ref.read(authViewModelProvider.notifier).requestOtp(widget.phoneNumber);
    if (!mounted) return;

    if (result.ok) {
      AppSnackbar.success(context, 'New 4-digit OTP code sent to +91 ${widget.phoneNumber}');
      if (result.devOtp != null && result.devOtp!.length == 4) {
        for (int i = 0; i < 4; i++) {
          _controllers[i].text = result.devOtp![i];
        }
      }
    } else {
      _showErrorSnackBar(
        ref.read(authViewModelProvider.notifier).lastError ?? 'Failed to resend OTP. Try again.',
      );
    }
  }

  void _handleSkip() {
    Haptics.light();
    final target = widget.fromPath ?? RouteNames.home;
    context.go(target);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    AppSnackbar.error(context, message);
  }

  String _formatTimer(int seconds) {
    final secs = seconds.toString().padLeft(2, '0');
    return '00:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFDFF),
      body: Stack(
        children: [
          // Background soft gradient motifs
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          children: [
                  const SizedBox(height: 12),

                  // Top Header Row (Back Arrow on Left, Skip Button on Right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 24),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      InkWell(
                        onTap: _handleSkip,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.2),
                            color: Colors.white,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Skip',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // Smartphone & Security Verification Vector Graphic Header
                  _buildVerificationIllustration(),

                  const SizedBox(height: 28),

                  // Header Title & Phone Subtitle
                  Column(
                    children: [
                      const Text(
                        'Verify your number',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.4,
                          fontFamily: 'ManropeVariable',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "We've sent a 4-digit OTP to",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '+91 ${widget.phoneNumber}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 17,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // 4 Rounded Square OTP Input Boxes.
                  //
                  // The boxes share the row's width with a fixed gap between
                  // them, so they line up flush with the Verify button below.
                  // Fixed-width boxes inside an extra inset left uneven slack
                  // at both ends, and that slack grew with the screen.
                  Row(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: _buildOtpSquareBox(i)),
                      ],
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Resend Timer & Button
                  GestureDetector(
                    onTap: _resendCountdown == 0 ? _handleResend : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _resendCountdown > 0 ? 'Resend OTP in ' : "Didn't get OTP? ",
                          style: TextStyle(
                            fontSize: 13.5,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _resendCountdown > 0 ? _formatTimer(_resendCountdown) : 'Resend OTP',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Skip Link
                  InkWell(
                    onTap: _handleSkip,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Verify & Continue Pill Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: _isVerifying
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  'Verify & Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                    ),
                  ),

                  // A fixed gap before the flexible one: with the keyboard up
                  // the viewport shrinks, every Spacer collapses to zero, and
                  // the footer ends up flush against the button.
                  const SizedBox(height: 28),
                  const Spacer(flex: 2),

                  // Security Footer Badge (Shield + Your data is safe with us)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                        child: Icon(Icons.shield_outlined, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Your data is safe with us.\nWe never share your details.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      );
    },
  ),
),
        ],
      ),
    );
  }

  /// Single OTP Input Rounded Square Box Widget (4 Boxes Total)
  Widget _buildOtpSquareBox(int index) {
    final isFocused = _focusNodes[index].hasFocus;
    final hasValue = _controllers[index].text.isNotEmpty;

    return Container(
      // Width comes from the Expanded in the row; only the height is fixed.
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFocused
              ? AppColors.primary
              : (hasValue ? AppColors.primary.withValues(alpha: 0.6) : const Color(0xFFE2E8F0)),
          width: isFocused ? 2.0 : 1.2,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Center(
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
          decoration: const InputDecoration(
            hintText: '—',
            hintStyle: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (val) => _onOtpDigitChanged(index, val),
        ),
      ),
    );
  }

  /// Verification Vector Smartphone Graphic Widget
  Widget _buildVerificationIllustration() {
    return SizedBox(
      width: 170,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft circular background tint
          Container(
            width: 160,
            height: 160,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE8F6F5),
            ),
          ),

          // Smartphone device vector
          Container(
            width: 80,
            height: 135,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF0F172A), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 6),
                // Speaker notch bar
                Container(
                  width: 22,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                // Teal Shield badge on screen
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 14),
                // Dotted password lines • • • • •
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Envelope Mail on Left with Checkmark Badge
          Positioned(
            left: 8,
            top: 60,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.mail_outline_rounded, color: Color(0xFF64748B), size: 24),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
          ),

          // Chat Bubble Icon on Right
          Positioned(
            right: 8,
            top: 45,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  );
                }),
              ),
            ),
          ),

          // Sparkle ✨ top right
          Positioned(
            top: 24,
            right: 32,
            child: Icon(Icons.auto_awesome, color: AppColors.primary, size: 14),
          ),
        ],
      ),
    );
  }
}
