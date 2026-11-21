// The Glass theme's building blocks, adapted from XPENC's Liquid Glass
// (https://github.com/PATILYASHH/XPENC — MIT License, Copyright (c) 2026
// Yash Patil). See CREDITS.md.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Glass, modelled on iOS's Liquid Glass, over a pure black page — the way
/// XPENC draws it. Two materials:
///  * **Content** ([GlassPane]): cards. A thin, see-through frost with a
///    rim that catches light along its top edge.
///  * **Controls** ([LiquidGlass]): what floats above content — the tab
///    bar, back buttons. Near-clear glass with real *lensing*: on Impeller a
///    fragment shader bends what's behind at the rim
///    (`shaders/liquid_glass.frag`); elsewhere it degrades to blur alone.
class GlassStyle {
  const GlassStyle._();

  /// Controls: barely any blur — the lens needs detail behind it to bend.
  static const double controlBlur = 3.5;

  /// The tab bar: whole rows of cards slide under it, so it diffuses a
  /// little more to stay calm.
  static const double barBlur = 9;
}

/// Every colour a glass surface takes. FITNS's Glass is XPENC's "ink" tone:
/// dark glass over black, iOS's dark grouped look.
@immutable
class GlassTone {
  const GlassTone._();

  /// Content pane frost, top to bottom.
  static const frostHigh = Color(0x29FFFFFF);
  static const frostLow = Color(0x1AFFFFFF);

  /// Control frost — nearly clear.
  static const controlFrost = Color(0x29FFFFFF);

  /// The selected-tab droplet.
  static const selected = Color(0x38FFFFFF);

  /// Sheets and dialogs hold forms and lists, so they frost denser.
  static const floating = Color(0xF22C2C2E);

  /// Menus and pickers Material paints with nothing blurred behind them.
  static const solidFrost = Color(0xF22C2C2E);

  /// Inputs, chips and secondary buttons.
  static const fill = Color(0x29FFFFFF);
  static const separator = Color(0x33FFFFFF);

  /// Multiplier on the white rim's brightness.
  static const rimStrength = 0.5;
  static const shadowOpacity = 0.5;
  static const barrier = Color(0x80000000);
  static const track = Color(0x3D787880);

  /// Hairline edge of inputs and plain cards.
  static const edge = Color(0x33FFFFFF);

  /// Smoked glass for the tab bar: what scrolls under it fades to a hint of
  /// its colour, and the tabs stay the brightest thing on it.
  static const barFrost = Color(0xA62C2C2E);
}

/// Whether the current theme is Glass. Read with [AppSurface.of].
@immutable
class AppSurface extends ThemeExtension<AppSurface> {
  const AppSurface({required this.glass});

  static const solid = AppSurface(glass: false);

  final bool glass;

  static AppSurface of(BuildContext context) =>
      Theme.of(context).extension<AppSurface>() ?? solid;

  static bool isGlass(BuildContext context) => of(context).glass;

  @override
  AppSurface copyWith({bool? glass}) => AppSurface(glass: glass ?? this.glass);

  @override
  AppSurface lerp(AppSurface? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

/// Loads and holds the lens shader. [program] stays `null` where the
/// renderer can't run shader filters (Skia, tests), and every glass surface
/// then falls back to blur alone.
class LiquidGlassShader {
  const LiquidGlassShader._();

  static ui.FragmentProgram? _program;
  static ui.FragmentProgram? get program => _program;

  /// Call once before `runApp`. Never throws: a failure only costs the lens.
  static Future<void> load() async {
    if (_program != null || !ui.ImageFilter.isShaderFilterSupported) return;
    try {
      _program = await ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass.frag',
      );
    } catch (e) {
      debugPrint('Liquid Glass lens unavailable: $e');
    }
  }
}

/// A content pane — a card. A thin, see-through frost in iOS's
/// continuous-corner squircle, lit from above by a light-catching rim.
///
/// No backdrop blur: behind a card is only the black page, so a blur pass
/// would cost GPU time for no visible difference.
class GlassPane extends StatelessWidget {
  const GlassPane({required this.child, required this.borderRadius, super.key});

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRSuperellipse(
      borderRadius: borderRadius,
      child: CustomPaint(
        foregroundPainter: GlassRimPainter(
          borderRadius,
          strength: 0.85 * GlassTone.rimStrength,
          continuous: true,
          topLit: true,
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              // Lit from above, like the rim: the slab is brightest where
              // the light enters it.
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [GlassTone.frostHigh, GlassTone.frostLow],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Liquid Glass — the control material. Clear, lensed glass for anything
/// that floats above content.
///
/// [borderRadius] defaults to a capsule (half the shorter side, resolved
/// from the laid-out size).
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    required this.child,
    this.borderRadius,
    this.frost,
    this.blur = GlassStyle.controlBlur,
    this.refraction = 18,
    this.band = 22,
    this.light = 1,
    this.shadow = true,
    this.backdrop = true,
    super.key,
  });

  final Widget child;
  final BorderRadius? borderRadius;

  /// Defaults to the near-clear control frost.
  final Color? frost;
  final double blur;

  /// Lens strength (logical pixels the rim pulls the backdrop inward) and
  /// the width of the curved rim band.
  final double refraction;
  final double band;

  /// How strongly the glass takes the light of what's behind it. Needs the
  /// lens shader; 0 turns it off.
  final double light;
  final bool shadow;

  /// Whether to read (blur, bend) what's behind. Off for glass that only
  /// ever sits on the plain page, where a backdrop pass shows nothing new.
  final bool backdrop;

  @override
  Widget build(BuildContext context) {
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Thickness: light pools at the top of the slab, a shade at its
          // foot.
          colors: [
            Colors.white.withValues(alpha: 0.2 * GlassTone.rimStrength),
            Colors.white.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.03),
          ],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: child,
    );
    body = DecoratedBox(
      decoration: BoxDecoration(color: frost ?? GlassTone.controlFrost),
      child: body,
    );
    final continuous = borderRadius != null;
    Widget glass = CustomPaint(
      foregroundPainter: GlassRimPainter(
        borderRadius,
        strength: GlassTone.rimStrength,
        continuous: continuous,
      ),
      child: body,
    );
    final lens = !backdrop || (blur <= 0 && refraction <= 0 && light <= 0)
        ? glass
        : _LensFilter(
            radius: borderRadius?.topLeft.x,
            blur: blur,
            refraction: refraction,
            band: band,
            light: light,
            dpr: MediaQuery.devicePixelRatioOf(context),
            screen: MediaQuery.sizeOf(context),
            child: glass,
          );
    glass = continuous
        ? ClipRSuperellipse(borderRadius: borderRadius!, child: lens)
        : ClipRRect(clipper: _GlassClipper(borderRadius), child: lens);
    if (!shadow) return glass;
    return CustomPaint(
      painter: GlassShadowPainter(
        borderRadius,
        opacity: GlassTone.shadowOpacity,
      ),
      child: glass,
    );
  }
}

