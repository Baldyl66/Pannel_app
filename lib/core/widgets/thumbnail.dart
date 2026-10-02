import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';

/// Vignette (image locale ou distante) avec repli sur une icône ou des
/// initiales si l'image est absente ou ne se charge pas.
class Thumbnail extends StatelessWidget {
  final String? path;
  final IconData fallbackIcon;
  final String? fallbackText;
  final Color? fallbackColor;
  final double size;
  final double? radius;
  final BoxFit fit;
  final Color? background;

  const Thumbnail({
    super.key,
    required this.path,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackText,
    this.fallbackColor,
    this.size = 44,
    this.radius,
    this.fit = BoxFit.cover,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final color = fallbackColor ?? AppColors.textSecondary;
    final initials = fallbackText == null ? null : initialsOf(fallbackText!);
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: fallbackColor?.withValues(alpha: 0.18) ?? Colors.white.withValues(alpha: 0.06),
      child: initials != null && initials.isNotEmpty
          ? Text(
              initials,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: size * 0.36, letterSpacing: -0.5),
            )
          : Icon(fallbackIcon, color: color, size: size * 0.5),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? size * 0.28),
      child: SizedBox(
        width: size,
        height: size,
        child: path == null || path!.isEmpty
            ? fallback
            : ColoredBox(
                color: background ?? Colors.transparent,
                child: Image(
                  image: imageProviderFor(path!),
                  width: size,
                  height: size,
                  fit: fit,
                  errorBuilder: (_, _, _) => fallback,
                  frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
                    opacity: sync || frame != null ? 1 : 0,
                    duration: AppDurations.medium,
                    child: child,
                  ),
                ),
              ),
      ),
    );
  }
}
