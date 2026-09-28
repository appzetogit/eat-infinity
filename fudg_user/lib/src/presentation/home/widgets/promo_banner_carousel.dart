import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/promo_banner_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/smart_image.dart';
import '../../navigation/route_names.dart';

/// Ultra-polished promotional banner carousel displaying high-resolution
/// admin-uploaded network banners and crisp fallback cards without image distortion.
class PromoBannerCarousel extends StatefulWidget {
  const PromoBannerCarousel({
    super.key,
    this.banners = const [],
    this.onBannerTap,
    this.compact = false,
    this.fullBleed = false,
    this.autoScroll = true,
  });

  final List<PromoBannerModel> banners;

  /// Per-banner tap handler. Defaults to always opening All Offers — the hero
  /// carousel's long-standing behaviour. Pass this to instead honour each
  /// banner's own `ctaLink` (see [PromoBannerModel.destination]).
  final void Function(BuildContext context, PromoBannerModel banner)?
  onBannerTap;

  /// Shrinks the strip for a secondary carousel (e.g. offer banners) so it
  /// doesn't compete with the hero carousel above it for attention.
  final bool compact;

  /// Full-width edge-to-edge mode for the top hero header.
  final bool fullBleed;

  /// Whether the strip auto-rotates on a timer. Off for carousels that should
  /// only move on a user swipe (e.g. offer banners).
  final bool autoScroll;

  /// Fallback card shape, used until the artwork's real one is known.
  static const double fallbackAspect = 1.45;
  static const double compactFallbackAspect = 1.45;

  /// Height of the strip for a card [cardWidth] wide showing artwork of
  /// [imageAspect] (width / height), or null while that is still loading.
  ///
  /// Derives the height *from* the aspect rather than clamping the height
  /// afterwards. Clamping the height was the cropping bug: it detached the card
  /// from the ratio it was computed from, so a 2048x768 banner (aspect 2.67)
  /// got a card of aspect 1.68 and lost ~37% of its width to `cover`. The clamp
  /// lives on the aspect instead, where it only reins in shapes no banner has
  /// — a square or a portrait poster — and leaves every wide one exact.
  /// Bounds on the card's aspect ratio.
  ///
  /// Named rather than inline so the tests can assert against the same numbers
  /// these are tuned to, instead of copies that silently go stale the next time
  /// someone adjusts the shape of the strip.
  static const double minAspect = 1.2;
  static const double compactMinAspect = 1.1;
  static const double maxAspect = 3.2;

  @visibleForTesting
  static double stripHeightFor({
    required double cardWidth,
    required double? imageAspect,
    required bool compact,
  }) {
    final aspect =
        (imageAspect ?? (compact ? compactFallbackAspect : fallbackAspect))
            .clamp(compact ? compactMinAspect : minAspect, maxAspect);
    return cardWidth / aspect;
  }

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  static const _rotateEvery = Duration(seconds: 4);

  /// How much of the strip's width one card occupies.
  ///
  /// Under 1.0 on purpose: the sliver of the next banner showing at the edge is
  /// what tells people the strip swipes. 0.94 keeps that hint while giving the
  /// card back the width it was leaving on the table — and since the card's
  /// height is derived from its width (see [PromoBannerCarousel.stripHeightFor]),
  /// widening it is the only way to make the banner bigger that doesn't crop
  /// the artwork or stretch it.
  double get _viewportFraction =>
      widget.fullBleed ? 1.0 : (widget.compact ? 0.41 : 0.94);

  /// Extra height given to the hero card beyond the artwork's own aspect ratio.
  /// 1.0 in full-bleed: the boost makes the card taller than the artwork's own
  /// ratio, which `cover` pays for by trimming the sides. That is a fair trade
  /// for a strip in the middle of the page, but the header is meant to show one
  /// banner whole, so it takes the artwork's exact shape instead.
  double get _heightBoost => widget.fullBleed ? 1.0 : 1.45;

  /// Gutter between cards, and the most any one card loses to padding.
  double get _leadGutter => widget.fullBleed ? 0 : 3.w;
  double get _trailGutter => widget.fullBleed ? 0 : 4.w;
  double get _maxGutter => _leadGutter + _trailGutter;
  static const _virtualMultiplier = 1000;

