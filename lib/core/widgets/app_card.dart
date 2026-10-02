import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Carte de base de l'application.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final DecorationImage? image;
  final Gradient? gradient;
  final double radius;
  final double? height;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.onLongPress,
    this.color,
    this.image,
    this.gradient,
    this.radius = AppRadius.lg,
    this.height,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final content = Material(
      color: Colors.transparent,
      child: Ink(
        height: height,
        decoration: BoxDecoration(
          color: gradient == null ? (color ?? AppColors.surface) : null,
          gradient: gradient,
          image: image,
          borderRadius: borderRadius,
          border: Border.all(color: borderColor ?? AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: borderRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return onTap == null && onLongPress == null ? content : Pressable(child: content);
  }
}

/// Réduit légèrement son enfant quand on appuie dessus.
class Pressable extends StatefulWidget {
  final Widget child;
  final double scale;
  const Pressable({super.key, required this.child, this.scale = 0.975});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        child: widget.child,
      ),
    );
  }
}

/// Pastille arrondie colorée qui accueille une icône.
class IconBadge extends StatelessWidget {
  final Widget icon;
  final Color color;
  final double size;
  final bool circle;
  final bool solid;

  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
    this.circle = false,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = solid
        ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black)
        : color;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.16),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.28),
      ),
      child: IconTheme(
        data: IconThemeData(color: fg, size: size * 0.52),
        child: icon,
      ),
    );
  }
}

/// Bloc grisé animé affiché pendant les chargements.
class SkeletonBox extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const SkeletonBox({super.key, this.height = 120, this.width, this.radius = AppRadius.lg});

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Petite étiquette arrondie (« Dans 3 jours », « Nitro »…).
class AppTag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const AppTag({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}
