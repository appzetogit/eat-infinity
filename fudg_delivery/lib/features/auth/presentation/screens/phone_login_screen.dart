import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/result.dart';
import '../../application/auth_controller.dart';
import 'package:food_user_application/core/theme/app_colors.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;
  final String _selectedLanguage = 'English';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      final result =
          await ref.read(authControllerProvider.notifier).requestOtp(phone);

      if (!mounted) return;

      result.when(
        success: (_) => context.push('/otp-verify', extra: phone),
        failure: (error) => setState(() => _errorText = error.message),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const tealPrimary = AppColors.primary;
    const tealBgLight = AppColors.primaryLight;
    const darkText = AppColors.lightTextPrimary;
    const subtitleColor = AppColors.lightTextSecondary;
    const borderColor = AppColors.lightBorder;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 10.h),

                // 1. TOP BAR: Language Selector on Right
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.language_rounded,
                          size: 16.sp,
                          color: tealPrimary,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          _selectedLanguage,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: darkText,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18.sp,
                          color: subtitleColor,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 10.h),

                // 2. HEADER SECTION (Logo on Left, Hero Image on Right)
                SizedBox(
                  height: 150.h,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left: Logo & App Title
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Motion Dashes + M
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: 12.w,
                                      height: 3.h,
                                      decoration: BoxDecoration(
                                        color: tealPrimary,
                                        borderRadius:
                                            BorderRadius.circular(2.r),
                                      ),
                                    ),
                                    SizedBox(height: 2.5.h),
                                    Container(
                                      width: 16.w,
                                      height: 3.h,
                                      decoration: BoxDecoration(
                                        color: tealPrimary,
                                        borderRadius:
                                            BorderRadius.circular(2.r),
                                      ),
                                    ),
                                    SizedBox(height: 2.5.h),
                                    Container(
                                      width: 10.w,
                                      height: 3.h,
                                      decoration: BoxDecoration(
                                        color: tealPrimary,
                                        borderRadius:
                                            BorderRadius.circular(2.r),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  'M',
                                  style: TextStyle(
                                    fontSize: 42.sp,
                                    fontWeight: FontWeight.w900,
                                    color: tealPrimary,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 2.h),

                            // FudgFood
                            RichText(
                              text: TextSpan(
                                text: 'Eatinfinity',
                                style: TextStyle(
                                  fontSize: 28.sp,
                                  fontWeight: FontWeight.w900,
                                  color: darkText,
                                  letterSpacing: -0.5,
                                ),
                                children: const [
                                  TextSpan(
                                    text: 'Food',
                                    style: TextStyle(
                                      color: tealPrimary,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 6.h),

                            // Badge: — RIDER —
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 18.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: tealPrimary,
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: Text(
                                '— RIDER —',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ),
                            SizedBox(height: 4.h),

                            Text(
                              'Delivery Partner App',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Right: Cropped Rider Hero Graphic
                      Expanded(
                        flex: 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(80.r),
                          ),
                          child: Container(
                            color: tealBgLight.withValues(alpha: 0.5),
                            child: Image.asset(
                              'assets/image/delivery_hero.png',
                              fit: BoxFit.cover,
                              alignment: Alignment.centerLeft,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20.h),

                // 3. WELCOME TEXT
                Text(
                  'Welcome Partner! 👋',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    color: darkText,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Login to start delivering happiness\nand earn better.',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Container(
                      width: 24.w,
                      height: 3.5.h,
                      decoration: BoxDecoration(
                        color: tealPrimary,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Container(
                      width: 4.w,
                      height: 3.5.h,
                      decoration: BoxDecoration(
                        color: tealPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 20.h),

                // 4. LOGIN FORM FLOATING CARD
                Container(
                  padding: EdgeInsets.all(18.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: borderColor, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Login with Mobile Number',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: darkText,
                        ),
                      ),
                      SizedBox(height: 14.h),

                      // Mobile Number Input Field
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 50.h,
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                // The phone keyboard offers +, *, #, spaces
                                // and brackets. Whatever is typed here becomes
                                // the exact key the OTP is stored under
                                // (otp.service.js does a raw `findOne({phone})`)
                                // and the number the SMS is sent to, so only
                                // digits may reach it — and maxLength must not
                                // spend its 10 characters on punctuation.
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: darkText,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: 'Enter your mobile number',
                                  hintStyle: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.lightTextSecondary,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.smartphone_rounded,
                                    size: 20.sp,
                                    color: tealPrimary,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 14.h,
                                    horizontal: 12.w,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                    borderSide: const BorderSide(
                                      color: borderColor,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                    borderSide: const BorderSide(
                                      color: tealPrimary,
                                      width: 1.5,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                    borderSide: const BorderSide(
                                      color: Colors.redAccent,
                                      width: 1,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                    borderSide: const BorderSide(
                                      color: Colors.redAccent,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  final v = value?.trim() ?? '';
                                  if (v.isEmpty) {
                                    return 'Enter mobile number';
                                  }
                                  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
                                    return 'Enter valid 10-digit number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (_errorText != null) ...[
                        SizedBox(height: 8.h),
                        Text(
                          _errorText!,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],

                      SizedBox(height: 16.h),

                      // Send OTP Primary Button
                      SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tealPrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: _isSubmitting
                              ? SizedBox(
                                  width: 22.w,
                                  height: 22.h,
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Send OTP',
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18.sp,
                                    ),
                                  ],
                                ),
                        ),
                      ),

                    ],
                  ),
                ),

                SizedBox(height: 24.h),

                // 5. BOTTOM 3 FEATURE ITEMS
                Row(
                  children: [
                    const _LoginFeatureItem(
                      icon: Icons.shield_outlined,
                      title: 'Safe & Secure',
                      subtitle: 'Your safety is\nour priority',
                    ),
                    Container(width: 1.w, height: 48.h, color: borderColor),
                    const _LoginFeatureItem(
                      icon: Icons.offline_bolt_outlined,
                      title: 'Quick Access',
                      subtitle: 'Login in seconds\nand go online',
                    ),
                    Container(width: 1.w, height: 48.h, color: borderColor),
                    const _LoginFeatureItem(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Better Earnings',
                      subtitle: 'More orders,\nmore incentives',
                    ),
                  ],
                ),

                SizedBox(height: 24.h),

                // 6. TERMS & PRIVACY FOOTER
                Center(
                  child: Column(
                    children: [
                      Text(
                        'By continuing, you agree to our',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: subtitleColor,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {},
                            child: Text(
                              'Terms & Conditions',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: tealPrimary,
                                decoration: TextDecoration.underline,
                                decorationColor: tealPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '  and  ',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                              color: subtitleColor,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {},
                            child: Text(
                              'Privacy Policy',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: tealPrimary,
                                decoration: TextDecoration.underline,
                                decorationColor: tealPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginFeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _LoginFeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    const tealPrimary = AppColors.primary;
    const tealBgLight = AppColors.primaryLight;
    const darkText = AppColors.lightTextPrimary;
    const subtitleColor = AppColors.lightTextSecondary;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: const BoxDecoration(
              color: tealBgLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18.sp,
              color: tealPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: darkText,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w500,
              color: subtitleColor,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