  late final PageController _controller;
  Timer? _timer;
  int _currentIndex = 0;
  bool _userInteracting = false;

  /// The first banner's true width/height, once the image has decoded.
  ///
  /// The strip used to be locked to a constant whatever the artwork
  /// actually was, which is what cropped it: a card of one shape showing an
  /// image of another has to either trim the overflow or leave a gap. Sizing
  /// the card to the image instead means neither happens.
  ///
  /// One value for the whole strip, not one per page, because a PageView gives
  /// every page the same height — and admin banner sets are uploaded at a
  /// single size in practice, so the first page's shape fits the rest.
  double? _imageAspect;
  ImageStream? _aspectStream;
  ImageStreamListener? _aspectListener;

  @override
  void initState() {
    super.initState();
    final count = _realCount;
    final initialPage = count > 1 ? count * _virtualMultiplier : 0;
    _controller = PageController(
      initialPage: initialPage,
      viewportFraction: _viewportFraction,
    );
    _currentIndex = 0;
    _startTimer();
    _resolveAspect();
  }

  @override
  void didUpdateWidget(PromoBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startTimer();
    // Banners arrive from a FutureProvider, so the first build is usually an
    // empty list and the real one lands here — re-measure when the artwork
    // changes, or the strip keeps the fallback shape forever.
    final oldUrl = oldWidget.banners.isEmpty
        ? null
        : oldWidget.banners.first.imageUrl;
    final newUrl = widget.banners.isEmpty
        ? null
        : widget.banners.first.imageUrl;
    if (oldUrl != newUrl) {
      _imageAspect = null;
      _resolveAspect();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (!widget.autoScroll) return;
    final count = _realCount;
    if (count <= 1) return;
    _timer = Timer.periodic(_rotateEvery, (_) {
      if (!mounted || _userInteracting || !_controller.hasClients) return;
      final currentPage = _controller.page?.round() ?? _controller.initialPage;
      _controller.animateToPage(
        currentPage + 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _disposeAspectStream();
    _controller.dispose();
    super.dispose();
  }

  int get _realCount => widget.banners.length;

  /// Reads the intrinsic size of the first banner off the *same* cache entry
  /// SmartImage renders from, so this costs a cache lookup rather than a second
  /// download of an image the strip is about to show anyway.
  void _resolveAspect() {
    _disposeAspectStream();
    if (widget.banners.isEmpty) return;
    final url = widget.banners.first.imageUrl;
    // Asset and data: URLs never reach CachedNetworkImageProvider; the fallback
    // aspect covers them.
    if (!url.startsWith('http')) return;

    final stream = CachedNetworkImageProvider(
      url,
    ).resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, _) {
        final aspect = info.image.width / info.image.height;
        if (mounted && aspect.isFinite && aspect > 0) {
          setState(() => _imageAspect = aspect);
        }
      },
      // A banner that fails to load keeps the fallback shape rather than
      // collapsing the strip to nothing.
      onError: (_, _) {},
    );
    stream.addListener(listener);
    _aspectStream = stream;
    _aspectListener = listener;
  }

  void _disposeAspectStream() {
    if (_aspectStream != null && _aspectListener != null) {
      _aspectStream!.removeListener(_aspectListener!);
    }
    _aspectStream = null;
    _aspectListener = null;
  }

  @override
  Widget build(BuildContext context) {
    final realCount = _realCount;
    // Nothing to page through: draw nothing rather than index an empty list.
    if (realCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final cardWidth = availableWidth * _viewportFraction;
        // Size from the *card*, not the viewport slot: the gutters below make
        // the card narrower than its slot, and deriving the height from the
        // slot would leave the card marginally wider than its own aspect —
        // putting back a sliver of the crop this is all meant to remove. The
        // widest gutter is used so no page crops; the flush-left first page
        // gains a fraction of a point of slack instead.
        // Square in the header: height tracks the width rather than a share of
        // the screen, so the banner keeps the same shape on every device
        // instead of stretching on tall phones and squashing on short ones.
        final stripHeight = widget.fullBleed
            ? availableWidth
            : PromoBannerCarousel.stripHeightFor(
                    cardWidth: cardWidth - _maxGutter,
                    imageAspect: _imageAspect,
                    compact: widget.compact,
                  ) *
                  (widget.compact ? 1.20 : _heightBoost);

        final dots = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(realCount, (index) {
            final isSelected = _currentIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              width: isSelected ? 18.w : 8.w,
              height: 8.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4.r),
                color: isSelected
                    ? AppColors.primary
                    : (widget.fullBleed
                          ? Colors.white.withValues(alpha: 0.7)
                          : const Color(0xFFCBD5E1)),
              ),
            );
          }),
        );

