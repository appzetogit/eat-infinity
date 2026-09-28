import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? fromPath;
  final int initialTabIndex;

  const LoginScreen({
    super.key,
    this.fromPath,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  String _getRedirectTarget() {
    final queryFrom = GoRouterState.of(context).uri.queryParameters['from'];
    return widget.fromPath ?? queryFrom ?? RouteNames.home;
  }

  void _handleContinue() async {
    Haptics.light();
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');

    if (phone.length < 10) {
      _showErrorSnackBar('Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() => _isLoading = true);

    if (kDebugMode) debugPrint('[AUTH] Requesting OTP for +91 $phone');
    final result = await ref.read(authViewModelProvider.notifier).requestOtp(phone);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.ok) {
      _showErrorSnackBar(
        ref.read(authViewModelProvider.notifier).lastError ?? 'Could not send OTP. Please try again.',
      );
      return;
    }

    Haptics.medium();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => OtpScreen(
          phoneNumber: phone,
          devOtp: result.devOtp,
          fromPath: _getRedirectTarget(),
        ),
      ),
    );
  }


  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    AppSnackbar.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFDFF),
      body: Stack(
        children: [
          // 1. Decorative Curved Wave Shapes in Corners
          Positioned(
            top: -60,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.07),
              ),
            ),
          ),
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

          // 2. Main Content (Wrapped in LayoutBuilder & SingleChildScrollView to eliminate keyboard overflow)
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

                  // Exact Fudg Brand Logo Header (using assets/images/logo.png)
                  _buildFudgLogoHeader(),

                  const SizedBox(height: 36),

                  // Welcome Text
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                            fontFamily: 'ManropeVariable',
                          ),
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                              height: 1.45,
                              fontFamily: 'ManropeVariable',
                            ),
                            children: [
                              const TextSpan(text: 'Login or Sign up to continue\nto your favorite food '),
                              TextSpan(
                                text: '🩵',
                                style: TextStyle(color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Exact Mobile Input Field (matching zoomed-in reference image)
                  Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(29),
                      border: Border.all(color: const Color(0xFFD5EFEF), width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        // Left Mint Square Box for Phone Handset Icon
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF9F8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.phone_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Faint Vertical Line
                        Container(width: 1, height: 20, color: const Color(0xFFE5E7EB)),
                        const SizedBox(width: 12),



                        // Mobile Number Input Field
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            focusNode: _phoneFocusNode,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Enter your mobile number',
                              hintStyle: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Continue Pill Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppColors.primary.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  'Continue',
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

                  const SizedBox(height: 28),

                  // Security Footer Badge
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

  /// Builds Exact Fudg Brand Logo Header using asset image
  Widget _buildFudgLogoHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Exact Logo Icon from Reference Image
        Image.asset(
          'assets/images/logo.png',
          height: 54,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              fontFamily: 'ManropeVariable',
            ),
            children: [
              TextSpan(
                text: 'Eatinfinity',
                style: TextStyle(color: AppColors.primary),
              ),
              const TextSpan(
                text: 'Food',
                style: TextStyle(color: Color(0xFF1E293B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 24, height: 1.5, color: AppColors.primary),
            const SizedBox(width: 6),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
                children: [
                  const TextSpan(text: 'Food Delivered in '),
                  TextSpan(
                    text: 'Minutes',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(width: 24, height: 1.5, color: AppColors.primary),
          ],
        ),
      ],
    );
  }
}
