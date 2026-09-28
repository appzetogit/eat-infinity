import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../branding/app_colors.dart';

enum ImageCategory { restaurant, food, category, brand }

class SmartImage extends StatelessWidget {
  final String url;
  final ImageCategory category;
  final BoxFit fit;
  final double? width;
  final double? height;
  final FilterQuality filterQuality;

  const SmartImage({
    super.key,
    required this.url,
    required this.category,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.filterQuality = FilterQuality.high,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _placeholder();
    }

    // Only apply cacheWidth if width is >= 300 to prevent downsampling low-res/icon assets
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final hasLargeWidth = width != null && width!.isFinite && width! >= 300;
    final cacheWidth = hasLargeWidth ? (width! * dpr * 1.5).round() : null;

    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: cacheWidth,
        filterQuality: filterQuality,
        fadeInDuration: const Duration(milliseconds: 150),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (context, url) => _skeleton(context),
        errorWidget: (context, url, error) => _placeholder(),
      );
    }

    // Inline data: URIs come from seeded placeholder records. They are not
    // assets, so Image.asset would throw — and the app has no SVG renderer, so
    // there is nothing honest to draw. Show the category placeholder until a
    // real image is uploaded through the admin panel.
    if (url.startsWith('data:')) return _placeholder();

    return Image.asset(
      url,
      fit: fit,
      width: width,
      height: height,
      cacheWidth: cacheWidth,
      filterQuality: filterQuality,
      isAntiAlias: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _skeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      color: isDark ? const Color(0xFF242424) : const Color(0xFFF2F2F2),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.primaryTintStrong,
      alignment: Alignment.center,
      child: Icon(
        category == ImageCategory.food ? Icons.restaurant_rounded : Icons.storefront_rounded,
        color: AppColors.primaryAlpha(0.6),
        size: (width != null && width! < 40) ? width! * 0.6 : 28,
      ),
    );
  }
}
