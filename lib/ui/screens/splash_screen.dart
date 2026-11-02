import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_routes.dart';
import '../../data/local/shared_prefs_service.dart';
import '../../data/services/profile_service.dart';


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

  // Imperial Gold Colors
  static const Color imperialGold = Color(0xFFD4AF37);
  static const Color lightGold = Color(0xFFF5D76E);
  static const Color darkGold = Color(0xFFB8960C);

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
      _particles.add(Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 4 + 2,
        speed: _random.nextDouble() * 0.25 + 0.08,
        opacity: _random.nextDouble() * 0.6 + 0.2,
      ));
    }
  }

  void _startAnimations() async {
    _mainController.forward();
    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
    _shimmerController.repeat();
    _particleController.repeat();


    await Future.delayed(const Duration(milliseconds: 3000));
    
    // Check login status before checking mounted to avoid async gaps in conditions
    final bool isLoggedIn = await _isUserLoggedIn();
    
    if (mounted) {
      // Check navigation flow:
      // 1. First check if onboarding was seen
      // 2. Then check if user is logged in (has active session)
      // 3. Then check if profile exists locally
      if (!SharedPrefsService.isOnboardingSeen()) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
      } else if (isLoggedIn) {
        // User is logged in - CRITICAL: Ensure profile is loaded!
        // If app restarted, ProfileService might be empty even if Session exists
        if (ProfileService.instance.activeProfile == null) {
            try {
              final user = Supabase.instance.client.auth.currentUser;
              if (user != null) {
                 final displayName = user.userMetadata?['full_name'] ?? 
                                   user.userMetadata?['name'] ?? 
                                   'لاعب';
                                   
                 await ProfileService.instance.createOrLoadProfileForUser(
                   userId: user.id,
                   displayName: displayName,
                 );
              }
            } catch (e) {
               debugPrint('Error loading profile in splash: $e');
            }
        }
        
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        }
      } else if (ProfileService.instance.hasProfiles) {
        // Not logged in but has local profiles - go to home
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      } else {
        // No login and no profiles - show profile setup
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.profileSetup,
          arguments: {'isFirstTime': true},
        );
      }
    }
  }

  /// Check if user has an active Supabase session
  Future<bool> _isUserLoggedIn() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      return session != null;
    } catch (e) {
      return false;
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
              Color(0xFF1A0F2E), // Deep Royal Purple
              Color(0xFF2D1B4E), // Royal Purple
              Color(0xFF1A0F2E), // Deep Royal Purple
              Color(0xFF0D0618), // Very Dark Purple
            ],
            stops: [0.0, 0.4, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animated particles background
            AnimatedBuilder(
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

            // Rotating geometric pattern
            Center(
              child: AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * math.pi * 2,
                    child: CustomPaint(
                      painter: IslamicPatternPainter(
                        color: imperialGold.withAlpha(20),
                      ),
                      size: Size(size.width * 1.5, size.width * 1.5),
                    ),
                  );
                },
              ),
            ),

            // Decorative corner ornaments
            _buildCornerOrnament(Alignment.topLeft),
            _buildCornerOrnament(Alignment.topRight, flip: true),
            _buildCornerOrnament(Alignment.bottomLeft, flipVertical: true),
            _buildCornerOrnament(Alignment.bottomRight, flip: true, flipVertical: true),

            // Center glow effect
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
                          imperialGold.withAlpha(30),
                          imperialGold.withAlpha(10),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Main content
            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_fadeAnimation, _scaleAnimation, _slideAnimation]),
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
                    // Animated logo with glow
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: _buildLogo(),
                    ),
                    
                    const SizedBox(height: 40),

                    // App name with shimmer effect
                    _buildAppName(),

                    const SizedBox(height: 14),

                    // Subtitle with elegant styling
                    _buildSubtitle(),
                    
                    const SizedBox(height: 55),

                    // Elegant loading indicator
                    _buildLoadingIndicator(),
                  ],
                ),
              ),
            ),

            // Bottom branding
            Positioned(
              bottom: 45,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value * 0.9,
                    child: child,
                  );
                },
                child: Column(
                  children: [
                    // Bismillah
                    ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          colors: [lightGold, imperialGold, lightGold],
                        ).createShader(bounds);
                      },
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
                      'الإصدار 1.0.0',
                      style: TextStyle(
                        color: imperialGold.withAlpha(120),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lightGold, imperialGold, darkGold],
        ),
        boxShadow: [
          BoxShadow(
            color: imperialGold.withAlpha(150),
            blurRadius: 50,
            spreadRadius: 15,
          ),
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
        border: Border.all(
          color: lightGold,
          width: 4,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner decorative rings
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withAlpha(60),
                width: 2,
              ),
            ),
          ),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withAlpha(40),
                width: 1,
              ),
            ),
          ),
          // Logo Image
          ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              width: 100, // Slightly smaller than container to show inner rings if needed, or fill
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppName() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: const [
                lightGold,
                Colors.white,
                lightGold,
              ],
              stops: [
                (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                _shimmerController.value.clamp(0.0, 1.0),
                (_shimmerController.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Column(
        children: [
            Text(
              'معركة أحفاد الصحابة',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28, // Slightly smaller to fit "Battle of..."
                fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black.withAlpha(80),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
                Shadow(
                  color: imperialGold.withAlpha(80),
                  offset: const Offset(0, 0),
                  blurRadius: 25,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  imperialGold.withAlpha(0),
                  imperialGold.withAlpha(50),
                  imperialGold.withAlpha(0),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '─── تحدي العُظماء ───',
              style: TextStyle(
                color: imperialGold,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                shadows: [
                  Shadow(
                    color: Colors.black.withAlpha(60),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withAlpha(0),
            Colors.white.withAlpha(20),
            Colors.white.withAlpha(0),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: imperialGold.withAlpha(50),
          width: 1,
        ),
      ),
      child: Text(
        'اكتشف قوة المعرفة الإسلامية',
        style: TextStyle(
          color: Colors.white.withAlpha(220),
          fontSize: 10,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 55,
      height: 55,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating ring
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationController.value * math.pi * 2,
                child: Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: imperialGold.withAlpha(50),
                      width: 2,
                    ),
                    gradient: SweepGradient(
                      colors: [
                        Colors.transparent,
                        imperialGold.withAlpha(180),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Inner pulsing dot
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 14 * _pulseAnimation.value,
                height: 14 * _pulseAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [lightGold, imperialGold],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: imperialGold.withAlpha(150),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCornerOrnament(Alignment alignment, {bool flip = false, bool flipVertical = false}) {
    return Positioned(
      top: alignment == Alignment.topLeft || alignment == Alignment.topRight ? 0 : null,
      bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight ? 0 : null,
      left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft ? 0 : null,
      right: alignment == Alignment.topRight || alignment == Alignment.bottomRight ? 0 : null,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value * 0.5,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..scale(flip ? -1.0 : 1.0, flipVertical ? -1.0 : 1.0),
              child: CustomPaint(
                painter: CornerOrnamentPainter(
                  color: imperialGold,
                ),
                size: const Size(120, 120),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Particle model
class Particle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

// Particle painter
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double progress;

  ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final y = (particle.y + progress * particle.speed) % 1.0;
      final paint = Paint()
        ..color = _SplashScreenState.imperialGold.withAlpha((particle.opacity * 255).toInt())
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(particle.x * size.width, y * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

// Islamic pattern painter
class IslamicPatternPainter extends CustomPainter {
  final Color color;

  IslamicPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    // Draw 8-pointed star pattern
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4);
      canvas.drawLine(
        center,
        Offset(
          center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius,
        ),
        paint,
      );
    }

    // Draw concentric circles
    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(center, radius * i / 5, paint);
    }

    // Draw octagon
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - math.pi / 8;
      final point = Offset(
        center.dx + math.cos(angle) * radius * 0.9,
        center.dy + math.sin(angle) * radius * 0.9,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(IslamicPatternPainter oldDelegate) => false;
}

// Corner ornament painter
class CornerOrnamentPainter extends CustomPainter {
  final Color color;

  CornerOrnamentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    
    // Draw curved corner ornament
    path.moveTo(0, size.height * 0.8);
    path.quadraticBezierTo(0, 0, size.width * 0.8, 0);
    
    path.moveTo(0, size.height * 0.6);
    path.quadraticBezierTo(0, 0, size.width * 0.6, 0);

    path.moveTo(0, size.height * 0.4);
    path.quadraticBezierTo(0, 0, size.width * 0.4, 0);

    path.moveTo(0, size.height * 0.2);
    path.quadraticBezierTo(0, 0, size.width * 0.2, 0);

    canvas.drawPath(path, paint);

    // Draw decorative dots
    final dotPaint = Paint()
      ..color = color.withAlpha(100)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.12, size.height * 0.12), 4, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.22, size.height * 0.08), 3, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.22), 3, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.05, size.height * 0.35), 2, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.05), 2, dotPaint);
  }

  @override
  bool shouldRepaint(CornerOrnamentPainter oldDelegate) => false;
}
