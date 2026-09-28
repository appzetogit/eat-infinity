import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:food_user_application/config/constants/app_constants.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/auth/domain/restaurant_model.dart';
import 'package:food_user_application/features/registration/presentation/widgets/image_picker_tile.dart';
import 'package:food_user_application/features/registration/presentation/widgets/labeled_text_field.dart';
import 'package:food_user_application/features/restaurant_profile/data/restaurant_repository.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/widgets/edit_field_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_media_controller.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';

class OutletInfoScreen extends ConsumerWidget {
  const OutletInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantAsync = ref.watch(restaurantProfileControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        title: Text(
          'Outlet info',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (restaurantAsync.value != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Text(
                  'ID: ${restaurantAsync.value!.restaurantId.isNotEmpty ? restaurantAsync.value!.restaurantId : restaurantAsync.value!.id.substring(0, restaurantAsync.value!.id.length.clamp(0, 6))}',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: restaurantAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error is ApiException
                  ? error.message
                  : 'Failed to load outlet info.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (restaurant) => AppRefreshIndicator(
          onRefresh: () =>
              ref.read(restaurantProfileControllerProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBanner(context, restaurant),
                _buildLogoCard(context, ref, restaurant),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Restaurant Information',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'All onboarding and profile details at one place.',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildRestaurantNameCard(context, ref, restaurant),
                      const SizedBox(height: 16),
                      _buildBasicDetailsCard(context, ref, restaurant),
                      const SizedBox(height: 16),
                      _buildAddressCard(context, restaurant),
                      const SizedBox(height: 16),
                      _buildComplianceCard(context, ref, restaurant),
                      const SizedBox(height: 16),
                      _buildBankDetailsCard(context, ref, restaurant),
                      const SizedBox(height: 16),
                      _buildMediaCard(context, ref, restaurant),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBanner(BuildContext context, RestaurantModel restaurant) {
    if (restaurant.isApproved) return const SizedBox.shrink();

    final message = restaurant.isRejected
        ? (restaurant.rejectionReason.isNotEmpty
              ? restaurant.rejectionReason
              : 'Your application was rejected. Please contact support.')
        : "Your restaurant is still under review — customers can't order from you yet.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 24, bottom: 24, left: 16, right: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF43305D), Color(0xFF704478)],
        ),
      ),
      child: Column(
        children: [
          Text(
            restaurant.isRejected
                ? 'Application Rejected'
                : "We'll be there soon - hang tight!",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return Transform.translate(
      offset: restaurant.isApproved ? Offset.zero : const Offset(0, -20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primarySurfaceStrong, AppColors.primarySurface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -16,
                bottom: -16,
                child: Opacity(
                  opacity: 0.15,
                  child: Image.asset(
                    'assets/image/shopman.webp',
                    width: 130,
                    height: 130,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: restaurant.profileImage.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: restaurant.profileImage,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _logoPlaceholder(),
                              )
                            : _logoPlaceholder(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              restaurant.restaurantName.isNotEmpty
                                  ? restaurant.restaurantName
                                  : '—',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (restaurant.isApproved)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green.shade600,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Verified',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          if (restaurant.isApproved) {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Change restaurant logo?'),
                                content: const Text(
                                  'Your restaurant is currently approved. Changing the logo will send your '
                                  'profile back for admin review, and ordering will pause until re-approved.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Continue'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                          }
                          final file = await pickImageWithSourceSheet(context);
                          if (file == null) return;
                          try {
                            await ref
                                .read(
                                  restaurantProfileControllerProvider.notifier,
                                )
                                .uploadProfileImage(file);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Logo updated.')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) _showError(context, e);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.camera_alt_outlined,
                                size: 16,
                                color: Colors.black87,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Change logo',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Text(
                              restaurant.totalRatings > 0 
                                  ? restaurant.rating.toStringAsFixed(1) 
                                  : 'New',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            if (restaurant.totalRatings > 0) ...[
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 12,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${restaurant.totalRatings} Ratings',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '|',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Be the first to review!',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Container(
      width: 64,
      height: 64,
      color: const Color(0xFF5B3B68),
      child: const Center(child: Icon(Icons.storefront, color: Colors.white70)),
    );
  }

  Widget _buildRestaurantNameCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return _buildInfoCard(
      context: context,
      title: 'Restaurant name',
      showApprovedBadge: restaurant.isApproved,
      onEdit: () async {
        final result = await showEditFieldSheet(
          context: context,
          title: 'Edit restaurant name',
          fields: [
            EditFieldSpec(
              key: 'restaurantName',
              label: 'Restaurant name',
              initialValue: restaurant.restaurantName,
            ),
          ],
        );
        if (result == null) return;
        await _saveProfile(context, ref, result);
      },
      children: [
        _buildDetailRow(
          context,
          'Restaurant Name',
          restaurant.restaurantName,
          icon: Icons.storefront_outlined,
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildBasicDetailsCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return _buildInfoCard(
      context: context,
      title: 'Basic details',
      showApprovedBadge: restaurant.isApproved,
      onEdit: () async {
        final result = await showEditFieldSheet(
          context: context,
          title: 'Edit basic details',
          fields: [
            EditFieldSpec(
              key: 'ownerName',
              label: 'Owner name',
              initialValue: restaurant.ownerName,
            ),
            EditFieldSpec(
              key: 'primaryContactNumber',
              label: 'Primary contact',
              initialValue: restaurant.primaryContactNumber,
              keyboardType: TextInputType.phone,
            ),
            EditFieldSpec(
              key: 'ownerEmail',
              label: 'Email',
              initialValue: restaurant.ownerEmail,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        );
        if (result == null) return;
        await _saveProfile(context, ref, result);
      },
      children: [
        _buildDetailRow(
          context,
          'Owner name',
          restaurant.ownerName,
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          context,
          'Primary contact',
          restaurant.primaryContactNumber,
          icon: Icons.phone_outlined,
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          context,
          'Email',
          restaurant.ownerEmail.isEmpty ? 'Not set' : restaurant.ownerEmail,
          icon: Icons.mail_outline,
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildAddressCard(BuildContext context, RestaurantModel restaurant) {
    return _buildInfoCard(
      context: context,
      title: 'Address and location',
      showApprovedBadge: false,
      hideEdit: true,
      children: [
        _buildDetailRow(
          context,
          'Full address',
          restaurant.fullAddress.isNotEmpty
              ? restaurant.fullAddress
              : 'Not set yet',
          isVertical: true,
        ),
        if (restaurant.hasPendingLocationUpdate) ...[
          const SizedBox(height: 16),
          Text(
            'A location update is pending admin review.',
            style: TextStyle(
              color: AppColors.warningDark,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => context.push('/zone-setup'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.my_location,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Update via Zone Setup',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.primary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComplianceCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return _buildInfoCard(
      context: context,
      title: 'Compliance details',
      showApprovedBadge: restaurant.isApproved,
      onEdit: () => _openComplianceSheet(context, ref, restaurant),
      children: [
        _buildDetailRow(
          context,
          'PAN number',
          restaurant.panNumber.isEmpty ? 'Not set' : restaurant.panNumber,
          icon: Icons.credit_card_outlined,
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          context,
          'GST registered',
          restaurant.gstRegistered ? 'Yes' : 'No',
          icon: Icons.receipt_long_outlined,
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          context,
          'FSSAI number',
          restaurant.fssaiNumber.isEmpty ? 'Not set' : restaurant.fssaiNumber,
          icon: Icons.shield_outlined,
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          context,
          'FSSAI expiry',
          restaurant.fssaiExpiry.isEmpty ? 'Not set' : restaurant.fssaiExpiry,
          icon: Icons.event_outlined,
          showDivider: false,
        ),
      ],
    );
  }

  Widget _buildBankDetailsCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return _buildInfoCard(
      context: context,
      title: 'Bank and UPI details',
      showApprovedBadge: restaurant.isApproved,
      onEdit: () async {
        final result = await showEditFieldSheet(
          context: context,
          title: 'Edit bank & UPI details',
          fields: [
            EditFieldSpec(
              key: 'accountHolderName',
              label: 'Account holder',
              initialValue: restaurant.accountHolderName,
            ),
            EditFieldSpec(
              key: 'accountNumber',
              label: 'Account number',
              initialValue: restaurant.accountNumber,
              keyboardType: TextInputType.number,
            ),
            EditFieldSpec(
              key: 'ifscCode',
              label: 'IFSC code',
              initialValue: restaurant.ifscCode,
            ),
            EditFieldSpec(
              key: 'upiId',
              label: 'UPI ID',
              initialValue: restaurant.upiId,
            ),
          ],
        );
        if (result == null) return;
        await _saveProfile(context, ref, result);
      },
      children: [
        _buildDetailRow(
          context,
          'Account holder',
          restaurant.accountHolderName.isEmpty
              ? 'Not set'
              : restaurant.accountHolderName,
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          context,
          'Account number',
          _maskAccount(restaurant.accountNumber),
          icon: Icons.account_balance_outlined,
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          context,
          'IFSC code',
          restaurant.ifscCode.isEmpty ? 'Not set' : restaurant.ifscCode,
          icon: Icons.pin_outlined,
        ),
        const SizedBox(height: 12),
        _buildDetailRow(
          context,
          'UPI ID',
          restaurant.upiId.isEmpty ? 'Not set' : restaurant.upiId,
          icon: Icons.qr_code_outlined,
          showDivider: false,
        ),
      ],
    );
  }

  String _maskAccount(String accountNumber) {
    if (accountNumber.isEmpty) return 'Not set';
    if (accountNumber.length <= 4) return accountNumber;
    return '•••• •••• ${accountNumber.substring(accountNumber.length - 4)}';
  }

  Future<void> _saveProfile(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> patch,
  ) async {
    try {
      await ref
          .read(restaurantProfileControllerProvider.notifier)
          .updateProfile(patch);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved.')));
      }
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

  Future<void> _openComplianceSheet(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ComplianceEditSheet(restaurant: restaurant),
    );
  }

  String _resolveMediaUrl(String path) => AppConstants.resolveMediaUrl(path);

  Widget _buildMediaCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    final mediaState = ref.watch(restaurantMediaControllerProvider);

    return _buildInfoCard(
      context: context,
      title: 'Restaurant media',
      showApprovedBadge: false,
      hideEdit: true,
      children: [
        mediaState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text(
            'Failed to load media: $err',
            style: const TextStyle(color: Colors.red),
          ),
          data: (media) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cover Image',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final file = await pickImageWithSourceSheet(context);
                    if (file == null) return;
                    try {
                      await ref
                          .read(restaurantMediaControllerProvider.notifier)
                          .uploadCoverImage(file);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cover image updated.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) _showError(context, e);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: media.coverImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: _resolveMediaUrl(media.coverImage),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 32, color: Colors.grey.shade600),
                              const SizedBox(height: 8),
                              Text(
                                'Add Cover Image',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Gallery Images',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '${media.galleryImages.length}/${media.maxGalleryImages}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final url in media.galleryImages)
                      Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: CachedNetworkImage(
                              imageUrl: _resolveMediaUrl(url),
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Delete Image?'),
                                    content: const Text(
                                        'Are you sure you want to delete this image?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;
                                try {
                                  await ref
                                      .read(restaurantMediaControllerProvider.notifier)
                                      .deleteGalleryImage(url);
                                } catch (e) {
                                  if (context.mounted) _showError(context, e);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    if (media.galleryImages.length < media.maxGalleryImages)
                      GestureDetector(
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();
                          final List<XFile> images = await picker.pickMultiImage(
                            limit: media.maxGalleryImages - media.galleryImages.length,
                          );
                          if (images.isEmpty) return;
                          try {
                            await ref
                                .read(restaurantMediaControllerProvider.notifier)
                                .uploadGalleryImages(images);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Gallery images uploaded.')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) _showError(context, e);
                          }
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  color: Colors.grey.shade600),
                              const SizedBox(height: 4),
                              Text(
                                'Add',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    IconData? titleIcon,
    required bool showApprovedBadge,
    required List<Widget> children,
    bool hideEdit = false,
    VoidCallback? onEdit,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (titleIcon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(titleIcon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (showApprovedBadge) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Approved',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (!hideEdit)
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.edit,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Edit',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
    bool isVertical = false,
    bool showDivider = true,
  }) {
    if (isVertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 12),
            ],
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        if (showDivider) ...[
          const SizedBox(height: 12),
          Divider(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
            height: 1,
          ),
        ],
      ],
    );
  }
}

/// Compliance is richer than a plain text-field sheet (GST toggle + document
/// images), so it gets its own small form instead of `edit_field_sheet.dart`.
class _ComplianceEditSheet extends ConsumerStatefulWidget {
  const _ComplianceEditSheet({required this.restaurant});

  final RestaurantModel restaurant;

  @override
  ConsumerState<_ComplianceEditSheet> createState() =>
      _ComplianceEditSheetState();
}

class _ComplianceEditSheetState extends ConsumerState<_ComplianceEditSheet> {
  late final _panNumber = TextEditingController(
    text: widget.restaurant.panNumber,
  );
  late final _nameOnPan = TextEditingController(
    text: widget.restaurant.nameOnPan,
  );
  late final _gstNumber = TextEditingController(
    text: widget.restaurant.gstNumber,
  );
  late final _fssaiNumber = TextEditingController(
    text: widget.restaurant.fssaiNumber,
  );
  late bool _gstRegistered = widget.restaurant.gstRegistered;
  XFile? _panImage;
  XFile? _gstImage;
  XFile? _fssaiImage;
  bool _isSaving = false;

  @override
  void dispose() {
    _panNumber.dispose();
    _nameOnPan.dispose();
    _gstNumber.dispose();
    _fssaiNumber.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final repository = ref.read(restaurantRepositoryProvider);
      final patch = <String, dynamic>{
        'panNumber': _panNumber.text.trim(),
        'nameOnPan': _nameOnPan.text.trim(),
        'gstRegistered': _gstRegistered,
        'gstNumber': _gstNumber.text.trim(),
        'fssaiNumber': _fssaiNumber.text.trim(),
      };
      if (_panImage != null)
        patch['panImage'] = await repository.uploadAttachment(
          _panImage!,
          folder: 'pan',
        );
      if (_gstImage != null)
        patch['gstImage'] = await repository.uploadAttachment(
          _gstImage!,
          folder: 'gst',
        );
      if (_fssaiImage != null)
        patch['fssaiImage'] = await repository.uploadAttachment(
          _fssaiImage!,
          folder: 'fssai',
        );

      await ref
          .read(restaurantProfileControllerProvider.notifier)
          .updateProfile(patch);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compliance details saved.')),
        );
      }
    } catch (e) {
      final message = e is ApiException
          ? e.message
          : 'Something went wrong. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit compliance details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LabeledTextField(label: 'PAN number', controller: _panNumber),
            const SizedBox(height: 16),
            LabeledTextField(label: 'Name on PAN', controller: _nameOnPan),
            const SizedBox(height: 16),
            ImagePickerTile(
              label: 'PAN card image',
              image: _panImage,
              height: 100,
              onPick: () async {
                final file = await pickImageWithSourceSheet(context);
                if (file != null) setState(() => _panImage = file);
              },
              onRemove: () => setState(() => _panImage = null),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Registered for GST?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                Switch(
                  value: _gstRegistered,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _gstRegistered = v),
                ),
              ],
            ),
            if (_gstRegistered) ...[
              const SizedBox(height: 12),
              LabeledTextField(label: 'GST number', controller: _gstNumber),
              const SizedBox(height: 16),
              ImagePickerTile(
                label: 'GST certificate image',
                image: _gstImage,
                height: 100,
                onPick: () async {
                  final file = await pickImageWithSourceSheet(context);
                  if (file != null) setState(() => _gstImage = file);
                },
                onRemove: () => setState(() => _gstImage = null),
              ),
            ],
            const SizedBox(height: 20),
            LabeledTextField(
              label: 'FSSAI number',
              controller: _fssaiNumber,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ImagePickerTile(
              label: 'FSSAI license image',
              image: _fssaiImage,
              height: 100,
              onPick: () async {
                final file = await pickImageWithSourceSheet(context);
                if (file != null) setState(() => _fssaiImage = file);
              },
              onRemove: () => setState(() => _fssaiImage = null),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
