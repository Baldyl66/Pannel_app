import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';

/// Vignette d'image (locale ou distante) avec repli sur une icône si l'image
/// est absente ou ne se charge pas.
class Thumbnail extends StatelessWidget {
  final String? path;
  final IconData fallbackIcon;
  final double size;
  final double radius;
  final BoxFit fit;
  final Color? background;

  const Thumbnail({
    super.key,
    required this.path,
    required this.fallbackIcon,
    this.size = 44,
    this.radius = AppRadius.sm,
    this.fit = BoxFit.cover,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(fallbackIcon, color: AppColors.textSecondary, size: size * 0.5);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: background ?? Colors.white.withValues(alpha: 0.06),
        alignment: Alignment.center,
        child: path == null || path!.isEmpty
            ? fallback
            : Image(
                image: imageProviderFor(path!),
                width: size,
                height: size,
                fit: fit,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
