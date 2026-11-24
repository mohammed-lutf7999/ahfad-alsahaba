import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_constants.dart';
import '../../core/app_routes.dart';
import '../../core/startup_bootstrap.dart';
import '../../data/local/shared_prefs_service.dart';
import '../../data/models/achievement_model.dart';
import '../../data/services/achievement_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/profile_service.dart';
import 'splash/splash_painters.dart';
import 'splash/splash_visuals.dart';

export 'splash/splash_painters.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _particleController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeParticles();
    _startAnimations();
  }

  void _initializeAnimations() {
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _rotationController = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _particleController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _initializeParticles() {
    for (int i = 0; i < 35; i++) {
      _particles.add(
        Particle(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          size: _random.nextDouble() * 4 + 2,
          speed: _random.nextDouble() * 0.25 + 0.08,
          opacity: _random.nextDouble() * 0.6 + 0.2,
        ),
      );
    }
  }

  void _startAnimations() {
    _mainController.forward();
    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
    _shimmerController.repeat();
    _particleController.repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resolveInitialNavigation();
    });
  }

  Future<void> _resolveInitialNavigation() async {
    if (!mounted) return;

    if (!SharedPrefsService.isOnboardingSeen()) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
      return;
    }

    if (ProfileService.instance.hasProfiles) {
      unawaited(_runLocalAndBackgroundReconciliation());
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }
      return;
    }

    await StartupBootstrap.ensureSupabaseReady()
        .timeout(const Duration(seconds: 3), onTimeout: () => false);

    final user = AuthService().currentUser;
    if (user != null) {
      try {
        final displayName = user.userMetadata?['full_name'] ??
            user.userMetadata?['name'] ??
            'لاعب';
        await ProfileService.instance
            .createOrLoadProfileForUser(
              userId: user.id,
              displayName: displayName.toString(),
            )
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Error restoring profile in splash: $e');
      }

      unawaited(_runLocalAndBackgroundReconciliation());
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.profileSetup,
        arguments: {'isFirstTime': true},
      );
    }
  }

  Future<void> _runLocalAndBackgroundReconciliation() async {
    try {
      await AchievementService.instance
          .checkAchievements(AchievementEvent.appOpened());
      await AchievementService.instance.reconcileAchievements();
      await StartupBootstrap.runBackgroundStartupSync();
    } catch (e) {
      debugPrint('Error reconciling achievements/cloud in background: $e');
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A0F2E),
              Color(0xFF2D1B4E),
              Color(0xFF1A0F2E),
              Color(0xFF0D0618),
            ],
            stops: [0.0, 0.4, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: ParticlePainter(
                      particles: _particles,
                      progress: _particleController.value,
                    ),
                    size: size,
                  );
                },
              ),
            ),
            RepaintBoundary(
              child: Center(
                child: AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationController.value * math.pi * 2,
                      child: child,
                    );
                  },
                  child: CustomPaint(
                    painter: IslamicPatternPainter(
                      color: SplashPalette.imperialGold.withAlpha(20),
                    ),
                    size: Size(size.width * 1.5, size.width * 1.5),
                  ),
                ),
              ),
            ),
            SplashCornerOrnament(
              alignment: Alignment.topLeft,
              fadeAnimation: _fadeAnimation,
            ),
            SplashCornerOrnament(
              alignment: Alignment.topRight,
              fadeAnimation: _fadeAnimation,
              flip: true,
            ),
            SplashCornerOrnament(
              alignment: Alignment.bottomLeft,
              fadeAnimation: _fadeAnimation,
              flipVertical: true,
            ),
            SplashCornerOrnament(
              alignment: Alignment.bottomRight,
              fadeAnimation: _fadeAnimation,
              flip: true,
              flipVertical: true,
            ),
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 300 * _pulseAnimation.value,
                    height: 300 * _pulseAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          SplashPalette.imperialGold.withAlpha(30),
                          SplashPalette.imperialGold.withAlpha(10),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge(
                    [_fadeAnimation, _scaleAnimation, _slideAnimation],
                  ),
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.translate(
                        offset: Offset(0, _slideAnimation.value),
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) => Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        ),
                        child: const SplashLogoWidget(),
                      ),
                      const SizedBox(height: 40),
                      SplashAppNameBlock(shimmerAnimation: _shimmerController),
                      const SizedBox(height: 14),
                      const SplashSubtitleCapsule(),
                      const SizedBox(height: 55),
                      SplashLoadingIndicator(
                        rotationAnimation: _rotationController,
                        pulseAnimation: _pulseAnimation,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) => Opacity(
                      opacity: _fadeAnimation.value * 0.9,
                      child: child,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              SplashPalette.lightGold,
                              SplashPalette.imperialGold,
                              SplashPalette.lightGold,
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            '﷽',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'الإصدار ${AppConstants.appVersion}',
                          style: TextStyle(
                            color: SplashPalette.imperialGold.withAlpha(120),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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
