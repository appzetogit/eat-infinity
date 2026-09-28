import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/result.dart';
import '../../../../core/services/referral_tracking_service.dart';
import '../../application/auth_controller.dart';
import 'package:food_user_application/core/theme/app_colors.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key, this.phone = ''});

  final String phone;

  @override
  ConsumerState<RegistrationScreen> createState() =>
      _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  /// Digits only, as the backend counts them: it validates `phone` with
  /// `z.string().min(8)` and normalises with `replace(/\D/g, '').slice(-10)`.
  /// A '+91 ' prefix or a stray space is therefore worth stripping here rather
  /// than discovering as a 400.
  static String _digits(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  /// The same shapes `delivery.validator.js` enforces. Checked here so a
  /// mistyped document number is reported against its own field, instead of
  /// coming back as a bare 'Invalid PAN format' after the whole multipart
  /// upload — photos included — has already gone over the wire.
  static final _panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
  static final _aadhaarPattern = RegExp(r'^[0-9]{12}$');
  static final _licensePattern = RegExp(r'^[A-Z]{2}[0-9A-Z]{8,16}$');

  /// First problem found, or null when the form is good to send. Every field
  /// is optional to the backend *unless* non-empty, so each check is skipped
  /// for a blank value.
  String? _formatError({
    required String pan,
    required String aadhaar,
    required String license,
    required String email,
  }) {
    if (pan.isNotEmpty && !_panPattern.hasMatch(pan)) {
      return 'PAN should look like ABCDE1234F.';
    }
    if (aadhaar.isNotEmpty && !_aadhaarPattern.hasMatch(aadhaar)) {
      return 'Aadhaar should be exactly 12 digits.';
    }
    if (license.isNotEmpty && !_licensePattern.hasMatch(license)) {
      return 'Driving licence should be 2 letters followed by 8-16 letters or digits.';
    }
    if (email.isNotEmpty && !email.contains(RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$'))) {
      return 'Enter a valid email address, or leave it blank.';
    }
    return null;
  }

  // Text Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _vehicleNameController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _licenseController = TextEditingController();
  final _panController = TextEditingController();
  final _aadharController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _referralController = TextEditingController();

  final String _vehicleType = 'bike';

  // File Uploads
  File? _profilePhoto; // Selfie
  File? _aadharPhoto;
  File? _panPhoto;
  File? _licensePhoto;
  File? _vehicleRcPhoto;
  File? _upiQrCode;

  bool _isSubmitting = false;
  String? _errorText;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadReferralCode();
    _restorePhone();
  }

  /// Recovers the verified number from, in order: the route extra, the live
  /// auth state, and the copy persisted at verify-otp.
  ///
  /// Only the first two existed before. Neither survives the process being
  /// killed during the KYC photo steps, and the screen then POSTed an empty
  /// `phone` — the backend replied "Phone must be at least 8 digits" and the
  /// partner had no field to correct, because the phone input is never built.
  Future<void> _restorePhone() async {
    final fromRoute = _digits(widget.phone);
    if (fromRoute.isNotEmpty) {
      _phoneController.text = fromRoute;
      return;
    }
    final resolved = await ref
        .read(authControllerProvider.notifier)
        .pendingRegistrationPhone();
    if (!mounted) return;
    setState(() => _phoneController.text = _digits(resolved));
  }

  Future<void> _loadReferralCode() async {
    final code = await ReferralTrackingService.getReferralCode();
    if (code != null && code.isNotEmpty && mounted) {
      setState(() {
        _referralController.text = code;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _vehicleNameController.dispose();
    _vehicleNumberController.dispose();
    _licenseController.dispose();
    _panController.dispose();
    _aadharController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(
    void Function(File) onPicked, {
    ImageSource source = ImageSource.gallery,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked != null) {
      setState(() => onPicked(File(picked.path)));
    }
  }

  int get _completedCount {
    int count = 0;
    if (_aadharPhoto != null || _aadharController.text.trim().isNotEmpty) {
      count++;
    }
    if (_panPhoto != null || _panController.text.trim().isNotEmpty) count++;
    if (_licensePhoto != null || _licenseController.text.trim().isNotEmpty) {
      count++;
    }
    if (_vehicleRcPhoto != null ||
        _vehicleNumberController.text.trim().isNotEmpty) {
      count++;
    }
    if (_upiQrCode != null ||
        _bankAccountController.text.trim().isNotEmpty) {
      count++;
    }
    if (_profilePhoto != null) count++;
    return count;
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      _showPersonalDetailsModal();
      return;
    }

    // Checked here rather than left to the server: an empty or short phone
    // came back as an opaque 400 the partner could do nothing about.
    final phone = _digits(_phoneController.text);
    if (phone.length < 8) {
      setState(() => _errorText = phone.isEmpty
          ? 'We lost your verified phone number. Please sign in again to continue.'
          : 'Enter a valid phone number of at least 8 digits.');
      _showPersonalDetailsModal();
      return;
    }

    if (_completedCount < 4) {
      setState(() => _errorText = 'Please upload at least required KYC documents');
      return;
    }

    final pan = _panController.text.trim().toUpperCase();
    final aadhaar = _digits(_aadharController.text);
    final license = _licenseController.text
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]'), '');
    final email = _emailController.text.trim();

    final formatError = _formatError(
      pan: pan,
      aadhaar: aadhaar,
      license: license,
      email: email,
    );
    if (formatError != null) {
      setState(() => _errorText = formatError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final vehicleNumber =
          _vehicleNumberController.text.trim().toUpperCase();
      final address = _addressController.text.trim();
      final city = _cityController.text.trim();
      final stateName = _stateController.text.trim();
      final vehicleName = _vehicleNameController.text.trim();

      final map = <String, dynamic>{
        // No 'Partner' fallback: _submit() already refuses an empty name, so
        // the only thing a default could do is write a made-up one.
        'name': _nameController.text.trim(),
        'phone': phone,
        'countryCode': '+91',
        if (email.isNotEmpty) 'email': email,
        if (address.isNotEmpty) 'address': address,
        if (city.isNotEmpty) 'city': city,
        if (stateName.isNotEmpty) 'state': stateName,
        'vehicleType': _vehicleType,
        if (vehicleName.isNotEmpty) 'vehicleName': vehicleName,
        if (vehicleNumber.isNotEmpty) 'vehicleNumber': vehicleNumber,
        if (license.isNotEmpty) 'drivingLicenseNumber': license,
        if (pan.isNotEmpty) 'panNumber': pan,
        if (aadhaar.isNotEmpty) 'aadharNumber': aadhaar,
        if (_referralController.text.trim().isNotEmpty)
          'ref': _referralController.text.trim(),
        'platform': 'mobile',
      };

      if (_profilePhoto != null && await _profilePhoto!.exists()) {
        map['profilePhoto'] = await MultipartFile.fromFile(_profilePhoto!.path);
      }
      if (_aadharPhoto != null && await _aadharPhoto!.exists()) {
        map['aadharPhoto'] = await MultipartFile.fromFile(_aadharPhoto!.path);
      }
      if (_panPhoto != null && await _panPhoto!.exists()) {
        map['panPhoto'] = await MultipartFile.fromFile(_panPhoto!.path);
      }
      if (_licensePhoto != null && await _licensePhoto!.exists()) {
        map['drivingLicensePhoto'] =
            await MultipartFile.fromFile(_licensePhoto!.path);
      }
      if (_upiQrCode != null && await _upiQrCode!.exists()) {
        map['upiQrCode'] = await MultipartFile.fromFile(_upiQrCode!.path);
      }

      final formData = FormData.fromMap(map);

      final result = await ref
          .read(authControllerProvider.notifier)
          .register(formData);

      if (!mounted) return;

      result.when(
        success: (_) {},
        failure: (error) => setState(() => _errorText = error.message),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = 'Submission error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showDocumentUploadModal({
    required String title,
    required String labelText,
    required TextEditingController controller,
    required File? photo,
    required void Function(File) onPhotoPicked,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h,
            left: 20.w,
            right: 20.w,
            top: 20.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: labelText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Document Photo',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightTextPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              InkWell(
                onTap: () {
                  _pickImage((f) {
                    onPhotoPicked(f);
                    if (Navigator.of(ctx).canPop()) {
                      Navigator.of(ctx).pop();
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12.r),
                child: Container(
                  width: double.infinity,
                  height: 120.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: AppColors.lightBorder,
                      width: 1,
                    ),
                  ),
                  child: photo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: Image.file(photo, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 32.sp,
                              color: AppColors.primary,
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              'Tap to upload document photo',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: () {
                    if (Navigator.of(ctx).canPop()) {
                      Navigator.of(ctx).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Save & Continue',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPersonalDetailsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.h,
            left: 20.w,
            right: 20.w,
            top: 20.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Details',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.lightTextPrimary,
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              // The verified number, shown so it can be seen and corrected.
              // It was collected at OTP and then only ever held in a
              // controller with no field attached, so when it went missing
              // there was no way to put it back.
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  prefixText: '+91 ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _cityController,
                decoration: InputDecoration(
                  labelText: 'City *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: () {
                    if (Navigator.of(ctx).canPop()) {
                      Navigator.of(ctx).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Save Details',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const tealPrimary = AppColors.primary;
    const tealBgLight = AppColors.primaryLight;
    const darkText = AppColors.lightTextPrimary;
    const subtitleColor = AppColors.lightTextSecondary;
    const borderColor = AppColors.lightBorder;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SizedBox(height: 10.h),

              // 1. TOP BAR HEADER
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  children: [
                    // Back Circle Button
                    InkWell(
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      borderRadius: BorderRadius.circular(20.r),
                      child: Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          size: 20.sp,
                          color: darkText,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'KYC Verification',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                              color: darkText,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Complete your KYC to start delivering',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Help Pill Button
                    InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(20.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: borderColor, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.help_outline_rounded,
                              size: 16.sp,
                              color: tealPrimary,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'Help',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: tealPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 14.h),

              // SCROLLABLE CONTENT AREA
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    children: [
                      // 2. HERO PROGRESS CARD
                      Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: tealBgLight,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: const Color(0xFFD0F2EC),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Hero Graphic
                            Container(
                              width: 90.w,
                              height: 75.h,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.assignment_turned_in_rounded,
                                    size: 44.sp,
                                    color: tealPrimary,
                                  ),
                                  Positioned(
                                    right: 4,
                                    bottom: 4,
                                    child: Icon(
                                      Icons.two_wheeler_rounded,
                                      size: 28.sp,
                                      color: tealPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 14.w),

                            // Hero Text & Progress
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Documents, Your Safety',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w800,
                                      color: darkText,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'Verify your documents to ensure a safe and trusted delivery experience.',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w400,
                                      color: subtitleColor,
                                      height: 1.3,
                                    ),
                                  ),
                                  SizedBox(height: 10.h),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4.r),
                                    child: LinearProgressIndicator(
                                      value: _completedCount / 6,
                                      backgroundColor: Colors.white,
                                      color: tealPrimary,
                                      minHeight: 6.h,
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    '$_completedCount of 6 Completed',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: tealPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 14.h),

                      // 3. DOCUMENT VERIFICATION LIST CARDS
                      _KycDocumentCard(
                        icon: Icons.fingerprint_rounded,
                        iconColor: const Color(0xFFF97316),
                        title: 'Aadhaar Card',
                        subtitle: 'Upload front & back side',
                        isUploaded: _aadharPhoto != null ||
                            _aadharController.text.trim().isNotEmpty,
                        onTap: () {
                          _showDocumentUploadModal(
                            title: 'Aadhaar Card',
                            labelText: 'Aadhaar Number (12 digits)',
                            controller: _aadharController,
                            photo: _aadharPhoto,
                            onPhotoPicked: (f) =>
                                setState(() => _aadharPhoto = f),
                          );
                        },
                      ),

                      SizedBox(height: 10.h),

                      _KycDocumentCard(
                        icon: Icons.credit_card_rounded,
                        iconColor: tealPrimary,
                        title: 'PAN Card',
                        subtitle: 'Upload PAN card',
                        isUploaded: _panPhoto != null ||
                            _panController.text.trim().isNotEmpty,
                        onTap: () {
                          _showDocumentUploadModal(
                            title: 'PAN Card',
                            labelText: 'PAN Number (e.g. ABCDE1234F)',
                            controller: _panController,
                            photo: _panPhoto,
                            onPhotoPicked: (f) => setState(() => _panPhoto = f),
                          );
                        },
                      ),

                      SizedBox(height: 10.h),

                      _KycDocumentCard(
                        icon: Icons.badge_outlined,
                        iconColor: tealPrimary,
                        title: 'Driving Licence',
                        subtitle: 'Upload driving licence',
                        isUploaded: _licensePhoto != null ||
                            _licenseController.text.trim().isNotEmpty,
                        isActive: true, // Highlights with active teal border
                        onTap: () {
                          _showDocumentUploadModal(
                            title: 'Driving Licence',
                            labelText: 'Driving Licence Number',
                            controller: _licenseController,
                            photo: _licensePhoto,
                            onPhotoPicked: (f) =>
                                setState(() => _licensePhoto = f),
                          );
                        },
                      ),

                      SizedBox(height: 10.h),

                      _KycDocumentCard(
                        icon: Icons.article_outlined,
                        iconColor: tealPrimary,
                        title: 'Vehicle RC',
                        subtitle: 'Upload vehicle registration certificate',
                        isUploaded: _vehicleRcPhoto != null ||
                            _vehicleNumberController.text.trim().isNotEmpty,
                        onTap: () {
                          _showDocumentUploadModal(
                            title: 'Vehicle RC',
                            labelText: 'Vehicle Number (e.g. MH12AB1234)',
                            controller: _vehicleNumberController,
                            photo: _vehicleRcPhoto,
                            onPhotoPicked: (f) =>
                                setState(() => _vehicleRcPhoto = f),
                          );
                        },
                      ),

                      SizedBox(height: 10.h),

                      _KycDocumentCard(
                        icon: Icons.account_balance_outlined,
                        iconColor: tealPrimary,
                        title: 'Bank Account',
                        subtitle: 'Add bank account details',
                        isUploaded: _upiQrCode != null ||
                            _bankAccountController.text.trim().isNotEmpty,
                        buttonLabel: 'Add Now',
                        onTap: () {
                          _showDocumentUploadModal(
                            title: 'Bank Account / UPI',
                            labelText: 'Bank Account Number or UPI ID',
                            controller: _bankAccountController,
                            photo: _upiQrCode,
                            onPhotoPicked: (f) =>
                                setState(() => _upiQrCode = f),
                          );
                        },
                      ),

                      SizedBox(height: 10.h),

                      _KycDocumentCard(
                        icon: Icons.face_retouching_natural_rounded,
                        iconColor: tealPrimary,
                        title: 'Selfie Verification',
                        subtitle: 'Take a selfie to verify your identity',
                        isUploaded: _profilePhoto != null,
                        buttonLabel: 'Verify',
                        onTap: () {
                          _pickImage(
                            (f) => setState(() => _profilePhoto = f),
                            source: ImageSource.camera,
                          );
                        },
                      ),

                      SizedBox(height: 14.h),

                      // 4. 100% SECURE & CONFIDENTIAL BANNER
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 12.h,
                        ),
                        decoration: BoxDecoration(
                          color: tealBgLight,
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Icon(
                                  Icons.shield_rounded,
                                  size: 32.sp,
                                  color: tealPrimary,
                                ),
                                Container(
                                  padding: EdgeInsets.all(2.r),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.lock_rounded,
                                    size: 12.sp,
                                    color: tealPrimary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '100% Secure & Confidential',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                      color: darkText,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    'Your data is encrypted and safe with us.',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w400,
                                      color: subtitleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                // Theme minimumSize is full-width; crashes in a Row.
                                minimumSize: Size.zero,
                                side: const BorderSide(
                                  color: tealPrimary,
                                  width: 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 6.h,
                                ),
                              ),
                              child: Text(
                                'Know More',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: tealPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_errorText != null) ...[
                        SizedBox(height: 12.h),
                        Text(
                          _errorText!,
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13.sp,
                          ),
                        ),
                      ],

                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
              ),

              // 5. BOTTOM SUBMIT KYC BUTTON
              Padding(
                padding: EdgeInsets.all(16.r),
                child: SizedBox(
                  width: double.infinity,
                  height: 50.h,
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
                                'Submit KYC',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 20.sp,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KycDocumentCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isUploaded;
  final bool isActive;
  final String buttonLabel;
  final VoidCallback onTap;

  const _KycDocumentCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isUploaded,
    this.isActive = false,
    this.buttonLabel = 'Upload',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const tealPrimary = AppColors.primary;
    const darkText = AppColors.lightTextPrimary;
    const subtitleColor = AppColors.lightTextSecondary;
    const borderColor = AppColors.lightBorder;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isActive ? tealPrimary : borderColor,
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left Circle Icon
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 22.sp,
                color: iconColor,
              ),
            ),
            SizedBox(width: 12.w),

            // Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5.sp,
                      fontWeight: FontWeight.w700,
                      color: darkText,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w400,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),

            // Right Status Badge / Action Button
            if (isUploaded)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.online.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14.sp,
                          color: AppColors.online,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Verified',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.online,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20.sp,
                    color: subtitleColor,
                  ),
                ],
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(4.r),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: tealPrimary,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 12.sp,
                          color: tealPrimary,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        buttonLabel,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: tealPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 6.w),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20.sp,
                    color: subtitleColor,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
