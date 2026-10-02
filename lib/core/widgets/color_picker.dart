import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import '../utils/haptics.dart';
import 'feedback.dart';

/// Rangée de pastilles de couleurs prêtes à l'emploi, terminée par une
/// pastille arc-en-ciel qui ouvre la roue chromatique.
class ColorSwatchPicker extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onChanged;
  final double size;
  final bool allowCustom;

  const ColorSwatchPicker({
    super.key,
    this.colors = AppColors.swatches,
    required this.selected,
    required this.onChanged,
    this.size = 38,
    this.allowCustom = true,
  });

  bool _same(Color a, Color b) => a.toARGB32() == b.toARGB32();

  @override
  Widget build(BuildContext context) {
    final isCustom = !colors.any((c) => _same(c, selected));
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final color in colors)
          _Swatch(
            size: size,
            isSelected: _same(color, selected),
            fill: BoxDecoration(color: color, shape: BoxShape.circle),
            checkColor: _onColor(color),
            onTap: () {
              Haptics.selection();
              onChanged(color);
            },
            semanticLabel: 'Couleur',
          ),
        if (allowCustom)
          _Swatch(
            size: size,
            isSelected: isCustom,
            semanticLabel: 'Couleur personnalisée',
            fill: BoxDecoration(
              shape: BoxShape.circle,
              color: isCustom ? selected : null,
              gradient: isCustom ? null : const SweepGradient(colors: _rainbow),
            ),
            checkColor: _onColor(selected),
            icon: isCustom ? Icons.colorize_rounded : Icons.add_rounded,
            onTap: () async {
              final color = await showColorPickerSheet(context, initial: selected);
              if (color != null) onChanged(color);
            },
          ),
      ],
    );
  }
}

Color _onColor(Color c) => ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : Colors.black;

const _rainbow = [
  Color(0xFFFF0000),
  Color(0xFFFFFF00),
  Color(0xFF00FF00),
  Color(0xFF00FFFF),
  Color(0xFF0000FF),
  Color(0xFFFF00FF),
  Color(0xFFFF0000),
];

class _Swatch extends StatelessWidget {
  final double size;
  final bool isSelected;
  final BoxDecoration fill;
  final Color checkColor;
  final VoidCallback onTap;
  final IconData? icon;
  final String semanticLabel;