        final strip = SizedBox(
          height: stripHeight,
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollStartNotification) _userInteracting = true;
              if (n is ScrollEndNotification) _userInteracting = false;
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              padEnds: false,
              itemCount: realCount > 1 ? null : 1,
              onPageChanged: (pageIndex) {
                setState(() {
                  _currentIndex = pageIndex % realCount;
                });
              },
              itemBuilder: (context, pageIndex) {
                final realIndex = pageIndex % realCount;
                return Padding(
                  // Trimmed with the wider viewport above: at 0.94 the
                  // peek is only a few points, and the old 6pt gutter ate
                  // most of it.
                  padding: EdgeInsets.only(
                    left: (realIndex == 0) ? 0 : _leadGutter,
                    right: _trailGutter,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      Haptics.light();
                      final banner = widget.banners[realIndex];
                      if (widget.onBannerTap != null) {
                        widget.onBannerTap!(context, banner);
                      } else {
                        context.go(RouteNames.allOffers);
                      }
                    },
                    child: _buildNetworkBannerCard(widget.banners[realIndex]),
                  ),
                );
              },
            ),
          ),
        );

        // In full-bleed the dots go *on* the artwork, so the widget is exactly
        // as tall as the banner. Stacked underneath instead, they made the
        // carousel taller than the image it shows — and anything positioned
        // against its bottom edge, like the search bar meant to half-overlap
        // the banner, ended up floating over the dots rather than the artwork.
        if (widget.fullBleed) {
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              strip,
              Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: dots,
              ),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            strip,
            SizedBox(height: 6.h),
            dots,
          ],
        );
      },
    );
  }

  Widget _buildNetworkBannerCard(PromoBannerModel banner) {
    final radius = widget.fullBleed
        ? BorderRadius.vertical(bottom: Radius.circular(24.r))
        : BorderRadius.circular(18.r);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        // cover, filling the header outright.
        //
        // The header is square and the artwork is much wider than it is tall,
        // so this trims a lot off the left and right. That is the
        // deliberate choice of the two available: the alternative is drawing
        // the banner whole against a blurred fill of itself, which leaves most
        // of the header out of focus. Artwork cut near 1:1 would need neither.
        child: banner.isVideo
            ? _BannerVideo(url: banner.imageUrl)
            : SmartImage(
                url: banner.imageUrl,
                category: ImageCategory.restaurant,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
      ),
    );
  }
}

/// A looping, muted video banner.
///
/// Muted and autoplaying because this sits on the home screen: a banner that
/// starts talking the moment the app opens, over whatever the phone is already
/// playing, is not a banner anyone wants. No controls for the same reason — it
/// is artwork that happens to move, and the card's own tap handler still opens
/// the banner's link.
class _BannerVideo extends StatefulWidget {
  const _BannerVideo({required this.url});

  final String url;

  @override
  State<_BannerVideo> createState() => _BannerVideoState();
}

class _BannerVideoState extends State<_BannerVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant _BannerVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _controller?.dispose();
      _controller = null;
      _ready = false;
      _open();
    }
  }

  Future<void> _open() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
    } catch (_) {
      // A banner that will not load keeps its placeholder rather than taking
      // the home screen down with it.
      return;
    }
    // The carousel can page away mid-load; without this the setState lands on
    // a disposed State.
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_ready || controller == null) {
      return ColoredBox(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF242424)
            : const Color(0xFFF2F2F2),
      );
    }
    // Same treatment as the stills beside it: scaled to fill the card and
    // cropped, rather than letterboxed inside it.
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}
