import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// A circular progress ring with a value centered inside it — the Today
/// screen's weekly-goal gauge (Winter Arc reference's milestone dial,
/// adapted: martial arts logged here has no per-lift weight/PR to plot
/// against, so this tracks the one number the app already has an honest
/// weekly target for for — mat minutes toward [Goals.weeklyMatMinutesTarget]).
///
/// Paints the gradient arc directly with a [CustomPainter] rather than a
/// `ShaderMask` wrapped around a separate `CircularProgressIndicator` — that
/// combination is a known-quirky pairing: the round stroke cap's
/// antialiased edge pixels carry partial alpha, and modulating those against
/// the shader can leave a thin sliver of the masked child's own base color
/// (here, white) visible right at the arc's start/end. Painting the arc's
/// stroke with a gradient-shaded `Paint` directly removes that whole
/// masking step, so there is nothing left to leave a seam.
class GoalRing extends StatelessWidget {
  const GoalRing({
    super.key,
    required this.progress,
    required this.centerValue,
    required this.centerUnit,
    this.size = 96,
    this.strokeWidth = 8,
  });

  /// 0–1. Values above 1 are clamped — a goal met is full, not overflowing.
  final double progress;
  final String centerValue;
  final String centerUnit;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _GoalRingPainter(
              progress: clamped,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerValue,
                style: AppTextStyles.numeral(
                  fontSize: 20,
                  color: AppColors.gold,
                ),
              ),
              Text(
                centerUnit,
                style: const TextStyle(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalRingPainter extends CustomPainter {
  const _GoalRingPainter({required this.progress, required this.strokeWidth});

  final double progress;
  final double strokeWidth;

  static const _sweepColors = [
    AppColors.goldStrong,
    AppColors.gold,
    AppColors.goldDeep,
    AppColors.goldStrong,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppColors.nightBlueWash;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    // CircularProgressIndicator's own convention: start at the top (-90°)
    // and sweep clockwise. SweepGradient's own 0.0 stop sits at the 3
    // o'clock position by default, so it's rotated to match — otherwise the
    // gradient's colors would land at the wrong point along the arc, not
    // wrong in a way that's visible as a gap, but wrong all the same.
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      transform: GradientRotation(-math.pi / 2),
      colors: _sweepColors,
    );
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(arcRect);

    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoalRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.strokeWidth != strokeWidth;
}