  const _Swatch({
    required this.size,
    required this.isSelected,
    required this.fill,
    required this.checkColor,
    required this.onTap,
    required this.semanticLabel,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          width: size,
          height: size,
          padding: EdgeInsets.all(isSelected ? 3 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
          ),
          child: DecoratedBox(
            decoration: fill,
            child: icon != null
                ? Icon(icon, size: size * 0.45, color: fill.gradient != null ? Colors.white : checkColor)
                : AnimatedOpacity(
                    duration: AppDurations.fast,
                    opacity: isSelected ? 1 : 0,
                    child: Icon(Icons.check_rounded, size: size * 0.45, color: checkColor),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Feuille avec roue chromatique : on choisit sa couleur au doigt, sans
/// connaître de code hexadécimal.
Future<Color?> showColorPickerSheet(BuildContext context, {required Color initial, String title = 'Choisir une couleur'}) {
  return showAppSheet<Color>(
    context,
    title: title,
    builder: (_) => _ColorPickerBody(initial: initial),
  );
}

class _ColorPickerBody extends StatefulWidget {
  final Color initial;
  const _ColorPickerBody({required this.initial});

  @override
  State<_ColorPickerBody> createState() => _ColorPickerBodyState();
}

class _ColorPickerBodyState extends State<_ColorPickerBody> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);

  Color get _color => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 260,
            height: 260,
            child: ColorWheel(
              color: _hsv,
              onChanged: (hsv) => setState(() => _hsv = hsv),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('LUMINOSITÉ', style: theme.textTheme.labelSmall),
        const SizedBox(height: AppSpacing.sm),
        _GradientSlider(
          value: _hsv.value,
          colors: [Colors.black, _hsv.withValue(1).toColor()],
          onChanged: (v) => setState(() => _hsv = _hsv.withValue(v.clamp(0.15, 1.0))),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('SUGGESTIONS', style: theme.textTheme.labelSmall),
        const SizedBox(height: AppSpacing.md),
        ColorSwatchPicker(
          selected: _color,
          allowCustom: false,
          size: 32,
          onChanged: (c) => setState(() => _hsv = HSVColor.fromColor(c)),
        ),
        const SizedBox(height: AppSpacing.xl),
        // Aperçu
        Row(
          children: [
            AnimatedContainer(
              duration: AppDurations.fast,
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.5), blurRadius: 18)],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _color, foregroundColor: _onColor(_color)),
                onPressed: () {
                  Haptics.medium();
                  Navigator.pop(context, _color);
                },
                child: const Text('Utiliser cette couleur'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Disque teinte (angle) × saturation (distance au centre).
class ColorWheel extends StatelessWidget {
  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  const ColorWheel({super.key, required this.color, required this.onChanged});

  void _handle(Offset local, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final delta = local - center;
    final distance = math.min(delta.distance / radius, 1.0);
    var angle = math.atan2(delta.dy, delta.dx) * 180 / math.pi;
    if (angle < 0) angle += 360;
    onChanged(color.withHue(angle).withSaturation(distance));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size.square(constraints.biggest.shortestSide);
        final radius = size.width / 2;
        final angle = color.hue * math.pi / 180;
        final handle = Offset(
          radius + math.cos(angle) * color.saturation * radius,
          radius + math.sin(angle) * color.saturation * radius,
        );
        return _EagerPan(
          onDown: (p) {
            Haptics.selection();
            _handle(p, size);
          },
          onUpdate: (p) => _handle(p, size),
          child: SizedBox.fromSize(
            size: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Teintes
                const DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: _rainbow)),
                  child: SizedBox.expand(),
                ),
                // Saturation : blanc au centre
                const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Colors.white, Color(0x00FFFFFF)]),
                  ),
                  child: SizedBox.expand(),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(BorderSide(color: AppColors.borderStrong)),
                  ),
                  child: SizedBox.expand(),
                ),
                Positioned(
                  left: handle.dx - 16,
                  top: handle.dy - 16,
                  child: IgnorePointer(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.toColor(),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2))],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GradientSlider extends StatelessWidget {
  final double value;
  final List<Color> colors;
  final ValueChanged<double> onChanged;

  const _GradientSlider({required this.value, required this.colors, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const height = 32.0;
        final width = constraints.maxWidth;
        void update(double dx) => onChanged((dx / width).clamp(0.0, 1.0));
        return _EagerPan(
          onDown: (p) => update(p.dx),
          onUpdate: (p) => update(p.dx),
          child: SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    gradient: LinearGradient(colors: colors),
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                ),
                Positioned(
                  left: (value * width - height / 2).clamp(0.0, width - height),
                  top: 0,
                  child: Container(
                    width: height,
                    height: height,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Glisser qui capture le doigt dès le contact, pour ne pas être volé par le
/// défilement ou la fermeture de la feuille.
class _EagerPan extends StatelessWidget {
  final ValueChanged<Offset> onDown;
  final ValueChanged<Offset> onUpdate;
  final Widget child;

  const _EagerPan({required this.onDown, required this.onUpdate, required this.child});

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        _EagerPanRecognizer: GestureRecognizerFactoryWithHandlers<_EagerPanRecognizer>(
          _EagerPanRecognizer.new,
          (r) => r
            ..onDown = ((d) => onDown(d.localPosition))
            ..onUpdate = ((d) => onUpdate(d.localPosition)),
        ),
      },
      child: child,
    );
  }
}

class _EagerPanRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
