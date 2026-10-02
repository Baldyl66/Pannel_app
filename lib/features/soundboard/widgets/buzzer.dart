import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import '../soundboard_controller.dart';

/// Gros bouton « buzzer » en relief qui s'enfonce sous le doigt.
class Buzzer extends StatefulWidget {
  final SoundItem sound;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isPlaying;

  const Buzzer({super.key, required this.sound, required this.onTap, this.onLongPress, this.isPlaying = false});

  @override
  State<Buzzer> createState() => _BuzzerState();
}

class _BuzzerState extends State<Buzzer> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value) setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.sound.color;
    final hsl = HSLColor.fromColor(color);
    final base = hsl.withLightness((hsl.lightness * 0.45).clamp(0.0, 1.0)).toColor();
    final light = hsl.withLightness((hsl.lightness + 0.14).clamp(0.0, 1.0)).toColor();
    final onColor = ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;

    return Semantics(
      button: true,
      label: widget.sound.name,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) {
          _setPressed(false);
          widget.onTap();
        },
        onTapCancel: () => _setPressed(false),
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _setPressed(false);
                widget.onLongPress!();
              },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final depth = constraints.maxWidth * 0.06;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Socle + halo pendant la lecture
                Positioned.fill(
                  top: depth,
                  child: AnimatedContainer(
                    duration: AppDurations.medium,
                    decoration: BoxDecoration(
                      color: base,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: widget.isPlaying ? 0.75 : 0.22),
                          blurRadius: widget.isPlaying ? 30 : 14,
                          spreadRadius: widget.isPlaying ? 3 : 0,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 70),
                  curve: Curves.easeOutQuad,
                  top: _isPressed ? depth : 0,
                  bottom: _isPressed ? 0 : depth,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [light, color], center: const Alignment(-0.35, -0.4), radius: 0.95),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.05),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: AppDurations.fast,
                          child: Icon(
                            widget.isPlaying ? Icons.graphic_eq_rounded : widget.sound.iconData,
                            key: ValueKey(widget.isPlaying),
                            color: onColor,
                            size: constraints.maxWidth * 0.24,
                          ),
                        ),
                        SizedBox(height: constraints.maxWidth * 0.03),
                        // Les mots longs sont réduits plutôt que coupés en deux.
                        _FittedLabel(
                          text: widget.sound.name,
                          maxWidth: constraints.maxWidth * 0.88,
                          style: TextStyle(
                            color: onColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: -0.2,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.sound.loop)
                  Positioned(
                    right: constraints.maxWidth * 0.08,
                    top: constraints.maxWidth * 0.04,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.repeat_rounded, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Texte sur deux lignes maximum, réduit si son mot le plus long ne tient
/// pas dans la largeur disponible (jamais de mot coupé en deux).
class _FittedLabel extends StatelessWidget {
  final String text;
  final double maxWidth;
  final TextStyle style;

  const _FittedLabel({required this.text, required this.maxWidth, required this.style});

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    var longest = 0.0;
    for (final word in text.split(RegExp(r'\s+'))) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > longest) longest = painter.width;
      painter.dispose();
    }
    final width = longest > maxWidth ? longest + 1 : maxWidth;
    return SizedBox(
      width: maxWidth,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: width,
          child: Text(
            text,
            style: style,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
