import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/src/core/services/update_service.dart';
import 'package:food_user_application/src/presentation/navigation/route_names.dart';
import 'package:food_user_application/src/presentation/branding/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _heartbeatController;

  late Animation<double> _blobScale;
  late Animation<double> _screenSpread;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _heartbeatAnimation;

  @override
  void initState() {
    super.initState();
    // Hide status bar during splash screen (keeps bottom nav bar if present)
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom],
    );
    UpdateService.checkForUpdate();
    _setupSuperSmoothAnimations();
  }

  void _setupSuperSmoothAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    );

    _heartbeatController = AnimationController(
      duration: const Duration(milliseconds: 1100),
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

    // Initial scale up from small (0.2) to full size (1.0)
    _logoScale = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.08, 0.52, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.08, 0.38, curve: Curves.easeIn),
      ),
    );

    // Realistic double-thump heartbeat pulse animation
    _heartbeatAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.10,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.10,
          end: 1.02,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.02,
          end: 1.14,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.14,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 40,
      ),
    ]).animate(_heartbeatController);

    _animationController.forward().then((_) {
      if (mounted) {
        _heartbeatController.repeat();
      }
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          context.go(RouteNames.home);
        }
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _heartbeatController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
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

          // 2. Logo Component with Scale-Up & Heartbeat Pulse
          AnimatedBuilder(
            animation: Listenable.merge([
              _animationController,
              _heartbeatController,
            ]),
            builder: (context, child) {
              final scaleMultiplier = _heartbeatController.isAnimating
                  ? _heartbeatAnimation.value
                  : 1.0;
              final totalScale = _logoScale.value * scaleMultiplier;

              return Opacity(
                opacity: _logoOpacity.value,
                // The logo is the only thing on the splash now, so the Column
                // that used to stack it above the tagline is gone with it.
                child: Center(
                  child: Transform.scale(
                    scale: totalScale,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 250,
                      height: 250,
                      fit: BoxFit.contain,
                      // Kept: this only ever draws if logo.png itself fails to
                      // load, and a blank splash would be worse than a wordmark.
                      errorBuilder: (context, error, stackTrace) {
                        return const Text(
                          'Eatinfinity',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
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
