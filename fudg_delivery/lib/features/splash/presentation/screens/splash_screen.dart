import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:food_user_application/core/services/update_service.dart';

import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';

/// The brand teal the customer app's splash is painted in.
///
/// Deliberately a literal, not `AppColors.primary` — this splash must match
/// the customer app's brand color exactly even if that constant changes.
const Color _splashBrand = Color(0xFFF41222);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _animationController;

  late Animation<double> _blobScale;
  late Animation<double> _screenSpread;
  late Animation<double> _logoOpacity;
  late Animation<double> _loaderOpacity;

  /// Navigation waits for this. Auth often resolves well before the animation
  /// does, and leaving without it cuts the splash off part-way through.
  bool _animationDone = false;

  @override
  void initState() {
    super.initState();
    UpdateService.checkForUpdate();
    // Hide status bar during splash screen (keeps bottom nav bar if present)
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom],
    );
    _setupSuperSmoothAnimations();
  }

  void _setupSuperSmoothAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );

    _blobScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.38, curve: Curves.easeOutBack),
      ),
    );

    _screenSpread = Tween<double>(begin: 1.0, end: 16.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.45, 0.85, curve: Curves.easeInOutCubic),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.15, 0.48, curve: Curves.easeIn),
      ),
    );

    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
      ),
    );

    _animationController.forward().then((_) {
      _animationDone = true;
      _tryNavigate();
    });
  }

  void _tryNavigate() {
    if (!mounted || !_animationDone) return;
    final authState = ref.read(authControllerProvider);
    if (authState is AuthInitial || authState is AuthLoading) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 300), _tryNavigate);
      return;
    }
    if (authState is AuthAuthenticated) {
      context.go('/main');
    } else if (authState is AuthNeedsRegistration) {
      context.go('/register');
    } else if (authState is AuthPendingApproval) {
      context.go('/account-status');
    } else {
      context.go('/phone-login');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) => _tryNavigate(),
    );

    return Scaffold(
      backgroundColor: _splashBrand,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Premium Hand-crafted Amoeba Shape
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              double currentScale = _blobScale.value * _screenSpread.value;

              return Transform.scale(
                scale: currentScale,
                child: ClipPath(
                  clipper: PerfectAmoebaClipper(),
                  child: Container(
                    width: 480,
                    height: 480,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),

          // 2. Logo Component
          AnimatedBuilder(
            animation: _logoOpacity,
            builder: (context, child) {
              return Opacity(
                opacity: _logoOpacity.value,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/image/logo.png',
                        width: 270,
                        height: 270,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Text(
                            'Eatinfinity',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 3. Bottom Loader Dots Matrix
          Positioned(
            bottom: 65,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _loaderOpacity,
                builder: (context, child) {
                  return Opacity(
                    opacity: _loaderOpacity.value,
                    child: const VideoStyleDotLoader(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Clipper utilizing precise control vectors to map a fluid, smooth amoebic structure
class PerfectAmoebaClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Start at a smooth dip on the top side
    path.moveTo(w * 0.50, h * 0.25);

    // Top-right smooth protrusion
    path.cubicTo(w * 0.60, h * 0.15, w * 0.75, h * 0.10, w * 0.82, h * 0.25);
    path.cubicTo(w * 0.88, h * 0.38, w * 0.72, h * 0.48, w * 0.85, h * 0.55);

    // Mid-right fluid extension
    path.cubicTo(w * 0.98, h * 0.62, w * 0.95, h * 0.78, w * 0.78, h * 0.82);

    // Bottom asymmetric elongated pseudopodia lobe
    path.cubicTo(w * 0.65, h * 0.85, w * 0.55, h * 0.98, w * 0.42, h * 0.90);
    path.cubicTo(w * 0.32, h * 0.82, w * 0.35, h * 0.70, w * 0.22, h * 0.72);

    // Bottom-left wide organic curve
    path.cubicTo(w * 0.08, h * 0.75, w * 0.02, h * 0.55, w * 0.15, h * 0.45);

    // Upper-left smooth arm wrapping back around the logo area
    path.cubicTo(w * 0.25, h * 0.38, w * 0.12, h * 0.20, w * 0.32, h * 0.22);
    path.cubicTo(w * 0.42, h * 0.24, w * 0.45, h * 0.30, w * 0.50, h * 0.25);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class VideoStyleDotLoader extends StatefulWidget {
  const VideoStyleDotLoader({super.key});

  @override
  State<VideoStyleDotLoader> createState() => _VideoStyleDotLoaderState();
}

class _VideoStyleDotLoaderState extends State<VideoStyleDotLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            double delay = index * 0.2;
            double progress = (_dotController.value - delay);
            if (progress < 0) progress += 1.0;

            double scaleOpacity = Curves.easeInOut.transform(
              progress <= 0.5 ? progress * 2 : (1.0 - progress) * 2,
            );

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5.0),
              width: 5.5,
              height: 5.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white
                    .withValues(alpha: 0.25 + (scaleOpacity * 0.75)),
              ),
            );
          }),
        );
      },
    );
  }
}
