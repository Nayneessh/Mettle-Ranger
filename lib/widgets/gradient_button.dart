import 'package:flutter/material.dart';

import '../app_theme.dart';

/// The gold, "blingy" primary CTA — a diagonal gradient sweep plus a soft
/// gold glow, replacing the flat single-tone default [ElevatedButton] on
/// the handful of highest-visibility actions (Start Session, Save, Log a
/// check-in, Create). Everything else stays the plain Material button;
/// this is reserved for the one action a screen most wants tapped.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 56,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double height;

  static const _onGold = Color(0xFF241B00);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: enabled ? AppColors.goldGradient : null,
              color: enabled ? null : AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(14),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.38),
                        blurRadius: 18,
                        spreadRadius: -2,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: enabled ? _onGold : AppColors.onSurfaceFaint,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: enabled ? _onGold : AppColors.onSurfaceFaint,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