/// [radius], or a capsule of whatever size the pane turned out to be.
BorderRadius _resolve(BorderRadius? radius, Size size) =>
    radius ?? BorderRadius.circular(size.shortestSide / 2);

class _GlassClipper extends CustomClipper<RRect> {
  _GlassClipper(this.radius);

  final BorderRadius? radius;

  @override
  RRect getClip(Size size) =>
      _resolve(radius, size).toRRect(Offset.zero & size);

  @override
  bool shouldReclip(_GlassClipper old) => old.radius != radius;
}

/// The backdrop filter behind a [LiquidGlass]: on Impeller the lens shader
/// (after a light blur), otherwise blur alone.
class _LensFilter extends SingleChildRenderObjectWidget {
  const _LensFilter({
    required this.radius,
    required this.blur,
    required this.refraction,
    required this.band,
    required this.light,
    required this.dpr,
    required this.screen,
    super.child,
  });

  /// `null` = a capsule, resolved from the laid-out size.
  final double? radius;
  final double blur;
  final double refraction;
  final double band;
  final double light;
  final double dpr;
  final Size screen;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLensFilter()
    ..radius = radius
    ..blur = blur
    ..refraction = refraction
    ..band = band
    ..light = light
    ..dpr = dpr
    ..screen = screen;

  @override
  void updateRenderObject(BuildContext context, _RenderLensFilter r) => r
    ..radius = radius
    ..blur = blur
    ..refraction = refraction
    ..band = band
    ..light = light
    ..dpr = dpr
    ..screen = screen;
}

class _RenderLensFilter extends RenderProxyBox {
  double? _radius;
  double _blur = 0, _refraction = 0, _band = 0, _dpr = 1, _light = 0;
  Size _screen = Size.zero;

  set radius(double? v) {
    if (_radius == v) return;
    _radius = v;
    markNeedsPaint();
  }

  set blur(double v) => _set(_blur, v, (x) => _blur = x);
  set refraction(double v) => _set(_refraction, v, (x) => _refraction = x);
  set band(double v) => _set(_band, v, (x) => _band = x);
  set dpr(double v) => _set(_dpr, v, (x) => _dpr = x);
  set light(double v) => _set(_light, v, (x) => _light = x);

  set screen(Size v) {
    if (_screen == v) return;
    _screen = v;
    markNeedsPaint();
  }

