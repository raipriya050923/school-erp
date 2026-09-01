import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The single surface primitive used across the app: a flat card with a hair
/// line border and an optional tap target.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.borderColor,
    this.color,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color border =
        borderColor ?? theme.dividerTheme.color ?? theme.dividerColor;

    return Material(
      color: color ?? theme.cardTheme.color,
      borderRadius: AppRadius.cardRadius,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: border),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A rounded, tinted square holding an icon — used in list rows and stat tiles.
class SoftIcon extends StatelessWidget {
  const SoftIcon(
    this.icon, {
    super.key,
    required this.color,
    this.size = 44,
    this.iconSize = 21,
    this.radius = AppRadius.md,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: isDark ? Color.lerp(color, Colors.white, 0.25) : color,
      ),
    );
  }
}
