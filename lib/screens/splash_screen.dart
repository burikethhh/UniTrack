import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/constants/app_constants.dart';

/// Animated radar sweep splash screen for ISKSULARS TRACK
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pinController;
  late AnimationController _sweepController;
  late AnimationController _ringController;
  late AnimationController _textController;
  late AnimationController _gyroController;

  late Animation<double> _pinScale;
  late Animation<double> _pinTranslateY;
  late Animation<double> _pinGlow;
  late Animation<double> _sweepAngle;
  late Animation<double> _textOpacity;
  late Animation<double> _textTranslateY;
  late Animation<double> _progressRing;
  late Animation<double> _gyroAngle;

  @override
  void initState() {
    super.initState();

    // Preload logo image before starting animations to avoid flash
    precacheImage(const AssetImage('assets/isksularstracklogo.png'), context);

    // Pin drop controller (1s)
    _pinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pinScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _pinController,
        curve: const Interval(0.0, 1.0, curve: Curves.elasticOut),
      ),
    );
    _pinTranslateY = Tween<double>(begin: -120, end: 0).animate(
      CurvedAnimation(
        parent: _pinController,
        curve: const Interval(0.0, 1.0, curve: Curves.elasticOut),
      ),
    );
    _pinGlow = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(
        parent: _pinController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Sweep controller (continuous 2.5s loop)
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _sweepAngle = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _sweepController, curve: Curves.linear),
    );
    _sweepController.repeat();

    // Ring expand controller (continuous 3s loop, staggered)
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _ringController.repeat();

    // Text rise controller (0.8s with 1.2s delay)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textTranslateY = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    // Progress ring controller (2s with 2s delay, fills once)
    _progressRing = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Gyro tilt controller (6s continuous)
    _gyroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );
    _gyroAngle = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _gyroController, curve: Curves.easeInOut),
    );
    _gyroController.repeat(reverse: true);

    // Start animations in sequence
    _startAnimations();

    // Navigate after ~4 seconds (allow full animation cycle)
    Future.delayed(const Duration(milliseconds: 4000), () {
      if (mounted) widget.onComplete();
    });
  }

  void _startAnimations() {
    _pinController.forward();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _textController.forward();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _sweepController.dispose();
    _ringController.dispose();
    _textController.dispose();
    _gyroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0a2540),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _pinController,
                _sweepController,
                _ringController,
                _textController,
                _gyroController,
              ]),
              builder: (context, child) {
                return Transform(
                  transform: Matrix4.identity()
                    ..rotateX((0.1 * sin(_gyroAngle.value * 2 * pi)).toDouble())
                    ..rotateZ((0.035 * sin(_gyroAngle.value * 2 * pi)).toDouble()),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Radar with logo
                      SizedBox(
                        width: 260,
                        height: 260,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Expanding sonar rings
                            ...List.generate(3, (i) => _buildExpandingRing(i)),

                            // Radar grid + crosshair + intersections
                            CustomPaint(
                              painter: _RadarGridPainter(
                                ringProgress: _ringController.value,
                                crosshairProgress: _ringController.value < 0.3
                                    ? _ringController.value / 0.3
                                    : 1.0,
                                intersectionProgress: _ringController.value < 0.4
                                    ? (_ringController.value - 0.3) / 0.1
                                    : 1.0,
                              ),
                              size: const Size(240, 240),
                            ),

                            // Progress ring
                            CustomPaint(
                              painter: _ProgressRingPainter(progress: _progressRing.value),
                              size: const Size(240, 240),
                            ),

                            // Sweeping arc
                            Transform.rotate(
                              angle: _sweepAngle.value,
                              child: CustomPaint(
                                painter: _SweepPainter(),
                                size: const Size(240, 240),
                              ),
                            ),

                            // Frosted ring
                            _buildFrostedRing(),

                            // Logo pin
                            Transform.translate(
                              offset: Offset(0, _pinTranslateY.value),
                              child: Transform.scale(
                                scale: _pinScale.value,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.6 * _pinGlow.value,
                                        ),
                                        blurRadius: 20 + 15 * _pinGlow.value,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/isksularstracklogo.png',
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Ping dots
                            ..._buildPingDots(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // App name with letter stagger
                      Transform.translate(
                        offset: Offset(0, _textTranslateY.value),
                        child: Opacity(
                          opacity: _textOpacity.value,
                          child: Column(
                            children: [
                              _buildGradientAppName(),
                              const SizedBox(height: 6),
                              Text(
                                AppConstants.appTagline,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.55),
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandingRing(int index) {
    final delay = index * 1000.0;
    final localProgress = (_ringController.value * 3000 - delay).clamp(0.0, 3000.0) / 3000.0;
    final scale = Tween<double>(begin: 0.25, end: 1.35)
        .transform(localProgress);
    final opacity = Tween<double>(begin: 0.0, end: 1.0)
        .transform(localProgress / 0.15)
        .clamp(0.0, 1.0) *
        (1.0 - Tween<double>(begin: 0.0, end: 1.0)
            .transform((localProgress - 0.15) / 0.85)
            .clamp(0.0, 1.0));

    if (opacity <= 0) return const SizedBox.shrink();

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25 * (1.0 - localProgress)),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrostedRing() {
    return AnimatedBuilder(
      animation: _pinController,
      builder: (context, child) {
        final pulse = (0.5 + 0.5 * sin(_pinController.value * 2 * pi * 0.5)).clamp(0.5, 1.0);
        return Container(
          width: 105,
          height: 105,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25 * pulse),
                blurRadius: 20 + 20 * pulse,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.05 * pulse),
                blurRadius: 12 + 6 * pulse,
                spreadRadius: 0,
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildPingDots() {
    final dots = [
      _PingConfig(top: 0.20, left: 0.72, color: AppColors.primary, delay: 1.5),
      _PingConfig(top: 0.73, left: 0.24, color: AppColors.primary, delay: 2.0),
      _PingConfig(top: 0.34, left: 0.16, color: AppColors.accent, delay: 2.4),
      _PingConfig(top: 0.66, left: 0.78, color: AppColors.primary, delay: 2.8),
    ];

    return dots.map((config) {
      return AnimatedBuilder(
        animation: _sweepController,
        builder: (context, child) {
          // Each dot runs on its own 2.5s cycle offset by delay
          final localTime = (_sweepController.value * 2500 + config.delay * 1000) % 2500 / 2500;
          if (localTime > 0.92) return const SizedBox.shrink();

          double opacity, scale;
          if (localTime < 0.08) {
            final t = localTime / 0.08;
            opacity = t;
            scale = 0.6 + 1.0 * t;
          } else if (localTime < 0.18) {
            final t = (localTime - 0.08) / 0.10;
            opacity = 1.0 - 0.1 * t;
            scale = 1.6 - 0.6 * t;
          } else if (localTime < 0.55) {
            opacity = 0.9 - 0.3 * ((localTime - 0.18) / 0.37);
            scale = 1.0;
          } else {
            final t = (localTime - 0.55) / 0.37;
            opacity = 0.6 - 0.55 * t;
            scale = 1.0;
          }

          return Positioned(
            top: config.top * 260,
            left: config.left * 260,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: config.color,
                    boxShadow: [
                      BoxShadow(
                        color: config.color,
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  Widget _buildGradientAppName() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          AppColors.primary,
          AppColors.primaryLight,
          AppColors.accent,
        ],
      ).createShader(bounds),
      child: Text(
        AppConstants.appName,
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: 4,
          color: Colors.white, // masked by shader
        ),
      ),
    );
  }
}

class _PingConfig {
  final double top;
  final double left;
  final Color color;
  final double delay;
  _PingConfig({required this.top, required this.left, required this.color, required this.delay});
}

/// Radar grid, crosshair, and intersection dots painter
class _RadarGridPainter extends CustomPainter {
  final double ringProgress;
  final double crosshairProgress;
  final double intersectionProgress;

  _RadarGridPainter({
    required this.ringProgress,
    required this.crosshairProgress,
    required this.intersectionProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 - 5;

    // Static concentric circles
    final circlePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final r in [maxRadius, maxRadius * 0.67, maxRadius * 0.33]) {
      canvas.drawCircle(center, r, circlePaint);
    }

    // Crosshair lines (animated draw-in)
    final crosshairPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final halfLen = maxRadius * crosshairProgress.clamp(0.0, 1.0);
    canvas.drawLine(
      Offset(center.dx - halfLen, center.dy),
      Offset(center.dx + halfLen, center.dy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - halfLen),
      Offset(center.dx, center.dy + halfLen),
      crosshairPaint,
    );

    // Intersection dots (animated glow-in)
    if (intersectionProgress > 0) {
      final dotPaint = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.fill;

      final opacities = [
        intersectionProgress.clamp(0.0, 1.0),
        intersectionProgress.clamp(0.0, 1.0),
        intersectionProgress.clamp(0.0, 1.0),
        intersectionProgress.clamp(0.0, 1.0),
        (intersectionProgress - 0.05).clamp(0.0, 1.0),
        (intersectionProgress - 0.10).clamp(0.0, 1.0),
      ];

      final positions = [
        Offset(center.dx + maxRadius, center.dy),
        Offset(center.dx - maxRadius, center.dy),
        Offset(center.dx, center.dy + maxRadius),
        Offset(center.dx, center.dy - maxRadius),
        Offset(center.dx + maxRadius * 0.67, center.dy),
        Offset(center.dx - maxRadius * 0.67, center.dy),
      ];
      final radii = [3.0, 3.0, 3.0, 3.0, 2.5, 2.5];

      for (int i = 0; i < positions.length; i++) {
        if (opacities[i] > 0) {
          canvas.drawCircle(
            positions[i],
            radii[i],
            dotPaint..color = AppColors.primary.withValues(alpha: 0.9 * opacities[i]),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarGridPainter oldDelegate) {
    return oldDelegate.ringProgress != ringProgress ||
        oldDelegate.crosshairProgress != crosshairProgress ||
        oldDelegate.intersectionProgress != intersectionProgress;
  }
}

/// Sweeping radar arc with comet tail
class _SweepPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Main sweep with radial gradient mask effect (comet tail)
    // Draw multiple arcs with decreasing opacity to simulate tapered tail
    for (int i = 0; i < 20; i++) {
      final t = i / 20.0;
      final sweepAngle = t * 2 * pi;
      final opacity = (1.0 - t).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = AppColors.primary.withValues(alpha: opacity * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.015
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, // start at top
        sweepAngle,
        false,
        paint,
      );
    }

    // Leading edge highlight
    final edgePaint = Paint()
      ..color = AppColors.primaryLight.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.02
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2 + 2 * pi * 0.985,
      2 * pi * 0.015,
      false,
      edgePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Circular progress ring painter
class _ProgressRingPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0

  _ProgressRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 5;

    // Track
    final trackPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc (starts at top, goes clockwise)
    final progressPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}