  void _set(double old, double v, void Function(double) write) {
    if (old == v) return;
    write(v);
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  final _blurLayer = LayerHandle<BackdropFilterLayer>();
  final _lensLayer = LayerHandle<BackdropFilterLayer>();

  @override
  void dispose() {
    _blurLayer.layer = null;
    _lensLayer.layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    // Two passes, not one composed filter: composing lets the engine pad
    // the shader's input by the blur radius, and the lens then can't tell
    // where the pane sits in it. Blur first, then the lens bends the
    // blurred backdrop.
    final program = LiquidGlassShader.program;
    final lens = program != null && (_refraction > 0 || _light > 0);
    if (_blur > 0) {
      _blurLayer.layer ??= BackdropFilterLayer();
      _blurLayer.layer!.filter = ui.ImageFilter.blur(
        sigmaX: _blur,
        sigmaY: _blur,
        tileMode: TileMode.mirror,
      );
    } else {
      _blurLayer.layer = null;
    }
    if (!lens) {
      _lensLayer.layer = null;
      if (_blurLayer.layer == null) {
        super.paint(context, offset);
      } else {
        context.pushLayer(_blurLayer.layer!, super.paint, offset);
      }
      return;
    }
    final origin = localToGlobal(Offset.zero) * _dpr;
    final shader = program.fragmentShader()
      // 0–1: uSize, written by the engine.
      ..setFloat(2, origin.dx)
      ..setFloat(3, origin.dy)
      ..setFloat(4, size.width * _dpr)
      ..setFloat(5, size.height * _dpr)
      ..setFloat(6, (_radius ?? size.shortestSide / 2) * _dpr)
      ..setFloat(7, _refraction * _dpr)
      ..setFloat(8, _band * _dpr)
      ..setFloat(9, 0.18)
      ..setFloat(10, 1.04)
      ..setFloat(11, _screen.width * _dpr)
      ..setFloat(12, _screen.height * _dpr)
      ..setFloat(13, _light)
      // Dark glass: the light it takes adds.
      ..setFloat(14, 1);
    _lensLayer.layer ??= BackdropFilterLayer();
    _lensLayer.layer!.filter = ui.ImageFilter.shader(shader);
    void lensPass(PaintingContext context, Offset offset) =>
        context.pushLayer(_lensLayer.layer!, super.paint, offset);
    if (_blurLayer.layer == null) {
      lensPass(context, offset);
    } else {
      context.pushLayer(_blurLayer.layer!, lensPass, offset);
    }
  }
}

/// The glyph inside a Glass back/close button: a small glass disc. Used by
/// the Glass theme's `actionIconTheme`, so every app bar's automatic back
/// button wears it with no per-screen change.
class GlassNavGlyph extends StatelessWidget {
  const GlassNavGlyph(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: LiquidGlass(
        backdrop: false,
        child: Center(
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// The rim of a glass pane: bright where light would catch it (top-left),
/// all but gone along the sides, catching again at the bottom-right.
///
/// [topLit] is the content-pane rim: light enters along the top edge and
/// fades within the first few points, with only a faint hairline below.
class GlassRimPainter extends CustomPainter {
  GlassRimPainter(
    this.radius, {
    this.strength = 1,
    this.continuous = false,
    this.topLit = false,
  });

  /// `null` = a capsule.
  final BorderRadius? radius;
  final double strength;

  /// iOS continuous (squircle) corners rather than circular ones.
  final bool continuous;
  final bool topLit;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final inner = rect.deflate(0.5);
    final Shader shader;
    if (topLit) {
      // A fixed depth, not a fraction of the pane, so a tall card and a
      // short row catch the same sliver of light.
      final lit = (28 / math.max(size.height, 1)).clamp(0.0, 0.5);
      shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        [
          Colors.white.withValues(alpha: 0.85 * strength),
          Colors.white.withValues(alpha: 0.16 * strength),
          Colors.white.withValues(alpha: 0.08 * strength),
          Colors.white.withValues(alpha: 0.14 * strength),
        ],
        [0, lit, 1 - lit * 0.5, 1],
      );
    } else {
      // Swept round the centre, so the light sits on the corners whatever
      // the shape. Angles run clockwise from 3 o'clock.
      shader = ui.Gradient.sweep(
        rect.center,
        [
          for (final a in const [
            0.22, // right
            0.6, // bottom-right
            0.05, // bottom
            0.05, // bottom-left
            0.3, // left
            0.95, // top-left — where the light comes from
            0.28, // top
            0.08, // top-right
            0.22, // right again
          ])
            Colors.white.withValues(alpha: a * strength),
        ],
        const [0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1],
      );
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = shader;
    final r = _resolve(radius, size);
    if (continuous) {
      canvas.drawRSuperellipse(r.toRSuperellipse(inner), paint);
    } else {
      canvas.drawRRect(r.toRRect(inner), paint);
    }
  }

  @override
  bool shouldRepaint(GlassRimPainter old) =>
      old.radius != radius ||
      old.strength != strength ||
      old.continuous != continuous ||
      old.topLit != topLit;
}

/// A soft drop shadow drawn only *outside* the pane — under translucent
/// glass a shadow would otherwise show through and grey the frost.
class GlassShadowPainter extends CustomPainter {
  GlassShadowPainter(this.radius, {this.opacity = 0.1});

  /// `null` = a capsule.
  final BorderRadius? radius;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = _resolve(radius, size).toRRect(Offset.zero & size);
    final side = size.shortestSide;
    final spread = (side * 0.1).clamp(3.0, 14.0);
    final lift = (side * 0.06).clamp(1.5, 6.0);
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(48)),
      Path()..addRRect(rrect),
    );
    canvas
      ..save()
      ..clipPath(outside)
      ..drawRRect(
        rrect.shift(Offset(0, lift)),
        Paint()
          ..color = Color.fromRGBO(30, 34, 60, opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, spread),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(GlassShadowPainter old) =>
      old.radius != radius || old.opacity != opacity;
}
